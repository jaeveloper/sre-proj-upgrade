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
