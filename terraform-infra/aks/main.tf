resource "azurerm_kubernetes_cluster" "aks" {
  name                = "sre-aks"
  location            = var.location
  resource_group_name = var.rg_name
  dns_prefix          = "sre-aks"

  identity {
    type = "SystemAssigned"
  }

  default_node_pool {
    name       = "system"
    node_count = 2
    vm_size = "Standard_DC2ds_v3"
    vnet_subnet_id = var.subnet_id
  }

  oms_agent {
    log_analytics_workspace_id = var.log_analytics_id
  }

  network_profile {
  network_plugin = "azure"
  service_cidr   = "10.1.0.0/16"
  dns_service_ip = "10.1.0.10"
  }
}
