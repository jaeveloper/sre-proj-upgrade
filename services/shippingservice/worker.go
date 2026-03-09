package main

import (
	"context"
	"encoding/json"
	"os"
	"time"

	"github.com/Azure/azure-sdk-for-go/sdk/azidentity"
	"github.com/Azure/azure-sdk-for-go/sdk/messaging/azservicebus"
)

type OrderEvent struct {
	OrderID string  `json:"order_id"`
	Total   float64 `json:"total"`
}

func getEnvOrDefault(key, defaultVal string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return defaultVal
}

func startWorker() {
	namespace := getEnvOrDefault("SERVICEBUS_NAMESPACE", "sre-sb-namespace")
	topic := getEnvOrDefault("SERVICEBUS_TOPIC", "checkout-events")
	subscription := getEnvOrDefault("SERVICEBUS_SUBSCRIPTION", "shipping")
	fqns := namespace + ".servicebus.windows.net"

	cred, err := azidentity.NewDefaultAzureCredential(nil)
	if err != nil {
		log.Fatalf("shipping worker: failed to create credential: %v", err)
	}

	client, err := azservicebus.NewClient(fqns, cred, nil)
	if err != nil {
		log.Fatalf("shipping worker: failed to create Service Bus client: %v", err)
	}
	defer client.Close(context.Background())

	receiver, err := client.NewReceiverForSubscription(topic, subscription, nil)
	if err != nil {
		log.Fatalf("shipping worker: failed to create receiver: %v", err)
	}
	defer receiver.Close(context.Background())

	log.Infof("Shipping worker started — %s topic=%s sub=%s", fqns, topic, subscription)

	for {
		messages, err := receiver.ReceiveMessages(context.Background(), 10, nil)
		if err != nil {
			log.Errorf("shipping worker: receive error: %v", err)
			time.Sleep(5 * time.Second)
			continue
		}

		for _, msg := range messages {
			body := string(msg.Body)

			var order OrderEvent
			if jsonErr := json.Unmarshal([]byte(body), &order); jsonErr != nil {
				log.Warnf("shipping worker: could not parse message body — %v", jsonErr)
				_ = receiver.AbandonMessage(context.Background(), msg, nil)
				continue
			}

			log.Infof("[ShipOrder] Processing order_id=%s total=%.2f", order.OrderID, order.Total)

			trackingID := CreateTrackingId("worker-dispatch-center")
			quote := CreateQuoteFromCount(1)

			log.Infof("[ShipOrder] tracking_id=%s cost=$%d.%02d", trackingID, quote.Dollars, quote.Cents)

			if compErr := receiver.CompleteMessage(context.Background(), msg, nil); compErr != nil {
				log.Errorf("shipping worker: failed to complete message: %v", compErr)
			}
		}
	}
}
