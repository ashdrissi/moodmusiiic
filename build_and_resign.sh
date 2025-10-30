#!/bin/bash

# Script to build Flutter iOS app and re-sign with custom entitlements
# This bypasses Xcode's automatic code signing restrictions

set -e

echo "🚀 Building and Re-signing MoodMusic for iOS 18"

# Configuration
PROJECT_DIR="/Users/achraf/Downloads/Dev/Mobile/Apps/MoodMusic/flutter_moodmusic"
DEVICE_ID="00008130-001E04C93C91001C"
APP_NAME="Runner"
ENTITLEMENTS_FILE="$PROJECT_DIR/ios/Runner/Runner.entitlements"
SIGNING_IDENTITY="Apple Development: ashdrissi@gmail.com (NVLM8D9GAV)"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

cd "$PROJECT_DIR"

# Step 1: Build the app
echo -e "${BLUE}📦 Step 1: Building Flutter app...${NC}"
flutter build ios --debug --no-codesign

# Find the app bundle
APP_BUNDLE=$(find build/ios/iphoneos -name "${APP_NAME}.app" -type d | head -1)

if [ -z "$APP_BUNDLE" ] || [ ! -d "$APP_BUNDLE" ]; then
    echo -e "${RED}❌ Error: Could not find ${APP_NAME}.app bundle${NC}"
    exit 1
fi

echo -e "${GREEN}✅ App built at: $APP_BUNDLE${NC}"

# Step 2: Re-sign with custom entitlements
echo -e "${BLUE}🔐 Step 2: Re-signing with custom entitlements...${NC}"

# First, remove existing code signature
rm -rf "$APP_BUNDLE/_CodeSignature" 2>/dev/null || true

# Re-sign the app with our entitlements
/usr/bin/codesign --force \
    --sign "$SIGNING_IDENTITY" \
    --entitlements "$ENTITLEMENTS_FILE" \
    --timestamp=none \
    --generate-entitlement-der \
    "$APP_BUNDLE"

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Error: Code signing failed${NC}"
    exit 1
fi

echo -e "${GREEN}✅ App re-signed successfully${NC}"

# Step 3: Verify entitlements
echo -e "${BLUE}🔍 Step 3: Verifying entitlements...${NC}"
codesign -d --entitlements - "$APP_BUNDLE" 2>&1 | grep -q "com.apple.security.cs.allow-jit"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Custom entitlements verified:${NC}"
    codesign -d --entitlements - "$APP_BUNDLE" 2>&1 | grep -E "(allow-jit|allow-unsigned-executable-memory|disable-executable-page-protection)"
else
    echo -e "${RED}❌ Warning: Custom entitlements may not be present${NC}"
    codesign -d --entitlements - "$APP_BUNDLE"
fi

# Step 4: Install to device
echo -e "${BLUE}📲 Step 4: Installing to iPhone...${NC}"

# Check if ios-deploy is available
if ! command -v ios-deploy &> /dev/null; then
    echo -e "${YELLOW}⚠️  ios-deploy not found. Installing...${NC}"
    brew install ios-deploy
fi

# Install the app
ios-deploy --id "$DEVICE_ID" --bundle "$APP_BUNDLE" --no-wifi

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ App installed successfully!${NC}"
    echo -e "${GREEN}🎉 MoodMusic should now launch on your iPhone${NC}"
else
    echo -e "${RED}❌ Installation failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Build and installation complete!${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo ""
echo "To check app logs, use:"
echo "  ios-deploy --id $DEVICE_ID --justlaunch --bundle \"$APP_BUNDLE\""
