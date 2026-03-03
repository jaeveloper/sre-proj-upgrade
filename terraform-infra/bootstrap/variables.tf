variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

variable "location" {
  type    = string
  default = "westus2"
}

variable "rg_name" {
  type    = string
  default = "jd-core-rg"
}
