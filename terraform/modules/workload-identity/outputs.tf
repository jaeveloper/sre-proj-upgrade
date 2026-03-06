output "client_ids" {
  description = "Map of worker name to Managed Identity client ID"
  value = {
    for name, identity in azurerm_user_assigned_identity.worker :
    name => identity.client_id
  }
}

output "principal_ids" {
  description = "Map of worker name to Managed Identity principal ID"
  value = {
    for name, identity in azurerm_user_assigned_identity.worker :
    name => identity.principal_id
  }
}
