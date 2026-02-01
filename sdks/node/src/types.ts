export interface App {
  id: string;
  name: string;
  platform: string;
  bundle_id: string;
  created_at: string;
  updated_at: string;
  store_credentials_encrypted?: string | null;
}

export interface Subscriber {
  id: string;
  app_id: string;
  app_user_id: string;
  created_at: string;
}

export interface EntitlementInfo {
  id: string;
  is_active: boolean;
  product_id: string;
  store: string;
  expiration_date?: string | null;
  will_renew: boolean;
  purchase_date?: string | null;
}

export interface SubscriberInfo {
  subscriber: Subscriber;
  active_entitlements: EntitlementInfo[];
  transactions: Transaction[];
}

export interface Entitlement {
  id: string;
  app_id: string;
  name: string;
  description?: string | null;
  created_at: string;
}

export interface Product {
  id: string;
  app_id: string;
  store_product_id: string;
  product_type: string;
  created_at: string;
}

export interface Transaction {
  id: string;
  subscriber_id: string;
  product_id: string;
  store: string;
  store_transaction_id: string;
  purchase_date: string;
  expiration_date?: string | null;
  status: string;
  raw_receipt?: string | null;
  created_at: string;
  updated_at: string;
}

export interface WebhookEndpoint {
  id: string;
  app_id: string;
  url: string;
  secret: string;
  active: boolean;
  created_at: string;
}

export interface Event {
  id: string;
  subscriber_id: string;
  event_type: string;
  payload: string;
  created_at: string;
}
