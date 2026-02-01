package opencat

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
)

type Error struct {
	StatusCode int
	Detail     string
}

func (e *Error) Error() string {
	return fmt.Sprintf("HTTP %d: %s", e.StatusCode, e.Detail)
}

type Client struct {
	baseURL    string
	apiKey     string
	httpClient *http.Client
}

func NewClient(serverURL, apiKey string) *Client {
	return &Client{
		baseURL:    strings.TrimRight(serverURL, "/"),
		apiKey:     apiKey,
		httpClient: &http.Client{Timeout: 30 * time.Second},
	}
}

func (c *Client) request(method, path string, body any, query url.Values, result any) error {
	u := c.baseURL + path
	if len(query) > 0 {
		u += "?" + query.Encode()
	}

	var bodyReader io.Reader
	if body != nil {
		b, err := json.Marshal(body)
		if err != nil {
			return err
		}
		bodyReader = bytes.NewReader(b)
	}

	req, err := http.NewRequest(method, u, bodyReader)
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+c.apiKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return err
	}

	if resp.StatusCode >= 400 {
		return &Error{StatusCode: resp.StatusCode, Detail: string(data)}
	}
	if result != nil && resp.StatusCode != 204 {
		return json.Unmarshal(data, result)
	}
	return nil
}

// -- apps --

func (c *Client) CreateApp(name, platform, bundleID string) (*App, error) {
	var result App
	err := c.request("POST", "/v1/apps", map[string]string{
		"name": name, "platform": platform, "bundle_id": bundleID,
	}, nil, &result)
	return &result, err
}

func (c *Client) ListApps() ([]App, error) {
	var result []App
	err := c.request("GET", "/v1/apps", nil, nil, &result)
	return result, err
}

// -- subscribers --

func (c *Client) GetSubscriber(appUserID string) (*SubscriberInfo, error) {
	var result SubscriberInfo
	err := c.request("GET", "/v1/subscribers/"+url.PathEscape(appUserID), nil, nil, &result)
	return &result, err
}

// -- products --

func (c *Client) CreateProduct(appID, storeProductID, productType string, entitlementIDs []string) (*Product, error) {
	var result Product
	err := c.request("POST", fmt.Sprintf("/v1/apps/%s/products", appID), map[string]any{
		"store_product_id": storeProductID,
		"product_type":     productType,
		"entitlement_ids":  entitlementIDs,
	}, nil, &result)
	return &result, err
}

func (c *Client) ListProducts(appID string) ([]Product, error) {
	var result []Product
	err := c.request("GET", fmt.Sprintf("/v1/apps/%s/products", appID), nil, nil, &result)
	return result, err
}

// -- entitlements --

func (c *Client) CreateEntitlement(appID, name string, description *string) (*Entitlement, error) {
	body := map[string]any{"name": name}
	if description != nil {
		body["description"] = *description
	}
	var result Entitlement
	err := c.request("POST", fmt.Sprintf("/v1/apps/%s/entitlements", appID), body, nil, &result)
	return &result, err
}

func (c *Client) ListEntitlements(appID string) ([]Entitlement, error) {
	var result []Entitlement
	err := c.request("GET", fmt.Sprintf("/v1/apps/%s/entitlements", appID), nil, nil, &result)
	return result, err
}

// -- receipts --

func (c *Client) SubmitReceipt(appID, appUserID, store, receiptData, productID string) (*Transaction, error) {
	var result Transaction
	err := c.request("POST", "/v1/receipts", map[string]string{
		"app_id":       appID,
		"app_user_id":  appUserID,
		"store":        store,
		"receipt_data": receiptData,
		"product_id":   productID,
	}, nil, &result)
	return &result, err
}

// -- webhooks --

func (c *Client) CreateWebhook(appID, webhookURL string) (*WebhookEndpoint, error) {
	var result WebhookEndpoint
	err := c.request("POST", "/v1/webhooks", map[string]string{
		"app_id": appID, "url": webhookURL,
	}, nil, &result)
	return &result, err
}

func (c *Client) ListWebhooks() ([]WebhookEndpoint, error) {
	var result []WebhookEndpoint
	err := c.request("GET", "/v1/webhooks", nil, nil, &result)
	return result, err
}

// -- events --

func (c *Client) ListEvents(cursor string) ([]Event, error) {
	q := url.Values{}
	if cursor != "" {
		q.Set("since", cursor)
	}
	var result []Event
	err := c.request("GET", "/v1/events", nil, q, &result)
	return result, err
}
