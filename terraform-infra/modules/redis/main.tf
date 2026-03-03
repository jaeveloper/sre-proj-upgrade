resource "azurerm_redis_cache" "redis" {
  name                = "sre-redis-cart"
  location            = var.location
  resource_group_name = var.rg_name
  capacity            = 1
  family              = "C"
  sku_name            = "Standard"

  redis_configuration {
    maxmemory_policy = "allkeys-lru"
  }

  minimum_tls_version = "1.2"
}

# Restrict Redis access to AKS pod subnet only (Standard SKU uses firewall rules)
# AKS subnet is 10.0.0.0/22 after network expansion
resource "azurerm_redis_firewall_rule" "aks_subnet" {
  name                = "allow_aks_pods"
  redis_cache_name    = azurerm_redis_cache.redis.name
  resource_group_name = var.rg_name
  start_ip            = "10.0.0.0"
  end_ip              = "10.0.3.255"
}
