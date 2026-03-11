"""Seed Azure Cosmos DB products container from products.json.

Reads configuration from environment variables — no secrets or keys required.
Uses DefaultAzureCredential (Workload Identity in AKS, az login on dev machine).

Required env vars:
    COSMOS_ENDPOINT   - e.g. https://sre-cosmos.documents.azure.com:443/
    COSMOS_DATABASE   - e.g. product-catalog-db
    COSMOS_CONTAINER  - e.g. products
    PRODUCTS_JSON     - path to products.json (defaults to services/productcatalogservice/products.json)

The principal running this script must have the
'Cosmos DB Built-in Data Contributor' role on the Cosmos account.
"""
import json
import os
import sys

from azure.cosmos import CosmosClient
from azure.identity import DefaultAzureCredential

ENDPOINT = os.environ.get("COSMOS_ENDPOINT")
DB = os.environ.get("COSMOS_DATABASE")
CONTAINER = os.environ.get("COSMOS_CONTAINER")
PRODUCTS_JSON = os.environ.get(
    "PRODUCTS_JSON",
    os.path.join(os.path.dirname(__file__), "..", "services", "productcatalogservice", "products.json"),
)

missing = [k for k, v in {"COSMOS_ENDPOINT": ENDPOINT, "COSMOS_DATABASE": DB, "COSMOS_CONTAINER": CONTAINER}.items() if not v]
if missing:
    print(f"ERROR: missing required environment variables: {', '.join(missing)}", file=sys.stderr)
    sys.exit(1)

with open(PRODUCTS_JSON) as f:
    data = json.load(f)

credential = DefaultAzureCredential()
client = CosmosClient(url=ENDPOINT, credential=credential)
container = client.get_database_client(DB).get_container_client(CONTAINER)

success = 0
for product in data["products"]:
    doc = {
        "id": product["id"],
        "name": product["name"],
        "description": product["description"],
        "picture": product["picture"],
        "priceUsd": product["priceUsd"],
        "categories": product["categories"],
    }
    container.upsert_item(doc)
    success += 1
    print(f"  upserted: {doc['id']} - {doc['name']}")

print(f"\nDone: {success} products seeded into {DB}/{CONTAINER}.")
