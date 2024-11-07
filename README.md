# Kindling - Kubernetes Development Environment

A complete development environment using Kind (Kubernetes in Docker) with built-in observability, GitOps, and essential services.

## Features

- Kind cluster with one control plane and two worker nodes
- Complete observability stack:
  - Prometheus for metrics collection
  - Grafana with pre-configured dashboards
  - Loki for log aggregation
  - Tempo for distributed tracing
  - OpenTelemetry for instrumentation
- GitOps ready with ArgoCD
- Ingress with NGINX controller
- Certificate management with cert-manager
- Custom Grafana dashboards for cluster monitoring

## Prerequisites

- Docker
- Terraform >= 1.0.0
- kubectl
- Helm
- Update your `/etc/hosts` file:
  ```
  127.0.0.1 kind-registry kind-registry.local argocd.local
  ```

## Quick Start

1. Initialize Terraform:
   ```bash
   terraform init
   ```

2. Deploy the cluster and services:
   ```bash
   terraform apply
   ```

3. Access the services:
   ```bash
   # Grafana
   kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring
   # Default credentials: admin/admin

   # ArgoCD
   kubectl port-forward svc/argo-cd-argocd-server -n argo-cd 8080:443
   # Default credentials: admin/changeme

   # Prometheus
   kubectl port-forward svc/prometheus-prometheus 9090:9090 -n monitoring
   ```

## Monitoring Stack

The cluster comes with a comprehensive monitoring solution:

1. **Metrics (Prometheus)**
   - Node-level metrics
   - Container metrics
   - Service metrics
   - Custom metrics from applications

2. **Logs (Loki + Promtail)**
   - Centralized logging
   - Log aggregation from all pods
   - Label-based log querying

3. **Traces (Tempo + OpenTelemetry)**
   - Distributed tracing
   - Request flow visualization
   - Performance bottleneck identification

4. **Pre-configured Dashboards**
   - Cluster Overview
   - Resource Usage
   - Network & Storage
   - ArgoCD Status

## Dashboard Access

The Grafana instance comes with three pre-configured dashboards:

1. Basic Metrics Dashboard
   - Cluster health overview
   - Node count
   - Pod status
   - Namespace overview

2. Resource Usage Dashboard
   - CPU usage by node
   - Memory usage by node
   - Pod resource consumption

3. Network and Storage Dashboard
   - Network I/O metrics
   - Disk usage
   - Storage allocation

Access the dashboards through Grafana at `http://localhost:3000` after port forwarding.

## Configuration

Main configuration variables can be adjusted in `variables.tf`:
- `kubernetes_version`: Kubernetes version for the Kind cluster
- `argocd_domain`: Domain for ArgoCD ingress
- `grafana_admin_password`: Initial Grafana admin password
- `environment`: Environment name
- `project_name`: Project name

## Project Structure

```
.
├── main.tf                # Core cluster configuration
├── variables.tf           # Variable definitions
├── outputs.tf            # Output definitions
├── monitoring.tf         # Monitoring stack configuration
├── argocd.tf            # ArgoCD configuration
├── dashboards.tf         # Grafana dashboard configurations
├── dashboards/
│   ├── cluster-dashboard-part1.json   # Basic metrics
│   ├── cluster-dashboard-part2.json   # Resource usage
│   ├── cluster-dashboard-part3.json   # Network & storage
│   └── argocd-dashboard.json         # ArgoCD metrics
└── README.md
```

## Day 2 Operations

- Scale worker nodes by adjusting the range in the `dynamic "node"` block
- Update dashboards by modifying JSON files in the `dashboards` directory
- Add custom monitoring by extending the Prometheus configuration
- Configure GitOps workflows through ArgoCD
- Add additional Helm charts through Terraform or ArgoCD

## Contributing

Feel free to open issues or pull requests for improvements.

## References

- [Kind Configuration](https://kind.sigs.k8s.io/docs/user/configuration/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/en/stable/)
- [Prometheus Operator](https://prometheus-operator.dev/)
- [Grafana Documentation](https://grafana.com/docs/)
- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)