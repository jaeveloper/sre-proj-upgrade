terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  # Remote state backend — uncomment after running: terraform -chdir=bootstrap apply
  # backend "azurerm" {
  #   resource_group_name  = "jd-core-rg"
  #   storage_account_name = "sretfstate"
  #   container_name       = "tfstate"
  #   key                  = "sre.tfstate"
  # }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}
