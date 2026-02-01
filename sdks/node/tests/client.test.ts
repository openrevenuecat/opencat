import { OpenCatClient, OpenCatError } from "../src";

const BASE = "https://api.example.com";

let fetchMock: jest.Mock;

beforeEach(() => {
  fetchMock = jest.fn();
  global.fetch = fetchMock;
});

function mockResponse(status: number, body: unknown) {
  return {
    ok: status >= 200 && status < 400,
    status,
    text: async () => (typeof body === "string" ? body : JSON.stringify(body)),
    json: async () => body,
  };
}

function client() {
  return new OpenCatClient(BASE, "test-key");
}

test("createApp sends correct request", async () => {
  fetchMock.mockResolvedValue(mockResponse(200, {
    id: "app-1", name: "My App", platform: "ios", bundle_id: "com.example",
    created_at: "t", updated_at: "t",
  }));
  const app = await client().createApp("My App", "ios", "com.example");
  expect(app.id).toBe("app-1");
  expect(fetchMock).toHaveBeenCalledWith(
    `${BASE}/v1/apps`,
    expect.objectContaining({ method: "POST" }),
  );
});

test("listApps returns array", async () => {
  fetchMock.mockResolvedValue(mockResponse(200, [
    { id: "app-1", name: "A", platform: "ios", bundle_id: "com.a", created_at: "t", updated_at: "t" },
  ]));
  const apps = await client().listApps();
  expect(apps).toHaveLength(1);
});

test("getSubscriber", async () => {
  fetchMock.mockResolvedValue(mockResponse(200, {
    subscriber: { id: "s1", app_id: "app-1", app_user_id: "user-1", created_at: "t" },
    active_entitlements: [],
    transactions: [],
  }));
  const info = await client().getSubscriber("user-1");
  expect(info.subscriber.app_user_id).toBe("user-1");
});

test("createProduct", async () => {
  fetchMock.mockResolvedValue(mockResponse(200, {
    id: "p1", app_id: "app-1", store_product_id: "com.example.pro",
    product_type: "subscription", created_at: "t",
  }));
  const p = await client().createProduct("app-1", "com.example.pro", "subscription", ["e1"]);
  expect(p.store_product_id).toBe("com.example.pro");
});

test("createEntitlement", async () => {
  fetchMock.mockResolvedValue(mockResponse(200, {
    id: "e1", app_id: "app-1", name: "pro", created_at: "t",
  }));
  const e = await client().createEntitlement("app-1", "pro");
  expect(e.name).toBe("pro");
});

test("submitReceipt", async () => {
  fetchMock.mockResolvedValue(mockResponse(200, {
    id: "tx1", subscriber_id: "s1", product_id: "p1", store: "apple",
    store_transaction_id: "abc", purchase_date: "t", status: "active",
    created_at: "t", updated_at: "t",
  }));
  const tx = await client().submitReceipt("app-1", "user-1", "apple", "data", "p1");
  expect(tx.status).toBe("active");
});

test("createWebhook", async () => {
  fetchMock.mockResolvedValue(mockResponse(200, {
    id: "w1", app_id: "app-1", url: "https://hook.example.com",
    secret: "sec", active: true, created_at: "t",
  }));
  const wh = await client().createWebhook("app-1", "https://hook.example.com");
  expect(wh.url).toBe("https://hook.example.com");
});

test("listEvents", async () => {
  fetchMock.mockResolvedValue(mockResponse(200, [
    { id: "ev1", subscriber_id: "s1", event_type: "purchase", payload: "{}", created_at: "t" },
  ]));
  const events = await client().listEvents();
  expect(events).toHaveLength(1);
});

test("error handling", async () => {
  fetchMock.mockResolvedValue(mockResponse(401, "Unauthorized"));
  await expect(client().listApps()).rejects.toThrow(OpenCatError);
});

test("auth header is set", async () => {
  fetchMock.mockResolvedValue(mockResponse(200, []));
  await client().listApps();
  const headers = fetchMock.mock.calls[0][1].headers;
  expect(headers.Authorization).toBe("Bearer test-key");
});
