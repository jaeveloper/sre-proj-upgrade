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

# ── original workers ────────────────────────────────────────────
resource "azurerm_servicebus_subscription" "order" {
  name               = "order-sub"
  topic_id           = azurerm_servicebus_topic.events.id
  max_delivery_count = 5
}

resource "azurerm_servicebus_subscription" "retry" {
  name               = "retry-sub"
  topic_id           = azurerm_servicebus_topic.events.id
  max_delivery_count = 10
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

resource "azurerm_servicebus_subscription" "checkoutservice" {
  name               = "checkoutservice-sub"
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
