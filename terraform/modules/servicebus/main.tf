resource "azurerm_servicebus_namespace" "sb" {
  name                = "sre-sb-namespace"
  location            = var.location
  resource_group_name = var.rg_name
  sku                 = var.sku
}

resource "azurerm_servicebus_topic" "events" {
  name         = "business-events"
  namespace_id = azurerm_servicebus_namespace.sb.id

  depends_on = [azurerm_servicebus_namespace.sb]
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

# ── microservice workers ─────────────────────────────────────────
resource "azurerm_servicebus_subscription" "adservice" {
  name               = "adservice-sub"
  topic_id           = azurerm_servicebus_topic.events.id
  max_delivery_count = 5
}

resource "azurerm_servicebus_subscription" "cartservice" {
  name               = "cartservice-sub"
  topic_id           = azurerm_servicebus_topic.events.id
  max_delivery_count = 10
}

resource "azurerm_servicebus_subscription" "currencyservice" {
  name               = "currencyservice-sub"
  topic_id           = azurerm_servicebus_topic.events.id
  max_delivery_count = 5
}

resource "azurerm_servicebus_subscription" "emailservice" {
  name               = "emailservice-sub"
  topic_id           = azurerm_servicebus_topic.events.id
  max_delivery_count = 3
}

resource "azurerm_servicebus_subscription" "paymentservice" {
  name               = "paymentservice-sub"
  topic_id           = azurerm_servicebus_topic.events.id
  max_delivery_count = 10
}

resource "azurerm_servicebus_subscription" "productcatalogservice" {
  name               = "catalogservice-sub"
  topic_id           = azurerm_servicebus_topic.events.id
  max_delivery_count = 5
}

resource "azurerm_servicebus_subscription" "recommendationservice" {
  name               = "recommendationservice-sub"
  topic_id           = azurerm_servicebus_topic.events.id
  max_delivery_count = 5
}

resource "azurerm_servicebus_subscription" "shippingservice" {
  name               = "shippingservice-sub"
  topic_id           = azurerm_servicebus_topic.events.id
  max_delivery_count = 10
}

resource "azurerm_servicebus_subscription" "shoppingassistantservice" {
  name               = "shoppingassistant-sub"
  topic_id           = azurerm_servicebus_topic.events.id
  max_delivery_count = 3
}
