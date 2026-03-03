#!/bin/bash
# ELUXR Cutover Verification
#
# Tests all 13 webhook endpoints to confirm they are active and
# the Auth Validator is working (expects HTTP 401 without JWT).
#
# Usage: ./scripts/verify-cutover.sh
#
# No API key needed - just hits the public webhook endpoints.

set -euo pipefail

WEBHOOK_BASE="https://flowbound.app.n8n.cloud/webhook"

declare -A ENDPOINTS=(
  ["01-ICP-Analyzer"]="eluxr-phase1-analyzer"
  ["02-Theme-Generator"]="eluxr-phase2-themes"
  ["03-Themes-List"]="eluxr-themes-list"
  ["04-Content-Studio"]="eluxr-phase4-studio"
  ["05-Content-Submit"]="eluxr-phase5-submit"
  ["06-Approval-List"]="eluxr-approval-list"
  ["07-Approval-Action"]="eluxr-approval-action"
  ["08-Clear-Pending"]="eluxr-clear-pending"
  ["09-Calendar-Sync"]="eluxr-phase3-calendar"
  ["10-Chat"]="eluxr-chat"
  ["11-Image-Generator"]="eluxr-imagegen"
  ["12-Video-Script-Builder"]="eluxr-videoscript"
  ["13-Video-Creator"]="eluxr-videogen"
)

echo "========================================="
echo "ELUXR Cutover Verification"
echo "========================================="
echo ""
echo "Testing 13 webhook endpoints..."
echo "(HTTP 401 = endpoint active + auth working)"
echo ""

PASS=0
FAIL=0
RESULTS=""

for name in $(echo "${!ENDPOINTS[@]}" | tr ' ' '\n' | sort); do
  path="${ENDPOINTS[$name]}"
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$WEBHOOK_BASE/$path" \
    -H "Content-Type: application/json" \
    -d '{"test": true}' 2>/dev/null)

  if [ "$STATUS" = "401" ]; then
    printf "  PASS  %-30s /%-30s HTTP %s\n" "$name" "$path" "$STATUS"
    PASS=$((PASS + 1))
  else
    printf "  FAIL  %-30s /%-30s HTTP %s\n" "$name" "$path" "$STATUS"
    FAIL=$((FAIL + 1))
  fi
done

echo ""
echo "========================================="
echo "Results: $PASS passed, $FAIL failed (of 13)"
echo "========================================="

if [ "$FAIL" -eq 0 ]; then
  echo ""
  echo "All 13 endpoints are active and auth-protected."
  echo "Cutover verified successfully."
  exit 0
else
  echo ""
  echo "Some endpoints are not responding correctly."
  echo "Check that:"
  echo "  1. Monolith is deactivated (frees webhook paths)"
  echo "  2. All 13 sub-workflows are activated"
  echo "  3. Auth Validator (S4QtfIKpvhW4mQYG) is active"
  exit 1
fi
