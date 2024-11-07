output "cluster_endpoint" {
  description = "Endpoint for the Kind cluster"
  value       = kind_cluster.this.endpoint
}

output "argocd_admin_password" {
  description = "Initial admin password for ArgoCD"
  value       = "changeme"
  sensitive   = true
}

output "grafana_admin_password" {
  description = "Grafana admin password"
  value       = var.grafana_admin_password
  sensitive   = true
}

output "prometheus_url" {
  description = "URL for Prometheus"
  value       = "http://prometheus.monitoring:9090"
}

output "grafana_url" {
  description = "URL for Grafana"
  value       = "http://grafana.monitoring:3000"
}

output "argocd_url" {
  description = "URL for ArgoCD"
  value       = "https://${var.argocd_domain}"
}

output "kubeconfig_path" {
  description = "Path to the kubeconfig file"
  value       = local.k8s_config_path
}

output "monitoring_namespace" {
  description = "Namespace where monitoring stack is deployed"
  value       = kubernetes_namespace.monitoring.metadata[0].name
}

output "dashboard_access_commands" {
  description = "Commands to access the dashboards"
  value = {
    grafana    = "kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring"
    prometheus = "kubectl port-forward svc/prometheus-prometheus 9090:9090 -n monitoring"
    argocd     = "kubectl port-forward svc/argo-cd-argocd-server -n argo-cd 8080:443"
  }
}