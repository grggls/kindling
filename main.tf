locals {
  kubernetes_version = "1.23.4"
  argocd_namespace   = "argocd"
}

terraform {
  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "0.0.16"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0.1"
    }
  }
}

provider "kind" {
}

resource "kind_cluster" "kindle" {
  name           = "kindle"
  node_image     = "kindest/node:v${local.kubernetes_version}"
  wait_for_ready = "true"
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

      extra_port_mappings {
        container_port = 80
        host_port      = 8080
      }
      extra_port_mappings {
        container_port = 443
        host_port      = 8443
      }
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
  config_path    = "./kindle-config"
  config_context = "kind-kindle"
}

provider "kubectl" {
  config_path = "./kindle-config"
}

provider "helm" {
  kubernetes {
    config_path = "./kindle-config"
  }
}

resource "helm_release" "cert_manager" {
  chart      = "cert-manager"
  repository = "https://charts.jetstack.io"
  name       = "cert-manager"

  create_namespace = "true"
  namespace        = "cert-manager"

  timeout = 900

  set {
    name  = "installCRDs"
    value = "true"
  }

  depends_on = [
    kind_cluster.kindle
  ]
}

resource "helm_release" "ingress_nginx" {
  name = "ingress-nginx"

  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"

  create_namespace = "true"
  namespace        = "ingress-nginx"

  wait = true
  timeout = 900

  depends_on = [
    helm_release.cert_manager
  ]
}

# create a namespace for Argo
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = local.argocd_namespace
  }
  depends_on = [
    helm_release.ingress_nginx
  ]
}

# install argocd with a module that leverages the official helm chart - https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd 
module "argocd" {
  source               = "aigisuk/argocd/kubernetes"
  version              = "0.2.7"
  namespace            = local.argocd_namespace
  argocd_chart_version = "5.27.4"
  timeout_seconds      = 900
  admin_password       = "admin"
  insecure             = "true"
  depends_on = [
    kubernetes_namespace.argocd
  ]
}
