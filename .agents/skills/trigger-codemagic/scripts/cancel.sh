#!/bin/bash

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

echo "Canceling build $BUILD_ID..."
curl -s -X POST -H "x-auth-token: $CODEMAGIC_TOKEN" "https://api.codemagic.io/builds/$BUILD_ID/cancel" | jq .
