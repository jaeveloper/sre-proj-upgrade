from azure.identity import DefaultAzureCredential
from azure.servicebus import ServiceBusClient, ServiceBusMessage

# Service Bus namespace + topic
NAMESPACE = "sre-sb-namespace.servicebus.windows.net"
TOPIC_NAME = "business-events"

def main():
    # Use Workload Identity inside AKS, or Azure CLI login locally
    credential = DefaultAzureCredential()

    sb_client = ServiceBusClient(NAMESPACE, credential)

    # Send 10 test messages
    with sb_client.get_topic_sender(TOPIC_NAME) as sender:
        for i in range(10):
            msg = ServiceBusMessage(f"Test message {i}")
            sender.send_messages(msg)
            print(f"Sent message {i}")

if __name__ == "__main__":
    main()
