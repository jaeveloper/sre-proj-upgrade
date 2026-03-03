from azure.identity import DefaultAzureCredential
from azure.servicebus import ServiceBusClient
from azure.cosmos import CosmosClient
import requests
import os
import time
import json

# ==============================
# Configuration
# ==============================

SERVICEBUS_NAMESPACE = "sre-sb-namespace.servicebus.windows.net"
TOPIC_NAME = "business-events"
SUBSCRIPTION_NAME = os.getenv("SUBSCRIPTION_NAME", "retry-sub")

COSMOS_ENDPOINT = "https://sre-cosmos.documents.azure.com:443/"
COSMOS_DATABASE = "orders-db"
COSMOS_CONTAINER = "orders"

NERVE_CENTER_URL = os.getenv(
    "NERVE_CENTER_URL",
    "http://nerve-center.core.svc.cluster.local:8080"
)

# ==============================
# Globals (lazy init)
# ==============================

_credential = None
_sb_client = None
_cosmos_client = None


# ==============================
# Identity + Clients
# ==============================

def get_credential():
    global _credential
    if _credential is None:
        _credential = DefaultAzureCredential()
    return _credential


def get_servicebus_client():
    global _sb_client
    if _sb_client is None:
        _sb_client = ServiceBusClient(
            fully_qualified_namespace=SERVICEBUS_NAMESPACE,
            credential=get_credential()
        )
    return _sb_client


def get_cosmos_client():
    global _cosmos_client
    if _cosmos_client is None:
        _cosmos_client = CosmosClient(
            COSMOS_ENDPOINT,
            credential=get_credential()
        )
    return _cosmos_client


# ==============================
# External System State Check
# ==============================

def system_is_paused():
    try:
        r = requests.get(f"{NERVE_CENTER_URL}/system-state", timeout=2)
        r.raise_for_status()
        return r.json().get("pauseProcessing", False)
    except Exception as e:
        print("Could not reach nerve center:", e)
        return False


# ==============================
# Message Processing Logic
# ==============================

def process_message(message_body, cosmos_client):
    try:
        db = cosmos_client.get_database_client(COSMOS_DATABASE)
        container = db.get_container_client(COSMOS_CONTAINER)

        item = json.loads(message_body)

        container.upsert_item(item)

        print(f"Processed and stored message: {item.get('id')}")

    except Exception as e:
        print("Failed to process message:", e)


def pull_messages():
    sb_client = get_servicebus_client()
    cosmos_client = get_cosmos_client()

    with sb_client:
        receiver = sb_client.get_subscription_receiver(
            topic_name=TOPIC_NAME,
            subscription_name=SUBSCRIPTION_NAME,
            max_wait_time=5
        )

        with receiver:
            messages = receiver.receive_messages(max_message_count=5, max_wait_time=5)

            for msg in messages:
                try:
                    body = b"".join(msg.body).decode("utf-8")
                    print("Received message:", body)

                    process_message(body, cosmos_client)

                    receiver.complete_message(msg)

                except Exception as e:
                    print("Message processing failed:", e)
                    receiver.abandon_message(msg)


# ==============================
# Main Worker Loop
# ==============================

def run_worker():
    print("Worker started...")
    while True:
        if system_is_paused():
            print("System paused. Sleeping...")
            time.sleep(5)
            continue

        try:
            pull_messages()
        except Exception as e:
            print("Worker error:", e)

        time.sleep(2)


if __name__ == "__main__":
    run_worker()
