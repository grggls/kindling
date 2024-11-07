# Common variables
variable "environment" {
  description = "Environment name"
  type        = string
  default     = "development"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "kindling"
}

# Kubernetes variables
variable "kubernetes_version" {
  description = "Kubernetes version to use for the Kind cluster"
  type        = string
  default     = "1.31.0"
}

# Domain variables
variable "argocd_domain" {
  description = "Domain for ArgoCD ingress"
  type        = string
  default     = "argocd.local"
}

# Credentials
variable "grafana_admin_password" {
  description = "Admin password for Grafana"
  type        = string
  default     = "admin"
  sensitive   = true
}

# Resource sizing
variable "monitoring_storage_size" {
  description = "Storage size for monitoring components"
  type        = string
  default     = "10Gi"
}

variable "node_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 2
}