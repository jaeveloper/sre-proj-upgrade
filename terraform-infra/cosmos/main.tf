resource "azurerm_cosmosdb_account" "cosmos" {
  name                = "sre-cosmos"
  location            = var.location
  resource_group_name = var.rg_name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = var.location
    failover_priority = 0
    zone_redundant = false
  }
}
