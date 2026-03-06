variable "location" {
  type = string
}

variable "rg_name" {
  type = string
}

variable "oidc_issuer_url" {
  type        = string
  description = "OIDC issuer URL from the AKS cluster"
}

variable "servicebus_namespace_id" {
  type        = string
  description = "Resource ID of the Service Bus namespace"
}

variable "workers" {
  type        = list(string)
  description = "List of worker names to create identities for"
  default = [
    "adservice-worker",
    "cartservice-worker",
    "checkoutservice-worker",
    "currencyservice-worker",
    "emailservice-worker",
    "paymentservice-worker",
    "productcatalogservice-worker",
    "recommendationservice-worker",
    "shippingservice-worker",
    "shoppingassistantservice-worker"
  ]
}

variable "k8s_namespace" {
  type        = string
  description = "Kubernetes namespace where worker ServiceAccounts live"
  default     = "workers"
}
