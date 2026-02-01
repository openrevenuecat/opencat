from __future__ import annotations
from dataclasses import dataclass, field
from typing import Optional


@dataclass
class App:
    id: str
    name: str
    platform: str
    bundle_id: str
    created_at: str
    updated_at: str
    store_credentials_encrypted: Optional[str] = None


@dataclass
class Subscriber:
    id: str
    app_id: str
    app_user_id: str
    created_at: str


@dataclass
class EntitlementInfo:
    id: str
    is_active: bool
    product_id: str
    store: str
    expiration_date: Optional[str] = None
    will_renew: bool = False
    purchase_date: Optional[str] = None


@dataclass
class SubscriberInfo:
    subscriber: Subscriber
    active_entitlements: list[EntitlementInfo] = field(default_factory=list)
    transactions: list[Transaction] = field(default_factory=list)


@dataclass
class Entitlement:
    id: str
    app_id: str
    name: str
    created_at: str
    description: Optional[str] = None


@dataclass
class Product:
    id: str
    app_id: str
    store_product_id: str
    product_type: str
    created_at: str


@dataclass
class Transaction:
    id: str
    subscriber_id: str
    product_id: str
    store: str
    store_transaction_id: str
    purchase_date: str
    status: str
    created_at: str
    updated_at: str
    expiration_date: Optional[str] = None
    raw_receipt: Optional[str] = None


@dataclass
class WebhookEndpoint:
    id: str
    app_id: str
    url: str
    secret: str
    active: bool
    created_at: str


@dataclass
class Event:
    id: str
    subscriber_id: str
    event_type: str
    payload: str
    created_at: str
