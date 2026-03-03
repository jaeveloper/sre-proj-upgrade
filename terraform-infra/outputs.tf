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

output "redis_hostname" {
  value = module.redis.redis_hostname
}

output "redis_port" {
  value = module.redis.redis_port
}

output "redis_primary_key" {
  value     = module.redis.redis_primary_key
  sensitive = true
}
