resource "azurerm_servicebus_namespace" "sb" {
  name                = "sre-sb-namespace"
  location            = var.location
  resource_group_name = var.rg_name
  sku                 = "Standard"
}

resource "azurerm_servicebus_topic" "events" {
  name         = "business-events"
  namespace_id = azurerm_servicebus_namespace.sb.id
}

resource "azurerm_servicebus_subscription" "order" {
  name     = "order-sub"
  topic_id = azurerm_servicebus_topic.events.id
  max_delivery_count = 5
}
