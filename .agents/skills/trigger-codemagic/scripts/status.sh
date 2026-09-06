#!/bin/bash

# Load env variables from .env if it exists
if [ -f .env ]; then
  source .env
fi

if [ -z "$CODEMAGIC_TOKEN" ]; then
    echo "Error: CODEMAGIC_TOKEN environment variable is not set."
    exit 1
fi

BUILD_ID=$1
if [ -z "$BUILD_ID" ]; then
    echo "Usage: $0 <build_id>"
    exit 1
fi

# Fetch build status
RESPONSE=$(curl -s -H "x-auth-token: $CODEMAGIC_TOKEN" "https://api.codemagic.io/builds/$BUILD_ID")

# Extract the top-level status
STATUS=$(echo "$RESPONSE" | jq -r '.build.status')

echo "Build ID: $BUILD_ID"
echo "Status: $STATUS"

if [ "$STATUS" == "failed" ]; then
    echo ""
    echo "Build failed. Fetching step statuses to find the failure..."
    echo "$RESPONSE" | jq -r '.build.buildActions[] | select(.status == "failed" or .status == "canceled") | "Failed Step: \(.name) (Status: \(.status)) - \(.error // "")"'
    
    # We could theoretically fetch the artifact/log URL here if provided, but typically the UI is best for full logs.
    echo ""
    echo "Please check the Codemagic dashboard for full logs of the failed step."
fi
