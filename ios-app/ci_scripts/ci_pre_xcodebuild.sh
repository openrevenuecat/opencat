#!/bin/bash
# =============================================================================
# Xcode Cloud Pre-Build Script
# Sets build number using timestamp (HHMMDDMMYY format)
# Optionally increments version based on VERSION_BUMP env var
# =============================================================================
# Environment Variables (set in Xcode Cloud):
#   - VERSION_BUMP: "patch", "minor", or "major" (optional)
# =============================================================================

set -e

echo "=== Pre-Build: Version Bump ==="

# Project file path (relative to ci_scripts location)
PROJECT_FILE="../RushDay.xcodeproj/project.pbxproj"

if [ ! -f "$PROJECT_FILE" ]; then
    echo "Error: project.pbxproj not found at $PROJECT_FILE"
    exit 1
fi

# Get current marketing version
CURRENT_VERSION=$(grep "MARKETING_VERSION" "$PROJECT_FILE" | head -1 | sed 's/.*= \(.*\);/\1/')
echo "Current version: $CURRENT_VERSION"

# Parse version components
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

# Increment version if VERSION_BUMP is set
NEW_VERSION=$CURRENT_VERSION
if [ -n "$VERSION_BUMP" ]; then
    case $VERSION_BUMP in
        major)
            MAJOR=$((MAJOR + 1))
            MINOR=0
            PATCH=0
            ;;
        minor)
            MINOR=$((MINOR + 1))
            PATCH=0
            ;;
        patch)
            PATCH=$((PATCH + 1))
            ;;
    esac
    NEW_VERSION="$MAJOR.$MINOR.$PATCH"
    echo "Bumping version ($VERSION_BUMP): $CURRENT_VERSION -> $NEW_VERSION"
    sed -i '' "s/MARKETING_VERSION = [^;]*;/MARKETING_VERSION = $NEW_VERSION;/g" "$PROJECT_FILE"
fi

# Generate build number from timestamp (HHMMDDMMYY) in Tashkent timezone
NEW_BUILD=$(TZ="Asia/Tashkent" date +"%H%M%d%m%y")
echo "New build number: $NEW_BUILD (timestamp: HHMMDDMMYY, Tashkent time)"

# Update CURRENT_PROJECT_VERSION in project file
sed -i '' "s/CURRENT_PROJECT_VERSION = [^;]*;/CURRENT_PROJECT_VERSION = $NEW_BUILD;/g" "$PROJECT_FILE"

echo "Final version: $NEW_VERSION ($NEW_BUILD)"

# Save start time for duration calculation in post-build script
echo $(date +%s) > /tmp/build_start_time
