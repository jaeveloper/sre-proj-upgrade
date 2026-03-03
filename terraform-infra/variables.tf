
variable "location" {
  default = "westus2"
}

variable "rg_name" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "subscription_id" {
  description = "Azure Subscription ID — required by azurerm v4 provider"
  type        = string
}
