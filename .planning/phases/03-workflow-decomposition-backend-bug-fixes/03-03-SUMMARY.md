---
phase: 03-workflow-decomposition-backend-bug-fixes
plan: 03
subsystem: workflows
tags: [supabase-rest-api, approval-queue, calendar-sync, chat, google-sheets-migration, tenant-isolation]

# Dependency graph
requires:
  - phase: 03-workflow-decomposition-backend-bug-fixes
    plan: 01
    provides: "SUPABASE_CREDENTIAL_PATTERN, SUPABASE_URL, CONTENT_TYPE_VALUES"
  - phase: 02-authentication
    plan: 02
    provides: "AUTH_VALIDATOR_WORKFLOW_ID: S4QtfIKpvhW4mQYG"
provides:
  - "DEPLOYED_WORKFLOWS: 06-Approval-List, 07-Approval-Action, 08-Clear-Pending, 09-Calendar-Sync, 10-Chat"
  - "WEBHOOK_PATHS: eluxr-approval-list, eluxr-approval-action, eluxr-clear-pending, eluxr-phase3-calendar, eluxr-chat"
  - "SHEETS_NODES_REPLACED: 11 Google Sheets nodes replaced/collapsed across 4 workflows"
  - "COLLAPSED_OPERATIONS: 3 find+update pairs collapsed to 3 single PATCH calls in 07-Approval-Action"
  - "CALENDAR_NODE_STATUS: Google Calendar node preserved in 09-Calendar-Sync (credential FJBcOjKITBIaEqRV)"
affects:
  - "03-05 (Router): Needs workflow IDs for all sub-workflows including these 5"
  - "Phase 7 (Approval Queue): Frontend will call these approval endpoints"
  - "Phase 8 (Calendar): 09-Calendar-Sync ready for Google Calendar decisions"
  - "Phase 9 (AI Chat): 10-Chat ready for Supabase context loading enhancement"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Switch node for action routing with first-match mode and fallback output"
    - "Supabase DELETE with Prefer: return=representation for deleted row count"
    - "splitInBatches loop for Google Calendar batch event creation"
    - "Code node this.helpers.httpRequest() for Claude API calls"

key-files:
  created:
    - workflows/06-approval-list.json
    - workflows/07-approval-action.json
    - workflows/08-clear-pending.json
    - workflows/09-calendar-sync.json
    - workflows/10-chat.json
  modified: []

key-decisions:
  - "Switch node replaces IF cascade for approval actions -- cleaner routing with fallback for unknown actions"
  - "DB status is pending_review not pending -- updated from v1 Sheets convention to v2 DB CHECK constraint values"
  - "Chat pipeline preserved as-is -- Supabase context loading deferred to Phase 9"
  - "Google Calendar node kept with existing OAuth credential -- Phase 8 will decide its future"

patterns-established:
  - "Approval PATCH pattern: single PATCH with id+user_id filter replaces find+update pair"
  - "Supabase DELETE with status filter for bulk operations"
  - "Calendar event format from content_items: platform times, color coding, content preview"

# Metrics
duration: 5min
completed: 2026-03-02
---

# Phase 3 Plan 03: Sub-workflows 06-10 Summary

**Built 5 approval/calendar/chat sub-workflows replacing 11 Google Sheets nodes with Supabase operations, collapsing 3 find+update pairs into single PATCH calls**

## Performance

- **Duration:** 5 min
- **Started:** 2026-03-02T07:22:14Z
- **Completed:** 2026-03-02T07:27:38Z
- **Tasks:** 5
- **Files created:** 5

## Accomplishments

- Built and saved 06-Approval-List: Supabase SELECT with status grouping replaces Google Sheets read
- Built and saved 07-Approval-Action: Switch node routes approve/reject/edit to 3 Supabase PATCH calls, replacing 8 Google Sheets nodes (3 Find + 3 Update + 2 IF)
- Built and saved 08-Clear-Pending: Single Supabase DELETE replaces Get Pending + Delete Pending pair
- Built and saved 09-Calendar-Sync: Supabase SELECT replaces Google Sheets read, Google Calendar node preserved
- Built and saved 10-Chat: Extracted chat pipeline with Claude API call (no Sheets migration needed)
- All 5 workflows follow standard webhook + Auth Validator + IF + business logic + respond pattern
- All Supabase operations include user_id filter for tenant isolation

## Critical Results for Downstream Plans

### 1. DEPLOYED_WORKFLOWS

| Workflow | File | Webhook Path | Node Count |
|----------|------|-------------|------------|
| 06-Approval-List | workflows/06-approval-list.json | /eluxr-approval-list | 7 |
| 07-Approval-Action | workflows/07-approval-action.json | /eluxr-approval-action | 10 |
| 08-Clear-Pending | workflows/08-clear-pending.json | /eluxr-clear-pending | 7 |
| 09-Calendar-Sync | workflows/09-calendar-sync.json | /eluxr-phase3-calendar | 9 |
| 10-Chat | workflows/10-chat.json | /eluxr-chat | 7 |

**Note:** Workflows are saved as JSON files. Cloud deployment requires import via n8n UI or API key. Cloud workflow IDs will be assigned upon import.

### 2. SHEETS_NODES_REPLACED

| Workflow | Sheets Nodes Replaced | Supabase Replacement | Operation |
|----------|-----------------------|---------------------|-----------|
| 06-Approval-List | Read Queue Sheet (1) | Supabase SELECT content_items | GET with user_id filter |
| 07-Approval-Action | Find Content Row + Update to Approved (2) | Supabase PATCH Approve | PATCH with id+user_id filter |
| 07-Approval-Action | Find Row for Reject + Update to Rejected (2) | Supabase PATCH Reject | PATCH with id+user_id filter |
| 07-Approval-Action | Find Row for Edit + Update Content (2) | Supabase PATCH Edit | PATCH with id+user_id filter |
| 07-Approval-Action | Is Approve? + Is Reject? IF nodes (2) | Switch "Route Action" | Single Switch with 3 outputs + fallback |
| 08-Clear-Pending | Get Pending Rows + Delete Pending Rows (2) | Supabase DELETE | DELETE with user_id+status filter |
| 09-Calendar-Sync | Read Approval Queue for Calendar (1) | Supabase SELECT content_items | GET with user_id+status=approved |
| 10-Chat | (none -- no Sheets in chat) | N/A | N/A |
| **Total** | **11 nodes replaced** | **7 Supabase operations** | |

### 3. COLLAPSED_OPERATIONS

Three find+update pairs in 07-Approval-Action collapsed to single PATCH calls:

| Old Pattern (Sheets) | New Pattern (Supabase) |
|----------------------|----------------------|
| Find Content Row -> Update to Approved (2 nodes) | PATCH /content_items?id=eq.{id}&user_id=eq.{uid} (1 node) |
| Find Row for Reject -> Update to Rejected (2 nodes) | PATCH /content_items?id=eq.{id}&user_id=eq.{uid} (1 node) |
| Find Row for Edit -> Update Content (2 nodes) | PATCH /content_items?id=eq.{id}&user_id=eq.{uid} (1 node) |

Additionally, the 2 IF nodes (Is Approve?, Is Reject?) were replaced by a single Switch node with 3 outputs + fallback.

### 4. CALENDAR_NODE_STATUS

- Google Calendar node **preserved** in 09-Calendar-Sync
- Uses existing OAuth credential: `FJBcOjKITBIaEqRV` (Google Calendar account)
- Calendar type: `primary`
- This is NOT a Google Sheets node -- it creates Google Calendar events
- Phase 8 will decide whether to keep, replace with .ics export, or enhance

### 5. STATUS VALUE MAPPING

The v1 Google Sheets used "pending" as the status value. The v2 Supabase schema uses "pending_review" (as defined in the content_items CHECK constraint). All workflows use the correct v2 values:

| v1 (Sheets) | v2 (Supabase) | Used In |
|-------------|---------------|---------|
| pending | pending_review | 06-Approval-List grouping, 08-Clear-Pending filter |
| approved | approved | 07-Approval-Action PATCH, 09-Calendar-Sync filter |
| rejected | rejected | 07-Approval-Action PATCH |
| published | published | 06-Approval-List grouping |

## Task Commits

Each task was committed atomically:

1. **Task 1: Build 06-Approval-List** - `7151920` (feat)
   - Supabase SELECT replaces Google Sheets Read Queue Sheet
   - Organize by Status handles all DB status values
2. **Task 2: Build 07-Approval-Action** - `bd6b49f` (feat)
   - 8 Sheets nodes collapsed to 3 Supabase PATCH + 1 Switch
   - Switch with first-match mode and fallback for unknown actions
3. **Task 3: Build 08-Clear-Pending** - `86fcb27` (feat)
   - Single Supabase DELETE replaces 2-step Get+Delete Sheets pair
   - Format Response computes deleted_count
4. **Task 4: Build 09-Calendar-Sync** - `0ab245f` (feat)
   - Supabase SELECT replaces Sheets read; Calendar node preserved
   - Format Calendar Events adapted for content_items data shape
5. **Task 5: Build 10-Chat** - `5bbd8d0` (feat)
   - Pure extraction, no Sheets migration needed
   - Claude API call via this.helpers.httpRequest() preserved

## Files Created/Modified

- `workflows/06-approval-list.json` - Approval queue read with Supabase SELECT + status grouping (7 nodes)
- `workflows/07-approval-action.json` - Approve/reject/edit with Switch routing + Supabase PATCH (10 nodes)
- `workflows/08-clear-pending.json` - Clear pending items with Supabase DELETE (7 nodes)
- `workflows/09-calendar-sync.json` - Calendar sync with Supabase SELECT + Google Calendar (9 nodes)
- `workflows/10-chat.json` - Chat endpoint with Claude API call (7 nodes)

## Decisions Made

1. **Switch node instead of IF cascade for approval routing:** The monolith used Is Approve? (IF) -> Is Reject? (IF) -> fallthrough (Edit). Replaced with a single Switch node with 3 named outputs (Approve, Reject, Edit) and a fallback output returning 400 Bad Request. This is cleaner and handles unknown actions gracefully.

2. **DB status "pending_review" not "pending":** The v1 Sheets used "pending" but the v2 content_items table CHECK constraint requires "pending_review". All workflows use the correct DB value.

3. **Chat pipeline preserved as-is:** The Prepare Chat Context code node uses phase-based system prompts without querying any database. Supabase context loading (fetching ICP data, themes, etc. for richer chat context) is explicitly deferred to Phase 9 (AI Chat).

4. **Google Calendar node kept with existing credential:** The Calendar integration (OAuth credential FJBcOjKITBIaEqRV) is preserved. Phase 8 will decide whether to keep it, replace with .ics export, or enhance with per-user OAuth.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Added 400 Bad Request fallback for unknown actions in 07-Approval-Action**
- **Found during:** Task 2
- **Issue:** The plan described approve/reject/edit routes but no handling for unknown action values
- **Fix:** Added Switch fallback output connecting to a 400 Bad Request response node
- **Files modified:** workflows/07-approval-action.json
- **Commit:** bd6b49f

**2. [Rule 1 - Bug] Status value "pending" vs "pending_review"**
- **Found during:** Task 1 and Task 3
- **Issue:** The v1 monolith uses status "pending" but the Supabase content_items CHECK constraint requires "pending_review"
- **Fix:** Used "pending_review" in all Supabase queries (06-Approval-List grouping, 08-Clear-Pending DELETE filter)
- **Files modified:** workflows/06-approval-list.json, workflows/08-clear-pending.json
- **Commits:** 7151920, 86fcb27

**3. [Rule 2 - Missing Critical] Added Format Response code node in 08-Clear-Pending**
- **Found during:** Task 3
- **Issue:** Supabase DELETE with Prefer: return=representation returns the deleted rows as an array, but the monolith's Respond node expected a formatted response with deleted_count
- **Fix:** Added Format Response code node to compute deleted_count from the Supabase response array
- **Files modified:** workflows/08-clear-pending.json
- **Commit:** 86fcb27

---

**Total deviations:** 3 auto-fixed (1 missing fallback, 1 status value bug, 1 missing response formatter)
**Impact on plan:** All fixes improve correctness. No scope creep.

## Issues Encountered

1. **n8n API key not available:** The local n8n instance requires an X-N8N-API-KEY header for programmatic deployment. No API key was available. Workflows saved as JSON files for manual import via n8n UI or future API key configuration. This is consistent with how all previous plans (01-ICP-Analyzer, 11-Image-Generator) handled deployment.

## User Setup Required

**Cloud deployment:** Import each workflow JSON to flowbound.app.n8n.cloud:

1. Open flowbound.app.n8n.cloud
2. Create new workflow > Import from file for each:
   - `workflows/06-approval-list.json`
   - `workflows/07-approval-action.json`
   - `workflows/08-clear-pending.json`
   - `workflows/09-calendar-sync.json`
   - `workflows/10-chat.json`
3. Activate all 5 workflows
4. Record cloud workflow IDs for the Router (Plan 03-05)

**Note:** The SUPABASE_SERVICE_ROLE_KEY must be set as an n8n environment variable for the Supabase HTTP headers to resolve.

## Next Phase Readiness

- **Ready for 03-04:** Sub-workflows 11-13 (standalone tools) can proceed independently
- **Ready for 03-05:** Router workflow needs workflow IDs from these 5 (plus the 01-05 from Plan 02)
- **Ready for Phase 7:** Approval queue frontend can call these endpoints
- **Ready for Phase 8:** Calendar sync workflow is extracted and ready for Google Calendar decisions
- **Ready for Phase 9:** Chat workflow is extracted and ready for Supabase context loading
- **No blockers** for continuing Phase 3

---
*Phase: 03-workflow-decomposition-backend-bug-fixes*
*Completed: 2026-03-02*
