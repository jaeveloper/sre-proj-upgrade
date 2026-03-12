# SRE Platform — Azure AKS Microservices

**Terraform · AKS · ArgoCD GitOps · KEDA · Workload Identity · OpenTelemetry · Prometheus · Grafana · Application Insights**

---

## Architecture Overview

A production-grade, event-driven microservices platform on Azure Kubernetes Service. Based on the Google Online Boutique e-commerce demo, re-architected for Azure with zero-credential security, GitOps delivery, event-driven autoscaling, and a full observability stack.

```
┌─────────────────────────────────────────────────────────────────┐
│                        GitHub (source of truth)                  │
│                                                                   │
│   services/*   →   GitHub Actions   →   DockerHub (jukpozi/*)    │
│   kubernetes-platform/*  ─────────────────────────────────────┐  │
└───────────────────────────────────────────────────────────────┼──┘
                                                                │
                                                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                        AKS: jd-aks  (westus2)                   │
│                                                                   │
│  ns: argocd                                                       │
│  └─ ArgoCD  ──── watches git ────► reconciles all namespaces     │
│                                                                   │
│  ns: core                          ns: workers                    │
│  ├─ frontend (Go)                  ├─ payment-worker    ┐         │
│  ├─ checkoutservice (Go)           ├─ email-worker      ├─ KEDA  │
│  ├─ cartservice (.NET)             └─ shipping-worker   ┘         │
│  ├─ productcatalogservice (Go)                                    │
│  ├─ currencyservice (Node.js)      ns: keda                       │
│  ├─ recommendationservice (Python) └─ keda-operator               │
│  ├─ paymentservice (Node.js)                                      │
│  ├─ emailservice (Python)          ns: observability              │
│  ├─ shippingservice (Go)           ├─ prometheus                  │
│  └─ adservice (Java)               ├─ grafana                     │
│                                    └─ otel-collector              │
└─────────────────────────────────────────────────────────────────┘
         │                    │                    │
         ▼                    ▼                    ▼
  Azure Service Bus     Azure Cosmos DB      Azure Cache
  sre-sb-namespace      SQL API (RBAC)       for Redis
  topic: checkout-events
         │
         ▼
  App Insights ◄── OTEL Collector ◄── all services (traces + metrics)
  Prometheus   ◄── OTEL Collector (metrics)
  Grafana      ◄── Prometheus
```

### Request Flow

```
Browser → frontend → checkoutservice → [cartservice, productcatalogservice,
          currencyservice, paymentservice, shippingservice, emailservice]
                          │
                          ▼
               Service Bus (checkout-events topic)
                          │
          ┌───────────────┼───────────────┐
          ▼               ▼               ▼
    payment-worker   email-worker   shipping-worker
    (KEDA scaled)    (KEDA scaled)  (KEDA scaled)
```

### Telemetry Flow

```
All services
    │
    │  OTLP gRPC :4317
    ▼
otel-collector-opentelemetry-collector.observability
    ├── traces  ──► Azure Application Insights
    ├── metrics ──► Prometheus :8889
    └── logs    ──► Azure Application Insights

Prometheus ──► Grafana dashboards
```

---

## Repository Structure

```
sre-proj-upgrade/
├── .github/workflows/          # CI — one build workflow per service
├── helm/
│   ├── core-services/          # Helm charts for all 10 storefront services
│   │   ├── adservice/
│   │   ├── cartservice/
│   │   ├── checkoutservice/
│   │   ├── currencyservice/
│   │   ├── emailservice/
│   │   ├── frontend/
│   │   ├── paymentservice/
│   │   ├── productcatalogservice/
│   │   ├── recommendationservice/
│   │   └── shippingservice/
│   └── workers/                # Helm charts for KEDA-scaled event workers
│       ├── email-worker/
│       ├── payment-worker/
│       └── shipping-worker/
├── kubernetes-platform/
│   ├── argocd/
│   │   ├── root-app.yaml       # App-of-Apps bootstrap entry point
│   │   └── apps/               # One ArgoCD Application per service/worker/tool
│   ├── keda/
│   │   └── keda-operator-sa.yaml
│   ├── namespaces/             # argocd, core, keda, observability, workers
│   └── observability/
│       ├── app-insights/       # ConfigMap (both core + observability ns)
│       ├── grafana/
│       ├── otel-collector/     # OTEL pipeline values.yaml
│       └── prometheus/         # ServiceMonitor CRs
├── scripts/
│   └── seed_cosmos.py          # Product catalog seeder (run by terraform)
├── services/                   # All microservice source code
│   ├── adservice/              # Java / gRPC
│   ├── cartservice/            # .NET
│   ├── checkoutservice/        # Go
│   ├── currencyservice/        # Node.js
│   ├── emailservice/           # Python
│   ├── frontend/               # Go
│   ├── paymentservice/         # Node.js
│   ├── productcatalogservice/  # Go
│   ├── recommendationservice/  # Python
│   ├── shippingservice/        # Go
│   └── shoppingassistantservice/
└── terraform/
    ├── environments/
    │   └── dev/                # config.yaml, main.tf, providers.tf
    └── modules/
        ├── aks/
        ├── cosmos/
        ├── network/
        ├── observability/
        ├── redis/
        ├── servicebus/
        └── workload-identity/
```

---

## Services

### Core (Namespace: `core`)

| Service | Language | Port | Role |
|---|---|---|---|
| `frontend` | Go | 8080 | HTTP server, renders shop UI, enables tracing via `COLLECTOR_SERVICE_ADDR` |
| `checkoutservice` | Go | 5050 | Orchestrates checkout, publishes to Service Bus |
| `cartservice` | .NET | 7070 | Shopping cart backed by Azure Cache for Redis |
| `productcatalogservice` | Go | 3550 | Product listing/search, reads from Cosmos DB |
| `currencyservice` | Node.js | 7000 | Currency conversion |
| `recommendationservice` | Python | 8080 | Product recommendations |
| `paymentservice` | Node.js | 50051 | Payment processing |
| `emailservice` | Python | 5000 | Confirmation emails |
| `shippingservice` | Go | 50051 | Shipping quotes |
| `adservice` | Java | 9555 | Contextual ads |

All services send OpenTelemetry traces and metrics to `otel-collector-opentelemetry-collector.observability.svc.cluster.local:4317`.  
Go services use `COLLECTOR_SERVICE_ADDR` (raw gRPC `host:port`).  
Non-Go services use `OTEL_EXPORTER_OTLP_ENDPOINT` (standard SDK env var).

### Workers (Namespace: `workers`)

| Worker | Subscription | Scales on |
|---|---|---|
| `payment-worker` | `payment` | `checkout-events` message count |
| `email-worker` | `email` | `checkout-events` message count |
| `shipping-worker` | `shipping` | `checkout-events` message count |

Workers scale from 0 → 15 replicas driven by KEDA. Idle queues scale back to zero.

---

## Infrastructure (Terraform)

All Azure resources are provisioned by Terraform. Configuration lives in `terraform/environments/dev/config.yaml`.

### Current dev config

| Setting | Value |
|---|---|
| Resource group | `jd-core-rg` |
| Location | `westus2` |
| AKS cluster | `jd-aks` |
| Node VM size (system + user) | `Standard_D2s_v5` |
| Node range | 1–3 per pool |
| Service CIDR | `10.1.0.0/16` |
| Cosmos DB throughput | 4000 RU/s |
| Service Bus SKU | Standard |

### Terraform modules

| Module | Resources provisioned |
|---|---|
| `network` | VNet `10.0.0.0/16`, AKS subnet `10.0.0.0/22` |
| `aks` | AKS cluster, OIDC issuer, diagnostic settings → Log Analytics |
| `observability` | Log Analytics workspace, Application Insights |
| `cosmos` | Cosmos DB account, `product-catalog-db` database, `products` container |
| `servicebus` | Namespace, `checkout-events` topic, `payment`/`email`/`shipping` subscriptions |
| `redis` | Azure Cache for Redis (firewall rules scoped to AKS egress IP) |
| `workload-identity` | User Assigned Managed Identities (one per worker + KEDA), Federated Credentials, RBAC assignments |

### Terraform outputs (used at deploy time)

```bash
terraform output worker_client_ids           # → helm/workers/*/values.yaml
terraform output keda_operator_client_id     # → kubernetes-platform/argocd/apps/keda.yaml
terraform output cosmos_endpoint             # → helm/core-services/productcatalogservice/values.yaml
terraform output -raw redis_hostname         # → cartservice redis secret
terraform output -raw app_insights_connection_string  # → observability/app-insights/configmap.yaml
```

---

## Security Model

Zero credentials stored anywhere in the cluster or the repository.

| Access path | Mechanism |
|---|---|
| Workers → Service Bus | Azure RBAC `Service Bus Data Receiver` via Workload Identity |
| checkoutservice → Service Bus | Azure RBAC `Service Bus Data Sender` via Workload Identity |
| productcatalogservice → Cosmos DB | Cosmos Native RBAC `Built-in Data Contributor` via Workload Identity |
| cartservice → Redis | TLS connection string in Kubernetes Secret (no password in git) |
| KEDA → Service Bus | Workload Identity via `TriggerAuthentication` — no SAS tokens |
| Pod → Entra ID | OIDC projected service account token, validated by Entra ID |

### Workload Identity flow

```
Pod starts
  │
  ├─ Projected OIDC token mounted at /var/run/secrets/azure/tokens/
  │
  └─ DefaultAzureCredential exchanges OIDC token with Entra ID
       │
       └─ Access token returned, scoped to assigned Azure RBAC roles
            │
            └─ SDK calls Service Bus / Cosmos DB with bearer token
```

---

## GitOps (ArgoCD)

The repository is the single source of truth. ArgoCD continuously reconciles cluster state to match `main`.

```
kubernetes-platform/argocd/root-app.yaml
  └─ watches:  kubernetes-platform/argocd/apps/
       ├─ adservice.yaml
       ├─ cartservice.yaml
       ├─ checkoutservice.yaml
       ├─ currencyservice.yaml
       ├─ email-worker.yaml
       ├─ emailservice.yaml
       ├─ frontend.yaml
       ├─ keda.yaml                   (kube-prometheus-stack v58.2.0)
       ├─ observability-config.yaml   (App Insights ConfigMaps)
       ├─ otel-collector.yaml         (opentelemetry-collector v0.91.0)
       ├─ payment-worker.yaml
       ├─ paymentservice.yaml
       ├─ productcatalogservice.yaml
       ├─ prometheus.yaml             (kube-prometheus-stack v58.2.0)
       ├─ prometheus-monitors.yaml    (ServiceMonitor CRs)
       ├─ recommendationservice.yaml
       ├─ shipping-worker.yaml
       └─ shippingservice.yaml
```

All applications use:
```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
```

Manual changes to the cluster are automatically reverted within ~3 minutes.

---

## Observability Stack

| Pillar | Tool | Where |
|---|---|---|
| Metrics | Prometheus | `observability` namespace |
| Dashboards | Grafana | `observability` namespace — port-forward `:3000` |
| Traces | OpenTelemetry Collector → Application Insights | `observability` namespace |
| Logs | Application Insights | Azure Portal |
| Alerting | Alertmanager | `observability` namespace |

### OTEL Collector pipeline

```yaml
receivers:  otlp (gRPC :4317, HTTP :4318)
processors: memory_limiter → batch
exporters:
  traces + logs  → azuremonitor (App Insights connection string)
  metrics        → prometheus (:8889)
```

The connection string is injected via a ConfigMap (`appinsights-config`) deployed by the `observability-config` ArgoCD app.

### Grafana access

```bash
kubectl port-forward svc/prometheus-grafana -n observability 3000:80
# http://localhost:3000
# username: admin
# password: prom-operator
```

Pre-loaded dashboards: Kubernetes cluster resources, node exporter, pod resources.

### SRE Platform Dashboard

A custom dashboard covering latency, Service Bus queue depth, and KEDA worker scaling is included in the repo.

**Import steps:**
1. Open Grafana (`kubectl port-forward svc/prometheus-grafana -n observability 3000:80`)
2. **Dashboards → New → Import → Upload JSON file**
3. Select `kubernetes-platform/observability/grafana/dashboards/sre-platform.json`
4. Set the datasource to **Prometheus** → **Import**

**Panels:**

| Panel | What it shows | Available |
|---|---|---|
| Request Latency (p50 / p95 / p99) | End-to-end trace latency from OTEL spans | After first traces arrive in App Insights |
| Service Bus Queue Depth | Active message count per subscription seen by KEDA | Immediately (KEDA ServiceMonitor) |
| Queue Depth (current) | Stat panel — single number per subscription | Immediately |
| Worker Replicas — Desired vs Running | KEDA target vs actual pod count | Immediately |
| Worker Current Pods | Stat panel — live pod count, maps 0 to "IDLE" | Immediately |
| Pod Restarts | CrashLoopBackOff / OOMKill detection | Immediately |
| CPU Usage | Per-pod CPU across `core` and `workers` namespaces | Immediately |
| Memory Usage | Per-pod memory across both namespaces | Immediately |

> **Tip:** Send a checkout event to `checkout-events` via Service Bus Explorer to trigger KEDA scaling and see the queue depth and replica panels respond in real time.

---

## CI — GitHub Actions

Each service has a dedicated workflow under `.github/workflows/build-<service>.yml`.

Trigger: push to `main` affecting `services/<service>/**`

Pipeline steps:
1. Build language-specific binary / run tests
2. Docker login (`DOCKER_USERNAME` / `DOCKER_PASSWORD` repo secrets)
3. `docker build -t jukpozi/<service>:latest`
4. Trivy image scan — fails on `CRITICAL` vulnerabilities
5. `docker push jukpozi/<service>:latest`

ArgoCD detects the updated image tag on next sync.

---

## Deploy — Complete Steps (Fresh Environment)

### Prerequisites

| Tool | Minimum version |
|---|---|
| Azure CLI | 2.60+ (`az login` completed) |
| Terraform | 1.9+ |
| kubectl | 1.28+ |
| Helm | 3.14+ |
| ArgoCD CLI | 2.10+ (optional, for CLI management) |

You also need:
- An Azure subscription with Contributor access
- GitHub repo secrets `DOCKER_USERNAME` and `DOCKER_PASSWORD` set (DockerHub credentials)

---

### Step 1 — Provision Azure infrastructure

```bash
cd terraform/environments/dev

# Initialise providers
terraform init

# Review plan
terraform plan

# Provision everything (~10 min)
terraform apply
```

This creates: resource group, VNet, AKS cluster, Cosmos DB, Service Bus, Redis, App Insights, Log Analytics, all Managed Identities, all RBAC assignments, and seeds the Cosmos DB product catalog automatically.

Capture outputs:

```bash
# Used in step 5
terraform output -raw app_insights_connection_string
terraform output -raw redis_hostname       # used to build the Redis connection string
```

---

### Step 2 — Connect kubectl to AKS

```bash
az aks get-credentials \
  --resource-group jd-core-rg \
  --name jd-aks \
  --overwrite-existing

kubectl get nodes
```

---

### Step 3 — Install ArgoCD

```bash
kubectl create namespace argocd

helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm install argocd argo/argo-cd \
  --namespace argocd \
  --version 7.7.0 \
  --set server.service.type=LoadBalancer
```

Wait for ArgoCD to be ready:

```bash
kubectl wait --for=condition=available deployment/argocd-server \
  -n argocd --timeout=120s
```

Get the initial admin password:

```bash
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath="{.data.password}" | base64 -d
```

---

### Step 4 — Bootstrap GitOps

```bash
kubectl apply -f kubernetes-platform/argocd/root-app.yaml
```

ArgoCD will now discover and sync every Application in `kubernetes-platform/argocd/apps/` — all namespaces, KEDA, Prometheus, Grafana, OTEL Collector, and all microservices are deployed automatically.

Monitor sync progress:

```bash
kubectl get applications -n argocd
# or port-forward the ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# https://localhost:8080  (admin / <password from step 3>)
```

---

### Step 5 — Create the Redis secret

The cartservice connects to Azure Cache for Redis. The connection string is not stored in git — create the secret manually:

```bash
# Get the Redis primary key
REDIS_HOST=$(cd terraform/environments/dev && terraform output -raw redis_hostname)
REDIS_KEY=$(az redis list-keys \
  --name sre-redis-cart \
  --resource-group jd-core-rg \
  --query primaryKey -o tsv)

kubectl create secret generic redis-secret \
  --namespace core \
  --from-literal=connectionString="${REDIS_HOST}:6380,ssl=true,abortConnect=false,password=${REDIS_KEY}"
```

---

### Step 6 — Verify everything is running

```bash
# All core services (10 pods expected Running)
kubectl get pods -n core

# Workers (expected: 0 replicas when no messages in queue — this is correct)
kubectl get pods -n workers
kubectl get scaledobject -n workers

# Observability stack
kubectl get pods -n observability

# KEDA operator
kubectl get pods -n keda

# All ArgoCD apps Synced + Healthy
kubectl get applications -n argocd
```

---

### Step 7 — Access the platform

**Storefront (frontend)**
```bash
kubectl get svc frontend -n core
# External IP is exposed via LoadBalancer — open in browser
```

**Grafana**
```bash
kubectl port-forward svc/prometheus-grafana -n observability 3000:80
# http://localhost:3000  admin / prom-operator
```

**ArgoCD UI**
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# https://localhost:8080
```

**Application Insights**
```
Azure Portal → Resource group jd-core-rg → sre-appinsights
→ Transaction search / Live metrics / Application map
```

---

## Operational Reference

### Stop / resume (cost management)

```bash
# Stop — eliminates compute billing, preserves all data
az aks stop --name jd-aks --resource-group jd-core-rg

# Resume
az aks start --name jd-aks --resource-group jd-core-rg
```

### Redis outbound IP update

If the AKS cluster is rebuilt, the Redis firewall rule (`aks_outbound_ip` in `config.yaml`) must be updated:

```bash
az aks show \
  --name jd-aks \
  --resource-group jd-core-rg \
  --query "networkProfile.loadBalancerProfile.effectiveOutboundIPs[0].id" \
  -o tsv \
  | xargs az network public-ip show --ids --query ipAddress -o tsv
```

Paste the new IP into `terraform/environments/dev/config.yaml` → `redis.aks_outbound_ip`, then `terraform apply`.

### Forced ArgoCD sync

```bash
kubectl annotate application <app-name> \
  -n argocd \
  argocd.argoproj.io/refresh=hard --overwrite
```

### Tear down everything

```bash
az group delete --name jd-core-rg --yes --no-wait
```

---

## Known Behaviours

| Observation | Reason |
|---|---|
| Workers show 0 pods | Expected — KEDA scales to zero when the Service Bus queue is empty |
| KEDA shows OutOfSync briefly after deploy | CRD size exceeds `kubectl apply` annotation limit; `ServerSideApply=true` is set to handle this |
| frontend/checkoutservice/productcatalogservice use `COLLECTOR_SERVICE_ADDR` | These Go services use a custom `mustMapEnv`+`mustConnGRPC` pattern requiring raw `host:port`, not a URL |

---

## Author

**Joshua Ukpozi**  
Cloud Infrastructure Engineer  
Azure · Kubernetes · Terraform · SRE · Observability

