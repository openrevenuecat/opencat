import type {
  App,
  Entitlement,
  Event,
  Product,
  SubscriberInfo,
  Transaction,
  WebhookEndpoint,
} from "./types";

export class OpenCatError extends Error {
  constructor(
    public statusCode: number,
    public detail: string,
  ) {
    super(`HTTP ${statusCode}: ${detail}`);
    this.name = "OpenCatError";
  }
}

export class OpenCatClient {
  private baseUrl: string;
  private headers: Record<string, string>;

  constructor(serverUrl: string, apiKey: string) {
    this.baseUrl = serverUrl.replace(/\/+$/, "");
    this.headers = {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    };
  }

  private async request<T>(method: string, path: string, body?: unknown, params?: Record<string, string>): Promise<T> {
    let url = `${this.baseUrl}${path}`;
    if (params) {
      const qs = new URLSearchParams(params).toString();
      if (qs) url += `?${qs}`;
    }
    const resp = await fetch(url, {
      method,
      headers: this.headers,
      body: body ? JSON.stringify(body) : undefined,
    });
    if (!resp.ok) {
      throw new OpenCatError(resp.status, await resp.text());
    }
    if (resp.status === 204) return undefined as T;
    return resp.json() as Promise<T>;
  }

  // -- apps --

  async createApp(name: string, platform: string, bundleId: string): Promise<App> {
    return this.request("POST", "/v1/apps", { name, platform, bundle_id: bundleId });
  }

  async listApps(): Promise<App[]> {
    return this.request("GET", "/v1/apps");
  }

  // -- subscribers --

  async getSubscriber(appUserId: string): Promise<SubscriberInfo> {
    return this.request("GET", `/v1/subscribers/${encodeURIComponent(appUserId)}`);
  }

  // -- products --

  async createProduct(
    appId: string,
    storeProductId: string,
    productType: string,
    entitlementIds: string[],
  ): Promise<Product> {
    return this.request("POST", `/v1/apps/${appId}/products`, {
      store_product_id: storeProductId,
      product_type: productType,
      entitlement_ids: entitlementIds,
    });
  }

  async listProducts(appId: string): Promise<Product[]> {
    return this.request("GET", `/v1/apps/${appId}/products`);
  }

  // -- entitlements --

  async createEntitlement(appId: string, name: string, description?: string): Promise<Entitlement> {
    const body: Record<string, string> = { name };
    if (description !== undefined) body.description = description;
    return this.request("POST", `/v1/apps/${appId}/entitlements`, body);
  }

  async listEntitlements(appId: string): Promise<Entitlement[]> {
    return this.request("GET", `/v1/apps/${appId}/entitlements`);
  }

  // -- receipts --

  async submitReceipt(
    appId: string,
    appUserId: string,
    store: string,
    receiptData: string,
    productId: string,
  ): Promise<Transaction> {
    return this.request("POST", "/v1/receipts", {
      app_id: appId,
      app_user_id: appUserId,
      store,
      receipt_data: receiptData,
      product_id: productId,
    });
  }

  // -- webhooks --

  async createWebhook(appId: string, url: string, secret?: string): Promise<WebhookEndpoint> {
    const body: Record<string, string> = { app_id: appId, url };
    if (secret !== undefined) body.secret = secret;
    return this.request("POST", "/v1/webhooks", body);
  }

  async listWebhooks(): Promise<WebhookEndpoint[]> {
    return this.request("GET", "/v1/webhooks");
  }

  // -- events --

  async listEvents(cursor?: string): Promise<Event[]> {
    const params: Record<string, string> = {};
    if (cursor !== undefined) params.since = cursor;
    return this.request("GET", "/v1/events", undefined, params);
  }
}
