# CORS + JWT Test Results

**Date:** 2026-03-02
**Phase:** 02-authentication, Plan 01
**Purpose:** Determine JWT delivery architecture for frontend-to-n8n communication

## Test 1: JWT Signing Algorithm

**Method:** Login via Supabase Auth API, decode JWT header

```
JWT Header: {"alg":"ES256","kid":"be20fe3a-8b07-4816-b26e-52ee5759d9c3","typ":"JWT"}
```

**Result:** ES256 (ECDSA with P-256 curve)

This is NOT HS256 as initially expected. Supabase newer projects use ES256 (asymmetric).
- HS256 uses a shared secret (passphrase)
- ES256 uses a public/private key pair
- For JWT verification, we need the **public key** (available via JWKS endpoint)

**JWKS Endpoint:** `https://llpnwaoxisfwptxvdfed.supabase.co/auth/v1/.well-known/jwks.json`

**Public Key (PEM format):**
```
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEb7h3ci9QxPXSzw70mRbSE11PCSEL
25Mr2q+0SupxKzRyWiHBAY06E91N7DtiUFlGwss62jpZ11VY+uRhKPUYIw==
-----END PUBLIC KEY-----
```

**Impact on n8n JWT Auth credential:**
- Key Type: **PEM Key** (not Passphrase)
- Algorithm: **ES256**
- Secret: Paste the PEM public key above

## Test 2: Test Account Login

Both test accounts successfully authenticate:

| Account | Email | Status | User ID |
|---------|-------|--------|---------|
| Test User A | testuser-a@eluxr.test | LOGIN SUCCESS | 2488af7b-69ea-4bad-9876-ef28617b031c |
| Test User B | testuser-b@eluxr.test | LOGIN SUCCESS | 26df3ba0-046c-4b24-bc0a-eceaa99e624e |

JWT payload contains all expected claims:
- `sub`: user ID (matches auth.uid() for RLS)
- `email`: user email
- `role`: "authenticated"
- `aud`: "authenticated"
- `iss`: Supabase auth URL
- `exp`/`iat`: 1-hour expiry

## Test 3: CORS Behavior with Authorization Header

**Method:** curl OPTIONS preflight + POST with Origin and Authorization headers

### Preflight (OPTIONS) Request
```
Request:
  OPTIONS /webhook/eluxr-chat
  Origin: http://localhost:8080
  Access-Control-Request-Method: POST
  Access-Control-Request-Headers: Content-Type, Authorization

Response:
  HTTP/2 204
  access-control-allow-origin: http://localhost:8080
  access-control-allow-headers: Content-Type, Authorization
  access-control-allow-methods: OPTIONS, POST
  access-control-max-age: 300
```

**Result: CORS ALLOWS Authorization header**

### POST with Authorization Header
```
Request:
  POST /webhook/eluxr-chat
  Origin: http://localhost:8080
  Content-Type: application/json
  Authorization: Bearer test-fake-jwt

Response:
  HTTP/2 200
  access-control-allow-origin: http://localhost:8080
  access-control-allow-methods: OPTIONS, POST
```

**Result: POST with Authorization header succeeds**

### Key CORS Findings
1. n8n Cloud webhooks REFLECT the Origin header in `access-control-allow-origin` (wildcard reflection)
2. OPTIONS preflight returns 204 with `access-control-allow-headers: Content-Type, Authorization`
3. POST requests with Authorization header receive proper CORS response headers
4. Preflight cache is 300 seconds (5 minutes)
5. Only webhooks configured for the correct HTTP method respond properly (GET-only webhooks return 500 for POST)

## Decisions

### CORS_RESULT: "header"
CORS allows Authorization headers on n8n Cloud webhooks. Use the standard `Authorization: Bearer <JWT>` approach.

### JWT_ALGORITHM: "ES256"
Supabase uses ES256 (ECDSA P-256), not HS256. The n8n JWT Auth credential must use PEM Key mode with the public key.

### JWT_DELIVERY: Authorization header (standard approach)
```
Frontend sends:
  POST https://flowbound.app.n8n.cloud/webhook/<endpoint>
  Authorization: Bearer <supabase-jwt>
  Content-Type: application/json

n8n validates:
  JWT Auth credential with ES256 PEM public key
  Extracts jwtPayload.sub as user_id for RLS queries
```

No token-in-body fallback needed. The standard approach works.

## Browser Test File

A browser-based CORS test is available at: `tests/cors-test.html`

To run in a real browser:
```bash
cd /home/andrew/workflow/eluxr-v2 && python3 -m http.server 8080
# Then visit http://localhost:8080/tests/cors-test.html
```

---
*Test completed: 2026-03-02*
