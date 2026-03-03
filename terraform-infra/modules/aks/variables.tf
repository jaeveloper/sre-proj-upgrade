variable "location" {
  type = string
}

variable "rg_name" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "vm_size" {
  type = string
}

variable "node_min" {
  type = number
}

variable "node_max" {
  type = number
}

variable "subnet_id" {
  type = string
}

variable "log_analytics_id" {
  type = string
}

variable "service_cidr" {
  type = string
}

variable "dns_service_ip" {
  type = string
}

