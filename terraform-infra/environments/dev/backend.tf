terraform {
  backend "azurerm" {
    resource_group_name  = "jd-core-rg"
    storage_account_name = "sretfstate"
    container_name       = "tfstate"
    key                  = "dev.terraform.tfstate"
  }
}
