#!/bin/bash
set -euo pipefail

TABLE_NAME="${1:-dev-roles}"
REGION="${2:-us-east-1}"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

echo "Seeding roles into table: $TABLE_NAME (region: $REGION)"

aws dynamodb put-item --table-name "$TABLE_NAME" --region "$REGION" --item '{
  "roleId": {"S": "ADMIN"},
  "roleName": {"S": "Administrator"},
  "description": {"S": "Full access to all endpoints"},
  "permissions": {"L": [
    {"M": {
      "endpoint": {"S": "/api/**"},
      "methods": {"L": [{"S": "GET"}, {"S": "POST"}, {"S": "PUT"}, {"S": "DELETE"}]}
    }}
  ]},
  "createdAt": {"S": "'"$TIMESTAMP"'"}
}'
echo "  [1/2] ADMIN - Full access to: /api/**"

aws dynamodb put-item --table-name "$TABLE_NAME" --region "$REGION" --item '{
  "roleId": {"S": "CLIENT"},
  "roleName": {"S": "Client"},
  "description": {"S": "Can manage own subscriptions and view funds"},
  "permissions": {"L": [
    {"M": {
      "endpoint": {"S": "/api/funds"},
      "methods": {"L": [{"S": "GET"}]}
    }},
    {"M": {
      "endpoint": {"S": "/api/funds/*"},
      "methods": {"L": [{"S": "GET"}]}
    }},
    {"M": {
      "endpoint": {"S": "/api/subscriptions"},
      "methods": {"L": [{"S": "GET"}, {"S": "POST"}]}
    }},
    {"M": {
      "endpoint": {"S": "/api/subscriptions/*"},
      "methods": {"L": [{"S": "GET"}, {"S": "DELETE"}, {"S": "POST"}]}
    }},
    {"M": {
      "endpoint": {"S": "/api/transactions"},
      "methods": {"L": [{"S": "GET"}]}
    }},
    {"M": {
      "endpoint": {"S": "/api/users/me"},
      "methods": {"L": [{"S": "GET"}, {"S": "PUT"}]}
    }}
  ]},
  "createdAt": {"S": "'"$TIMESTAMP"'"}
}'
echo "  [2/2] CLIENT - Limited access (funds read, own subscriptions, transactions)"

echo ""
echo "Default roles seeded successfully."
echo ""
echo "To create custom roles, use:"
echo "  aws dynamodb put-item --table-name $TABLE_NAME --region $REGION --item '{...}'"
