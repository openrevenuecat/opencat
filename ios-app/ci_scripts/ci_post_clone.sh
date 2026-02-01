#!/bin/bash
# =============================================================================
# Xcode Cloud Post-Clone Script
# Optional: Creates GoogleService-Info.plist from environment variable
# (Not needed if file is committed to repo)
# =============================================================================

set -e

echo "=== Post-Clone: Setup ==="

PLIST_PATH="../RushDay/Resources/GoogleService-Info.plist"

# Check if GoogleService-Info.plist already exists (committed to repo)
if [ -f "$PLIST_PATH" ]; then
    echo "GoogleService-Info.plist found in repo. Skipping creation."
    exit 0
fi

# Otherwise, try to create from environment variable
if [ -n "$GOOGLE_SERVICE_INFO_PLIST_BASE64" ]; then
    echo "Creating GoogleService-Info.plist from environment variable..."
    echo "$GOOGLE_SERVICE_INFO_PLIST_BASE64" | base64 --decode > "$PLIST_PATH"
    echo "GoogleService-Info.plist created successfully!"
else
    echo "Warning: GoogleService-Info.plist not found and GOOGLE_SERVICE_INFO_PLIST_BASE64 not set"
    exit 1
fi
