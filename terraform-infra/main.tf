resource "azurerm_resource_group" "rg" {
  name     = var.rg_name
  location = var.location
}

module "network" {
  source   = "./network"
  rg_name  = azurerm_resource_group.rg.name
  location = var.location
}

module "observability" {
  source   = "./observability"
  rg_name  = azurerm_resource_group.rg.name
  location = var.location
}

module "aks" {
  source           = "./aks"
  rg_name          = azurerm_resource_group.rg.name
  location         = var.location
  cluster_name     = var.cluster_name
  subnet_id        = module.network.aks_subnet_id
  log_analytics_id = module.observability.log_analytics_id
}

module "servicebus" {
  source   = "./servicebus"
  rg_name  = azurerm_resource_group.rg.name
  location = var.location
}

module "cosmos" {
  source   = "./cosmos"
  rg_name  = azurerm_resource_group.rg.name
  location = var.location
}



