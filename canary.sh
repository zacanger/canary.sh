#!/usr/bin/env bash
set -e

canarysh=$(basename "$0")
usage() {
  cat <<EOF
$canarysh usage example:

NAMESPACE=books \\
  NEW_VERSION=v1.0.1 \\
  SLEEP_SECONDS=30 \\
  TRAFFIC_INCREMENT=20 \\
  DEPLOYMENT_NAME=book-ratings \\
  SERVICE_NAME=book-ratings-loadbalancer \\
  $canarysh

These options would deploy version \`v1.0.1\` of \`book-ratings\` using the
image found in the previous version of the deployment with an updated
tag, in the \`books\` namespace, with traffic coming from the
\`book-ratings-loadbalancer\` service, migrating 20% of traffic at a time
to the new version at 30 second intervals.

Optional variables:
  WORKING_DIR: defaults to pwd.
  KUBE_CONTEXT: defaults to currently selected context.
  INPUT_DEPLOYMENT: YAML string for replacement deployment, defaults
    to using current deployment with updated version.
  CUSTOM_HEALTHCHECK: absolute path to script to run rather than using
    Kubernetes health check. This should return 0 if healthy and
    anything else otherwise.
EOF

  exit "$1"
}

# TODO: Should we switch to using getopt/getopts
# rather than env vars?
validate() {
  if ! hash kubectl 2>/dev/null; then
    echo "$canarysh: kubectl is required to use this program"
    exit 1
  fi

  # Match --help, -help, -h, help
  if [[ "$1" =~ "help" ]] || [[ "$1" =~ "-h" ]]; then
    usage 0
  fi

  if [ -z "$NEW_VERSION" ] || \
    [ -z "$SERVICE_NAME" ] || \
    [ -z "$DEPLOYMENT_NAME" ] || \
    [ -z "$TRAFFIC_INCREMENT" ] || \
    [ -z "$NAMESPACE" ] || \
    [ -z "$SLEEP_SECONDS" ]; then
    usage 1
  fi
}

healthcheck() {
  echo "[$canarysh ${FUNCNAME[0]}] Starting healthcheck"
  h=true

  # TODO: does this work?
  if [ -n "$CUSTOM_HEALTHCHECK" ]; then
    # Run whatever the user provided, check its exit code
    "$CUSTOM_HEALTHCHECK"
    # TODO:
    # shellcheck disable=SC2181
    if [ $? -ne 0 ]; then
      h=false
    fi
  else
    # K8s healthcheck
    output=$(kubectl get pods \
      -l app="$CANARY_DEPLOYMENT" \
      -n "$NAMESPACE" \
      --no-headers)

    echo "[$canarysh ${FUNCNAME[0]}] $output"
    # TODO:
    # shellcheck disable=SC2207
    s=($(echo "$output" | awk '{s+=$4}END{print s}'))
    # TODO:
    # shellcheck disable=SC2207
    # c=($(echo "$output" | wc -l))
    # if [ "$c" -lt "1" ]; then
    #     h=false
    # fi

    # TODO:
    # shellcheck disable=SC2128
    if [ "$s" -gt "2" ]; then
      h=false
    fi
  fi

  if [ ! $h == true ]; then
    cancel
    echo "[$canarysh ${FUNCNAME[0]}] Canary is unhealthy"
  else
    echo "[$canarysh ${FUNCNAME[0]}] Service healthy"
  fi
}

cancel() {
  echo "[$canarysh ${FUNCNAME[0]}] Healthcheck failed; canceling rollout"

  echo "[$canarysh ${FUNCNAME[0]}] Restoring original deployment to $PROD_DEPLOYMENT"
  kubectl apply \
    --force \
    -f "$WORKING_DIR/original_deployment.yaml" \
    -n "$NAMESPACE"
  kubectl rollout status "deployment/$PROD_DEPLOYMENT" -n "$NAMESPACE"

  echo "[$canarysh ${FUNCNAME[0]}] Removing canary deployment completely"
  kubectl delete deployment "$CANARY_DEPLOYMENT" -n "$NAMESPACE"

  echo "[$canarysh ${FUNCNAME[0]}] Removing canary HPA completely"
  kubectl delete hpa "$CANARY_DEPLOYMENT" -n "$NAMESPACE"

  exit 1
}

cleanup() {
  echo "[$canarysh ${FUNCNAME[0]}] Removing previous deployment $PROD_DEPLOYMENT"
  kubectl delete deployment "$PROD_DEPLOYMENT" -n "$NAMESPACE"

  echo "[$canarysh ${FUNCNAME[0]}] Removing previous HPA $PROD_DEPLOYMENT"
  kubectl delete hpa "$PROD_DEPLOYMENT" -n "$NAMESPACE"

  echo "[$canarysh ${FUNCNAME[0]}] Marking canary as new production"
  kubectl get service "$SERVICE_NAME" -o=yaml --namespace="${NAMESPACE}" | \
    sed -e "s/$CURRENT_VERSION/$NEW_VERSION/g" | \
    kubectl apply --namespace="${NAMESPACE}" -f -
}

increment_traffic() {
  percent=$1
  starting_replicas=$2

  echo "[$canarysh ${FUNCNAME[0]}] Increasing canaries to $percent percent, max replicas is $starting_replicas"

  prod_replicas=$(kubectl get deployment \
    "$PROD_DEPLOYMENT" \
    -n "$NAMESPACE" \
    -o=jsonpath='{.spec.replicas}')

  canary_replicas=$(kubectl get deployment \
    "$CANARY_DEPLOYMENT" \
    -n "$NAMESPACE" -o=jsonpath='{.spec.replicas}')

  echo "[$canarysh ${FUNCNAME[0]}] Production has now $prod_replicas replicas, canary has $canary_replicas replicas"

  # This gets the floor for pods, 2.69 will equal 2
  # TODO:
  # shellcheck disable=SC2219
  let increment="($percent*$starting_replicas*100)/(100-$percent)/100"

  echo "[$canarysh ${FUNCNAME[0]}] Incrementing canary and decreasing production for $increment replicas"

  # TODO:
  # shellcheck disable=SC2219
  let new_prod_replicas="$prod_replicas-$increment"
  # Sanity check
  if [ "$new_prod_replicas" -lt "0" ]; then
    new_prod_replicas=0
  fi

  # TODO:
  # shellcheck disable=SC2219
  let new_canary_replicas="$canary_replicas+$increment"
  # Sanity check
  if [ "$new_canary_replicas" -ge "$starting_replicas" ]; then
    new_canary_replicas=$starting_replicas
    new_prod_replicas=0
  fi

  echo "[$canarysh ${FUNCNAME[0]}] Setting canary replicas to $new_canary_replicas"
  kubectl -n "$NAMESPACE" scale --replicas="$new_canary_replicas" "deploy/$CANARY_DEPLOYMENT"

  echo "[$canarysh ${FUNCNAME[0]}] Setting production replicas to $new_prod_replicas"
  kubectl -n "$NAMESPACE" scale --replicas=$new_prod_replicas "deploy/$PROD_DEPLOYMENT"

  # Wait a bit until production instances are down. This should always succeed
  kubectl -n "$NAMESPACE" rollout status "deployment/$PROD_DEPLOYMENT"

  # Calulate increments. N = the number of starting pods, I = Increment value, X = how many pods to add
  # x / (N + x) = I
  # Starting pods N = 5
  # Desired increment I = 0.35
  # Solve for X
  # X / (5+X)= 0.35
  # X = .35(5+x)
  # X = 1.75 + .35x
  # X-.35X=1.75
  # .65X = 1.75
  # X = 35/13
  # X = 2.69
  # X = 3
  # 5+3 = 8 #3/8 = 37.5%
  # Round		A 	B
  # 1			5	3
  # 2			2	6
  # 3			0	5
}

copy_deployment() {
  # Replace old deployment name with new
  sed -Ei -- "s/name\: $PROD_DEPLOYMENT/name: $CANARY_DEPLOYMENT/g" "$WORKING_DIR/canary_deployment.yaml"
  echo "[$canarysh ${FUNCNAME[0]}] Replaced deployment name"

  # Replace docker image
  sed -Ei -- "s/$CURRENT_VERSION/$NEW_VERSION/g" "$WORKING_DIR/canary_deployment.yaml"
  echo "[$canarysh ${FUNCNAME[0]}] Replaced image name"
  echo "[$canarysh ${FUNCNAME[0]}] Production deployment is $PROD_DEPLOYMENT, canary is $CANARY_DEPLOYMENT"
}

# TODO: does this work?
input_deployment() {
  echo "${INPUT_DEPLOYMENT}" > "${WORKING_DIR}/canary_deployment.yaml"
}

main() {
  if [ -n "$KUBE_CONTEXT" ]; then
    echo "[$canarysh ${FUNCNAME[0]}] Setting Kubernetes context"
    kubectl config use-context "${KUBE_CONTEXT}"
  fi

  echo "[$canarysh ${FUNCNAME[0]}] Getting current version"
  CURRENT_VERSION=$(kubectl get service "$SERVICE_NAME" -o=jsonpath='{.metadata.labels.version}' --namespace="${NAMESPACE}")

  if [ "$CURRENT_VERSION" == "$NEW_VERSION" ]; then
   echo "[$canarysh ${FUNCNAME[0]}] NEW_VERSION matches CURRENT_VERSION: $CURRENT_VERSION"
   exit 0
  fi

  echo "[$canarysh ${FUNCNAME[0]}] Current version is $CURRENT_VERSION"
  PROD_DEPLOYMENT=$DEPLOYMENT_NAME-$CURRENT_VERSION

  echo "[$canarysh ${FUNCNAME[0]}] Getting current deployment"
  kubectl get deployment "$PROD_DEPLOYMENT" -n "$NAMESPACE" -o=yaml > "$WORKING_DIR/canary_deployment.yaml"

  echo "[$canarysh ${FUNCNAME[0]}] Backing up original deployment"
  cp "$WORKING_DIR/canary_deployment.yaml" "$WORKING_DIR/original_deployment.yaml"

  echo "[$canarysh ${FUNCNAME[0]}] Getting current container image"
  IMAGE=$(kubectl get deployment "$PROD_DEPLOYMENT" -n "$NAMESPACE" -o=yaml | grep image: | sed -E 's/.*image: (.*)/\1/')
  echo "[$canarysh ${FUNCNAME[0]}] Found image $IMAGE"
  echo "[$canarysh ${FUNCNAME[0]}] Finding current replicas"

  # TODO: does this work?
  if [[ -n ${INPUT_DEPLOYMENT} ]]; then
    input_deployment

    if ! STARTING_REPLICAS=$(grep "replicas:" < "${WORKING_DIR}/canary_deployment.yaml" | awk '{print $2}'); then
      echo "[$canarysh ${FUNCNAME[0]}] Failed getting replicas from input file: ${WORKING_DIR}/canary_deployment.yaml"
      echo "[$canarysh ${FUNCNAME[0]}] Using the same number of replicas from prod deployment"
      STARTING_REPLICAS=$(kubectl get deployment "$PROD_DEPLOYMENT" -n "$NAMESPACE" -o=jsonpath='{.spec.replicas}')
    fi
  else
    # Copy existing deployment and update image only
    copy_deployment

    STARTING_REPLICAS=$(kubectl get deployment "$PROD_DEPLOYMENT" -n "$NAMESPACE" -o=jsonpath='{.spec.replicas}')
    echo "[$canarysh ${FUNCNAME[0]}] Found replicas $STARTING_REPLICAS"
  fi

  # Start with one replica
  sed -Ei -- "s#replicas: $STARTING_REPLICAS#replicas: 1#g" "$WORKING_DIR/canary_deployment.yaml"
  echo "[$canarysh ${FUNCNAME[0]}] Launching 1 pod with canary"

  # Launch canary
  kubectl apply -f "$WORKING_DIR/canary_deployment.yaml" -n "$NAMESPACE"

  echo "[$canarysh ${FUNCNAME[0]}] Awaiting canary pod..."
  while [ "$(kubectl get pods -l app="$CANARY_DEPLOYMENT" -n "$NAMESPACE" --no-headers | wc -l)" -eq 0 ]; do
    sleep 2
  done

  echo "[$canarysh ${FUNCNAME[0]}] Canary target replicas: $STARTING_REPLICAS"

  healthcheck

  while [ "$TRAFFIC_INCREMENT" -lt 100 ]; do
    p=$((p + "$TRAFFIC_INCREMENT"))
    if [ "$p" -gt "100" ]; then
      p=100
    fi
    echo "[$canarysh ${FUNCNAME[0]}] Rollout is at $p percent"

    increment_traffic "$TRAFFIC_INCREMENT" "$STARTING_REPLICAS"

    if [ "$p" == "100" ]; then
      cleanup
      echo "[$canarysh ${FUNCNAME[0]}] Done"
      exit 0
    fi

    echo "[$canarysh ${FUNCNAME[0]}] Sleeping for $SLEEP_SECONDS seconds"
    sleep "$SLEEP_SECONDS"
    healthcheck
  done
}

if [ -z "$WORKING_DIR" ]; then
  WORKING_DIR=$(pwd)
fi
WORKING_DIR=${WORKING_DIR%/}
CANARY_DEPLOYMENT=$DEPLOYMENT_NAME-$NEW_VERSION
validate "$@"
main
