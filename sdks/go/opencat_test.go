package opencat

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func setupServer(t *testing.T, handler http.HandlerFunc) (*Client, *httptest.Server) {
	t.Helper()
	srv := httptest.NewServer(handler)
	c := NewClient(srv.URL, "test-key")
	return c, srv
}

func TestCreateApp(t *testing.T) {
	c, srv := setupServer(t, func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "POST" || r.URL.Path != "/v1/apps" {
			t.Fatalf("unexpected %s %s", r.Method, r.URL.Path)
		}
		if r.Header.Get("Authorization") != "Bearer test-key" {
			t.Fatal("missing auth header")
		}
		json.NewEncoder(w).Encode(App{
			ID: "app-1", Name: "My App", Platform: "ios",
			BundleID: "com.example", CreatedAt: "t", UpdatedAt: "t",
		})
	})
	defer srv.Close()

	app, err := c.CreateApp("My App", "ios", "com.example")
	if err != nil {
		t.Fatal(err)
	}
	if app.ID != "app-1" {
		t.Fatalf("expected app-1, got %s", app.ID)
	}
}

func TestListApps(t *testing.T) {
	c, srv := setupServer(t, func(w http.ResponseWriter, r *http.Request) {
		json.NewEncoder(w).Encode([]App{{ID: "app-1", Name: "A", Platform: "ios", BundleID: "com.a", CreatedAt: "t", UpdatedAt: "t"}})
	})
	defer srv.Close()

	apps, err := c.ListApps()
	if err != nil {
		t.Fatal(err)
	}
	if len(apps) != 1 {
		t.Fatalf("expected 1 app, got %d", len(apps))
	}
}

func TestGetSubscriber(t *testing.T) {
	c, srv := setupServer(t, func(w http.ResponseWriter, r *http.Request) {
		json.NewEncoder(w).Encode(SubscriberInfo{
			Subscriber:         Subscriber{ID: "s1", AppID: "app-1", AppUserID: "user-1", CreatedAt: "t"},
			ActiveEntitlements: []EntitlementInfo{},
			Transactions:       []Transaction{},
		})
	})
	defer srv.Close()

	info, err := c.GetSubscriber("user-1")
	if err != nil {
		t.Fatal(err)
	}
	if info.Subscriber.AppUserID != "user-1" {
		t.Fatalf("expected user-1, got %s", info.Subscriber.AppUserID)
	}
}

func TestCreateProduct(t *testing.T) {
	c, srv := setupServer(t, func(w http.ResponseWriter, r *http.Request) {
		json.NewEncoder(w).Encode(Product{
			ID: "p1", AppID: "app-1", StoreProductID: "com.example.pro",
			ProductType: "subscription", CreatedAt: "t",
		})
	})
	defer srv.Close()

	p, err := c.CreateProduct("app-1", "com.example.pro", "subscription", []string{"e1"})
	if err != nil {
		t.Fatal(err)
	}
	if p.StoreProductID != "com.example.pro" {
		t.Fatalf("unexpected store_product_id: %s", p.StoreProductID)
	}
}

func TestCreateEntitlement(t *testing.T) {
	c, srv := setupServer(t, func(w http.ResponseWriter, r *http.Request) {
		json.NewEncoder(w).Encode(Entitlement{ID: "e1", AppID: "app-1", Name: "pro", CreatedAt: "t"})
	})
	defer srv.Close()

	e, err := c.CreateEntitlement("app-1", "pro", nil)
	if err != nil {
		t.Fatal(err)
	}
	if e.Name != "pro" {
		t.Fatalf("expected pro, got %s", e.Name)
	}
}

func TestSubmitReceipt(t *testing.T) {
	c, srv := setupServer(t, func(w http.ResponseWriter, r *http.Request) {
		json.NewEncoder(w).Encode(Transaction{
			ID: "tx1", SubscriberID: "s1", ProductID: "p1", Store: "apple",
			StoreTransactionID: "abc", PurchaseDate: "t", Status: "active",
			CreatedAt: "t", UpdatedAt: "t",
		})
	})
	defer srv.Close()

	tx, err := c.SubmitReceipt("app-1", "user-1", "apple", "data", "p1")
	if err != nil {
		t.Fatal(err)
	}
	if tx.Status != "active" {
		t.Fatalf("expected active, got %s", tx.Status)
	}
}

func TestCreateWebhook(t *testing.T) {
	c, srv := setupServer(t, func(w http.ResponseWriter, r *http.Request) {
		json.NewEncoder(w).Encode(WebhookEndpoint{
			ID: "w1", AppID: "app-1", URL: "https://hook.example.com",
			Secret: "sec", Active: true, CreatedAt: "t",
		})
	})
	defer srv.Close()

	wh, err := c.CreateWebhook("app-1", "https://hook.example.com")
	if err != nil {
		t.Fatal(err)
	}
	if wh.URL != "https://hook.example.com" {
		t.Fatalf("unexpected url: %s", wh.URL)
	}
}

func TestListEvents(t *testing.T) {
	c, srv := setupServer(t, func(w http.ResponseWriter, r *http.Request) {
		json.NewEncoder(w).Encode([]Event{
			{ID: "ev1", SubscriberID: "s1", EventType: "purchase", Payload: "{}", CreatedAt: "t"},
		})
	})
	defer srv.Close()

	events, err := c.ListEvents("")
	if err != nil {
		t.Fatal(err)
	}
	if len(events) != 1 {
		t.Fatalf("expected 1 event, got %d", len(events))
	}
}

func TestErrorHandling(t *testing.T) {
	c, srv := setupServer(t, func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(401)
		w.Write([]byte("Unauthorized"))
	})
	defer srv.Close()

	_, err := c.ListApps()
	if err == nil {
		t.Fatal("expected error")
	}
	apiErr, ok := err.(*Error)
	if !ok {
		t.Fatal("expected *Error")
	}
	if apiErr.StatusCode != 401 {
		t.Fatalf("expected 401, got %d", apiErr.StatusCode)
	}
}
