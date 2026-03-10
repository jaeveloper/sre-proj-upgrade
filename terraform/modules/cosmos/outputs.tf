output "account_name" {
  value = azurerm_cosmosdb_account.cosmos.name
}

output "account_id" {
  value = azurerm_cosmosdb_account.cosmos.id
}

output "endpoint" {
  value = azurerm_cosmosdb_account.cosmos.endpoint
}

output "database_name" {
  value = azurerm_cosmosdb_sql_database.product_catalog.name
}

output "container_name" {
  value = azurerm_cosmosdb_sql_container.products.name
}
