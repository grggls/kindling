locals {
  k8s_config_path    = pathexpand("~/.kube/config")
  kubernetes_version = "1.23.4"
  argocd_namespace   = "argocd"
  argocd_domain      = "argocd.local"
}

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.19"
    }
    kind = {
      source  = "tehcyx/kind"
      version = "0.0.16"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0.1"
    }
  }
}

provider "kind" {
  #  kubeconfig_path = local.k8s_config_path
}

resource "kind_cluster" "this" {
  name            = "kindling"
  node_image      = "kindest/node:v${local.kubernetes_version}"
  wait_for_ready  = "true"
  kubeconfig_path = local.k8s_config_path
  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    # default address is localhost. define a port to avoid random allocation.
    networking {
      api_server_address = "127.0.0.1"
      api_server_port    = 6443
      # uncomment this when we're ready to install cilium
      #disable_default_cni = "true"
    }

    node {
      role = "control-plane"

      extra_mounts {
        host_path      = "./share"
        container_path = "/share"
      }

      kubeadm_config_patches = [
        "kind: InitConfiguration\nnodeRegistration:\n  kubeletExtraArgs:\n    node-labels: \"ingress-ready=true\"\n"
      ]
    }

    node {
      role = "worker"

    }
    node {
      role = "worker"
    }

    containerd_config_patches = [
      <<-TOML
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:5000"]
          endpoint = ["http://kind-registry:5000"]
      TOML
    ]
  }
}

# set up the TF kubernetes provider
provider "kubernetes" {
  config_path    = local.k8s_config_path
  config_context = "kind-kindling"
}

provider "helm" {
  kubernetes {
    config_path = kind_cluster.this.kubeconfig_path
  }
}

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  timeout          = 900
  atomic           = "true"
  create_namespace = true
  depends_on       = [kind_cluster.this]

  set {
    name  = "installCRDs"
    value = "true"
  }
}

# removing cert-issuer since we're not deploying this to a cloud or remote network

# config overrides from here: https://github.com/kubernetes-sigs/kind/issues/1693#issuecomment-1060872664
resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true
  depends_on       = [kind_cluster.this]

  set {
    name = "controller.hostPort.enabled"
    value = "true"
  }

  set {
    name  = "controller.service.type"
    value = "ClusterIP"
  }

  wait    = true
  timeout = 900
}

resource "helm_release" "argo_cd" {
  name             = "argo-cd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argo-cd"
  create_namespace = true
  depends_on       = [kind_cluster.this]
}

# kubectl port-forward service/argo-cd-argocd-server -n argo-cd 8080:http

#resource "kubernetes_ingress" "argo_cd" {
#  metadata {
#    name      = "argo-cd-ingress"
#    namespace = "argo-cd"
#  }
#  spec {
#    rule {
#      host = local.argocd_domain
#      http {
#        path {
#          backend {
#            service_name = "argo-cd-server"
#            service_port = "http"
#          }
#          path = "/"
#        }
#      }
#    }
#    tls {
#      # Replace with the appropriate secret name if you have TLS configured
#      secret_name = "argo-cd-server-tls"
#      hosts = [local.argocd_domain]
#    }
#  }
#  depends_on = [helm_release.argo_cd]
#}

resource "kubernetes_manifest" "argo_cd_ingress" {
  manifest = {
    "apiVersion" = "networking.k8s.io/v1"
    "kind"       = "Ingress"
    "metadata" = {
      "name"      = "argo-cd-ingress"
      "namespace" = "argo-cd"
    }
    "spec" = {
      "rules" = [
        {
          "host" = local.argocd_domain
          "http" = {
            "paths" = [
              {
                "backend" = {
                  "service" = {
                    "name" = "argo-cd-argocd-server"
                    "port" = {
                      "name" = "http"
                    }
                  }
                }
                "path"       = "/"
                "pathType"   = "Prefix"
              },
            ]
          }
        },
      ]
      "tls" = [
        {
          # Replace with the appropriate secret name if you have TLS configured
          "secretName" = "argo-cd-server-tls"
          "hosts"      = [local.argocd_domain]
        },
      ]
    }
  }
  depends_on = [helm_release.argo_cd]
}
