#!/bin/bash
set -euo pipefail

TABLE_NAME="${1:-dev-funds}"
REGION="${2:-us-east-1}"

echo "Seeding funds into table: $TABLE_NAME (region: $REGION)"

aws dynamodb put-item --table-name "$TABLE_NAME" --region "$REGION" --item '{
  "fundId": {"S": "1"},
  "name": {"S": "FPV_BTG_PACTUAL_RECAUDADORA"},
  "minimumAmount": {"N": "75000"},
  "category": {"S": "FPV"}
}'
echo '  [1/5] FPV_BTG_PACTUAL_RECAUDADORA - COP $75,000'

aws dynamodb put-item --table-name "$TABLE_NAME" --region "$REGION" --item '{
  "fundId": {"S": "2"},
  "name": {"S": "FPV_BTG_PACTUAL_ECOPETROL"},
  "minimumAmount": {"N": "125000"},
  "category": {"S": "FPV"}
}'
echo '  [2/5] FPV_BTG_PACTUAL_ECOPETROL - COP $125,000'

aws dynamodb put-item --table-name "$TABLE_NAME" --region "$REGION" --item '{
  "fundId": {"S": "3"},
  "name": {"S": "DEUDAPRIVADA"},
  "minimumAmount": {"N": "50000"},
  "category": {"S": "FIC"}
}'
echo '  [3/5] DEUDAPRIVADA - COP $50,000'

aws dynamodb put-item --table-name "$TABLE_NAME" --region "$REGION" --item '{
  "fundId": {"S": "4"},
  "name": {"S": "FDO-ACCIONES"},
  "minimumAmount": {"N": "250000"},
  "category": {"S": "FIC"}
}'
echo '  [4/5] FDO-ACCIONES - COP $250,000'

aws dynamodb put-item --table-name "$TABLE_NAME" --region "$REGION" --item '{
  "fundId": {"S": "5"},
  "name": {"S": "FPV_BTG_PACTUAL_DINAMICA"},
  "minimumAmount": {"N": "100000"},
  "category": {"S": "FPV"}
}'
echo '  [5/5] FPV_BTG_PACTUAL_DINAMICA - COP $100,000'

echo ""
echo "All 5 funds seeded successfully."
