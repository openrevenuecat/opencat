#!/bin/bash
# =============================================================================
# Xcode Cloud Post-Build Script
# Sends Telegram notification after successful build
# =============================================================================
# Required Environment Variables (set in Xcode Cloud):
#   - TELEGRAM_BOT_TOKEN
#   - TELEGRAM_CHAT_ID
#   - TELEGRAM_TOPIC_ID (optional, for forum groups)
# =============================================================================

set -e

echo "=== Post-Build: Telegram Notification ==="

# Check if build was successful
if [ "$CI_XCODEBUILD_EXIT_CODE" != "0" ]; then
    echo "Build failed, sending failure notification..."
    BUILD_STATUS="failed"
else
    echo "Build succeeded!"
    BUILD_STATUS="success"
fi

# Check for required environment variables
if [ -z "$TELEGRAM_BOT_TOKEN" ]; then
    echo "Warning: TELEGRAM_BOT_TOKEN not set. Skipping notification."
    echo "Set this in Xcode Cloud > Workflow > Environment Variables"
    exit 0
fi

if [ -z "$TELEGRAM_CHAT_ID" ]; then
    echo "Warning: TELEGRAM_CHAT_ID not set. Skipping notification."
    exit 0
fi

# Get version info from project
PROJECT_FILE="../RushDay.xcodeproj/project.pbxproj"
VERSION=$(grep "MARKETING_VERSION" "$PROJECT_FILE" | head -1 | sed 's/.*= \(.*\);/\1/')
# Use Xcode Cloud's build number (matches TestFlight)
BUILD=${CI_BUILD_NUMBER:-"?"}

# Get recent commits
COMMITS=$(git log --pretty=format:"• %s" --no-merges -5 2>/dev/null || echo "• No commit info available")

# Calculate build duration from saved start time
if [ -f /tmp/build_start_time ]; then
    START_TIME=$(cat /tmp/build_start_time)
    END_TIME=$(date +%s)
    ELAPSED=$((END_TIME - START_TIME))
    MINUTES=$((ELAPSED / 60))
    SECONDS=$((ELAPSED % 60))
    DURATION="${MINUTES}m ${SECONDS}s"
else
    DURATION="N/A"
fi

# Build message based on status
if [ "$BUILD_STATUS" = "success" ]; then
    EMOJI="🚀"
    STATUS_TEXT="deployed to TestFlight"
else
    EMOJI="❌"
    STATUS_TEXT="build FAILED"
fi

# Construct message
MESSAGE="${EMOJI} RushDay iOS v${VERSION} (${BUILD}) ${STATUS_TEXT}

📋 Recent changes:
${COMMITS}

⏱ Build time: ${DURATION}
🔧 Workflow: ${CI_WORKFLOW:-"Default"}
🌿 Branch: ${CI_BRANCH:-"unknown"}"

if [ "$BUILD_STATUS" = "success" ]; then
    MESSAGE="${MESSAGE}

📱 Available on TestFlight shortly"
fi

# URL encode the message
ENCODED_MESSAGE=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''${MESSAGE}'''))")

# Build API URL
URL="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage?chat_id=${TELEGRAM_CHAT_ID}"

# Add topic ID if set (for forum groups)
if [ -n "$TELEGRAM_TOPIC_ID" ]; then
    URL="${URL}&message_thread_id=${TELEGRAM_TOPIC_ID}"
fi

# Send notification
echo "Sending Telegram notification..."
RESPONSE=$(curl -s "${URL}&text=${ENCODED_MESSAGE}")

if echo "$RESPONSE" | grep -q '"ok":true'; then
    echo "Telegram notification sent successfully!"
else
    echo "Warning: Failed to send Telegram notification"
    echo "Response: $RESPONSE"
fi
