variable "location" {
  type = string
}

variable "rg_name" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "node_count" {
  type    = number
  default = 3
}

variable "subnet_id" {
  type = string
}

variable "log_analytics_id" {
  type = string
}

