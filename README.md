

```markdown
# Azure Cloud-Native Event-Driven Platform on AKS  
### (Workload Identity + Cosmos RBAC + KEDA + Argo CD GitOps)

---

## 📌 Executive Summary

This project implements a secure, event-driven microservices platform on Azure Kubernetes Service (AKS) using modern cloud-native and zero-trust patterns.

The system demonstrates:

- 🔐 Azure Workload Identity (OIDC federation)
- 🔐 Cosmos DB Native RBAC (no keys)
- 🔐 Azure RBAC for Service Bus (no SAS)
- ⚡ KEDA-based event-driven autoscaling
- 🔄 Argo CD GitOps continuous reconciliation
- 🧠 Centralized operational control via Nerve Center
- 🐳 Containerized microservices with Docker
- 🏗 Terraform-provisioned Azure infrastructure

This architecture mirrors enterprise-grade Azure platform engineering patterns.

---

# 🏗 High-Level Architecture

```

```
               ┌──────────────────────┐
               │       GitHub        │
               │  (Source of Truth)  │
               └──────────┬──────────┘
                          │
                          ▼
                    ┌────────────┐
                    │  Argo CD   │
                    │  GitOps    │
                    └──────┬─────┘
                           │
                           ▼
```

┌────────────────────────────────────────────────────────────┐
│                        AKS Cluster                         │
│                                                            │
│   Namespace: core                                          │
│   ├── nerve-center                                         │
│                                                            │
│   Namespace: workers                                       │
│   ├── order-processor                                      │
│   ├── retry-worker                                         │
│   └── KEDA ScaledObjects                                   │
│                                                            │
│   Namespace: keda                                          │
│   └── keda-operator                                        │
│                                                            │
└────────────────────────────────────────────────────────────┘
│                         │
▼                         ▼
Azure Service Bus          Azure Cosmos DB
(Topic + Subscriptions)     (RBAC Only Access)

```

---

# 🧠 Core Platform Components

---

## 1️⃣ Nerve Center (Control Plane API)

Nerve Center acts as an internal operational control API.

Responsibilities:

- Global pause/unpause of worker processing
- System state visibility
- Operational control endpoint
- Runtime control without redeployment

Workers continuously poll:

```

GET /system-state

```

If:

```

pauseProcessing = true

```

Workers stop consuming messages but remain alive.

---

### Example

**Pause Processing**
```

POST /pause-processing

```

**Check State**
```

GET /system-state


### 📷 IMAGE G – Port Forward to Nerve Center

> <img width="873" height="291" alt="image" src="https://github.com/user-attachments/assets/3c5c3396-b124-4771-ade4-5f7aa9afee39" />


```

---


```

kubectl port-forward -n core deployment/nerve-center 8080:8080


---

### 📷 IMAGE H – Pause Processing Response

> <img width="940" height="401" alt="image" src="https://github.com/user-attachments/assets/db475863-42d8-4b71-a4e9-7a4afd0e227e" />




---

### 📷 IMAGE I – System State Check (200 OK)

> <img width="861" height="392" alt="image" src="https://github.com/user-attachments/assets/857fe715-8cd8-4530-b132-29f1261e47dd" />


---

````


## 2️⃣ Worker Services

### order-processor
### retry-worker

Each worker:

- Uses `DefaultAzureCredential()`
- Authenticates via Workload Identity
- Connects to:
  - Azure Service Bus
  - Azure Cosmos DB
- Obeys Nerve Center state
- Scales via KEDA

No secrets.
No connection strings.
No stored keys.

---

## 3️⃣ Azure Service Bus (Event Backbone)

- Topic: `business-events`
- Subscriptions:
  - order-sub
  - retry-sub

KEDA monitors message count and scales deployments.

---
````
### 📷 IMAGE C – Service Bus Namespace (Azure Portal)

> <img width="901" height="422" alt="image" src="https://github.com/user-attachments/assets/00387330-e052-4358-8822-639803cc0121" />

````
---

## 4️⃣ Azure Cosmos DB (Data Layer)

- SQL API
- Native RBAC
- No primary keys used
- Role: `Cosmos DB Built-in Data Contributor`

Authentication via:

```python
CosmosClient(endpoint, credential=DefaultAzureCredential())
````

---

## 5️⃣ Azure Workload Identity (Zero-Secret Model)

Authentication flow:

1. AKS OIDC issuer enabled
2. User Assigned Managed Identity created
3. Federated Identity Credential configured
4. Kubernetes ServiceAccount annotated:

```
azure.workload.identity/client-id: <managed-identity-client-id>
```

5. Pod receives projected OIDC token
6. Azure AD validates token
7. Access token issued
8. Resource accessed via RBAC

No secret injection required.

---

# ⚡ KEDA – Event-Driven Autoscaling

KEDA ScaledObject monitors Service Bus:

```yaml
triggers:
  - type: azure-servicebus
    metadata:
      topicName: business-events
      subscriptionName: retry-sub
      messageCount: "1"
```

Scaling behavior:

* Queue length > threshold → scale up
* Queue empty → scale down to 0

---

### 📷 IMAGE A – Helm Install KEDA

<img width="940" height="475" alt="image" src="https://github.com/user-attachments/assets/94dacb1b-4e9e-40a1-a913-5782db604578" />

> helm install keda kedacore/keda --namespace keda --create-namespace

---

### 📷 IMAGE B – KEDA Pods Running

<img width="940" height="431" alt="image" src="https://github.com/user-attachments/assets/f747366d-ea22-45d4-a676-ac2e343044c2" />

> kubectl get pods -n keda

---

# 🔄 Argo CD – GitOps Continuous Reconciliation

Argo CD manages:

* worker deployments
* scaled objects
* service accounts
* namespace manifests

Auto Sync:

* Enabled
* Prune enabled
* Self-heal enabled

Manual drift is reverted automatically.

---

### 📷 IMAGE J – Argo CD UI

<img width="940" height="509" alt="image" src="https://github.com/user-attachments/assets/f032f452-7c24-4822-ba28-5d4d4b7dae13" />

> (Insert screenshot)

---

# 🐳 Containerization

### Docker Build

---

### 📷 IMAGE F – Docker Build
<img width="940" height="456" alt="image" src="https://github.com/user-attachments/assets/21673e87-e5e2-4557-bd98-b6dcd564bc6c" />

---

Images pushed to Docker Hub:
<img width="1877" height="1017" alt="image" src="https://github.com/user-attachments/assets/4c83ddfe-901e-426d-a0b6-c3ea1b535faa" />

```
jukpozi/order-processor:latest
jukpozi/retry-worker:latest
```

---

# 🏗 Infrastructure Provisioning (Terraform)

Provisioned Resources:

* AKS Cluster
* Cosmos DB Account
* Service Bus Namespace
* User Assigned Managed Identities
* Role Assignments
* OIDC Issuer Enabled

---

### 📷 IMAGE D – Azure Resources After Terraform Apply

> (Insert screenshot of resource group)

---

# 🔐 Security Model

| Component          | Authentication Method  |
| ------------------ | ---------------------- |
| AKS → Azure        | OIDC Workload Identity |
| Workers → SB       | Azure RBAC             |
| Workers → Cosmos   | Cosmos Native RBAC     |
| Secrets in Cluster | None                   |
| Connection Strings | None                   |

Zero secret sprawl.
Zero hardcoded credentials.

---

# 🔄 End-to-End Flow

1. Message published to Service Bus topic
2. KEDA detects message count
3. Deployment scales
4. Worker authenticates using Workload Identity
5. Worker processes message
6. Data written to Cosmos DB
7. Worker scales down when queue drains

---

# 📁 Repository Structure

```
sre-proj/
├── k8s/
│   ├── core/
│   │   ├── nerve-center/
│   │   └── keda/
│   ├── workers/
│   │   ├── order-processor/
│   │   └── retry-worker/
│   ├── namespaces/
│   └── observability/
├── services/
│   ├── worker-service/
│   ├── nerve-center/
│   └── test-service/
└── terraform-infra/
```

---

# 🎯 What This Demonstrates

* Identity-first cloud design
* Event-driven autoscaling
* Zero-secret architecture
* GitOps continuous reconciliation
* Azure-native RBAC enforcement
* Runtime operational control
* Terraform-based infra provisioning
* Kubernetes production patterns

---

# 🛑 Cost Shutdown

To stop billing:

```
az group delete --name <resource-group> --yes --no-wait
```

OR stop AKS:

```
az aks stop --name <aks-name> --resource-group <rg>
```

---

# 🚀 Future Enhancements

* Argo CD SSO via Entra ID
* Environment promotion (dev → prod)
* Argo Image Updater
* Helm chart refactor
* Prometheus + Grafana via GitOps
* Multi-cluster deployment
* Policy enforcement via Azure Policy for AKS

---

# 👤 Author

**Joshua Ukpozi**
Cloud Infrastructure Engineer
Azure | Kubernetes | Networking | IaC | Cloud Security

```

---
