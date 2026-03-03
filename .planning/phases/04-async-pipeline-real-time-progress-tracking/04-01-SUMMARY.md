---
phase: 04-async-pipeline-real-time-progress-tracking
plan: 01
subsystem: infra
tags: [n8n, pipeline-orchestrator, async-webhook, supabase-rest, respond-then-continue, pipeline_runs, progress-tracking]

# Dependency graph
requires:
  - phase: 02-authentication
    provides: "Auth Validator sub-workflow (S4QtfIKpvhW4mQYG)"
  - phase: 03-workflow-decomposition-backend-bug-fixes
    provides: "13 active sub-workflows on n8n Cloud"
provides:
  - "ORCHESTRATOR_WORKFLOW_JSON: workflows/14-pipeline-orchestrator.json -- ready for cloud deployment"
  - "ASYNC_PATTERN: Webhook -> Auth -> Dedup -> INSERT pipeline_runs -> Respond 202 -> 6x [Update Step + Execute Sub-Workflow] -> Mark Complete"
  - "PIPELINE_RUN_ID_RECOVERY: $('Extract Run ID').item.json.pipeline_run_id -- named node reference pattern for all PATCH URLs"
  - "TEST_SCRIPT: scripts/test-orchestrator.sh -- unauthenticated endpoint test"
affects:
  - "04-02 (Frontend Realtime): Needs deployed orchestrator endpoint to trigger pipelines"
  - "04-03 (E2E Verification): Full pipeline test requires deployed orchestrator + sub-workflow ID resolution"
  - "Phase 5 (Frontend Migration): Frontend will call /eluxr-generate-content instead of sequential phase1/phase2/phase4"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "responseMode: responseNode for async respond-then-continue (Respond to Webhook node sends 202, downstream nodes continue executing)"
    - "Named node reference $('Extract Run ID').item.json.pipeline_run_id to recover data after Execute Sub-Workflow replaces $json"
    - "$env.SUPABASE_URL for Supabase base URL (environment variable pattern, not hardcoded)"
    - "Dedup check: GET pipeline_runs?user_id=eq.X&status=eq.running before creating new run"

key-files:
  created:
    - workflows/14-pipeline-orchestrator.json
    - scripts/test-orchestrator.sh
  modified: []

key-decisions:
  - "Used $env.SUPABASE_URL instead of hardcoding URL -- cleaner pattern, requires env var to be set on n8n Cloud"
  - "Named node reference ($('Extract Run ID')) for all PATCH URLs -- required because Execute Sub-Workflow output replaces $json"
  - "Execute Sub-Workflow (Wait=true) for sub-workflow invocation -- shares parent timeout but conserves execution budget"
  - "Dedup returns existing run_id with resumed: true flag instead of error -- graceful handling"
  - "Auth Validator data recovered via $('Auth Validator').item.json in Create Pipeline Run -- HTTP Request replaces $json in data flow"

patterns-established:
  - "Async pipeline: Webhook -> Auth -> Create Run -> Respond 202 -> Sequential Steps -> Mark Complete"
  - "Pipeline progress: PATCH pipeline_runs with current_step/step_label/step_progress after each step"
  - "Named node reference: Use $('Node Name').item.json when data is lost after Execute Sub-Workflow"

# Metrics
duration: 7min
completed: 2026-03-03
---

# Phase 4 Plan 01: Pipeline Orchestrator Workflow Summary

**24-node n8n Pipeline Orchestrator workflow with async respond-then-continue pattern, dedup guard, 6 sequential pipeline steps with per-step Supabase progress updates, and named node reference for pipeline_run_id recovery**

## Performance

- **Duration:** 7 min
- **Started:** 2026-03-03T02:18:37Z
- **Completed:** 2026-03-03T02:26:07Z
- **Tasks:** 2
- **Files created:** 2

## Accomplishments

- Built complete 24-node Pipeline Orchestrator workflow JSON with full node chain: Webhook -> Auth Validator -> Dedup Check -> Create Run -> INSERT pipeline_runs -> Extract Run ID -> Respond 202 -> 6x [Update Step + Execute Sub-Workflow] -> Mark Complete
- All 7 PATCH URLs (Update Step 1-6 + Mark Complete) use `$('Extract Run ID').item.json.pipeline_run_id` named node reference -- required because Execute Sub-Workflow output replaces $json
- Webhook responseMode set to "responseNode" enabling the async respond-then-continue pattern
- Dedup guard prevents multiple concurrent pipeline runs for the same user
- All 9 Supabase HTTP Request nodes use `$env.SUPABASE_SERVICE_ROLE_KEY` for authorization
- Created executable test script (scripts/test-orchestrator.sh) for endpoint verification
- Fixed data flow issues: Create Pipeline Run uses `$('Auth Validator').item.json` to recover user data after HTTP Request replaces $json

## Task Commits

Each task was committed atomically:

1. **Task 1: Build Pipeline Orchestrator Workflow JSON** - `741c483` (feat)
   - 24 nodes, 21 connections, complete async pipeline chain
   - Webhook with responseMode: responseNode
   - 6 Execute Sub-Workflow nodes with placeholder IDs
2. **Task 2: Verify Orchestrator Structure and Create Test Script** - `d6d4940` (test)
   - scripts/test-orchestrator.sh created (executable)
   - Complete structural verification: all 7 PATCH URLs verified, node chain verified, data flow verified

## Files Created/Modified

- `workflows/14-pipeline-orchestrator.json` - Pipeline Orchestrator workflow (24 nodes: Webhook, Auth Validator, Auth OK?, 401 Unauthorized, Check Existing Run, Has Running?, Return Existing Run, Create Pipeline Run, INSERT pipeline_runs, Extract Run ID, Respond 202, Update Step 1-6, Execute 01/02/04/11/13/09, Mark Complete)
- `scripts/test-orchestrator.sh` - Test script for endpoint verification (unauthenticated test + authenticated flow documentation)

## Decisions Made

1. **$env.SUPABASE_URL instead of hardcoded URL:** Existing sub-workflows hardcode `https://llpnwaoxisfwptxvdfed.supabase.co`, but the orchestrator uses `$env.SUPABASE_URL` for cleaner configuration management. Requires `SUPABASE_URL` env var to be set on n8n Cloud (Settings > Variables). Value: `https://llpnwaoxisfwptxvdfed.supabase.co`.

2. **Named node reference pattern:** All PATCH URLs use `$('Extract Run ID').item.json.pipeline_run_id` instead of `$json.pipeline_run_id`. This is critical because Execute Sub-Workflow nodes replace the `$json` context with their output, losing the pipeline_run_id. The named reference retrieves data from the specific "Extract Run ID" node regardless of what the preceding node output.

3. **Execute Sub-Workflow (Wait=true) for pipeline steps:** Uses n8n's built-in sub-workflow execution. Each sub-workflow runs within the parent execution context (shared timeout budget). This conserves the n8n Cloud execution budget (1 execution per pipeline run vs 7 with HTTP triggers). Trade-off: the cumulative execution time of all 6 steps shares the parent's timeout.

4. **Auth Validator data recovery via named reference:** The Create Pipeline Run Code node uses `$('Auth Validator').item.json` to recover user_id, email, and body data. This is necessary because the Check Existing Run HTTP Request node replaces `$json` with its Supabase response.

5. **Dedup returns existing run gracefully:** When a running pipeline already exists for the user, the orchestrator returns the existing run's ID with `resumed: true` (HTTP 202) instead of returning an error. The frontend can use this to re-subscribe to progress.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Data flow loss after HTTP Request nodes**
- **Found during:** Task 1 (workflow construction)
- **Issue:** The `Create Pipeline Run` Code node originally used `$input.item.json.user_id` which would be undefined because the preceding `Check Existing Run` HTTP Request replaces `$json` with its Supabase response (an empty array or item)
- **Fix:** Changed to use `$('Auth Validator').item.json` named node reference to recover user data
- **Files modified:** workflows/14-pipeline-orchestrator.json
- **Verification:** Data flow traced through full node chain; Auth Validator output correctly referenced
- **Committed in:** 741c483 (Task 1 commit)

**2. [Rule 1 - Bug] Has Running? IF condition using Array.isArray on n8n item data**
- **Found during:** Task 1 (workflow construction)
- **Issue:** Originally checked `Array.isArray($json) ? $json.length : 0 > 0`. In n8n HTTP Request v4.2, array responses are split into individual items, so `$json` would be a single object `{id: "abc"}` not an array. The Array.isArray check would always be false.
- **Fix:** Changed condition to check `$json.id` is notEmpty (which correctly identifies a returned pipeline_run item)
- **Files modified:** workflows/14-pipeline-orchestrator.json
- **Verification:** Condition correctly evaluates: has run = id exists, no run = id undefined
- **Committed in:** 741c483 (Task 1 commit)

---

**Total deviations:** 2 auto-fixed (2 bugs related to n8n data flow patterns)
**Impact on plan:** Both fixes essential for correct operation. No scope creep.

## Outstanding Items (Pre-deployment Prerequisites)

These items require n8n Cloud access (dashboard or API key) which was not available during execution:

### 1. Cloud Deployment
The workflow JSON is ready at `workflows/14-pipeline-orchestrator.json`. To deploy:
1. Open flowbound.app.n8n.cloud
2. Create new workflow from import: use `workflows/14-pipeline-orchestrator.json`
3. Activate the workflow
4. Record the cloud workflow ID

### 2. Sub-Workflow ID Resolution
Six Execute Sub-Workflow nodes have placeholder IDs that must be replaced with actual cloud workflow IDs:

| Node | Placeholder | Target Workflow |
|------|-------------|-----------------|
| Execute 01-ICP-Analyzer | REPLACE_WITH_01_ICP_ANALYZER_ID | 01-ICP-Analyzer |
| Execute 02-Theme-Generator | REPLACE_WITH_02_THEME_GENERATOR_ID | 02-Theme-Generator |
| Execute 04-Content-Studio | REPLACE_WITH_04_CONTENT_STUDIO_ID | 04-Content-Studio |
| Execute 11-Image-Generator | REPLACE_WITH_11_IMAGE_GENERATOR_ID | 11-Image-Generator |
| Execute 13-Video-Creator | REPLACE_WITH_13_VIDEO_CREATOR_ID | 13-Video-Creator |
| Execute 09-Calendar-Sync | REPLACE_WITH_09_CALENDAR_SYNC_ID | 09-Calendar-Sync |

To resolve: List all workflows on n8n Cloud dashboard and match names to IDs.

### 3. Environment Variables
Set these on n8n Cloud (Settings > Variables):
- `SUPABASE_URL` = `https://llpnwaoxisfwptxvdfed.supabase.co`
- `SUPABASE_SERVICE_ROLE_KEY` = (already set from Phase 3)

### 4. Sub-Workflow Trigger Compatibility
The 6 target sub-workflows use Webhook triggers (`n8n-nodes-base.webhook`), not Sub-Workflow Triggers (`n8n-nodes-base.executeWorkflowTrigger`). When called via Execute Sub-Workflow:
- n8n passes data to whatever trigger the workflow has
- The Webhook trigger may receive data differently than an HTTP request
- Sub-workflows may need their first node adjusted to handle Execute Sub-Workflow data format
- OR: Switch Execute Sub-Workflow nodes to HTTP Request nodes that call the webhook URLs directly

This compatibility issue is explicitly scoped for 04-03 (E2E Verification) to test and resolve.

## Issues Encountered

1. **n8n Cloud API key not available:** Consistent with all previous phases. Cannot deploy programmatically or list workflows via API. Workflow JSON is ready for dashboard import.

2. **No MCP tools available in execution context:** The plan references n8n MCP tools (`n8n_create_workflow`, `search_nodes`) for deployment. These tools were not available in the current execution session. Deployment deferred to dashboard import or a future session with MCP access.

## User Setup Required

**Cloud deployment required before the orchestrator can be tested end-to-end.** See "Outstanding Items" section above for:
- Workflow import to n8n Cloud
- Sub-workflow ID resolution
- SUPABASE_URL environment variable

## Next Phase Readiness

- **Workflow JSON complete:** 24-node orchestrator ready for cloud import
- **Structural verification complete:** All node connections, PATCH URLs, data flow, and auth integration verified
- **Ready for 04-02:** Frontend Realtime plan can proceed (uses pipeline_run_id pattern established here)
- **Ready for 04-03:** E2E verification will test the deployed orchestrator, resolve sub-workflow IDs, and verify the respond-then-continue pattern works on n8n Cloud
- **Deployment blocker:** Orchestrator must be imported and activated on n8n Cloud before 04-03 can run end-to-end tests

---
*Phase: 04-async-pipeline-real-time-progress-tracking*
*Completed: 2026-03-03*
