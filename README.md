# [canary.sh](https://jane.github.io/canary.sh)

Pure Bash vanilla Kubernetes Canary rollouts

--------

## Installation

Get the script, put it somewhere in PATH, and make it executable. Example:

```bash
curl -sSL https://git.io/canary.sh -o /usr/local/bin/canary.sh
# Always verify the contents of anything you curl down before running!
less /usr/local/bin/canary/sh
chmod +x /usr/local/bin/canary.sh
canary.sh -h
```

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
  HEALTHCHECK: path to executable to run instead of
    Kubernetes health check. The command or script should return 0
    if healthy and anything else otherwise.
  HPA: name of Horizontal Pod Autoscaler if there's one targeting
    this deployment.
  ON_FAILURE: path to executable to run if the canary healthcheck
    fails and rolls back.
  WORKING_DIR: defaults to $(mktemp -d).

See https://github.com/jane/canary.sh for details.
```

## Example

```bash
NAMESPACE=canary-test \
  VERSION=v1.0.1 \
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
apiVersion: v1
kind: Service
metadata:
  namespace: canary-test
  name: awesome-app
  labels:
    # Version label is required
    version: v1.0.0
spec:
  ports:
  - port: 3000
    targetPort: 3000
    protocol: TCP
  selector:
    app: awesome-app
---
apiVersion: apps/v1
kind: Deployment
metadata:
  namespace: canary-test
  # Version appended to name is required
  name: awesome-app-v1.0.0
spec:
  selector:
    matchLabels:
      app: awesome-app
  replicas: 7
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        # App label is required
        app: awesome-app
    spec:
      containers:
      - image: 'awesome-app:v1.0.0'
        name: awesome-app
        ports:
        - containerPort: 3000
        env:
        - name: NODE_ENV
          value: 'production'
      restartPolicy: Always
---
# If using an HPA, make sure you provide the name as a variable,
# otherwise your HPA will continue targeting the previous deployment.
apiVersion: autoscaling/v1
kind: HorizontalPodAutoscaler
metadata:
  namespace: canary-test
  name: awesome-app
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    # Name target with version appended is required
    name: awesome-app-v1.0.0
  minReplicas: 7
  maxReplicas: 14
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
