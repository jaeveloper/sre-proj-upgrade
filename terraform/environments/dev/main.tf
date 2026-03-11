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
  user_vm_size     = local.config.aks.user_vm_size
  user_node_min    = local.config.aks.user_node_min
  user_node_max    = local.config.aks.user_node_max
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

  location        = local.config.location
  rg_name         = azurerm_resource_group.rg.name
  aks_outbound_ip = local.config.redis.aks_outbound_ip
}

module "workload_identity" {
  source = "../../modules/workload-identity"

  location                = local.config.location
  rg_name                 = azurerm_resource_group.rg.name
  oidc_issuer_url         = module.aks.oidc_issuer_url
  servicebus_namespace_id = module.servicebus.namespace_id
  cosmos_account_id       = module.cosmos.account_id
  cosmos_account_name     = module.cosmos.account_name
  redis_id                = module.redis.redis_id
}

# ── Cosmos DB seed ───────────────────────────────────────────────────────────
# Runs scripts/seed_cosmos.py after the products container is created (or
# recreated). The trigger ensures it re-runs if the container is destroyed and
# rebuilt, but is otherwise a no-op on subsequent applies (upserts are safe).
resource "null_resource" "seed_cosmos" {
  triggers = {
    container_id = module.cosmos.container_id
  }

  provisioner "local-exec" {
    command = "python ${path.module}/../../../scripts/seed_cosmos.py"

    environment = {
      COSMOS_ENDPOINT  = module.cosmos.endpoint
      COSMOS_DATABASE  = module.cosmos.database_name
      COSMOS_CONTAINER = module.cosmos.container_name
      PRODUCTS_JSON    = "${path.module}/../../../services/productcatalogservice/products.json"
    }
  }

  depends_on = [
    module.cosmos,
    module.workload_identity,
  ]
}

output "worker_client_ids" {
  description = "Managed Identity client IDs — paste into helm/workers/*/values.yaml"
  value       = module.workload_identity.client_ids
}

output "keda_operator_client_id" {
  description = "KEDA operator Managed Identity client ID — configure in KEDA ArgoCD app helm values"
  value       = module.workload_identity.keda_operator_client_id
}

output "cosmos_endpoint" {
  description = "Cosmos DB endpoint — use in productcatalogservice COSMOS_ENDPOINT env var"
  value       = module.cosmos.endpoint
}

output "cosmos_database" {
  description = "Cosmos DB database name"
  value       = module.cosmos.database_name
}

output "cosmos_container" {
  description = "Cosmos DB container name"
  value       = module.cosmos.container_name
}

output "redis_hostname" {
  description = "Redis hostname — part of REDIS_ADDR connection string"
  value       = module.redis.redis_hostname
}
