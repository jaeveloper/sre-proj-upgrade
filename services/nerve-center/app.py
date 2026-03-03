from fastapi import FastAPI
from pydantic import BaseModel
from azure.identity import DefaultAzureCredential
from azure.servicebus import ServiceBusClient
from azure.cosmos import CosmosClient

app = FastAPI(title="Nerve Center")

# In-memory state
system_state = {
    "state": "NORMAL",
    "pauseProcessing": False,
    "maxProcessingRate": None
}

# Lazy clients
_credential = None
_sb_client = None
_cosmos_client = None

def get_credential():
    global _credential
    if _credential is None:
        _credential = DefaultAzureCredential(
            exclude_environment_credential=False,
            exclude_managed_identity_credential=False,
            exclude_shared_token_cache_credential=True,
            exclude_visual_studio_code_credential=True,
            exclude_azure_cli_credential=True,
        )
    return _credential

def get_servicebus_client():
    global _sb_client
    if _sb_client is None:
        _sb_client = ServiceBusClient(
            fully_qualified_namespace="sre-sb-namespace.servicebus.windows.net",
            credential=get_credential(),
        )
    return _sb_client

def get_cosmos_client():
    global _cosmos_client
    if _cosmos_client is None:
        _cosmos_client = CosmosClient(
            url="https://sre-cosmos.documents.azure.com:443/",
            credential=get_credential(),
        )
    return _cosmos_client

class StateResponse(BaseModel):
    state: str
    pauseProcessing: bool
    maxProcessingRate: int | None

@app.get("/system-state", response_model=StateResponse)
def get_system_state():
    return system_state

@app.post("/pause-processing")
def pause_processing():
    system_state["pauseProcessing"] = True
    system_state["state"] = "PAUSED"
    # Example: publish pause event lazily
    # sb = get_servicebus_client()
    return {"message": "Processing paused"}

@app.post("/resume-processing")
def resume_processing():
    system_state["pauseProcessing"] = False
    system_state["state"] = "NORMAL"
    return {"message": "Processing resumed"}

@app.get("/healthz")
def health():
    return {
        "status": "ok",
        "azure_identity_ready": _credential is not None
    }
