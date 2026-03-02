---
phase: 02-authentication
plan: 04
subsystem: auth
tags: [jwt, authenticated-fetch, authorization-header, webhook-protection, sub-workflow, tenant-isolation, bearer-token]

# Dependency graph
requires:
  - phase: 02-authentication
    provides: "02-01: CORS_RESULT=header, JWT_CREDENTIAL_ID=GjLV4iwAj88m95yP, JWT_ALGORITHM=ES256"
  - phase: 02-authentication
    provides: "02-02: AUTH_VALIDATOR_WORKFLOW_ID=S4QtfIKpvhW4mQYG, INTEGRATION_PATTERN=Webhook->SubWorkflow->IF->process/401"
  - phase: 02-authentication
    provides: "02-03: window.supabase available, supabase.auth.getSession() for JWT, showLoginPage() for auth redirect"
provides:
  - "authenticatedFetch() wrapper: JWT attachment via Authorization: Bearer header, 401 retry with token refresh, login redirect on failure"
  - "All 27 frontend fetch calls to n8n webhooks use authenticatedFetch()"
  - "All 13 n8n webhook endpoints protected by Auth Validator sub-workflow (S4QtfIKpvhW4mQYG)"
  - "Updated workflow JSON: workflows/eluxr-social-media-action-v2-authenticated.json"
  - "user_id flows through data pipeline from Auth Validator to downstream nodes"
affects:
  - 02-05 (auth integration tests can now test full end-to-end authenticated flow)
  - 05-frontend-migration (all fetch calls already authenticated; migration only changes data targets)
  - "Phase 3 (workflow decomposition): user_id available in data pipeline for tenant-scoped queries"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "authenticatedFetch() wrapper: module-script defined, window-exposed for non-module script"
    - "JWT delivery via Authorization: Bearer header on all n8n webhook requests"
    - "401 retry: refresh token via supabase.auth.refreshSession(), retry once, redirect to login on failure"
    - "Webhook auth chain: Webhook -> Execute Sub-Workflow(Auth Validator) -> IF(authenticated) -> process / 401"

key-files:
  created:
    - workflows/eluxr-social-media-action-v2-authenticated.json
  modified:
    - index.html

key-decisions:
  - "Authorization: Bearer header approach (CORS_RESULT=header from 02-01) -- no body token needed, GET requests stay GET"
  - "authenticatedFetch() defined in module script (alongside supabase client) and exposed to window for non-module script"
  - "Content-Type: application/json added by wrapper automatically -- removed from all 21 individual call sites"
  - "Programmatic workflow transformation via Python script for reliability -- all 13 webhooks modified atomically"
  - "Auth node naming convention: Auth Validate (path), Auth OK? (path), 401 Unauthorized (path)"

patterns-established:
  - "authenticatedFetch(url, options) as standard API call pattern for all n8n webhook requests"
  - "Webhook protection chain: 3 nodes (Execute Sub-Workflow + IF + 401 Respond) inserted between every webhook and its business logic"
  - "user_id available in $json.user_id after Auth OK? true path for tenant-scoped operations"

# Metrics
duration: 20min
completed: 2026-03-02
---

# Phase 2 Plan 04: Protected Webhooks Summary

**authenticatedFetch() wrapper with JWT Bearer header + 401 retry on frontend, Auth Validator sub-workflow protection on all 13 n8n webhook endpoints**

## Performance

- **Duration:** 20 min
- **Started:** 2026-03-02T03:41:59Z
- **Completed:** 2026-03-02T04:02:28Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Built authenticatedFetch() wrapper in module script: gets JWT from supabase.auth.getSession(), attaches as Authorization: Bearer header, handles 401 with token refresh + single retry, redirects to login on refresh failure
- Replaced all 27 fetch() calls to n8n webhooks (N8N_BASE_URL and API_BASE) with authenticatedFetch()
- Removed redundant Content-Type: application/json headers from all call sites (wrapper adds automatically)
- Left proxyUrl fetch (eluxr-image-download) as regular fetch (not an authenticated endpoint)
- Integrated Auth Validator sub-workflow (S4QtfIKpvhW4mQYG) into all 13 n8n webhook endpoints in the main workflow
- Added 39 new nodes to workflow (13 Execute Sub-Workflow + 13 IF + 13 Respond to Webhook 401)
- All connections verified: every auth chain routes correctly to business logic on success and 401 response on failure
- Updated workflow saved as workflows/eluxr-social-media-action-v2-authenticated.json for cloud import

## Decision Outputs

| Key | Value | Used By |
|-----|-------|---------|
| **AUTHENTICATED_FETCH_AVAILABLE** | `window.authenticatedFetch` -- exposed for non-module scripts | 02-05, Phase 5 |
| **UPDATED_WORKFLOW_JSON** | `workflows/eluxr-social-media-action-v2-authenticated.json` | Cloud import needed |
| **WEBHOOK_PROTECTION_COMPLETE** | All 13 endpoints protected by Auth Validator | 02-05 (testing) |
| **USER_ID_IN_PIPELINE** | `$json.user_id` available after Auth OK? node on true path | Phase 3 (Supabase queries) |

### Protected Endpoints

| Endpoint | Webhook Node | Auth Chain |
|----------|-------------|------------|
| eluxr-phase1-analyzer | Phase 1 -- Webhook Trigger1 | Auth Validate -> Auth OK? -> Perplexity |
| eluxr-phase2-themes | Phase 2 -- Webhook Trigger | Auth Validate -> Auth OK? -> Claude Netflix |
| eluxr-phase3-calendar | Phase 3 -- Webhook Trigger | Auth Validate -> Auth OK? -> Read Queue |
| eluxr-phase4-studio | Phase 4 -- Webhook Trigger | Auth Validate -> Auth OK? -> Merge Sources |
| eluxr-phase5-submit | Submit Content -- Webhook | Auth Validate -> Auth OK? -> Format Item |
| eluxr-approval-list | List Queue -- Webhook | Auth Validate -> Auth OK? -> Read Sheet |
| eluxr-approval-action | Approval Action Webhook | Auth Validate -> Auth OK? -> Is Approve? |
| eluxr-themes-list | Themes List -- Webhook | Auth Validate -> Auth OK? -> Read Sheet |
| eluxr-clear-pending | Clear Pending Webhook | Auth Validate -> Auth OK? -> Get Rows |
| eluxr-videoscript | Video Script -- Webhook | Auth Validate -> Auth OK? -> Claude Script |
| eluxr-imagegen | Image Gen -- Webhook | Auth Validate -> Auth OK? -> Nano Banana |
| eluxr-videogen | Video Gen -- Webhook | Auth Validate -> Auth OK? -> Veo Prompt |
| eluxr-chat | Chat -- Webhook | Auth Validate -> Auth OK? -> Chat Context |

## Task Commits

Each task was committed atomically:

1. **Task 1: Build authenticatedFetch() wrapper and replace all fetch calls** - `f0bf3e7` (feat)
   - Added authenticatedFetch() to module script with JWT Bearer header, 401 retry, login redirect
   - Replaced 27 fetch() calls with authenticatedFetch()
   - Removed redundant Content-Type headers from all call sites
2. **Task 2: Integrate Auth Validator into all 13 n8n webhook endpoints** - `4e2d806` (feat)
   - Added 39 nodes (13 auth chains x 3 nodes each) to main workflow
   - All connections verified programmatically
   - Saved as workflows/eluxr-social-media-action-v2-authenticated.json

## Files Created/Modified

- `index.html` - Added authenticatedFetch() wrapper to module script; replaced all 27 n8n webhook fetch calls; removed redundant headers
- `workflows/eluxr-social-media-action-v2-authenticated.json` - Main workflow with Auth Validator protection on all 13 webhook endpoints (132 nodes total, up from 93)

## Decisions Made

1. **Authorization: Bearer header (not body):** Based on CORS_RESULT=header from 02-01. This means GET requests (eluxr-approval-list, eluxr-themes-list) stay as GET -- no need to convert to POST. The JWT travels in the standard Authorization header.

2. **authenticatedFetch() in module script:** Defined alongside the supabase client initialization (same script block) so it has direct access to `supabase.auth.getSession()` and `showLoginPage()` without cross-script dependencies. Exposed to window for the non-module script block.

3. **Wrapper adds Content-Type automatically:** Since every n8n webhook call uses JSON, the wrapper adds `Content-Type: application/json` by default. This allowed removing the header from all 21 call sites that had it, reducing code duplication.

4. **Programmatic workflow transformation:** Used a Python script to transform the workflow JSON rather than manual editing. This ensures consistent node naming, correct connections, and atomic modification of all 13 endpoints. Each auth chain follows the exact pattern established in 02-02's Auth Test workflow.

5. **Node naming convention:** `Auth Validate (path)`, `Auth OK? (path)`, `401 Unauthorized (path)` -- includes the webhook path in parentheses for easy identification in the n8n canvas.

## Deviations from Plan

None -- plan executed exactly as written. Both header approach (from CORS_RESULT) and integration pattern (from 02-02) were clearly specified.

## Issues Encountered

None -- both tasks executed cleanly. The programmatic approach for workflow transformation prevented any manual wiring errors.

## User Setup Required

**Cloud deployment of updated workflow:**

The updated workflow JSON needs to be imported to the cloud instance (flowbound.app.n8n.cloud). Options:

1. **Import via n8n UI:** Open flowbound.app.n8n.cloud, import `workflows/eluxr-social-media-action-v2-authenticated.json` to replace the existing workflow
2. **Via n8n API:** If API key is available, push programmatically

**Important:** The Auth Validator sub-workflow (S4QtfIKpvhW4mQYG) must already be active on the cloud instance for the Execute Sub-Workflow nodes to work.

## Next Phase Readiness

- **Ready for 02-05:** Full end-to-end auth flow can be tested -- login, get JWT, make authenticated webhook call, verify 401 on unauthenticated calls
- **Ready for Phase 3:** user_id flows through the data pipeline after Auth Validator; downstream Supabase queries can use it for tenant isolation
- **Ready for Phase 5:** Frontend already sends authenticated requests; migration only changes data display logic
- **Cloud deployment needed:** Updated workflow JSON must be imported to flowbound.app.n8n.cloud before authenticated requests will work end-to-end
- **No blockers** for downstream plans

---
*Phase: 02-authentication*
*Completed: 2026-03-02*
