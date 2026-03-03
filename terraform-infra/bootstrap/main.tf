# Bootstrap — run this ONCE before enabling the remote backend in providers.tf
#
#   terraform -chdir=terraform-infra/bootstrap init
#   terraform -chdir=terraform-infra/bootstrap apply -var="subscription_id=<YOUR_ID>"
#
# After apply, uncomment the backend block in terraform-infra/providers.tf,
# then run: terraform init -migrate-state

resource "azurerm_resource_group" "bootstrap" {
  name     = var.rg_name
  location = var.location
}

resource "azurerm_storage_account" "tfstate" {
  name                     = "sretfstate"
  resource_group_name      = azurerm_resource_group.bootstrap.name
  location                 = azurerm_resource_group.bootstrap.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  blob_properties {
    versioning_enabled = true
  }
}

resource "azurerm_storage_container" "tfstate" {
  name                 = "tfstate"
  storage_account_name = azurerm_storage_account.tfstate.name
  container_access_type = "private"
}

output "storage_account_name" {
  value = azurerm_storage_account.tfstate.name
}

output "container_name" {
  value = azurerm_storage_container.tfstate.name
}
