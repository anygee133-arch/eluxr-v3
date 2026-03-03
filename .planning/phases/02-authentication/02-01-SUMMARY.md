---
phase: 02-authentication
plan: 01
subsystem: auth
tags: [cors, jwt, es256, supabase-auth, n8n-webhook, pem-key]

# Dependency graph
requires:
  - phase: 01-security-hardening-database-foundation
    provides: "Supabase project with test accounts (testuser-a, testuser-b), RLS policies using auth.uid()"
provides:
  - "CORS_RESULT: header -- frontend sends JWT via Authorization: Bearer header"
  - "JWT_ALGORITHM: ES256 (ECDSA P-256, asymmetric)"
  - "JWT_CREDENTIAL_ID: GjLV4iwAj88m95yP (n8n 'Supabase JWT Auth' credential)"
  - "JWT_DELIVERY: Standard Authorization: Bearer <JWT> header on all webhook requests"
  - "JWKS endpoint: https://llpnwaoxisfwptxvdfed.supabase.co/auth/v1/.well-known/jwks.json"
  - "ES256 PEM public key for JWT verification"
  - "Supabase auth URL configuration (Site URL, redirect URLs)"
affects:
  - 02-02 (auth-middleware workflow uses JWT_CREDENTIAL_ID and JWT_ALGORITHM)
  - 02-03 (signup/login workflow depends on Supabase auth config)
  - 02-04 (protected webhook pattern uses Authorization header approach)
  - 02-05 (auth integration tests use JWT delivery approach)
  - 05-frontend-migration (frontend must send Authorization: Bearer header)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "ES256 asymmetric JWT verification via PEM public key"
    - "Authorization: Bearer <JWT> header for all frontend-to-n8n requests"
    - "n8n Cloud webhook CORS reflects Origin header, allows Authorization header"

key-files:
  created:
    - tests/cors-test.html
    - tests/cors-jwt-test-results.md
  modified: []

key-decisions:
  - "JWT_ALGORITHM is ES256, not HS256 -- Supabase uses asymmetric keys; n8n credential uses PEM Key mode"
  - "CORS_RESULT is 'header' -- n8n Cloud webhooks allow Authorization header via CORS preflight"
  - "JWT_DELIVERY uses standard Authorization: Bearer header, no token-in-body fallback needed"
  - "n8n JWT Auth credential (GjLV4iwAj88m95yP) configured with ES256 PEM public key from JWKS endpoint"

patterns-established:
  - "All authenticated n8n webhook requests use Authorization: Bearer <supabase-jwt> header"
  - "JWT validation extracts jwtPayload.sub as user_id for tenant-scoped RLS queries"
  - "ES256 public key sourced from Supabase JWKS endpoint for n8n credential"

# Metrics
duration: ~30min (across two sessions with human-action checkpoint)
completed: 2026-03-02
---

# Phase 2 Plan 01: CORS + JWT Auth Credential Setup Summary

**ES256 JWT verification via PEM public key on n8n Cloud webhooks with CORS-allowed Authorization: Bearer header delivery**

## Performance

- **Duration:** ~30 min (split across automated test + human dashboard config)
- **Started:** 2026-03-01T21:21:00Z (Task 1 commit)
- **Completed:** 2026-03-02T02:39:00Z
- **Tasks:** 2 (1 automated, 1 human-action checkpoint)
- **Files created:** 2

## Accomplishments

- Confirmed JWT signing algorithm is ES256 (asymmetric, not HS256) -- changes credential setup from passphrase to PEM public key
- Verified n8n Cloud webhooks allow Authorization header via CORS preflight (204 response with `access-control-allow-headers: Content-Type, Authorization`)
- Both test accounts (testuser-a, testuser-b) successfully authenticate and return JWTs with correct claims (`sub`, `email`, `role`, `aud`)
- Supabase auth URL configuration complete (Site URL, redirect URLs, email templates verified)
- n8n JWT Auth credential created (ID: `GjLV4iwAj88m95yP`) with ES256 PEM public key

## Decision Outputs

These decisions are consumed by downstream plans (02-02 through 02-05 and Phase 5):

| Key | Value | Used By |
|-----|-------|---------|
| **CORS_RESULT** | `"header"` -- frontend sends JWT via Authorization header | 02-02, 02-04, 05-frontend |
| **JWT_ALGORITHM** | `"ES256"` (ECDSA P-256, asymmetric) | 02-02 (credential reference) |
| **JWT_CREDENTIAL_ID** | `"GjLV4iwAj88m95yP"` (n8n credential: Supabase JWT Auth) | 02-02, 02-04, 02-05 |
| **JWT_DELIVERY** | Standard `Authorization: Bearer <JWT>` header. CORS allows Authorization header on n8n Cloud webhooks. | All auth plans, Phase 5 |

### Additional Reference Data

| Item | Value |
|------|-------|
| JWKS Endpoint | `https://llpnwaoxisfwptxvdfed.supabase.co/auth/v1/.well-known/jwks.json` |
| Key Type | PEM Key (ES256 public key) |
| Supabase Site URL | `http://localhost:8080` (temporary; updated in Phase 5) |
| Redirect URLs | `http://localhost:8080/**`, `http://localhost:3000/**`, `https://*.vercel.app/**` |
| Preflight Cache | 300 seconds (5 minutes) |
| JWT Expiry | 1 hour |
| Test User A ID | `2488af7b-69ea-4bad-9876-ef28617b031c` |
| Test User B ID | `26df3ba0-046c-4b24-bc0a-eceaa99e624e` |

## Task Commits

Each task was committed atomically:

1. **Task 1: Test CORS behavior and JWT signing algorithm** - `7889f6f` (test)
   - Created browser CORS test HTML and documented results
   - Confirmed ES256 algorithm, CORS allows Authorization header, test accounts work
2. **Task 2: Configure Supabase auth and create n8n JWT credential** - human-action checkpoint
   - User configured Supabase auth settings in dashboard
   - User created n8n JWT Auth credential (ID: GjLV4iwAj88m95yP)

## Files Created/Modified

- `tests/cors-test.html` - Browser-based CORS test for n8n Cloud webhooks with Authorization header
- `tests/cors-jwt-test-results.md` - Complete test results: JWT algorithm, CORS behavior, test account verification

## Decisions Made

1. **ES256 instead of HS256:** Supabase uses ES256 (asymmetric ECDSA) for JWT signing, not the HS256 (symmetric) that was initially expected. This means the n8n JWT Auth credential uses PEM Key mode with the public key from the JWKS endpoint, not a shared passphrase.

2. **Authorization header (not token-in-body):** CORS testing confirmed that n8n Cloud webhooks properly handle OPTIONS preflight and allow the Authorization header. This means we use the standard `Authorization: Bearer <JWT>` pattern rather than embedding the token in the request body.

3. **Origin reflection:** n8n Cloud webhooks reflect the Origin header in `access-control-allow-origin` responses (wildcard reflection). This means any origin can make authenticated requests -- which is fine since JWT validation provides the actual security layer, not CORS.

## Deviations from Plan

None -- plan executed exactly as written. The ES256 discovery was anticipated as a possible outcome in the plan (the plan mentioned "HS256/ES256/RS256" as possibilities).

## Issues Encountered

- **ES256 vs HS256 surprise:** The plan expected HS256 (Supabase default for legacy projects), but this project uses ES256. This was handled correctly -- the plan's user_setup section already included instructions for both key types. The user created the credential with PEM Key mode accordingly.

## User Setup Required

User setup was completed during Task 2 (human-action checkpoint):
- Supabase Dashboard: Site URL and redirect URLs configured
- Supabase Dashboard: Email templates verified (confirmation URLs present)
- n8n Cloud: JWT Auth credential created with ES256 PEM public key

No further user setup needed for this plan.

## Next Phase Readiness

- **Ready for 02-02:** JWT Auth credential exists and can be referenced by ID (`GjLV4iwAj88m95yP`) in auth-middleware workflow
- **Ready for 02-03:** Supabase auth is configured, test accounts work, signInWithPassword() returns valid JWTs
- **Ready for 02-04:** CORS result confirms Authorization header approach; all webhooks can be protected
- **Ready for 02-05:** All pieces in place for end-to-end auth integration testing
- **No blockers** for any downstream authentication plans

---
*Phase: 02-authentication*
*Completed: 2026-03-02*
