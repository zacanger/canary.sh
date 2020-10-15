#!/usr/bin/env bash
set -e

canarysh_repo='https://github.com/jane/canary.sh'
canarysh=$(basename "$0")
# TODO: change below when done debugging
# working_dir=$(mktemp -d)
working_dir=$(pwd)
canary_deployment=$DEPLOYMENT-$NEW_VERSION

# GNU sed only. This is specified in the readme.
if hash gsed 2>/dev/null; then
  _sed=$(which gsed)
else
  _sed=$(which sed)
fi

usage() {
  cat <<EOF
$canarysh usage example:

NAMESPACE=books \\
  NEW_VERSION=v1.0.1 \\
  INTERVAL=30 \\
  TRAFFIC_INCREMENT=20 \\
  DEPLOYMENT=book-ratings \\
  SERVICE=book-ratings-loadbalancer \\
  $canarysh

These options would deploy version \`v1.0.1\` of \`book-ratings\` using the
image found in the previous version of the deployment with an updated
tag, in the \`books\` namespace, with traffic coming from the
\`book-ratings-loadbalancer\` service, migrating 20% of traffic at a time
to the new version at 30 second intervals.

Optional variables:
  KUBE_CONTEXT: defaults to currently selected context.
  CUSTOM_HEALTHCHECK: absolute path to script to run rather than using
    Kubernetes health check. This should return 0 if healthy and
    anything else otherwise.

See $canarysh_repo for details.
EOF

  # Passed 0 or 1 from validate function
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
    [ -z "$SERVICE" ] || \
    [ -z "$DEPLOYMENT" ] || \
    [ -z "$TRAFFIC_INCREMENT" ] || \
    [ -z "$NAMESPACE" ] || \
    [ -z "$INTERVAL" ]; then
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
      -l app="$canary_deployment" \
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

  echo "[$canarysh ${FUNCNAME[0]}] Restoring original deployment to $prod_deployment"
  kubectl apply \
    --force \
    -f "$working_dir/original_deployment.yml" \
    -n "$NAMESPACE"
  kubectl rollout status "deployment/$prod_deployment" -n "$NAMESPACE"

  echo "[$canarysh ${FUNCNAME[0]}] Removing canary deployment completely"
  kubectl delete deployment "$canary_deployment" -n "$NAMESPACE"

  # echo "[$canarysh ${FUNCNAME[0]}] Removing canary HPA completely"
  # kubectl delete hpa "$canary_deployment" -n "$NAMESPACE"

  exit 1
}

cleanup() {
  echo "[$canarysh ${FUNCNAME[0]}] Removing previous deployment $prod_deployment"
  kubectl delete deployment "$prod_deployment" -n "$NAMESPACE"

  # echo "[$canarysh ${FUNCNAME[0]}] Removing previous HPA $prod_deployment"
  # kubectl delete hpa "$prod_deployment" -n "$NAMESPACE"

  echo "[$canarysh ${FUNCNAME[0]}] Marking canary as new production"
  kubectl get service "$SERVICE" -o=yaml --namespace="${NAMESPACE}" | \
    $_sed -e "s/$current_version/$NEW_VERSION/g" | \
    kubectl apply --namespace="${NAMESPACE}" -f -
}

increment_traffic() {
  percent=$1
  replicas=$2

  echo "[$canarysh ${FUNCNAME[0]}] Increasing canaries to $percent percent, max replicas is $replicas"

  prod_replicas=$(kubectl get deployment \
    "$prod_deployment" \
    -n "$NAMESPACE" \
    -o=jsonpath='{.spec.replicas}')

  canary_replicas=$(kubectl get deployment \
    "$canary_deployment" \
    -n "$NAMESPACE" -o=jsonpath='{.spec.replicas}')

  echo "[$canarysh ${FUNCNAME[0]}] Production has now $prod_replicas replicas, canary has $canary_replicas replicas"

  # This gets the floor for pods, 2.69 will equal 2
  increment=$(((percent*replicas*100)/(100-percent)/100))

  echo "[$canarysh ${FUNCNAME[0]}] Incrementing canary and decreasing production for $increment replicas"

  new_prod_replicas=$((prod_replicas-increment))
  # Sanity check
  if [ "$new_prod_replicas" -lt "0" ]; then
    new_prod_replicas=0
  fi

  new_canary_replicas=$((canary_replicas+increment))
  # Sanity check
  if [ "$new_canary_replicas" -ge "$replicas" ]; then
    new_canary_replicas=$replicas
    new_prod_replicas=0
  fi

  echo "[$canarysh ${FUNCNAME[0]}] Setting canary replicas to $new_canary_replicas"
  kubectl -n "$NAMESPACE" scale --replicas="$new_canary_replicas" "deploy/$canary_deployment"

  echo "[$canarysh ${FUNCNAME[0]}] Setting production replicas to $new_prod_replicas"
  kubectl -n "$NAMESPACE" scale --replicas=$new_prod_replicas "deploy/$prod_deployment"

  # Wait a bit until production instances are down. This should always succeed
  kubectl -n "$NAMESPACE" rollout status "deployment/$prod_deployment"
}

copy_deployment() {
  # Replace old deployment name with new
  $_sed -Ei -- "s/name\: $prod_deployment/name: $canary_deployment/g" "$working_dir/canary_deployment.yml"
  echo "[$canarysh ${FUNCNAME[0]}] Replaced deployment name"

  # Replace docker image
  $_sed -Ei -- "s/$current_version/$NEW_VERSION/g" "$working_dir/canary_deployment.yml"
  echo "[$canarysh ${FUNCNAME[0]}] Replaced image name"
  echo "[$canarysh ${FUNCNAME[0]}] Production deployment is $prod_deployment, canary is $canary_deployment"
}

main() {
  if [ -n "$KUBE_CONTEXT" ]; then
    echo "[$canarysh ${FUNCNAME[0]}] Setting Kubernetes context"
    kubectl config use-context "${KUBE_CONTEXT}"
  fi

  echo "[$canarysh ${FUNCNAME[0]}] Getting current version"
  current_version=$(kubectl get service "$SERVICE" -o=jsonpath='{.metadata.labels.version}' --namespace="${NAMESPACE}")

  if [ -z "$current_version" ]; then
    echo "[$canarysh ${FUNCNAME[0]}] No current version found"
    echo "[$canarysh ${FUNCNAME[0]}] Do you have metadata.labels.version set?"
    echo "[$canarysh ${FUNCNAME[0]}] Aborting"
    exit 1
  fi

  if [ "$current_version" == "$NEW_VERSION" ]; then
   echo "[$canarysh ${FUNCNAME[0]}] NEW_VERSION matches current_version: $current_version"
   exit 0
  fi

  echo "[$canarysh ${FUNCNAME[0]}] Current version is $current_version"
  prod_deployment=$DEPLOYMENT-$current_version

  echo "[$canarysh ${FUNCNAME[0]}] Getting current deployment"
  kubectl get deployment "$prod_deployment" -n "$NAMESPACE" -o=yaml > "$working_dir/canary_deployment.yml"

  echo "[$canarysh ${FUNCNAME[0]}] Backing up original deployment"
  cp "$working_dir/canary_deployment.yml" "$working_dir/original_deployment.yml"

  echo "[$canarysh ${FUNCNAME[0]}] Finding current replicas"

  # Copy existing deployment and update image only
  copy_deployment

  starting_replicas=$(kubectl get deployment "$prod_deployment" -n "$NAMESPACE" -o=jsonpath='{.spec.replicas}')
  echo "[$canarysh ${FUNCNAME[0]}] Found replicas $starting_replicas"

  # Launch one replica first
  $_sed -Ei -- "s#replicas: $starting_replicas#replicas: 1#g" "$working_dir/canary_deployment.yml"
  echo "[$canarysh ${FUNCNAME[0]}] Launching 1 pod with canary"
  kubectl apply -f "$working_dir/canary_deployment.yml" -n "$NAMESPACE"

  echo "[$canarysh ${FUNCNAME[0]}] Waiting for canary pod"
  while [ "$(kubectl get pods -l app="$canary_deployment" -n "$NAMESPACE" --no-headers | wc -l)" -eq 0 ]; do
    sleep 2
  done

  echo "[$canarysh ${FUNCNAME[0]}] Canary target replicas: $starting_replicas"

  healthcheck

  while [ "$TRAFFIC_INCREMENT" -lt 100 ]; do
    p=$((p + "$TRAFFIC_INCREMENT"))
    if [ "$p" -gt "100" ]; then
      p=100
    fi
    echo "[$canarysh ${FUNCNAME[0]}] Rollout is at $p percent"

    increment_traffic "$TRAFFIC_INCREMENT" "$starting_replicas"

    if [ "$p" == "100" ]; then
      cleanup
      echo "[$canarysh ${FUNCNAME[0]}] Done"
      exit 0
    fi

    echo "[$canarysh ${FUNCNAME[0]}] Sleeping for $INTERVAL seconds"
    sleep "$INTERVAL"
    healthcheck
  done
}

validate "$@"
main
