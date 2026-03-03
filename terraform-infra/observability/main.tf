resource "azurerm_log_analytics_workspace" "law" {
  name                = "sre-law"
  location            = var.location
  resource_group_name = var.rg_name
  sku                 = "PerGB2018"
}

resource "azurerm_application_insights" "appi" {
  name                = "sre-appinsights"
  location            = var.location
  resource_group_name = var.rg_name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.law.id
}
