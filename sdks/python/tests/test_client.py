import json

import httpx
import pytest
import respx

from opencat import OpenCatClient, OpenCatError


BASE = "https://api.example.com"


@pytest.fixture
def client():
    c = OpenCatClient(BASE, "test-key")
    yield c
    c.close()


@respx.mock
def test_create_app(client):
    respx.post(f"{BASE}/v1/apps").mock(return_value=httpx.Response(200, json={
        "id": "app-1", "name": "My App", "platform": "ios",
        "bundle_id": "com.example", "created_at": "2024-01-01T00:00:00Z",
        "updated_at": "2024-01-01T00:00:00Z",
    }))
    app = client.create_app("My App", "ios", "com.example")
    assert app.id == "app-1"
    assert app.name == "My App"


@respx.mock
def test_list_apps(client):
    respx.get(f"{BASE}/v1/apps").mock(return_value=httpx.Response(200, json=[
        {"id": "app-1", "name": "A", "platform": "ios", "bundle_id": "com.a",
         "created_at": "t", "updated_at": "t"},
    ]))
    apps = client.list_apps()
    assert len(apps) == 1


@respx.mock
def test_get_subscriber(client):
    respx.get(f"{BASE}/v1/subscribers/user-1").mock(return_value=httpx.Response(200, json={
        "subscriber": {"id": "s1", "app_id": "app-1", "app_user_id": "user-1", "created_at": "t"},
        "active_entitlements": [],
        "transactions": [],
    }))
    info = client.get_subscriber("user-1")
    assert info.subscriber.app_user_id == "user-1"


@respx.mock
def test_create_product(client):
    respx.post(f"{BASE}/v1/apps/app-1/products").mock(return_value=httpx.Response(200, json={
        "id": "p1", "app_id": "app-1", "store_product_id": "com.example.pro",
        "product_type": "subscription", "created_at": "t",
    }))
    product = client.create_product("app-1", "com.example.pro", "subscription", ["ent-1"])
    assert product.store_product_id == "com.example.pro"


@respx.mock
def test_create_entitlement(client):
    respx.post(f"{BASE}/v1/apps/app-1/entitlements").mock(return_value=httpx.Response(200, json={
        "id": "e1", "app_id": "app-1", "name": "pro", "created_at": "t",
    }))
    ent = client.create_entitlement("app-1", "pro")
    assert ent.name == "pro"


@respx.mock
def test_submit_receipt(client):
    respx.post(f"{BASE}/v1/receipts").mock(return_value=httpx.Response(200, json={
        "id": "tx1", "subscriber_id": "s1", "product_id": "p1",
        "store": "apple", "store_transaction_id": "abc",
        "purchase_date": "t", "status": "active",
        "created_at": "t", "updated_at": "t",
    }))
    tx = client.submit_receipt("app-1", "user-1", "apple", "receipt-data", "p1")
    assert tx.status == "active"


@respx.mock
def test_create_webhook(client):
    respx.post(f"{BASE}/v1/webhooks").mock(return_value=httpx.Response(200, json={
        "id": "w1", "app_id": "app-1", "url": "https://hook.example.com",
        "secret": "sec", "active": True, "created_at": "t",
    }))
    wh = client.create_webhook("app-1", "https://hook.example.com")
    assert wh.url == "https://hook.example.com"


@respx.mock
def test_list_events(client):
    respx.get(f"{BASE}/v1/events").mock(return_value=httpx.Response(200, json=[
        {"id": "ev1", "subscriber_id": "s1", "event_type": "purchase",
         "payload": "{}", "created_at": "t"},
    ]))
    events = client.list_events()
    assert len(events) == 1


@respx.mock
def test_error_handling(client):
    respx.get(f"{BASE}/v1/apps").mock(return_value=httpx.Response(401, text="Unauthorized"))
    with pytest.raises(OpenCatError) as exc_info:
        client.list_apps()
    assert exc_info.value.status_code == 401


@respx.mock
def test_auth_header(client):
    route = respx.get(f"{BASE}/v1/apps").mock(return_value=httpx.Response(200, json=[]))
    client.list_apps()
    assert route.calls[0].request.headers["Authorization"] == "Bearer test-key"
