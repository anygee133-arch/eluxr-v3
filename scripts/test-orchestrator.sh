#!/bin/bash
# ELUXR Pipeline Orchestrator Test Script
#
# Tests the /eluxr-generate-content webhook endpoint.
#
# Test 1: Unauthenticated request -> expect 401
# Test 2: Documents the authenticated flow (requires valid JWT)
#
# Usage: ./scripts/test-orchestrator.sh
#
# Prerequisites:
#   - 14-Pipeline-Orchestrator workflow deployed and ACTIVE on n8n Cloud
#   - SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY env vars set on n8n Cloud
#   - Sub-workflow IDs resolved and configured in orchestrator

set -euo pipefail

WEBHOOK_BASE="https://flowbound.app.n8n.cloud/webhook"
ENDPOINT="eluxr-generate-content"

echo "========================================="
echo "ELUXR Pipeline Orchestrator Tests"
echo "========================================="
echo ""

# ─── Test 1: Unauthenticated request ───────────────────────────────
echo "Test 1: Unauthenticated POST to /${ENDPOINT}"
echo "  Expected: HTTP 401 (Auth Validator rejects)"
echo ""

STATUS=$(curl -s -o /tmp/orch-test1.json -w "%{http_code}" \
  -X POST "${WEBHOOK_BASE}/${ENDPOINT}" \
  -H "Content-Type: application/json" \
  -d '{"business_url": "https://example.com", "industry": "test"}' \
  2>/dev/null)

BODY=$(cat /tmp/orch-test1.json 2>/dev/null || echo "{}")

if [ "$STATUS" = "401" ]; then
  echo "  PASS  HTTP ${STATUS}"
  echo "  Body: ${BODY}"
else
  echo "  FAIL  HTTP ${STATUS} (expected 401)"
  echo "  Body: ${BODY}"
  echo ""
  echo "  If HTTP 404: Workflow not deployed or not active"
  echo "  If HTTP 500: Check n8n execution logs"
fi

echo ""

# ─── Test 2: Authenticated request (documentation) ────────────────
echo "Test 2: Authenticated POST (documentation only)"
echo "  To test authenticated flow, use a valid Supabase JWT:"
echo ""
echo "  # Get a JWT from Supabase auth:"
echo "  JWT=\$(curl -s 'https://llpnwaoxisfwptxvdfed.supabase.co/auth/v1/token?grant_type=password' \\"
echo "    -H 'apikey: sb_publishable_9gnLO_J9HBxVta1f8Ecvxw_KO8huPYQ' \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"email\": \"your-email\", \"password\": \"your-password\"}' | jq -r '.access_token')"
echo ""
echo "  # Then call the orchestrator:"
echo "  curl -v -X POST '${WEBHOOK_BASE}/${ENDPOINT}' \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -H 'Authorization: Bearer \$JWT' \\"
echo "    -d '{"
echo "      \"business_url\": \"https://example.com\","
echo "      \"industry\": \"fitness\","
echo "      \"month\": \"April 2026\","
echo "      \"products\": \"Online coaching, meal plans\","
echo "      \"brand_voice\": \"Motivational and supportive\","
echo "      \"platforms\": [\"instagram\", \"twitter\", \"linkedin\"]"
echo "    }'"
echo ""
echo "  Expected: HTTP 202 with body:"
echo "  {"
echo "    \"success\": true,"
echo "    \"status\": \"accepted\","
echo "    \"pipeline_run_id\": \"<uuid>\""
echo "  }"
echo ""
echo "  The pipeline_run_id can be used to:"
echo "  - Query pipeline_runs table for status"
echo "  - Subscribe to Supabase Realtime for live progress updates"

echo ""
echo "========================================="
echo "Test complete."
echo "========================================="

# Cleanup
rm -f /tmp/orch-test1.json
