#  User Assigned Managed Identity per worker 
resource "azurerm_user_assigned_identity" "worker" {
  for_each = toset(var.workers)

  name                = each.key
  location            = var.location
  resource_group_name = var.rg_name
}

#  Federated Identity Credential (workload pod) 
# Links each worker K8s ServiceAccount to its Managed Identity via OIDC
resource "azurerm_federated_identity_credential" "worker" {
  for_each = toset(var.workers)

  name            = each.key
  parent_id       = azurerm_user_assigned_identity.worker[each.key].id
  audience        = ["api://AzureADTokenExchange"]
  issuer          = var.oidc_issuer_url
  subject         = "system:serviceaccount:${var.k8s_namespace}:${each.key}-sa"
}

resource "azurerm_federated_identity_credential" "checkoutservice_core" {
  name      = "checkoutservice-core"
  parent_id = azurerm_user_assigned_identity.worker["checkoutservice-worker"].id
  audience  = ["api://AzureADTokenExchange"]
  issuer    = var.oidc_issuer_url
  subject   = "system:serviceaccount:core:checkoutservice-sa"
}

# Federated Identity Credential (KEDA operator override)
# When TriggerAuthentication uses identityId to override, KEDA presents the
# keda-operator SA token — so each worker identity needs a federated credential
# trusting system:serviceaccount:keda:keda-operator as well.
resource "azurerm_federated_identity_credential" "keda_override" {
  for_each = toset(var.workers)

  name      = "${each.key}-keda-override"
  parent_id = azurerm_user_assigned_identity.worker[each.key].id
  audience  = ["api://AzureADTokenExchange"]
  issuer    = var.oidc_issuer_url
  subject   = "system:serviceaccount:${var.keda_namespace}:keda-operator"
}

#  Service Bus RBAC 
# Grants each worker identity permission to read from Service Bus
resource "azurerm_role_assignment" "servicebus_receiver" {
  for_each = toset(var.workers)

  scope                = var.servicebus_namespace_id
  role_definition_name = "Azure Service Bus Data Receiver"
  principal_id         = azurerm_user_assigned_identity.worker[each.key].principal_id
}

resource "azurerm_role_assignment" "checkoutservice_servicebus_sender" {
  scope                = var.servicebus_namespace_id
  role_definition_name = "Azure Service Bus Data Sender"
  principal_id         = azurerm_user_assigned_identity.worker["checkoutservice-worker"].principal_id
}

# ─── KEDA Operator Identity ───────────────────────────────────────────────────
# KEDA's operator pod itself needs workload identity to call Azure Service Bus
# metrics APIs on behalf of the TriggerAuthentication resources.

resource "azurerm_user_assigned_identity" "keda_operator" {
  name                = "keda-operator"
  location            = var.location
  resource_group_name = var.rg_name
}

resource "azurerm_federated_identity_credential" "keda_operator" {
  name      = "keda-operator"
  parent_id = azurerm_user_assigned_identity.keda_operator.id
  audience  = ["api://AzureADTokenExchange"]
  issuer    = var.oidc_issuer_url
  subject   = "system:serviceaccount:${var.keda_namespace}:keda-operator"
}

resource "azurerm_role_assignment" "keda_servicebus_receiver" {
  scope                = var.servicebus_namespace_id
  role_definition_name = "Azure Service Bus Data Receiver"
  principal_id         = azurerm_user_assigned_identity.keda_operator.principal_id
}

# ─── Core Service Identities ──────────────────────────────────────────────────
# cartservice and productcatalogservice run in the `core` namespace and need
# their own federated credentials bound to their Managed Identities
# (reusing the worker identities already created above).

resource "azurerm_federated_identity_credential" "cartservice_core" {
  name      = "cartservice-core"
  parent_id = azurerm_user_assigned_identity.worker["cartservice-worker"].id
  audience  = ["api://AzureADTokenExchange"]
  issuer    = var.oidc_issuer_url
  subject   = "system:serviceaccount:core:cartservice-sa"
}

resource "azurerm_federated_identity_credential" "productcatalogservice_core" {
  name      = "productcatalogservice-core"
  parent_id = azurerm_user_assigned_identity.worker["productcatalogservice-worker"].id
  audience  = ["api://AzureADTokenExchange"]
  issuer    = var.oidc_issuer_url
  subject   = "system:serviceaccount:core:productcatalogservice-sa"
}

# ─── Cosmos DB RBAC ───────────────────────────────────────────────────────────
# Grants productcatalogservice the built-in Cosmos DB Data Contributor role
# so it can read/write documents via DefaultAzureCredential (Workload Identity).

resource "azurerm_cosmosdb_sql_role_assignment" "productcatalog_data_contributor" {
  resource_group_name = var.rg_name
  account_name        = var.cosmos_account_name
  role_definition_id  = "${var.cosmos_account_id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
  principal_id        = azurerm_user_assigned_identity.worker["productcatalogservice-worker"].principal_id
  scope               = var.cosmos_account_id
}

# ─── Redis IAM ────────────────────────────────────────────────────────────────
# cartservice authenticates to Redis using the connection string stored in the
# redis-secret Kubernetes Secret (access key). No Azure RBAC role is required
# for data-plane access when using key authentication.
# Management-plane access (portal/CLI) is covered by the subscription owner role.
