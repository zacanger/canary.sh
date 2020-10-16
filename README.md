<<<<<<< HEAD
# This Repository is not used anymore

Please use the new repo for Pull requests and issues at https://github.com/codefresh-io/steps/tree/master/incubating/k8s-canary-deployment


# Kubernetes deployment with canaries

This repository holds a bash script that allows you to perform canary deployments on a Kubernetes cluster.
It is part of the respective [Codefresh blog post](https://codefresh.io/kubernetes-tutorial/fully-automated-canary-deployments-kubernetes/)

## Description

The script expects you to have an existing deployment and service on your K8s cluster. It does the following:

1. Reads the existing deployment from the cluster to a yml file
1. Changes the name of the deployment and the docker image to a new version 
1. Deploys 1 replica for the new version (the canary)
1. Waits for some time (it is configurable) and checks the number of restarts
1. If everything is ok it adds more canaries and scales down the production instances
1. The cycle continues until all replicas used by the service are canaries (the production replicas are zero)

If something goes wrong (the pods have restarts) the scripts deletes all canaries and scales
back the production version to the original number of replicas


Of course during the wait period when both deployments are active, you are free to run your own additional
checks or integration tests to see if the new deployment is ok.

The canary percentage is configurable. The script will automatically calculate the phase

Example:

 * Production instance has 5 replicas
 * User enters canary waves to 35%
 * Script calculates 35% is about 2 pods
 
 | Phase | Production | Canary |
 | ------------- | ------------- |------|
 | Original | 5 | 0 |
 | A  | 5  |1 |
 | B    | 3 | 3 |
 | C    | 1 | 5 |
 | Final    | 0 | 5 |

## Prerequisites

As a convention the script expects

1. The name of your deployment to be $APP_NAME-$VERSION
1. Your service has a metadata label that shows which deployment is currently "in production"

Notice that the new color deployment created by the script will follow the same conventions. This
way each subsequent pipeline you run will work in the same manner.

You can see examples of the labels with the sample application:

* [service](example/service.yml)
* [deployment](example/deployment.yml)

## How to use the script on its own

The script needs one environment variable called `KUBE_CONTEXT` that selects the K8s cluster that will be used (if you have more than one)

The rest of the parameters are provided as command line arguments

| Parameter | Argument Number | Description     |
| ----------| --------------- | --------------- |
| Working directory   |         1       | Folder used for temp/debug files |
| Service   |         2      | Name of the existing service |
| Deployment |        3       | Name of the existing deployment |
| Traffic increment |   4        | Percentage of pods to convert to canaries at each stage |  
| Namespace |     5           | Kubernetes namespace that will be used |
| New version |       6       | Tag of the new docker image    |
| Health seconds | 7          | Time to wait before each canary stage |


Here is an example:

```
./k8s-canary-rollout.sh myService myApp 20 my-namespace 73df943 30 
```

## How to do Canary deployments in Codefresh

The script also comes with a Dockerfile that allows you to use it as a Docker image in any Docker based workflow such as Codefresh.

For the `KUBE_CONTEXT` environment variable just use the name of your cluster as found in the Codefresh Kubernetes dashboard. For the rest of the arguments you need to define them as parameters in your [codefresh.yml](example/codefresh.yml) file.

```
 canaryDeploy:
    title: "Deploying new version ${{CF_SHORT_REVISION}}"
    image: codefresh/k8s-canary:master
    environment:
      - WORKING_VOLUME=.
      - SERVICE_NAME=my-demo-app
      - DEPLOYMENT_NAME=my-demo-app
      - TRAFFIC_INCREMENT=20
      - NEW_VERSION=${{CF_SHORT_REVISION}}
      - SLEEP_SECONDS=40
      - NAMESPACE=canary
      - KUBE_CONTEXT=myDemoAKSCluster
```

The `CF_SHORT_REVISION` variable is offered by Codefresh and contains the git hash of the version that was just pushed. See all variables in the [official documentation](https://codefresh.io/docs/docs/codefresh-yaml/variables/)

## Dockerhub

The canary step is now deployed in dockerhub as well

https://hub.docker.com/r/codefresh/k8s-canary/


## Future work

Further improvements

* Make the script create an initial deployment/service if nothing is deployed in the kubernetes cluster
* Add more complex and configurable healthchecks

=======
# canary.sh

Pure Bash vanilla Kubernetes Canary rollouts

This is tested and safe to use with one caveat: if you have HPAs, this will
break them, since it creates new deployments with new names. Copying over the
HPA is a WIP feature.

--------

## Installation

Get the script, put it somewhere in PATH, and make it executable. Example:

```
curl -sSL https://git.io/canary.sh -o /usr/bin/canary.sh
chmod +x /usr/bin/canary.sh
```

## Prerequisites

* Bash 4+
* kubectl
* GNU sed (if you have both `sed` and `gsed`, the script will use `gsed`)
* An existing deployment and service. These will need to be modified slightly
  to work with this script. See [the example](./example.yml) for required
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
  HEALTHCHECK: command or path to scrip to run instead of
    Kubernetes health check. The command or script should return 0
    if healthy and anything else otherwise.
  HPA: name of Horizontal Pod Autoscaler if there's one targeting
    this deployment.

See https://github.com/jane/canary.sh for details.
```

<<<<<<< HEAD
[LICENSE](./LICENSE.md)
>>>>>>> 209057a... chore: add all the stuff
=======
## Contributing

Pull requests and issues are welcome. See
[CONTRIBUTING](./.github/CONTRIBUTING.md) for details.

## Credits and License

Originally forked from
<https://github.com/codefresh-io/k8s-canary-deployment> (MIT licensed).
There's a later version in <https://github.com/codefresh-io/steps>.
Heavily modified to work without Codefresh, allow more options, include
better logs and usage messages, treat strings safely, and various other
changes.

[LICENSE (MIT)](./LICENSE.md)
>>>>>>> 462fa53... docs: links, better help, etc
