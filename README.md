# Kindle
This is a good starting point for K8s-related development or testing.

For additional config options for the "tehcyx/kind" TF provider, look [here](https://github.com/tehcyx/terraform-provider-kind/blob/master/docs/resources/cluster.md)

## Quickstart
```
> terraform init
> terraform plan
...
Terraform will perform the following actions:

  # kind_cluster.kindle will be created
  + resource "kind_cluster" "kindle" {
      + client_certificate     = (known after apply)
      + client_key             = (known after apply)
      + cluster_ca_certificate = (known after apply)
      + kubeconfig             = (known after apply)
      + kubeconfig_path        = (known after apply)
    }

Plan: 1 to add, 0 to change, 0 to destroy.
...
```
These very import variables will be written to a file in your local project directory called `kindle-config`. With a little bit of luck, your `kubectl` will use that file when you're in this directory.

```
> terraform apply
...
kind_cluster.kindle: Still creating... [3m30s elapsed]
kind_cluster.kindle: Creation complete after 3m35s [id=kindle-kindest/node:v1.23.4]
...
...
> kubectl get pods -n kube-system
NAMESPACE            NAME                                           READY   STATUS    RESTARTS   AGE
kube-system          coredns-64897985d-rgbcq                        1/1     Running   0          66s
kube-system          coredns-64897985d-w6z57                        1/1     Running   0          66s
kube-system          etcd-kindle-control-plane                      1/1     Running   0          80s
kube-system          kindnet-mtwjd                                  1/1     Running   0          47s
kube-system          kindnet-rz4pq                                  1/1     Running   0          66s
kube-system          kindnet-x6d87                                  1/1     Running   0          47s
kube-system          kube-apiserver-kindle-control-plane            1/1     Running   0          80s
kube-system          kube-controller-manager-kindle-control-plane   1/1     Running   0          84s
kube-system          kube-proxy-5qf99                               1/1     Running   0          47s
kube-system          kube-proxy-m26nd                               1/1     Running   0          47s
kube-system          kube-proxy-mrjq9                               1/1     Running   0          66s
kube-system          kube-scheduler-kindle-control-plane            1/1     Running   0          83s
local-path-storage   local-path-provisioner-5ddd94ff66-sk2nn        1/1     Running   0          66
```

## Basic Services

First things first, please add a cheeky line to your `/etc/hosts` file:
```
127.0.0.1 kind-registry kind-registry.local argocd.local
```

Now, at a minimum, our K8s cluster needs a few things to run. These have all been installed: 

 - `kube-apiserver`
 - `etcd`
 - `kube-scheduler`
 - `kube-controller-manager`

The default network overlay for Kind is called `kindnet`, and we can see this in the list of runninng pods.

I'm running Docker desktop for a container runtime on my Mac. Interestingly, Kind is running `containerd` as the container runtime inside the cluster.

We've configured the API server to run on 127.0.0.1:6443 and avoided being assigned a random port by Kind. This might pave the way for standardizing our `kube-config` (and potentially storing it in source control) later.

For now let's just verify that the port config option is working:
```
> curl -k https://localhost:6443/apis/apps/v1/namespaces/kube-system/deployments
{
  "kind": "Status",
  "apiVersion": "v1",
  "metadata": {},
  "status": "Failure",
  "message": "deployments.apps is forbidden: User \"system:anonymous\" cannot list resource \"deployments\" in API group \"apps\" in the namespace \"kube-system\"",
  "reason": "Forbidden",
  "details": {
    "group": "apps",
    "kind": "deployments"
  },
  "code": 403
```

Quite a few Kind config options exist and it's fun/interesting to explore them. They're documented [here](https://kind.sigs.k8s.io/docs/user/configuration/)

We're using the [`helm` provider](https://registry.terraform.io/providers/hashicorp/helm/latest/docs) in our Terraform config. This is going to depend on some configuration in your local workstation. If you've used helm before, then most likely this is already set up. Maybe consider runnning `helm repo update` to verify that everything is working as it should. In practice, these are the most time-consuming steps in the project: evaluating requirements and dependencies, downloading helm charts, downloading sometimes very large container images. We've gone ahead and set the Terraform resource create timeout at 15 minutes (900 seconds) for each of these.

Helm in Terraform is going to install some necessaries for you:
 - [`cert-manager`](https://cert-manager.io/docs/getting-started/)
 - [`nginx-ingress-controller`](https://kubernetes.github.io/ingress-nginx/deploy/)
 - [`argocd`](https://kubebyexample.com/learning-paths/argo-cd/argo-cd-getting-started)

The Terraform config here uses a module to install and configure ArgoCD on our Kind cluster. You'll want to get the ArgoCD client onto your local machine and have a look at the fine manual: https://argo-cd.readthedocs.io/en/stable/getting_started/

https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd
https://registry.terraform.io/modules/aigisuk/argocd/kubernetes/latest

Some more steps to do in here: 
https://kubebyexample.com/learning-paths/argo-cd/argo-cd-getting-started
https://magmax.org/en/blog/argocd/

This stuff could be better understood: 
https://kind.sigs.k8s.io/docs/user/ingress/

This helps:
```
> kubectl port-forward svc/argocd-server -n argocd 8080:443 &
> curl localhost:8080
Handling connection for 8080
<!doctype html><html lang="en"><head><meta charset="UTF-8"><title>Argo CD</title><base href="/"><meta name="viewport" content="width=device-width,initial-scale=1"><link rel="icon" type="image/png" href="assets/favicon/favicon-32x32.png" sizes="32x32"/><link rel="icon" type="image/png" href="assets/favicon/favicon-16x16.png" sizes="16x16"/><link href="assets/fonts.css" rel="stylesheet"><script defer="defer" src="main.c87b5e37f99fc2a30256.js"></script></head><body><noscript><p>Your browser does not support JavaScript. Please enable JavaScript to view the site. Alternatively, Argo CD can be used with the <a href="https://argoproj.github.io/argo-cd/cli_installation/">Argo CD CLI</a>.</p></noscript><div id="app"></div></body><script defer="defer" src="extensions.js"></script></html>%
```

## Day 2

Soon.
At this point we're happy to take configuration duties inside your `kind` cluster away from Terraform and hand them over to ArgoCD.

https://argo-cd.readthedocs.io/en/stable/getting_started/
