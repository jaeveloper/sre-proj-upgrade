locals {
  config = yamldecode(file("${path.module}/config.yaml"))
}

resource "azurerm_resource_group" "rg" {
  name     = local.config.rg_name
  location = local.config.location
}

module "network" {
  source      = "../../modules/network"

  location    = local.config.location
  rg_name     = azurerm_resource_group.rg.name
  vnet_cidr   = local.config.network.vnet_cidr
  subnet_cidr = local.config.network.subnet_cidr
}

module "observability" {
  source   = "../../modules/observability"

  location = local.config.location
  rg_name  = azurerm_resource_group.rg.name
}

module "aks" {
  source           = "../../modules/aks"

  location         = local.config.location
  rg_name          = azurerm_resource_group.rg.name
  cluster_name     = local.config.aks.cluster_name
  vm_size          = local.config.aks.vm_size
  node_min         = local.config.aks.node_min
  node_max         = local.config.aks.node_max
  subnet_id        = module.network.aks_subnet_id
  log_analytics_id = module.observability.log_analytics_id
  service_cidr     = local.config.aks.service_cidr
  dns_service_ip   = local.config.aks.dns_service_ip
}

module "cosmos" {
  source     = "../../modules/cosmos"

  location   = local.config.location
  rg_name    = azurerm_resource_group.rg.name
  throughput = local.config.cosmos.throughput
}

module "servicebus" {
  source   = "../../modules/servicebus"

  location = local.config.location
  rg_name  = azurerm_resource_group.rg.name
  sku      = local.config.servicebus.sku
}

module "redis" {
  source   = "../../modules/redis"

  location = local.config.location
  rg_name  = azurerm_resource_group.rg.name
}

module "workload_identity" {
  source = "../../modules/workload-identity"

  location                = local.config.location
  rg_name                 = azurerm_resource_group.rg.name
  oidc_issuer_url         = module.aks.oidc_issuer_url
  servicebus_namespace_id = module.servicebus.namespace_id
}

output "worker_client_ids" {
  description = "Managed Identity client IDs — paste into helm/workers/*/values.yaml"
  value       = module.workload_identity.client_ids
}
