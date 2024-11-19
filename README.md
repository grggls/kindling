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

2. Deploy the cluster and services with the Makefile:
This Makefile provides commands to manage your Terraform infrastructure deployment:

`make apply`: Deploys infrastructure in sequence, first creating the kind cluster and then applying remaining resources
`make destroy`: Safely tears down infrastructure by first removing all Helm releases, then destroying remaining resources, and finally removing the kind cluster

The destroy command automatically detects and removes all Helm releases from the Terraform state before proceeding with full destruction, preventing dependency conflicts.

If you encounter any timeout issues or need to cleanup a failed deployment:
```bash
# Clean up failed Helm releases
helm uninstall loki -n monitoring

# Optional: Clean up monitoring namespace entirely
kubectl delete namespace monitoring

# Then run terraform apply again
terraform apply
```

## Cluster Access

After deployment, Terraform will output several useful endpoints and commands. View them with:
```bash
terraform output
```

### Accessing Services

1. **Grafana**:
   ```bash
   kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring
   ```
   - URL: http://localhost:3000
   - Default credentials: admin/admin
   - Pre-configured dashboards are available in the dashboards menu

2. **ArgoCD**:
   ```bash
   kubectl port-forward svc/argo-cd-argocd-server -n argo-cd 8080:443
   ```
   - URL: https://localhost:8080
   - Default credentials: admin/changeme
   - Get admin password:
     ```bash
     kubectl -n argo-cd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
     ```

3. **Prometheus**:
   ```bash
   kubectl port-forward svc/prometheus-prometheus 9090:9090 -n monitoring
   ```
   - URL: http://localhost:9090

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

## Working with the Cluster

1. **Accessing the Kubernetes Dashboard**:
   ```bash
   # Create an admin service account
   kubectl create serviceaccount cluster-admin-dashboard-sa
   kubectl create clusterrolebinding cluster-admin-dashboard-sa \
     --clusterrole=cluster-admin \
     --serviceaccount=default:cluster-admin-dashboard-sa
   
   # Get the token
   kubectl get secret $(kubectl get serviceaccount cluster-admin-dashboard-sa -o jsonpath="{.secrets[0].name}") \
     -o jsonpath="{.data.token}" | base64 -d
   ```

2. **Working with Secrets**:
   ```bash
   # Create a secret
   kubectl create secret generic my-secret \
     --from-literal=key1=supersecret \
     --namespace=my-namespace

   # View secrets
   kubectl get secrets -n my-namespace
   
   # Decode a secret
   kubectl get secret my-secret -n my-namespace -o jsonpath="{.data.key1}" | base64 -d
   ```

3. **Deploying Applications**:
   
   Using kubectl:
   ```bash
   # Deploy a sample application
   kubectl create deployment nginx --image=nginx
   kubectl expose deployment nginx --port=80 --type=ClusterIP
   
   # Access the application
   kubectl port-forward svc/nginx 8080:80
   ```

   Using ArgoCD:
   ```bash
   # Create an application in ArgoCD
   argocd app create my-app \
     --repo https://github.com/my-org/my-repo.git \
     --path kubernetes \
     --dest-server https://kubernetes.default.svc \
     --dest-namespace my-namespace
   
   # Sync the application
   argocd app sync my-app
   ```

4. **Viewing Logs**:
   ```bash
   # View logs for a pod
   kubectl logs -f pod-name -n namespace
   
   # View logs in Grafana/Loki
   # After port-forwarding Grafana:
   # 1. Go to Explore
   # 2. Select Loki datasource
   # 3. Use LogQL queries, e.g.:
   #    {namespace="monitoring"}
   ```

5. **Managing Resources**:
   ```bash
   # View resource usage
   kubectl top nodes
   kubectl top pods -A
   
   # View pod status
   kubectl get pods -A -o wide
   
   # Describe resources for troubleshooting
   kubectl describe pod pod-name -n namespace
   kubectl describe node node-name
   ```

### Adding Custom Services

1. **Using Helm**:
   ```bash
   # Add a helm repository
   helm repo add bitnami https://charts.bitnami.com/bitnami
   helm repo update
   
   # Install a chart
   helm install my-release bitnami/postgresql \
     --namespace my-namespace \
     --create-namespace \
     --set persistence.enabled=false
   ```

2. **Using ArgoCD**:
   Create an Application manifest:
   ```yaml
   apiVersion: argoproj.io/v1alpha1
   kind: Application
   metadata:
     name: my-app
     namespace: argo-cd
   spec:
     project: default
     source:
       repoURL: https://github.com/my-org/my-repo.git
       targetRevision: HEAD
       path: k8s
     destination:
       server: https://kubernetes.default.svc
       namespace: my-namespace
     syncPolicy:
       automated:
         prune: true
         selfHeal: true
   ```

## Logging with Promtail and Loki

The cluster uses Promtail to collect logs from all pods and ships them to Loki. This setup provides:

### Features
- Automatic log collection from all containers
- Label-based log querying
- Metadata enrichment (namespace, pod name, node name)
- Low resource footprint (10m CPU, 32Mi memory requests)

### Viewing Logs
You can view logs in several ways:

1. **Through Grafana**:
   ```bash
   kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring
   ```
   Then:
   - Navigate to Explore
   - Select Loki as the data source
   - Use LogQL queries, for example:
     ```
     {namespace="monitoring"}              # All logs from monitoring namespace
     {namespace="argo-cd"}                 # All ArgoCD logs
     {namespace="monitoring"} |= "error"   # Filter for error messages
     ```

2. **Using kubectl** (for comparison):
   ```bash
   # View logs for a specific pod
   kubectl logs -f <pod-name> -n <namespace>
   
   # View logs for a specific container in a pod
   kubectl logs -f <pod-name> -c <container-name> -n <namespace>
   ```

### LogQL Examples
Loki uses LogQL for querying. Here are some useful queries:

```logql
# Show all logs from a specific namespace
{namespace="monitoring"}

# Filter for error logs across all namespaces
{namespace=~".+"} |= "error"

# Show logs from specific application pods
{namespace="monitoring", app="prometheus"}

# Show logs and parse JSON
{namespace="monitoring"} | json

# Count error occurrences by namespace
count_over_time({namespace=~".+", level="error"}[1h]) by (namespace)
```

### Configuration
Promtail is configured via the Helm chart with:
- Node tolerations to run on all cluster nodes
- Resource limits to ensure stable operation
- Automatic Kubernetes metadata labeling
- Direct connection to Loki service

For custom configurations, modify the `promtail` section in the `loki_stack` Helm release in `monitoring.tf`.

## Configuration

Main configuration variables can be adjusted in `variables.tf`:
- `kubernetes_version`: Kubernetes version for the Kind cluster (default: "1.31.0")
- `argocd_domain`: Domain for ArgoCD ingress (default: "argocd.local")
- `grafana_admin_password`: Initial Grafana admin password (default: "admin")
- `environment`: Environment name (default: "development")
- `project_name`: Project name (default: "kindling")
- `monitoring_storage_size`: Storage size for monitoring components (default: "10Gi")
- `node_count`: Number of worker nodes (default: 2)

## Project Structure

```
.
├── .github/
│   └── workflows/
│       ├── ci.yml                # CI workflow
│       └── release.yml           # Release workflow
├── main.tf                       # Core cluster configuration
├── variables.tf                  # Variable definitions
├── outputs.tf                    # Output definitions
├── versions.tf                   # Version constraints
├── monitoring.tf                 # Monitoring stack configuration
├── argocd.tf                     # ArgoCD configuration
├── dashboards.tf                 # Grafana dashboard configurations
├── dashboards/
│   ├── cluster-dashboard-part1.json   # Basic metrics
│   ├── cluster-dashboard-part2.json   # Resource usage
│   ├── cluster-dashboard-part3.json   # Network & storage
│   └── argocd-dashboard.json         # ArgoCD metrics
├── .pre-commit-config.yaml           # Pre-commit configuration
├── .gitignore
├── CHANGELOG.md
└── README.md
```

## Development vs Production Use

This configuration is optimized for local development and testing:

- Persistence is disabled for Loki to improve startup time
- Resource requests and limits are set low for local machine constraints
- Authentication is simplified for easier access
- Single-node configurations are used where possible

For production use, you would want to:
1. Enable persistence for all components
2. Adjust resource requests and limits appropriately
3. Enable proper authentication
4. Configure proper backup and retention policies
5. Use proper SSL certificates instead of self-signed
6. Configure proper ingress with real domain names

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run the lint checks:
   ```bash
   tflint
   terraform fmt -check -recursive
   ```
5. Create a Pull Request

The CI pipeline will verify:
- Terraform formatting
- Terraform validation
- TFLint checks
- JSON formatting
- Security scanning with TFSec and Checkov

## References

- [Kind Configuration](https://kind.sigs.k8s.io/docs/user/configuration/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/en/stable/)
- [Prometheus Operator](https://prometheus-operator.dev/)
- [Grafana Documentation](https://grafana.com/docs/)
- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
