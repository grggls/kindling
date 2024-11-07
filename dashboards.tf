# Create dashboards directory
resource "local_file" "create_dashboard_dir" {
  filename = "${path.module}/dashboards/.keep"
  content  = ""

  provisioner "local-exec" {
    command = "mkdir -p ${path.module}/dashboards"
  }
}

# Create ConfigMap for the cluster dashboards
resource "kubernetes_config_map" "cluster_dashboards" {
  metadata {
    name      = "cluster-dashboards"
    namespace = "monitoring"
    labels = merge(local.common_labels, {
      grafana_dashboard = "1"
    })
  }

  data = {
    "cluster-dashboard-basic.json"     = file("${path.module}/dashboards/cluster-dashboard-part1.json")
    "cluster-dashboard-resources.json" = file("${path.module}/dashboards/cluster-dashboard-part2.json")
    "cluster-dashboard-network.json"   = file("${path.module}/dashboards/cluster-dashboard-part3.json")
  }

  depends_on = [
    helm_release.prometheus_stack,
    local_file.create_dashboard_dir
  ]
}

# Create ConfigMap for ArgoCD dashboard
resource "kubernetes_config_map" "argocd_dashboard" {
  metadata {
    name      = "argocd-dashboard"
    namespace = "monitoring"
    labels = merge(local.common_labels, {
      grafana_dashboard = "1"
    })
  }

  data = {
    "argocd-dashboard.json" = file("${path.module}/dashboards/argocd-dashboard.json")
  }

  depends_on = [
    helm_release.prometheus_stack,
    local_file.create_dashboard_dir
  ]
}