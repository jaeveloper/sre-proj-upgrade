#  User Assigned Managed Identity per worker 
resource "azurerm_user_assigned_identity" "worker" {
  for_each = toset(var.workers)

  name                = each.key
  location            = var.location
  resource_group_name = var.rg_name
}

#  Federated Identity Credential 
# Links each K8s ServiceAccount to its Managed Identity via OIDC
resource "azurerm_federated_identity_credential" "worker" {
  for_each = toset(var.workers)

  name            = each.key
  parent_id       = azurerm_user_assigned_identity.worker[each.key].id
  audience        = ["api://AzureADTokenExchange"]
  issuer          = var.oidc_issuer_url
  subject         = "system:serviceaccount:${var.k8s_namespace}:${each.key}-sa"
}

#  Service Bus RBAC 
# Grants each worker identity permission to read from Service Bus
resource "azurerm_role_assignment" "servicebus_receiver" {
  for_each = toset(var.workers)

  scope                = var.servicebus_namespace_id
  role_definition_name = "Azure Service Bus Data Receiver"
  principal_id         = azurerm_user_assigned_identity.worker[each.key].principal_id
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
