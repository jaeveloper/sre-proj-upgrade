# Azure Cloud-Native Microservices Platform on AKS

**Workload Identity  Cosmos DB RBAC  KEDA  Argo CD GitOps  Terraform**

---

## Executive Summary

This project delivers a production-grade, event-driven microservices platform on Azure Kubernetes Service (AKS). It is based on the Google Online Boutique e-commerce demo, re-architected for Azure with enterprise security and operations patterns throughout.

Key capabilities:

- **Azure Workload Identity**  OIDC-federated pod authentication, zero stored credentials
- **Cosmos DB Native RBAC**  data-plane access with no primary keys
- **Azure RBAC for Service Bus**  no SAS tokens or connection strings
- **KEDA**  event-driven autoscaling driven by Service Bus message counts
- **Argo CD GitOps**  automated, self-healing reconciliation from Git
- **Terraform**  fully scripted Azure infrastructure across dev and prod environments
- **Observability**  Application Insights and structured logging

---

## High-Level Architecture

```
GitHub (Source of Truth)
        |
        v
   Argo CD (GitOps)
        |
        v
+-------------------------------------------------------+
|                      AKS: jd-aks                      |
|                                                       |
|  Namespace: core                                      |
|  +-- adservice, cartservice, checkoutservice,         |
|      currencyservice, frontend,                       |
|      productcatalogservice, recommendationservice     |
|                                                       |
|  Namespace: workers                                   |
|  +-- checkout-worker, email-worker,                   |
|      payment-worker, shipping-worker                  |
|      (each with KEDA ScaledObject)                    |
|                                                       |
|  Namespace: keda                                      |
|  +-- keda-operator (Workload Identity auth to SB)     |
|                                                       |
|  Namespace: argocd                                    |
|  +-- Argo CD control plane                            |
+-------------------------------------------------------+
        |                         |
        v                         v
Azure Service Bus           Azure Cosmos DB
sre-sb-namespace            SQL API, RBAC only
topic: business-events
        |
        v
   Azure Cache for Redis
```

---

## Repository Structure

```
sre-proj-upgrade/
+-- helm/
|   +-- core-services/          # Helm charts for storefront microservices
|   |   +-- adservice/
|   |   +-- cartservice/
|   |   +-- checkoutservice/
|   |   +-- currencyservice/
|   |   +-- frontend/
|   |   +-- productcatalogservice/
|   |   +-- recommendationservice/
|   +-- workers/                # Helm charts for KEDA-scaled event workers
|       +-- checkout-worker/
|       +-- email-worker/
|       +-- payment-worker/
|       +-- shipping-worker/
+-- kubernetes-platform/
|   +-- argocd/
|   |   +-- root-app.yaml       # App of Apps bootstrap
|   |   +-- apps/               # One Argo CD Application per service/worker
|   +-- keda/
|   |   +-- keda-operator-sa.yaml
|   +-- namespaces/             # argocd, core, keda, workers
|   +-- observability/
|       +-- app-insights/
|       +-- logging/
+-- services/                   # Microservice source code
|   +-- adservice/              # Java (gRPC)
|   +-- cartservice/            # .NET
|   +-- checkoutservice/        # Go
|   +-- currencyservice/        # Node.js
|   +-- emailservice/           # Python
|   +-- frontend/               # Go
|   +-- loadgenerator/          # Python / Locust
|   +-- paymentservice/         # Node.js
|   +-- productcatalogservice/  # Go
|   +-- recommendationservice/  # Python
|   +-- shippingservice/        # Go
|   +-- shoppingassistantservice/
+-- terraform/
    +-- environments/
    |   +-- dev/                # dev config + state
    |   +-- prod/               # prod config + state
    +-- modules/
        +-- aks/
        +-- cosmos/
        +-- network/
        +-- observability/
        +-- redis/
        +-- servicebus/
        +-- workload-identity/
```

---

## Core Services (Namespace: `core`)

The storefront microservices are adapted from the Google Online Boutique demo:

| Service | Language | Role |
|---|---|---|
| `frontend` | Go | HTTP server, renders the shop UI |
| `adservice` | Java | Returns context-targeted ads |
| `cartservice` | .NET | Manages user shopping carts via Redis |
| `checkoutservice` | Go | Orchestrates the checkout flow |
| `currencyservice` | Node.js | Currency conversion |
| `productcatalogservice` | Go | Product listing and search |
| `recommendationservice` | Python | Product recommendations |

Each service is deployed via its own Helm chart under `helm/core-services/` and managed by a dedicated Argo CD Application in `kubernetes-platform/argocd/apps/`.

---

## Worker Services (Namespace: `workers`)

Workers subscribe to the `business-events` Service Bus topic and process domain events asynchronously. Each worker:

- Authenticates to Azure via Workload Identity (`DefaultAzureCredential`)
- Reads from a dedicated Service Bus subscription
- Writes results to Cosmos DB
- Scales to zero when idle via KEDA

| Worker | Service Bus Subscription |
|---|---|
| `checkout-worker` | `checkoutservice-sub` |
| `email-worker` | `emailservice-sub` |
| `payment-worker` | `payment-sub` |
| `shipping-worker` | `shipping-sub` |

Each worker chart contains:

- `templates/deployment.yaml`
- `templates/serviceaccount.yaml` (annotated with Workload Identity client ID)
- `templates/scaledobject.yaml`
- `templates/trigger-auth.yaml`

---

## Azure Workload Identity

Authentication flow  no credentials stored anywhere:

1. AKS cluster has OIDC issuer enabled
2. Terraform provisions a User Assigned Managed Identity per worker
3. A Federated Identity Credential links the identity to the Kubernetes ServiceAccount
4. The ServiceAccount is annotated with the managed identity client ID:

```yaml
azure.workload.identity/client-id: "<client-id>"
```

5. At runtime the pod receives a projected OIDC token
6. Entra ID validates the token and issues an access token
7. The worker accesses Service Bus and Cosmos DB using Azure RBAC

No passwords. No connection strings. No Kubernetes Secrets.

---

## KEDA  Event-Driven Autoscaling

KEDA monitors the Service Bus subscription message count:

```yaml
triggers:
  - type: azure-servicebus
    metadata:
      topicName: business-events
      subscriptionName: checkoutservice-sub
      messageCount: "3"
```

KEDA authenticates to Service Bus using the same Workload Identity federated credential via a `TriggerAuthentication` object  no SAS tokens required.

Scaling behaviour:

- Messages present  scale up (up to `maxReplicaCount: 15`)
- Queue empty  scale down to zero (`minReplicaCount: 0`)

---

## Argo CD  GitOps

The repository is the single source of truth. An App of Apps pattern is used:

- `kubernetes-platform/argocd/root-app.yaml` bootstraps the platform
- `kubernetes-platform/argocd/apps/` contains one `Application` manifest per service and worker
- All applications use automated sync, prune, and self-heal:

```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
```

Any manual change to the cluster is automatically reverted.

---

## Infrastructure (Terraform)

All Azure resources are provisioned via Terraform modules driven by per-environment `config.yaml` files.

**Dev environment** (`terraform/environments/dev/`):

- Resource group: `jd-core-rg`  West US 2
- AKS cluster: `jd-aks` (system pool `Standard_B4als_v2`, user pool `Standard_D2s_v3`)
- Cosmos DB (SQL API, 4000 RU/s)
- Service Bus namespace `sre-sb-namespace` (Standard SKU)
- Azure Cache for Redis
- Virtual network with dedicated AKS subnet
- Log Analytics workspace + Application Insights
- Workload Identity  one User Assigned Managed Identity per worker

**Modules:**

| Module | Resources |
|---|---|
| `aks` | AKS cluster, OIDC issuer, node pools |
| `cosmos` | Cosmos DB account, database, container, RBAC role assignment |
| `servicebus` | Namespace, topic, subscriptions |
| `redis` | Azure Cache for Redis |
| `network` | VNet, subnet |
| `observability` | Log Analytics, Application Insights |
| `workload-identity` | Managed Identities, Federated Credentials, RBAC assignments |

After `terraform apply`, worker client IDs are output for pasting into the relevant `helm/workers/*/values.yaml` files.

---

## Security Model

| Component | Method |
|---|---|
| AKS  Entra ID | OIDC Workload Identity |
| Workers  Service Bus | Azure RBAC (`Azure Service Bus Data Receiver`) |
| Workers  Cosmos DB | Cosmos Native RBAC (`Built-in Data Contributor`) |
| KEDA  Service Bus | Workload Identity via TriggerAuthentication |
| Kubernetes Secrets | None |
| Connection Strings | None |
| SAS Tokens | None |

---

## End-to-End Event Flow

1. An event is published to the `business-events` Service Bus topic
2. KEDA detects the rising message count on the target subscription
3. The worker Deployment scales up from zero
4. The worker pod authenticates to Azure via Workload Identity
5. The worker reads and processes the message from Service Bus
6. Processed data is written to Cosmos DB
7. When the queue drains, KEDA scales the worker back to zero

---

## Getting Started

### Prerequisites

- Azure CLI authenticated (`az login`)
- Terraform >= 1.5
- kubectl
- Helm 3
- Argo CD CLI

### 1. Provision Infrastructure

```bash
cd terraform/environments/dev
terraform init
terraform apply
```

Note the `worker_client_ids` output and paste the values into the corresponding `helm/workers/*/values.yaml` files.

### 2. Bootstrap Argo CD

```bash
kubectl create namespace argocd
helm install argocd argo/argo-cd --namespace argocd
kubectl apply -f kubernetes-platform/argocd/root-app.yaml
```

Argo CD will detect and sync all Application manifests automatically.

### 3. Bootstrap KEDA

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm install keda kedacore/keda --namespace keda --create-namespace
```

### 4. Verify

```bash
# Core services
kubectl get pods -n core

# Workers
kubectl get pods -n workers

# KEDA scaled objects
kubectl get scaledobject -n workers

# Argo CD sync status
argocd app list
```

---

## Docker Images

Service images are built from source under `services/` and pushed to Docker Hub:

```
jukpozi/<service>:latest
jukpozi/<service>-worker:latest
```

---

## Cost Management

Stop the AKS cluster to pause compute billing:

```bash
az aks stop --name jd-aks --resource-group jd-core-rg
```

Tear down all resources:

```bash
az group delete --name jd-core-rg --yes --no-wait
```

---

## Future Enhancements

- Argo CD SSO via Entra ID
- Argo CD Image Updater for automated image promotion
- Environment promotion pipeline (dev  prod)
- Prometheus + Grafana via GitOps
- Azure Policy for AKS (admission control)
- Multi-cluster federation
- Distributed tracing with OpenTelemetry

---

## Author

**Joshua Ukpozi**  
Cloud Infrastructure Engineer  
Azure  Kubernetes  Networking  IaC  Cloud Security
