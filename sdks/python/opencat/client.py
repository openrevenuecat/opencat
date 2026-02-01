from __future__ import annotations

from typing import Any, Optional

import httpx

from .models import (
    App,
    Entitlement,
    Event,
    Product,
    SubscriberInfo,
    Subscriber,
    EntitlementInfo,
    Transaction,
    WebhookEndpoint,
)


class OpenCatError(Exception):
    def __init__(self, status_code: int, detail: str):
        self.status_code = status_code
        self.detail = detail
        super().__init__(f"HTTP {status_code}: {detail}")


class OpenCatClient:
    def __init__(self, server_url: str, api_key: str):
        self._base = server_url.rstrip("/")
        self._client = httpx.Client(
            base_url=self._base,
            headers={"Authorization": f"Bearer {api_key}"},
            timeout=30.0,
        )

    def close(self) -> None:
        self._client.close()

    def __enter__(self):
        return self

    def __exit__(self, *args: Any):
        self.close()

    # -- helpers --

    def _request(self, method: str, path: str, **kwargs: Any) -> Any:
        resp = self._client.request(method, path, **kwargs)
        if resp.status_code >= 400:
            raise OpenCatError(resp.status_code, resp.text)
        if resp.status_code == 204:
            return None
        return resp.json()

    # -- apps --

    def create_app(self, name: str, platform: str, bundle_id: str) -> App:
        data = self._request("POST", "/v1/apps", json={
            "name": name,
            "platform": platform,
            "bundle_id": bundle_id,
        })
        return App(**data)

    def list_apps(self) -> list[App]:
        data = self._request("GET", "/v1/apps")
        return [App(**a) for a in data]

    # -- subscribers --

    def get_subscriber(self, app_user_id: str) -> SubscriberInfo:
        data = self._request("GET", f"/v1/subscribers/{app_user_id}")
        sub = Subscriber(**data["subscriber"])
        entitlements = [EntitlementInfo(**e) for e in data.get("active_entitlements", [])]
        transactions = [Transaction(**t) for t in data.get("transactions", [])]
        return SubscriberInfo(subscriber=sub, active_entitlements=entitlements, transactions=transactions)

    # -- products --

    def create_product(
        self,
        app_id: str,
        store_product_id: str,
        product_type: str,
        entitlement_ids: list[str],
    ) -> Product:
        data = self._request("POST", f"/v1/apps/{app_id}/products", json={
            "store_product_id": store_product_id,
            "product_type": product_type,
            "entitlement_ids": entitlement_ids,
        })
        return Product(**data)

    def list_products(self, app_id: str) -> list[Product]:
        data = self._request("GET", f"/v1/apps/{app_id}/products")
        return [Product(**p) for p in data]

    # -- entitlements --

    def create_entitlement(
        self, app_id: str, name: str, description: Optional[str] = None
    ) -> Entitlement:
        body: dict[str, Any] = {"name": name}
        if description is not None:
            body["description"] = description
        data = self._request("POST", f"/v1/apps/{app_id}/entitlements", json=body)
        return Entitlement(**data)

    def list_entitlements(self, app_id: str) -> list[Entitlement]:
        data = self._request("GET", f"/v1/apps/{app_id}/entitlements")
        return [Entitlement(**e) for e in data]

    # -- receipts --

    def submit_receipt(
        self,
        app_id: str,
        app_user_id: str,
        store: str,
        receipt_data: str,
        product_id: str,
    ) -> Transaction:
        data = self._request("POST", "/v1/receipts", json={
            "app_id": app_id,
            "app_user_id": app_user_id,
            "store": store,
            "receipt_data": receipt_data,
            "product_id": product_id,
        })
        return Transaction(**data)

    # -- webhooks --

    def create_webhook(self, app_id: str, url: str, secret: Optional[str] = None) -> WebhookEndpoint:
        body: dict[str, Any] = {"app_id": app_id, "url": url}
        if secret is not None:
            body["secret"] = secret
        data = self._request("POST", "/v1/webhooks", json=body)
        return WebhookEndpoint(**data)

    def list_webhooks(self) -> list[WebhookEndpoint]:
        data = self._request("GET", "/v1/webhooks")
        return [WebhookEndpoint(**w) for w in data]

    # -- events --

    def list_events(self, cursor: Optional[str] = None) -> list[Event]:
        params: dict[str, str] = {}
        if cursor is not None:
            params["since"] = cursor
        data = self._request("GET", "/v1/events", params=params)
        return [Event(**e) for e in data]
