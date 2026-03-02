---
phase: 02-authentication
plan: 02
subsystem: auth
tags: [jwt, supabase-auth, n8n-sub-workflow, auth-middleware, bearer-token, tenant-isolation]

# Dependency graph
requires:
  - phase: 02-authentication
    provides: "JWT_CREDENTIAL_ID: GjLV4iwAj88m95yP, CORS_RESULT: header, JWT_ALGORITHM: ES256"
  - phase: 01-security-hardening-database-foundation
    provides: "Supabase project with test accounts, RLS policies using auth.uid()"
provides:
  - "AUTH_VALIDATOR_WORKFLOW_ID: ltscbuGU8ovNzLvo (local) -- reusable sub-workflow for JWT validation"
  - "AUTH_TEST_WORKFLOW_ID: xTD3cxVUqH5ZMecQ (local) -- test webhook demonstrating auth pattern"
  - "VALIDATION_APPROACH: Supabase HTTP API (/auth/v1/user) -- validates JWT and extracts user identity in one call"
  - "JWT_DELIVERY_CONFIRMED: Authorization: Bearer header -- end-to-end tested"
  - "INTEGRATION_PATTERN: Webhook -> Execute Sub-Workflow -> IF authenticated -> Success/Failure response"
affects:
  - 02-03 (signup/login workflow can reuse Auth Validator for protected routes)
  - 02-04 (all 13 webhooks will call Auth Validator as first step)
  - 02-05 (end-to-end auth testing uses Auth Validator + test patterns from this plan)
  - 05-frontend-migration (frontend sends Authorization: Bearer header, confirmed working)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "n8n Execute Sub-Workflow pattern for reusable auth validation"
    - "Supabase /auth/v1/user endpoint for JWT validation (returns user profile on valid token)"
    - "n8n Code node uses $input.item.json (default runOnceForEachItem mode)"
    - "n8n IF node v2.2 requires typeValidation: strict and version: 2 in conditions options"
    - "n8n Respond to Webhook v1.5 with responseCode option for custom HTTP status codes"

key-files:
  created:
    - workflows/eluxr-auth-validator.json
    - workflows/eluxr-auth-test.json
    - tests/auth-validator-test-results.md
  modified: []

key-decisions:
  - "Used Supabase HTTP API (/auth/v1/user) instead of n8n JWT node -- validates directly against Supabase (source of truth), no JWT credential needed on local instance"
  - "Sub-workflow uses executeWorkflowTrigger v1 (not v1.1) -- v1.1 caused WorkflowHasIssuesError"
  - "Code nodes use $input.item.json (default mode) not $input.first().json -- required for n8n Code v2 default runOnceForEachItem mode"
  - "HTTP Request node with neverError: true for Supabase call -- allows Code node to handle error responses gracefully"

patterns-established:
  - "Auth Validator integration: Webhook -> Execute Sub-Workflow(Auth Validator) -> IF(authenticated) -> true: process / false: 401"
  - "Auth Validator output: { authenticated: true, user_id, email, role, body, query } on success"
  - "Auth Validator output: { authenticated: false, error, statusCode: 401 } on failure"
  - "Execute Sub-Workflow passes full webhook output (headers, body, query) to sub-workflow"

# Metrics
duration: 38min
completed: 2026-03-02
---

# Phase 2 Plan 02: Auth Validator Sub-Workflow Summary

**Reusable n8n sub-workflow validating Supabase JWTs via /auth/v1/user endpoint with Bearer header extraction, returning user_id for tenant-scoped operations**

## Performance

- **Duration:** 38 min
- **Started:** 2026-03-02T02:43:56Z
- **Completed:** 2026-03-02T03:22:04Z
- **Tasks:** 2
- **Files created:** 3

## Accomplishments

- Built and deployed "ELUXR Auth Validator" reusable sub-workflow (6 nodes: Trigger, Extract Token, IF, HTTP Validate, Extract Identity, Error Output)
- Built and deployed "ELUXR Auth Test" webhook demonstrating correct auth integration pattern (5 nodes: Webhook, Execute Sub-Workflow, IF, Success Response, Failure Response)
- All 4 end-to-end tests pass: valid JWT (200 + correct user_id), missing JWT (401), invalid JWT (401), different users return different user_ids
- Established the integration pattern that all 13 existing webhooks will adopt in Plan 02-04

## Decision Outputs

These decisions are consumed by downstream plans (02-03 through 02-05 and Phase 5):

| Key | Value | Used By |
|-----|-------|---------|
| **AUTH_VALIDATOR_WORKFLOW_ID** | `ltscbuGU8ovNzLvo` (local instance) | 02-04 (all webhooks), 02-05 (integration tests) |
| **AUTH_TEST_WORKFLOW_ID** | `xTD3cxVUqH5ZMecQ` (local instance) | 02-05 (auth integration testing reference) |
| **VALIDATION_APPROACH** | Supabase HTTP API (`/auth/v1/user`) | 02-04 (same approach in sub-workflow), all auth plans |
| **JWT_DELIVERY_CONFIRMED** | `Authorization: Bearer <JWT>` header -- end-to-end tested | Phase 5 (frontend), all auth plans |
| **INTEGRATION_PATTERN** | Webhook -> Execute Sub-Workflow -> IF authenticated -> process/401 | 02-04 (apply to all 13 webhooks) |

### Workflow Node Architecture

**Auth Validator Sub-Workflow (6 nodes):**
```
[Sub-Workflow Trigger] -> [Extract Token (Code)]
  -> [Has Token? (IF)]
    -> true: [Validate via Supabase (HTTP GET /auth/v1/user)]
      -> [Extract User Identity (Code)]
    -> false: [Error Output (Code)]
```

**Test Webhook (5 nodes):**
```
[Webhook POST /eluxr-auth-test] -> [Execute Sub-Workflow: Auth Validator]
  -> [Auth OK? (IF)]
    -> true: [Success Response (200)]
    -> false: [Auth Failed Response (401)]
```

## Task Commits

Each task was committed atomically:

1. **Task 1: Build and deploy Auth Validator + Auth Test workflows** - `64a7f6a` (feat)
   - Created both workflow JSONs and deployed to local n8n
   - Auth Validator with Supabase HTTP API validation approach
2. **Task 2: End-to-end testing with 4 test cases** - `b8e15d1` (test)
   - All 4 tests pass (valid JWT, missing JWT, invalid JWT, different users)
   - Fixed Code node mode ($input.item.json), IF node format, trigger version
   - Updated on-disk JSON to match working deployed versions

## Files Created/Modified

- `workflows/eluxr-auth-validator.json` - Auth Validator sub-workflow (6 nodes: trigger, extract token, IF, HTTP validate, extract identity, error output)
- `workflows/eluxr-auth-test.json` - Auth Test webhook demonstrating integration pattern (5 nodes: webhook, execute sub-workflow, IF, success response, failure response)
- `tests/auth-validator-test-results.md` - Full test results with request/response details for all 4 test cases

## Decisions Made

1. **Supabase HTTP API instead of n8n JWT node:** The plan offered two approaches for JWT validation -- n8n JWT node with the ES256 credential, or Supabase HTTP API (`/auth/v1/user`). Chose the HTTP API approach because: (a) it validates directly against Supabase as the source of truth, (b) it extracts user profile in the same call (id, email, role), (c) it works identically on local and cloud instances without needing the JWT credential to be present.

2. **Execute Sub-Workflow v1 (not v1.2):** The n8n executeWorkflow node v1.2 requires a resource locator (`__rl` object) for the workflowId parameter, but v1 accepts a plain string ID. Using v1 for simplicity and reliability.

3. **executeWorkflowTrigger v1 (not v1.1):** The v1.1 trigger caused `WorkflowHasIssuesError` at runtime. Downgrading to v1 resolved the issue.

4. **Code node default mode with $input.item.json:** The n8n Code v2 node default mode is `runOnceForEachItem` which requires `$input.item.json` (not `$input.first().json`). The return format is `{ json: {} }` (not `[{ json: {} }]`). Discovered this by comparing with working Code nodes in the existing v2 workflow.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] n8n Code node API compatibility**
- **Found during:** Task 2 (testing)
- **Issue:** Code nodes used `$input.first().json` and returned `[{ json: {} }]` array format, which is for `runOnceForAllItems` mode. The default mode is `runOnceForEachItem` which requires `$input.item.json` and returns `{ json: {} }` (single object).
- **Fix:** Changed all Code nodes to use `$input.item.json` and single-object return format
- **Files modified:** workflows/eluxr-auth-validator.json
- **Verification:** All 4 tests pass
- **Committed in:** b8e15d1

**2. [Rule 1 - Bug] executeWorkflowTrigger v1.1 causes WorkflowHasIssuesError**
- **Found during:** Task 2 (testing)
- **Issue:** The executeWorkflowTrigger node at v1.1 caused the workflow to fail with "The workflow has issues and cannot be executed" error
- **Fix:** Downgraded to executeWorkflowTrigger v1
- **Files modified:** workflows/eluxr-auth-validator.json
- **Verification:** Sub-workflow executes successfully
- **Committed in:** b8e15d1

**3. [Rule 1 - Bug] IF node conditions missing typeValidation and version fields**
- **Found during:** Task 2 (testing)
- **Issue:** IF node v2.2 conditions require `typeValidation: "strict"` and `version: 2` in the options object. Without these, n8n flagged the workflow as having issues.
- **Fix:** Added `typeValidation: "strict"` and `version: 2` to IF conditions options
- **Files modified:** workflows/eluxr-auth-validator.json, workflows/eluxr-auth-test.json
- **Verification:** IF branching works correctly in all test cases
- **Committed in:** b8e15d1

---

**Total deviations:** 3 auto-fixed (3 bugs related to n8n node API compatibility)
**Impact on plan:** All fixes were necessary for the workflow to function. The Supabase HTTP API validation approach was already documented as an alternative in the plan. No scope creep.

## Issues Encountered

1. **n8n Cloud API key not available:** The cloud instance (flowbound.app.n8n.cloud) requires an API key for programmatic workflow creation. No API key was available in the environment. Workflows were deployed to the local n8n instance (localhost:5678) for testing. The on-disk JSON files are ready for cloud import.

2. **Password format:** The plan referenced passwords with exclamation marks (`TestPass123!A`) but the actual passwords are without (`TestPass123A`). Discovered during Test 1 authentication.

## User Setup Required

**Cloud deployment:** The workflows are deployed and tested on the local n8n instance. To deploy to the cloud instance (flowbound.app.n8n.cloud):

**Option A: Import via n8n UI**
1. Open flowbound.app.n8n.cloud
2. Create new workflow from import: use `workflows/eluxr-auth-validator.json`
3. Record the cloud workflow ID
4. Create new workflow from import: use `workflows/eluxr-auth-test.json`
5. Update the "Run Auth Validator" node's workflowId to the cloud Auth Validator ID
6. Activate both workflows

**Option B: Provide n8n Cloud API key**
1. In n8n Cloud: Settings > API Keys > Create new key
2. Workflows can then be pushed programmatically via the n8n REST API

## Next Phase Readiness

- **Ready for 02-03:** Auth Validator pattern established; signup/login workflow can use it for protected routes
- **Ready for 02-04:** Integration pattern documented and tested; all 13 webhooks can add Execute Sub-Workflow node calling Auth Validator
- **Ready for 02-05:** Test patterns established with curl commands for all auth scenarios
- **Cloud deployment needed:** Workflows need to be imported to flowbound.app.n8n.cloud before they can serve frontend requests (Phase 5)
- **No blockers** for continuing authentication phase development

---
*Phase: 02-authentication*
*Completed: 2026-03-02*
