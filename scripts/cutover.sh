#!/bin/bash
# ELUXR Cutover Script: Monolith -> 13 Sub-Workflows
#
# This script performs the cutover from the monolithic workflow
# to the 13 decomposed sub-workflows on n8n Cloud.
#
# Prerequisites:
#   - All 13 sub-workflow JSONs imported to n8n Cloud (but NOT activated)
#   - Auth Validator (S4QtfIKpvhW4mQYG) already active on cloud
#   - Monolith currently active on cloud
#
# Cutover order (CRITICAL - prevents webhook path conflicts):
#   1. Deactivate monolith FIRST (frees webhook paths)
#   2. Activate all 13 sub-workflows (claims same paths)
#   3. Deactivate Auth Test workflow (no longer needed)
#
# Usage:
#   export N8N_API_KEY="your-api-key"
#   ./scripts/cutover.sh
#
# Manual alternative (n8n Cloud UI):
#   See CUTOVER_GUIDE section below.

set -euo pipefail

CLOUD_URL="https://flowbound.app.n8n.cloud/api/v1"
WEBHOOK_BASE="https://flowbound.app.n8n.cloud/webhook"

# Workflow IDs (must be updated after import to cloud)
# These are placeholders - update with actual cloud IDs after import
MONOLITH_ID="${MONOLITH_WORKFLOW_ID:-REPLACE_WITH_MONOLITH_ID}"
AUTH_TEST_ID="${AUTH_TEST_WORKFLOW_ID:-lnx0S0c83ig0V7da}"

# Sub-workflow IDs (update after cloud import)
declare -A SUB_WORKFLOWS=(
  ["01-ICP-Analyzer"]="${SW_01_ID:-REPLACE}"
  ["02-Theme-Generator"]="${SW_02_ID:-REPLACE}"
  ["03-Themes-List"]="${SW_03_ID:-REPLACE}"
  ["04-Content-Studio"]="${SW_04_ID:-REPLACE}"
  ["05-Content-Submit"]="${SW_05_ID:-REPLACE}"
  ["06-Approval-List"]="${SW_06_ID:-REPLACE}"
  ["07-Approval-Action"]="${SW_07_ID:-REPLACE}"
  ["08-Clear-Pending"]="${SW_08_ID:-REPLACE}"
  ["09-Calendar-Sync"]="${SW_09_ID:-REPLACE}"
  ["10-Chat"]="${SW_10_ID:-REPLACE}"
  ["11-Image-Generator"]="${SW_11_ID:-REPLACE}"
  ["12-Video-Script-Builder"]="${SW_12_ID:-REPLACE}"
  ["13-Video-Creator"]="${SW_13_ID:-REPLACE}"
)

# Webhook paths for verification
WEBHOOK_PATHS=(
  "eluxr-phase1-analyzer"
  "eluxr-phase2-themes"
  "eluxr-themes-list"
  "eluxr-phase4-studio"
  "eluxr-phase5-submit"
  "eluxr-approval-list"
  "eluxr-approval-action"
  "eluxr-clear-pending"
  "eluxr-phase3-calendar"
  "eluxr-chat"
  "eluxr-imagegen"
  "eluxr-videoscript"
  "eluxr-videogen"
)

echo "========================================="
echo "ELUXR CUTOVER: Monolith -> Sub-Workflows"
echo "========================================="
echo ""

# Check API key
if [ -z "${N8N_API_KEY:-}" ]; then
  echo "ERROR: N8N_API_KEY not set"
  echo "Export your n8n Cloud API key first:"
  echo "  export N8N_API_KEY='your-api-key'"
  exit 1
fi

# Step 1: Deactivate monolith
echo "Step 1: Deactivating monolith ($MONOLITH_ID)..."
curl -s -X PATCH "$CLOUD_URL/workflows/$MONOLITH_ID" \
  -H "X-N8N-API-KEY: $N8N_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"active": false}' | jq '.active' 2>/dev/null || echo "FAILED"
echo ""

# Step 2: Activate all 13 sub-workflows
echo "Step 2: Activating 13 sub-workflows..."
for name in "${!SUB_WORKFLOWS[@]}"; do
  id="${SUB_WORKFLOWS[$name]}"
  printf "  %-30s (%s) ... " "$name" "$id"
  result=$(curl -s -X PATCH "$CLOUD_URL/workflows/$id" \
    -H "X-N8N-API-KEY: $N8N_API_KEY" \
    -H "Content-Type: application/json" \
    -d '{"active": true}')
  active=$(echo "$result" | jq '.active' 2>/dev/null)
  if [ "$active" = "true" ]; then
    echo "ACTIVE"
  else
    echo "FAILED: $result"
  fi
done
echo ""

# Step 3: Deactivate Auth Test
echo "Step 3: Deactivating Auth Test ($AUTH_TEST_ID)..."
curl -s -X PATCH "$CLOUD_URL/workflows/$AUTH_TEST_ID" \
  -H "X-N8N-API-KEY: $N8N_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"active": false}' | jq '.active' 2>/dev/null || echo "FAILED"
echo ""

# Step 4: Verify all endpoints
echo "Step 4: Verifying all 13 webhook endpoints..."
echo "(Expecting HTTP 401 = active + auth working)"
echo ""
ALL_OK=true
for path in "${WEBHOOK_PATHS[@]}"; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$WEBHOOK_BASE/$path" \
    -H "Content-Type: application/json" \
    -d '{"test": true}')
  if [ "$STATUS" = "401" ]; then
    printf "  %-30s HTTP %s  OK\n" "$path" "$STATUS"
  else
    printf "  %-30s HTTP %s  FAIL\n" "$path" "$STATUS"
    ALL_OK=false
  fi
done
echo ""

if [ "$ALL_OK" = true ]; then
  echo "========================================="
  echo "CUTOVER COMPLETE"
  echo "========================================="
  echo "All 13 endpoints active and returning 401 (auth working)"
  echo ""
  echo "Active workflows: 14"
  echo "  - Auth Validator (S4QtfIKpvhW4mQYG)"
  echo "  - 13 domain sub-workflows"
  echo ""
  echo "Deactivated workflows:"
  echo "  - Monolith ($MONOLITH_ID)"
  echo "  - Auth Test ($AUTH_TEST_ID)"
else
  echo "========================================="
  echo "CUTOVER INCOMPLETE - Some endpoints failed"
  echo "========================================="
  echo "Check failed endpoints above and investigate."
  echo "To rollback: reactivate monolith, deactivate sub-workflows."
  exit 1
fi
