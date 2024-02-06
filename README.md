# canary.sh

Pure Bash vanilla Kubernetes Canary rollouts

--------

## Installation

Get the script, put it somewhere in PATH, and make it executable. Example:

```bash
curl \
  -sSL \
  https://raw.githubusercontent.com/zacanger/canary.sh/master/canary.sh \
  -o /usr/local/bin/canary.sh
# Always verify the contents of anything you curl down before running!
less /usr/local/bin/canary.sh
chmod +x /usr/local/bin/canary.sh
canary.sh -h
```

You can also get specific tags or commits. Example:

```bash
curl -sSL https://raw.githubusercontent.com/zacanger/canary.sh/v0.4.0/canary.sh -o canary.sh
```

See the [changelog](./CHANGELOG.md) for history.

## Prerequisites

* Bash 4+
* kubectl
* GNU sed (if you have both `sed` and `gsed`, the script will use `gsed`)
* An existing deployment and service. These will need to be modified slightly
  to work with this script. See the example below for details on the required
  changes.

## Usage

```
$ canary.sh -h

canary.sh usage example:

NAMESPACE=books \
  VERSION=v1.0.1 \
  INTERVAL=30 \
  TRAFFIC_INCREMENT=20 \
  DEPLOYMENT=book-ratings \
  SERVICE=book-ratings-loadbalancer \
  canary.sh

These options would deploy version `v1.0.1` of `book-ratings` using the
image found in the previous version of the deployment with an updated
tag, in the `books` namespace, with traffic coming from the
`book-ratings-loadbalancer` service, migrating 20% of traffic at a time
to the new version at 30 second intervals.

Optional variables:
  KUBE_CONTEXT: defaults to currently selected context.
  HEALTHCHECK: path to executable to run instead of basing health
    on pod restarts. The command or script should return 0
    if healthy and anything else otherwise. If nothing is specified,
    pod restarts are used (see Kubernetes docs for probes).
  HPA: name of Horizontal Pod Autoscaler if there's one targeting
    this deployment.
  ON_FAILURE: path to executable to run if the canary healthcheck
    fails and rolls back.
  WORKING_DIR: defaults to $(mktemp -d).

See https://github.com/zacanger/canary.sh for details.
```

## Example

```bash
NAMESPACE=canary-test \
  VERSION=v0.0.2 \
  INTERVAL=60 \
  TRAFFIC_INCEMENT=20 \
  DEPLOYMENT=awesome-app \
  SERVICE=awesome-app \
  HPA=awesome-app \                # optional var
  HEALTHCHECK=/path/to/my/script \ # optional var
  ON_FAILURE=/path/to/script \     # optional var
  KUBE_CONTEXT=context \           # optional var
  WORKING_DIR=$(pwd) \             # optional var
  canary.sh
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    somecompany.app: awesome-app
  # Append version to name
  name: awesome-app-0.0.1
spec:
  selector:
    matchLabels:
      somecompany.app: awesome-app
  replicas: 7
  template:
    metadata:
      labels:
        # Add app label with name and version
        app: awesome-app-0.0.1
        somecompany.app: awesome-app
    spec:
      containers:
      - image: 'some-repo/awesome-app:0.0.1'
        name: awesome-app
        resources:
          limits:
            cpu: 2000m
            memory: 2Gi
          requests:
            cpu: 1000m
            memory: 1Gi
        livenessProbe:
          httpGet:
            path: /.health/alive
            port: 80
        readinessProbe:
          httpGet:
            path: /.health/ready
            port: 80
        ports:
        - containerPort: 80
        env:
          - name: FOO
            value: 'bar'
      restartPolicy: Always
---
apiVersion: v1
kind: Service
metadata:
  labels:
    somecompany.app: awesome-app
    # Add version label
    version: 0.0.1
  name: awesome-app
spec:
  type: LoadBalancer
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 21600
  ports:
  - name: https
    port: 443
    targetPort: 80
  selector:
    somecompany.app: awesome-app
---
apiVersion: autoscaling/v1
kind: HorizontalPodAutoscaler
metadata:
  name: awesome-app
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    # Append version to match deployment name if using an HPA
    name: awesome-app-0.0.1
  minReplicas: 7
  maxReplicas: 20
  targetCPUUtilizationPercentage: 70
```

## Contributing

Pull requests and issues are welcome. See
[CONTRIBUTING](./.github/CONTRIBUTING.md) for details.

## Credits and License

Originally forked from <https://github.com/codefresh-io/k8s-canary-deployment>
(MIT licensed). Heavily modified to work without Codefresh, allow more options,
include better logs and usage messages, treat strings safely, allow custom
healthchecks, allow running scripts on failure, work with Horizontal Pod
Autoscalers, and other changes.

[LICENSE (MIT)](./LICENSE.md)
