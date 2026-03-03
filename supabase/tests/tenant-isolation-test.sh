#!/bin/bash
# Tenant Isolation Verification Script
# Tests that RLS policies correctly isolate data between tenants
#
# Prerequisites:
#   - Two test accounts exist: testuser-a@eluxr.test, testuser-b@eluxr.test
#   - All 10 tables populated with test data (1 row per user per table)
#
# Usage: ./tenant-isolation-test.sh
#
# Environment variables (set before running):
#   SUPABASE_URL     - Supabase project URL
#   SUPABASE_APIKEY  - Publishable/anon API key (sb_publishable_*)
#   SERVICE_ROLE_KEY - Service role JWT (for admin verification)

set -euo pipefail

SUPABASE_URL="${SUPABASE_URL:-https://llpnwaoxisfwptxvdfed.supabase.co}"
SUPABASE_APIKEY="${SUPABASE_APIKEY:-sb_publishable_9gnLO_J9HBxVta1f8Ecvxw_KO8huPYQ}"

PASS=0
FAIL=0
TOTAL=0

pass() { PASS=$((PASS + 1)); TOTAL=$((TOTAL + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); TOTAL=$((TOTAL + 1)); echo "  FAIL: $1"; }

# --- Authenticate both test users ---
echo "=== Authenticating test users ==="

USER_A_JWT=$(curl -s -X POST "$SUPABASE_URL/auth/v1/token?grant_type=password" \
  -H "apikey: $SUPABASE_APIKEY" \
  -H "Content-Type: application/json" \
  -d '{"email":"testuser-a@eluxr.test","password":"TestPass123A"}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

USER_B_JWT=$(curl -s -X POST "$SUPABASE_URL/auth/v1/token?grant_type=password" \
  -H "apikey: $SUPABASE_APIKEY" \
  -H "Content-Type: application/json" \
  -d '{"email":"testuser-b@eluxr.test","password":"TestPass123B"}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

USER_A_ID=$(echo "$USER_A_JWT" | python3 -c "
import sys, json, base64
token = sys.stdin.read().strip()
payload = token.split('.')[1]
payload += '=' * (4 - len(payload) % 4)
data = json.loads(base64.urlsafe_b64decode(payload))
print(data['sub'])
")

USER_B_ID=$(echo "$USER_B_JWT" | python3 -c "
import sys, json, base64
token = sys.stdin.read().strip()
payload = token.split('.')[1]
payload += '=' * (4 - len(payload) % 4)
data = json.loads(base64.urlsafe_b64decode(payload))
print(data['sub'])
")

echo "User A: $USER_A_ID"
echo "User B: $USER_B_ID"
echo ""

TABLES="profiles icps campaigns themes content_items pipeline_runs chat_conversations chat_messages trend_alerts tool_outputs"

# --- Test 1: SELECT isolation ---
echo "=== Test 1: SELECT isolation (all 10 tables) ==="

for table in $TABLES; do
  # User A query
  A_COUNT=$(curl -s "$SUPABASE_URL/rest/v1/$table?select=id" \
    -H "apikey: $SUPABASE_APIKEY" \
    -H "Authorization: Bearer $USER_A_JWT" \
    | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")

  if [ "$A_COUNT" = "1" ]; then
    pass "$table: User A sees 1 row"
  else
    fail "$table: User A sees $A_COUNT rows (expected 1)"
  fi

  # User B query
  B_COUNT=$(curl -s "$SUPABASE_URL/rest/v1/$table?select=id" \
    -H "apikey: $SUPABASE_APIKEY" \
    -H "Authorization: Bearer $USER_B_JWT" \
    | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")

  if [ "$B_COUNT" = "1" ]; then
    pass "$table: User B sees 1 row"
  else
    fail "$table: User B sees $B_COUNT rows (expected 1)"
  fi

  # Verify User A only sees their own data
  A_USER_ID=$(curl -s "$SUPABASE_URL/rest/v1/$table?select=user_id" \
    -H "apikey: $SUPABASE_APIKEY" \
    -H "Authorization: Bearer $USER_A_JWT" \
    | python3 -c "import sys,json; data=json.load(sys.stdin); print(data[0].get('user_id','') if data else '')" 2>/dev/null)

  # profiles uses 'id' not 'user_id'
  if [ "$table" = "profiles" ]; then
    A_USER_ID=$(curl -s "$SUPABASE_URL/rest/v1/$table?select=id" \
      -H "apikey: $SUPABASE_APIKEY" \
      -H "Authorization: Bearer $USER_A_JWT" \
      | python3 -c "import sys,json; data=json.load(sys.stdin); print(data[0]['id'] if data else '')")
  fi

  if [ "$A_USER_ID" = "$USER_A_ID" ]; then
    pass "$table: User A data belongs to User A"
  else
    fail "$table: User A sees data for $A_USER_ID (expected $USER_A_ID)"
  fi
done

echo ""

# --- Test 2: Cross-tenant INSERT protection ---
echo "=== Test 2: Cross-tenant INSERT protection ==="

INSERT_RESP=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$SUPABASE_URL/rest/v1/tool_outputs" \
  -H "apikey: $SUPABASE_APIKEY" \
  -H "Authorization: Bearer $USER_A_JWT" \
  -H "Content-Type: application/json" \
  -d "{\"user_id\":\"$USER_B_ID\",\"tool_type\":\"test\",\"input_params\":{},\"output_data\":{}}")

if [ "$INSERT_RESP" = "403" ] || [ "$INSERT_RESP" = "401" ] || [ "$INSERT_RESP" = "400" ]; then
  pass "Cross-tenant INSERT blocked (HTTP $INSERT_RESP)"
else
  # Check if a row was actually created
  CHECK=$(curl -s "$SUPABASE_URL/rest/v1/tool_outputs?user_id=eq.$USER_B_ID&tool_type=eq.test" \
    -H "apikey: $SUPABASE_APIKEY" \
    -H "Authorization: Bearer $USER_A_JWT" \
    | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")
  if [ "$CHECK" = "0" ]; then
    pass "Cross-tenant INSERT returned $INSERT_RESP but no row visible"
  else
    fail "Cross-tenant INSERT succeeded (HTTP $INSERT_RESP)"
  fi
fi

echo ""

# --- Test 3: Cross-tenant UPDATE protection ---
echo "=== Test 3: Cross-tenant UPDATE protection ==="

UPDATE_RESP=$(curl -s -X PATCH "$SUPABASE_URL/rest/v1/icps?user_id=eq.$USER_B_ID" \
  -H "apikey: $SUPABASE_APIKEY" \
  -H "Authorization: Bearer $USER_A_JWT" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d '{"icp_summary":"HACKED BY USER A"}')

UPDATE_COUNT=$(echo "$UPDATE_RESP" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")

if [ "$UPDATE_COUNT" = "0" ]; then
  pass "Cross-tenant UPDATE affected 0 rows"
else
  fail "Cross-tenant UPDATE affected $UPDATE_COUNT rows"
fi

echo ""

# --- Test 4: Cross-tenant DELETE protection ---
echo "=== Test 4: Cross-tenant DELETE protection ==="

DELETE_RESP=$(curl -s -X DELETE "$SUPABASE_URL/rest/v1/trend_alerts?user_id=eq.$USER_B_ID" \
  -H "apikey: $SUPABASE_APIKEY" \
  -H "Authorization: Bearer $USER_A_JWT" \
  -H "Prefer: return=representation")

DELETE_COUNT=$(echo "$DELETE_RESP" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")

if [ "$DELETE_COUNT" = "0" ]; then
  pass "Cross-tenant DELETE affected 0 rows"
else
  fail "Cross-tenant DELETE affected $DELETE_COUNT rows"
fi

echo ""

# --- Test 5: Service role bypass ---
echo "=== Test 5: Service role bypass ==="

if [ -z "${SERVICE_ROLE_KEY:-}" ]; then
  echo "  SKIP: SERVICE_ROLE_KEY not set (run with SERVICE_ROLE_KEY=... to test)"
else
  SRK_COUNT=$(curl -s "$SUPABASE_URL/rest/v1/icps?select=id" \
    -H "apikey: $SUPABASE_APIKEY" \
    -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
    | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")

  if [ "$SRK_COUNT" = "2" ]; then
    pass "Service role sees all 2 rows in icps"
  else
    fail "Service role sees $SRK_COUNT rows in icps (expected 2)"
  fi
fi

echo ""

# --- Summary ---
echo "================================="
echo "  Results: $PASS passed, $FAIL failed out of $TOTAL tests"
echo "================================="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
