variable "location" {
  type = string
}

variable "rg_name" {
  type = string
}

variable "aks_outbound_ip" {
  type        = string
  description = "AKS cluster outbound NAT public IP. Pods reach Redis through this IP since Azure Cache for Redis does not support VNet service endpoints."
}
