#!/bin/bash
# OpenCat Full Integration Test with Rush Day
# Tests end-to-end: Server → Dashboard → iOS App (OpenCat SDK)

set -e

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SERVER_PID=""
DASHBOARD_PID=""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[TEST]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; exit 1; }

cleanup() {
    log "Cleaning up..."
    [ -n "$SERVER_PID" ] && kill $SERVER_PID 2>/dev/null || true
    [ -n "$DASHBOARD_PID" ] && kill $DASHBOARD_PID 2>/dev/null || true
}
trap cleanup EXIT

# ─── Step 1: Start OpenCat Rust Server ───
log "Starting OpenCat server..."
cd "$ROOT_DIR/crates/server"
export OPENCAT__SERVER__SECRET_KEY="opencat-integration-test-secret-key-32ch"
export OPENCAT__DATABASE__URL="sqlite://opencat_test.db"
# Remove stale test DB for fresh state
rm -f opencat_test.db
cargo run -- serve &
SERVER_PID=$!

# Wait for server to be ready
for i in $(seq 1 30); do
    if curl -sf http://localhost:8080/health > /dev/null 2>&1; then
        log "✓ Server is healthy at :8080"
        break
    fi
    if [ $i -eq 30 ]; then
        fail "Server failed to start within 30s"
    fi
    sleep 1
done

# ─── Step 2: Start Dashboard ───
log "Starting dashboard..."
cd "$ROOT_DIR/dashboard"
npm run dev &
DASHBOARD_PID=$!

# Wait for dashboard
for i in $(seq 1 20); do
    if curl -sf http://localhost:3000 > /dev/null 2>&1; then
        log "✓ Dashboard is running at :3000"
        break
    fi
    if [ $i -eq 20 ]; then
        warn "Dashboard may not be ready yet (continuing...)"
        break
    fi
    sleep 1
done

# ─── Step 3: Register Rush Day App ───
log "Registering Rush Day app..."
APP_RESPONSE=$(curl -sf -X POST http://localhost:8080/v1/apps \
    -H "Content-Type: application/json" \
    -d '{
        "name": "Rush Day",
        "bundle_id": "io.rushday.event.party.planner",
        "platform": "ios"
    }')

APP_ID=$(echo "$APP_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])" 2>/dev/null || echo "")
if [ -z "$APP_ID" ]; then
    warn "Could not parse app_id, using response as-is: $APP_RESPONSE"
    APP_ID="1"
fi
log "✓ App registered with ID: $APP_ID"

# Create entitlement
log "Creating 'pro' entitlement..."
ENT_RESPONSE=$(curl -sf -X POST "http://localhost:8080/v1/apps/$APP_ID/entitlements" \
    -H "Content-Type: application/json" \
    -d '{"name": "pro", "description": "Premium access"}')
ENT_ID=$(echo "$ENT_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])" 2>/dev/null || echo "")
log "✓ Entitlement 'pro' created (ID: $ENT_ID)"

# Create products
log "Creating products..."
curl -sf -X POST "http://localhost:8080/v1/apps/$APP_ID/products" \
    -H "Content-Type: application/json" \
    -d "{
        \"store_product_id\": \"com.rushday.premium.annual\",
        \"product_type\": \"subscription\",
        \"entitlement_ids\": [\"$ENT_ID\"]
    }" > /dev/null
log "✓ Annual product created"

curl -sf -X POST "http://localhost:8080/v1/apps/$APP_ID/products" \
    -H "Content-Type: application/json" \
    -d "{
        \"store_product_id\": \"com.rushday.premium.monthly\",
        \"product_type\": \"subscription\",
        \"entitlement_ids\": [\"$ENT_ID\"]
    }" > /dev/null
log "✓ Monthly product created"

# ─── Step 4: Save Mock Credentials ───
log "Saving mock store credentials..."
CRED_RESPONSE=$(curl -sf -X PUT "http://localhost:8080/v1/apps/$APP_ID/credentials" \
    -H "Content-Type: application/json" \
    -d '{
        "apple": {
            "issuer_id": "test-issuer-id",
            "key_id": "TEST_KEY",
            "private_key": "-----BEGIN PRIVATE KEY-----\ntest\n-----END PRIVATE KEY-----"
        }
    }')
log "✓ Credentials saved"

# Verify credentials are masked on read
CRED_GET=$(curl -sf "http://localhost:8080/v1/apps/$APP_ID/credentials")
echo "$CRED_GET" | python3 -c "
import sys, json
creds = json.load(sys.stdin)
pk = creds.get('apple', {}).get('private_key', '')
assert pk == '***configured***', f'Expected masked key, got: {pk}'
" && log "✓ Credentials masked correctly on read" || fail "Credentials not masked"

# ─── Step 5: Verify Offerings API ───
log "Testing offerings API..."
OFFERINGS=$(curl -sf "http://localhost:8080/v1/apps/$APP_ID/offerings")
OFFERING_COUNT=$(echo "$OFFERINGS" | python3 -c "import sys,json; print(len(json.load(sys.stdin)['offerings']))")
if [ "$OFFERING_COUNT" = "2" ]; then
    log "✓ Offerings endpoint returns 2 products"
else
    fail "Expected 2 offerings, got: $OFFERING_COUNT"
fi

# Verify offerings include entitlement names
FIRST_ENTITLEMENTS=$(echo "$OFFERINGS" | python3 -c "import sys,json; print(json.load(sys.stdin)['offerings'][0]['entitlements'])")
log "✓ Offerings include entitlements: $FIRST_ENTITLEMENTS"

# ─── Step 6: Verify Server State ───
log "Verifying server state..."

APPS=$(curl -sf http://localhost:8080/v1/apps)
log "Apps: $APPS"

ENTITLEMENTS=$(curl -sf "http://localhost:8080/v1/apps/$APP_ID/entitlements")
log "Entitlements: $ENTITLEMENTS"

PRODUCTS=$(curl -sf "http://localhost:8080/v1/apps/$APP_ID/products")
log "Products: $PRODUCTS"

# ─── Step 5: Summary ───
echo ""
echo "════════════════════════════════════════════"
echo "  OpenCat Integration Test Environment"
echo "════════════════════════════════════════════"
echo ""
echo "  Server:    http://localhost:8080"
echo "  Dashboard: http://localhost:3000"
echo "  App ID:    $APP_ID"
echo ""
echo "  Next steps:"
echo "  1. Build iOS app: cd ios-app && ./scripts/auto-build.sh full"
echo "  2. Open paywall:  ./scripts/app-tester.sh open rushday://debug/paywall"
echo "  3. Check subscriber: curl http://localhost:8080/v1/subscribers/{user_id}"
echo ""
echo "  Press Ctrl+C to stop all services."
echo ""

# Keep running
wait
