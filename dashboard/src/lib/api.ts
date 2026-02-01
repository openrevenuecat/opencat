const API_BASE = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8080";

async function request<T>(path: string, options?: RequestInit): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`, {
    ...options,
    headers: {
      "Content-Type": "application/json",
      ...options?.headers,
    },
  });
  if (!res.ok) {
    throw new Error(`API error: ${res.status} ${res.statusText}`);
  }
  return res.json();
}

export interface App {
  id: string;
  name: string;
  platform: string;
  bundle_id: string;
  created_at: string;
}

export interface Entitlement {
  id: string;
  app_id: string;
  name: string;
  description: string | null;
  created_at: string;
}

export interface Product {
  id: string;
  app_id: string;
  store_product_id: string;
  product_type: string;
  display_name: string | null;
  description: string | null;
  price_micros: number | null;
  currency: string | null;
  subscription_period: string | null;
  trial_period: string | null;
  last_synced_at: string | null;
  created_at: string;
}

export interface Subscriber {
  id: string;
  app_id: string;
  app_user_id: string;
  created_at: string;
}

export interface Transaction {
  id: string;
  subscriber_id: string;
  product_id: string;
  store: string;
  store_transaction_id: string;
  purchase_date: string;
  expiration_date: string | null;
  status: string;
  created_at: string;
}

export interface Event {
  id: string;
  subscriber_id: string;
  event_type: string;
  payload: string;
  created_at: string;
}

export interface WebhookEndpoint {
  id: string;
  app_id: string;
  url: string;
  secret: string;
  active: number;
  created_at: string;
}

export interface SubscriberInfo {
  subscriber: Subscriber;
  active_entitlements: Entitlement[];
  transactions: Transaction[];
}

export const api = {
  listApps: () => request<App[]>("/v1/apps"),
  createApp: (data: { name: string; platform: string; bundle_id: string }) =>
    request<App>("/v1/apps", { method: "POST", body: JSON.stringify(data) }),

  listEntitlements: (appId: string) =>
    request<Entitlement[]>(`/v1/apps/${appId}/entitlements`),

  listProducts: (appId: string) =>
    request<Product[]>(`/v1/apps/${appId}/products`),

  getSubscriber: (appUserId: string) =>
    request<SubscriberInfo>(`/v1/subscribers/${appUserId}`),

  listEvents: (since?: string, limit?: number) => {
    const params = new URLSearchParams();
    if (since) params.set("since", since);
    if (limit) params.set("limit", String(limit));
    return request<Event[]>(`/v1/events?${params}`);
  },

  updateCredentials: async (appId: string, data: { apple?: { issuer_id: string; key_id: string; private_key: string } }) => {
    const res = await fetch(`${API_BASE}/v1/apps/${appId}/credentials`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(data),
    });
    if (!res.ok) throw new Error(`API error: ${res.status} ${res.statusText}`);
  },

  getCredentials: (appId: string) =>
    request<Record<string, unknown>>(`/v1/apps/${appId}/credentials`),

  syncProducts: (appId: string) =>
    request<{ synced: number; products: string[] }>(`/v1/apps/${appId}/sync-products`, { method: "POST" }),

  listWebhooks: () => request<WebhookEndpoint[]>("/v1/webhooks"),
  createWebhook: (data: { app_id: string; url: string }) =>
    request<WebhookEndpoint>("/v1/webhooks", {
      method: "POST",
      body: JSON.stringify(data),
    }),
};
