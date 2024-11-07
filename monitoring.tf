# Create monitoring namespace
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name   = "monitoring"
    labels = local.common_labels
  }
  depends_on = [kind_cluster.this]
}

# Install cert-manager for SSL certificate management
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.14.0"
  namespace        = "cert-manager"
  timeout          = 900
  atomic           = true
  create_namespace = true
  depends_on       = [kind_cluster.this]

  values = [
    yamlencode({
      global = {
        labels = local.common_labels
      }
      installCRDs = true
      prometheus = {
        enabled = true
      }
    })
  ]
}

# Install NGINX ingress controller
resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "4.9.0"
  namespace        = "ingress-nginx"
  create_namespace = true
  depends_on       = [kind_cluster.this]

  values = [
    yamlencode({
      global = {
        labels = local.common_labels
      }
      controller = {
        hostPort = {
          enabled = true
        }
        service = {
          type = "ClusterIP"
        }
        metrics = {
          enabled = true
        }
        resources = {
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
        }
      }
    })
  ]
}

# Install Prometheus Stack
resource "helm_release" "prometheus_stack" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "55.5.0"
  namespace  = "monitoring"
  timeout    = 900
  atomic     = true
  depends_on = [kubernetes_namespace.monitoring]

  values = [
    yamlencode({
      global = {
        labels = local.common_labels
      }
      grafana = {
        enabled       = true
        adminPassword = var.grafana_admin_password
        persistence = {
          enabled = true
          size    = "10Gi"
        }
        sidecar = {
          dashboards = {
            enabled = true
            label   = "grafana_dashboard"
          }
        }
      }
      prometheus = {
        prometheusSpec = {
          retention = "15d"
          resources = {
            requests = {
              memory = "512Mi"
              cpu    = "500m"
            }
          }
          storage = {
            volumeClaimTemplate = {
              spec = {
                resources = {
                  requests = {
                    storage = var.monitoring_storage_size
                  }
                }
              }
            }
          }
        }
      }
      alertmanager = {
        enabled = true
        alertmanagerSpec = {
          storage = {
            volumeClaimTemplate = {
              spec = {
                resources = {
                  requests = {
                    storage = "10Gi"
                  }
                }
              }
            }
          }
        }
      }
    })
  ]
}

# Install Loki Stack with adjusted configuration
resource "helm_release" "loki_stack" {
  name             = "loki"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "loki-stack"
  version          = "2.9.11"
  namespace        = "monitoring"
  create_namespace = true
  timeout          = 300
  atomic          = true
  force_update    = true
  cleanup_on_fail = true
  
  depends_on       = [
    kubernetes_namespace.monitoring
  ]

  set {
    name  = "loki.enabled"
    value = "true"
  }

  set {
    name  = "loki.persistence.enabled"
    value = "false"
  }

  set {
    name  = "loki.auth_enabled"
    value = "false"
  }

  set {
    name  = "promtail.enabled"
    value = "false"  # Disable promtail temporarily until Loki is working
  }

  set {
    name  = "loki.readinessProbe.initialDelaySeconds"
    value = "30"
  }

  set {
    name  = "loki.livenessProbe.initialDelaySeconds"
    value = "30"
  }

  set {
    name  = "loki.config.limits_config.reject_old_samples"
    value = "true"
  }

  set {
    name  = "loki.config.limits_config.reject_old_samples_max_age"
    value = "168h"
  }

  set {
    name  = "loki.resources.requests.cpu"
    value = "10m"
  }

  set {
    name  = "loki.resources.requests.memory"
    value = "32Mi"
  }

  set {
    name  = "loki.resources.limits.cpu"
    value = "50m"
  }

  set {
    name  = "loki.resources.limits.memory"
    value = "64Mi"
  }
}

# Add explicit wait for cert-manager webhook
resource "time_sleep" "wait_for_cert_manager" {
  depends_on      = [helm_release.cert_manager]
  create_duration = "30s"
}

# Install OpenTelemetry Operator with adjusted configuration
resource "helm_release" "opentelemetry_operator" {
  name             = "opentelemetry-operator"
  repository       = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart            = "opentelemetry-operator"
  version          = "0.45.0"
  namespace        = "monitoring"
  create_namespace = true
  timeout          = 900
  atomic           = true
  depends_on = [
    kubernetes_namespace.monitoring,
    helm_release.cert_manager,
    time_sleep.wait_for_cert_manager
  ]

  values = [
    yamlencode({
      global = {
        labels = local.common_labels
      }
      resources = {
        requests = {
          cpu    = "50m"
          memory = "64Mi"
        }
        limits = {
          cpu    = "100m"
          memory = "128Mi"
        }
      }
      webhook = {
        resources = {
          requests = {
            cpu    = "50m"
            memory = "64Mi"
          }
          limits = {
            cpu    = "100m"
            memory = "128Mi"
          }
        }
      }
    })
  ]
}

# Install Tempo
resource "helm_release" "tempo" {
  name       = "tempo"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "tempo"
  version    = "1.7.1"
  namespace  = "monitoring"
  depends_on = [kubernetes_namespace.monitoring]

  values = [
    yamlencode({
      global = {
        labels = local.common_labels
      }
      tempo = {
        storage = {
          trace = {
            backend = "local"
            local = {
              path = "/var/tempo/traces"
            }
          }
        }
        retention = "24h"
      }
      persistence = {
        enabled = true
        size    = var.monitoring_storage_size
      }
    })
  ]
}