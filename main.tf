# Define local variables for reuse throughout the configuration
locals {
  k8s_config_path = pathexpand("~/.kube/config")
  
  # Common labels for all resources
  common_labels = {
    environment = var.environment
    managed_by  = "terraform"
    project     = var.project_name
  }
}

# Specify required providers and their versions
terraform {
  required_version = ">= 1.5" # Ensure minimum Terraform version

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.33"
    }
    kind = {
      source  = "tehcyx/kind"
      version = "0.6"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.16"
    }
  }
}

# Configure the Kind provider
provider "kind" {}

# Create a Kind cluster with a control plane and two workers
resource "kind_cluster" "this" {
  name            = var.project_name
  node_image      = "kindest/node:v${var.kubernetes_version}"
  wait_for_ready  = true
  kubeconfig_path = local.k8s_config_path

  # Add timeout for cluster creation
  timeouts {
    create = "30m"
    delete = "30m"
  }

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    # Configure networking settings
    networking {
      api_server_address = "127.0.0.1"
      api_server_port    = 6443
      pod_subnet     = "10.244.0.0/16"
      service_subnet = "10.96.0.0/16"
    }

    # Control plane node configuration
    node {
      role = "control-plane"
      
      # Mount local directory into node for persistence
      extra_mounts {
        host_path      = "./share"
        container_path = "/share"
      }

      # Configure node for ingress
      kubeadm_config_patches = [
        "kind: InitConfiguration\nnodeRegistration:\n  kubeletExtraArgs:\n    node-labels: \"ingress-ready=true\"\n"
      ]

      # Port mappings
      extra_port_mappings {
        container_port = 80
        host_port      = 80
        protocol       = "TCP"
      }
      extra_port_mappings {
        container_port = 443
        host_port      = 443
        protocol       = "TCP"
      }
    }

    # Worker nodes configuration
    dynamic "node" {
      for_each = range(var.node_count)
      content {
        role = "worker"
        kubeadm_config_patches = [
          "kind: JoinConfiguration\nnodeRegistration:\n  kubeletExtraArgs:\n    node-labels: \"worker=true\"\n"
        ]
      }
    }

    # Configure containerd to use local registry
    containerd_config_patches = [
      <<-TOML
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:5000"]
          endpoint = ["http://kind-registry:5000"]
        [plugins."io.containerd.grpc.v1.cri".registry.configs."localhost:5000".tls]
          insecure_skip_verify = true
      TOML
    ]
  }
}

# Configure Kubernetes provider to use the Kind cluster
provider "kubernetes" {
  host = kind_cluster.this.endpoint
  
  client_certificate     = kind_cluster.this.client_certificate
  client_key             = kind_cluster.this.client_key
  cluster_ca_certificate = kind_cluster.this.cluster_ca_certificate
}

# Configure Helm provider with the Kind cluster credentials
provider "helm" {
  kubernetes {
    host = kind_cluster.this.endpoint
    
    client_certificate     = kind_cluster.this.client_certificate
    client_key             = kind_cluster.this.client_key
    cluster_ca_certificate = kind_cluster.this.cluster_ca_certificate
  }
}

# Install cert-manager for SSL certificate management
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.14.0" # Specify version for stability
  namespace        = "cert-manager"
  timeout          = 900
  atomic           = true
  create_namespace = true
  depends_on       = [kind_cluster.this]

  set {
    name  = "installCRDs"
    value = "true"
  }

  # Add monitoring
  set {
    name  = "prometheus.enabled"
    value = "true"
  }

  values = [
    yamlencode({
      global = {
        labels = local.common_labels
      }
    })
  ]
}

# Install NGINX ingress controller
resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "4.9.0" # Specify version for stability
  namespace        = "ingress-nginx"
  create_namespace = true
  depends_on       = [kind_cluster.this]

  set {
    name  = "controller.hostPort.enabled"
    value = "true"
  }

  set {
    name  = "controller.service.type"
    value = "ClusterIP"
  }

  # Enable metrics for monitoring
  set {
    name  = "controller.metrics.enabled"
    value = "true"
  }

  # Add resource limits
  set {
    name  = "controller.resources.requests.cpu"
    value = "100m"
  }
  set {
    name  = "controller.resources.requests.memory"
    value = "128Mi"
  }

  wait    = true
  timeout = 900

  values = [
    yamlencode({
      global = {
        labels = local.common_labels
      }
    })
  ]
}

# Install ArgoCD
resource "helm_release" "argo_cd" {
  name             = "argo-cd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "5.51.6" # Specify version for stability
  namespace        = "argo-cd"
  create_namespace = true
  depends_on       = [kind_cluster.this]

  # Enable HA mode for better reliability
  set {
    name  = "controller.ha.enabled"
    value = "true"
  }

  # Enable metrics
  set {
    name  = "controller.metrics.enabled"
    value = "true"
  }

  values = [
    yamlencode({
      global = {
        labels = local.common_labels
      }
      configs = {
        secret = {
          # Enable additional security features
          argocdServerAdminPassword = bcrypt("changeme") # Change this in production
        }
      }
    })
  ]
}

# Configure ArgoCD Ingress
resource "kubernetes_manifest" "argo_cd_ingress" {
  manifest = {
    "apiVersion" = "networking.k8s.io/v1"
    "kind"       = "Ingress"
    "metadata" = {
      "name"      = "argo-cd-ingress"
      "namespace" = "argo-cd"
      "annotations" = {
        "nginx.ingress.kubernetes.io/ssl-passthrough"  = "true"
        "nginx.ingress.kubernetes.io/backend-protocol" = "HTTPS"
      }
      "labels" = local.common_labels
    }
    "spec" = {
      "ingressClassName" = "nginx"
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
                "path"     = "/"
                "pathType" = "Prefix"
              },
            ]
          }
        },
      ]
      "tls" = [
        {
          "secretName" = "argo-cd-server-tls"
          "hosts"      = [local.argocd_domain]
        },
      ]
    }
  }
  depends_on = [helm_release.argo_cd, helm_release.ingress_nginx]
}

# Output useful information
output "cluster_endpoint" {
  description = "Endpoint for the Kind cluster"
  value       = kind_cluster.this.endpoint
}

output "argocd_admin_password" {
  description = "Initial admin password for ArgoCD"
  value       = "changeme"
  sensitive   = true
}
