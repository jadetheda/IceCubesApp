#!/bin/bash

# Load env variables from .env if it exists
if [ -f .env ]; then
  source .env
fi

if [ -z "$CODEMAGIC_TOKEN" ]; then
    echo "Error: CODEMAGIC_TOKEN environment variable is not set."
    echo "Please ask the user for their token or have them save it to a .env file."
    exit 1
fi

if [ -z "$CODEMAGIC_APP_ID" ]; then
    echo "Error: CODEMAGIC_APP_ID environment variable is not set."
    echo "Please ask the user for their Codemagic App ID or have them save it to a .env file."
    exit 1
fi

WORKFLOW=${1:-"ios-unsigned-build"}
BRANCH=${2:-"main"}

echo "Triggering Codemagic build for App $CODEMAGIC_APP_ID, Workflow: $WORKFLOW on Branch: $BRANCH..."

curl -s -X POST https://api.codemagic.io/builds \
  -H "Content-Type: application/json" \
  -H "x-auth-token: $CODEMAGIC_TOKEN" \
  -d '{
    "appId": "'"$CODEMAGIC_APP_ID"'",
    "workflowId": "'"$WORKFLOW"'",
    "branch": "'"$BRANCH"'"
  }'
