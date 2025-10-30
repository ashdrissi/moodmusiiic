#!/bin/bash

# Script to re-sign the iOS app with custom entitlements
# This ensures the JIT and memory protection entitlements are applied

set -e

APP_PATH="$1"
ENTITLEMENTS_PATH="$2"

if [ -z "$APP_PATH" ] || [ -z "$ENTITLEMENTS_PATH" ]; then
    echo "Usage: $0 <path-to-app> <path-to-entitlements>"
    exit 1
fi

if [ ! -d "$APP_PATH" ]; then
    echo "Error: App not found at $APP_PATH"
    exit 1
fi

if [ ! -f "$ENTITLEMENTS_PATH" ]; then
    echo "Error: Entitlements file not found at $ENTITLEMENTS_PATH"
    exit 1
fi

# Get the current signing identity
SIGNING_IDENTITY=$(codesign -d -r- "$APP_PATH" 2>&1 | grep "designated =>" | sed 's/.*certificate leaf\[subject.CN\] = "\([^"]*\)".*/\1/')

if [ -z "$SIGNING_IDENTITY" ]; then
    echo "Error: Could not determine signing identity"
    exit 1
fi

echo "Re-signing $APP_PATH with entitlements from $ENTITLEMENTS_PATH"
echo "Using signing identity: $SIGNING_IDENTITY"

# Remove existing code signature
rm -rf "$APP_PATH/_CodeSignature"

# Re-sign with custom entitlements
codesign --force --sign "$SIGNING_IDENTITY" --entitlements "$ENTITLEMENTS_PATH" --timestamp=none "$APP_PATH"

echo "✅ Re-signing complete"

# Verify entitlements were applied
echo "Verifying entitlements:"
codesign -d --entitlements - "$APP_PATH"
