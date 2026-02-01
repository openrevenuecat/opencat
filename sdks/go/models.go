package opencat

type App struct {
	ID                        string  `json:"id"`
	Name                      string  `json:"name"`
	Platform                  string  `json:"platform"`
	BundleID                  string  `json:"bundle_id"`
	StoreCredentialsEncrypted *string `json:"store_credentials_encrypted,omitempty"`
	CreatedAt                 string  `json:"created_at"`
	UpdatedAt                 string  `json:"updated_at"`
}

type Subscriber struct {
	ID        string `json:"id"`
	AppID     string `json:"app_id"`
	AppUserID string `json:"app_user_id"`
	CreatedAt string `json:"created_at"`
}

type EntitlementInfo struct {
	ID             string  `json:"id"`
	IsActive       bool    `json:"is_active"`
	ProductID      string  `json:"product_id"`
	Store          string  `json:"store"`
	ExpirationDate *string `json:"expiration_date,omitempty"`
	WillRenew      bool    `json:"will_renew"`
	PurchaseDate   *string `json:"purchase_date,omitempty"`
}

type SubscriberInfo struct {
	Subscriber         Subscriber        `json:"subscriber"`
	ActiveEntitlements []EntitlementInfo  `json:"active_entitlements"`
	Transactions       []Transaction     `json:"transactions"`
}

type Entitlement struct {
	ID          string  `json:"id"`
	AppID       string  `json:"app_id"`
	Name        string  `json:"name"`
	Description *string `json:"description,omitempty"`
	CreatedAt   string  `json:"created_at"`
}

type Product struct {
	ID             string `json:"id"`
	AppID          string `json:"app_id"`
	StoreProductID string `json:"store_product_id"`
	ProductType    string `json:"product_type"`
	CreatedAt      string `json:"created_at"`
}

type Transaction struct {
	ID                 string  `json:"id"`
	SubscriberID       string  `json:"subscriber_id"`
	ProductID          string  `json:"product_id"`
	Store              string  `json:"store"`
	StoreTransactionID string  `json:"store_transaction_id"`
	PurchaseDate       string  `json:"purchase_date"`
	ExpirationDate     *string `json:"expiration_date,omitempty"`
	Status             string  `json:"status"`
	RawReceipt         *string `json:"raw_receipt,omitempty"`
	CreatedAt          string  `json:"created_at"`
	UpdatedAt          string  `json:"updated_at"`
}

type WebhookEndpoint struct {
	ID        string `json:"id"`
	AppID     string `json:"app_id"`
	URL       string `json:"url"`
	Secret    string `json:"secret"`
	Active    bool   `json:"active"`
	CreatedAt string `json:"created_at"`
}

type Event struct {
	ID           string `json:"id"`
	SubscriberID string `json:"subscriber_id"`
	EventType    string `json:"event_type"`
	Payload      string `json:"payload"`
	CreatedAt    string `json:"created_at"`
}
