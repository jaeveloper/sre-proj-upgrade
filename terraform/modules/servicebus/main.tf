resource "azurerm_servicebus_namespace" "sb" {
  name                = "sre-sb-namespace"
  location            = var.location
  resource_group_name = var.rg_name
  sku                 = var.sku
}

resource "azurerm_servicebus_topic" "checkout_events" {
  name         = "checkout-events"
  namespace_id = azurerm_servicebus_namespace.sb.id

  depends_on = [azurerm_servicebus_namespace.sb]
}

# ── checkout-events subscriptions (event-driven workers) ─────────
resource "azurerm_servicebus_subscription" "payment" {
  name                                 = "payment"
  topic_id                             = azurerm_servicebus_topic.checkout_events.id
  max_delivery_count                   = 10
  lock_duration                        = "PT30S"
  dead_lettering_on_message_expiration = true
}

resource "azurerm_servicebus_subscription" "email" {
  name                                 = "email"
  topic_id                             = azurerm_servicebus_topic.checkout_events.id
  max_delivery_count                   = 10
  lock_duration                        = "PT30S"
  dead_lettering_on_message_expiration = true
}

resource "azurerm_servicebus_subscription" "shipping" {
  name                                 = "shipping"
  topic_id                             = azurerm_servicebus_topic.checkout_events.id
  max_delivery_count                   = 10
  lock_duration                        = "PT30S"
  dead_lettering_on_message_expiration = true
}


