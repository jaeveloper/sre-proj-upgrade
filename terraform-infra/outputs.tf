output "aks_cluster_name" {
  value = module.aks.cluster_name
}

output "servicebus_namespace" {
  value = module.servicebus.namespace_name
}

output "log_analytics_workspace" {
  value = module.observability.log_analytics_id
}

output "cosmos_account_name" {
  value = module.cosmos.account_name
}
