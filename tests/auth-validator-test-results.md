# Auth Validator Test Results

**Date:** 2026-03-02
**Instance:** localhost:5678 (local n8n)
**Auth Validator Workflow ID:** ltscbuGU8ovNzLvo
**Auth Test Workflow ID:** xTD3cxVUqH5ZMecQ

## Test Results

### Test 1: Valid JWT (testuser-a)
- **JWT Source:** Supabase /auth/v1/token (email: testuser-a@eluxr.test)
- **Request:** POST /webhook/eluxr-auth-test with Authorization: Bearer header
- **HTTP Status:** 200
- **Response:**
```json
{
    "success": true,
    "user_id": "2488af7b-69ea-4bad-9876-ef28617b031c",
    "email": "testuser-a@eluxr.test",
    "message": "Auth validation successful",
    "received_body": {"test_data": "hello from test 1"}
}
```
- **PASS:** Correct user_id, email, body passed through

### Test 2: Missing JWT (unauthenticated)
- **Request:** POST /webhook/eluxr-auth-test with no Authorization header
- **HTTP Status:** 401
- **Response:**
```json
{
    "success": false,
    "error": "Missing or invalid Authorization header"
}
```
- **PASS:** Returns 401 with descriptive error

### Test 3: Invalid JWT
- **Request:** POST /webhook/eluxr-auth-test with Authorization: Bearer invalid-token-here
- **HTTP Status:** 401
- **Response:**
```json
{
    "success": false,
    "error": "invalid JWT: unable to parse or verify signature, token is malformed: token contains an invalid number of segments"
}
```
- **PASS:** Returns 401 with Supabase validation error

### Test 4: Different User (testuser-b)
- **JWT Source:** Supabase /auth/v1/token (email: testuser-b@eluxr.test)
- **Request:** POST /webhook/eluxr-auth-test with Authorization: Bearer header
- **HTTP Status:** 200
- **Response:**
```json
{
    "success": true,
    "user_id": "26df3ba0-046c-4b24-bc0a-eceaa99e624e",
    "email": "testuser-b@eluxr.test",
    "message": "Auth validation successful",
    "received_body": {"test_data": "user B test"}
}
```
- **PASS:** Different user_id (26df3ba0...) from Test 1 (2488af7b...)

## Summary

All 4 tests pass. The Auth Validator sub-workflow correctly:
1. Extracts JWT from Authorization: Bearer header
2. Validates against Supabase /auth/v1/user endpoint
3. Returns user_id and email on valid tokens
4. Returns 401 with descriptive errors on missing/invalid tokens
5. Returns different user_ids for different users (tenant isolation)

## Integration Pattern

For any webhook that needs authentication, add these nodes:

```
Webhook (POST, responseMode: "responseNode")
  -> Execute Sub-Workflow (workflowId: AUTH_VALIDATOR_WORKFLOW_ID)
    -> IF (authenticated === true)
      -> true: Success Response (200)
      -> false: Auth Failed Response (401)
```

The Execute Sub-Workflow node passes the webhook's full output (headers, body, query)
to the Auth Validator. The Auth Validator returns:

On success: `{ authenticated: true, user_id, email, role, body, query }`
On failure: `{ authenticated: false, error, statusCode: 401 }`
