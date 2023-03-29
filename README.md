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
      + completed              = (known after apply)
      + endpoint               = (known after apply)
      + id                     = (known after apply)
      + kubeconfig             = (known after apply)
      + kubeconfig_path        = (known after apply)
      + name                   = "kindle"
      + node_image             = "kindest/node:v1.23.4"
      + wait_for_ready         = true

      + kind_config {
          + api_version = "kind.x-k8s.io/v1alpha4"
          + kind        = "Cluster"

          + node {
              + role = "control-plane"
            }
          + node {
              + role = "worker"
            }
          + node {
              + role = "worker"
            }
        }
    }

Plan: 1 to add, 0 to change, 0 to destroy.
...

> terraform apply
...
kind_cluster.kindle: Still creating... [3m30s elapsed]
kind_cluster.kindle: Creation complete after 3m35s [id=kindle-kindest/node:v1.23.4]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
...

> kubectl get pods -A
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

At a minimum, our K8s cluster needs a few things to run. These have all been installed: 

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
