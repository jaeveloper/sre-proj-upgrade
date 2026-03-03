resource "azurerm_kubernetes_cluster" "aks" {
  name                = "sre-aks"
  location            = var.location
  resource_group_name = var.rg_name
  dns_prefix          = "sre-aks"

  identity {
    type = "SystemAssigned"
  }

  default_node_pool {
    name                = "system"
    vm_size             = "Standard_D4ds_v5"
    vnet_subnet_id      = var.subnet_id
    # auto_scaling_enabled is the correct azurerm v4 attribute name.
    # (v3 used enable_auto_scaling — renamed in azurerm v4 upgrade)
    # IDE shows schema error until `terraform init -upgrade` downloads the v4 provider.
    auto_scaling_enabled = true
    min_count            = 2
    max_count            = 5
  }

  network_profile {
    network_plugin = "azure"
    service_cidr   = "10.1.0.0/16"
    dns_service_ip = "10.1.0.10"
  }

  workload_identity_enabled = true
  oidc_issuer_enabled       = true
}

# Replaces oms_agent (removed in azurerm v4) — streams AKS control-plane
# logs and metrics to the existing Log Analytics workspace
resource "azurerm_monitor_diagnostic_setting" "aks" {
  name                       = "aks-diagnostics"
  target_resource_id         = azurerm_kubernetes_cluster.aks.id
  log_analytics_workspace_id = var.log_analytics_id

  enabled_log { category = "kube-apiserver" }
  enabled_log { category = "kube-controller-manager" }
  enabled_log { category = "kube-scheduler" }
  enabled_log { category = "cluster-autoscaler" }

  metric {
    category = "AllMetrics"
  }
}
