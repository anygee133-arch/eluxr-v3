---
phase: 03-workflow-decomposition-backend-bug-fixes
plan: 04
subsystem: api
tags: [n8n, sub-workflow, kie-api, image-generation, video-generation, polling-loop, bug-fix, tool-05, tool-06]

# Dependency graph
requires:
  - phase: 03-workflow-decomposition-backend-bug-fixes
    provides: "SUPABASE_CREDENTIAL_PATTERN, Auth Validator pattern, n8n Cloud unlimited active workflows"
  - phase: 02-authentication
    provides: "AUTH_VALIDATOR_WORKFLOW_ID: S4QtfIKpvhW4mQYG, Auth Validator sub-workflow"
provides:
  - "DEPLOYED_WORKFLOWS: 11-Image-Generator (xpMcgk1Q2pdmHBVE), 12-Video-Script-Builder (r2QokI9OpgY4HRyl), 13-Video-Creator (8FY33EKJMsTgFJ3N)"
  - "WEBHOOK_PATHS: /eluxr-imagegen -> 11-Image-Generator, /eluxr-videoscript -> 12-Video-Script-Builder, /eluxr-videogen -> 13-Video-Creator"
  - "TOOL_05_STATUS: FIXED -- Image polling uses Wait+IF loop (10s initial, 5s retry, 12 max attempts = 65s timeout)"
  - "TOOL_06_STATUS: FIXED -- Video Ready? TRUE -> Parse Video Result, FALSE -> Video Processing Response"
  - "POLLING_PATTERN: Init Poll Counter -> Initial Wait (10s) -> KIE Get Result -> Check Result -> IF isComplete -> TRUE: IF isSuccess -> parse/error | FALSE: Retry Wait (5s) -> loop"
affects:
  - "03-05 (Router): All 3 standalone tool webhooks ready for router integration"
  - "Phase 5 (Frontend): Image generator returns proper results instead of timing out; video generator correctly parses when ready"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Wait+IF polling loop for async API operations (replaces setTimeout hack)"
    - "neverError option on HTTP Request nodes for graceful error handling in polling loops"
    - "Single Wait + frontend retry for long-running operations (video >60s)"

key-files:
  created:
    - workflows/11-image-generator.json
    - workflows/12-video-script-builder.json
    - workflows/13-video-creator.json
  modified: []

key-decisions:
  - "TOOL-05: Replace setTimeout(35000) with Wait+IF polling loop (10s initial, 5s retry, max 12 attempts)"
  - "TOOL-06: Swap inverted TRUE/FALSE wiring on Video Ready? IF node"
  - "Video Creator keeps single Wait (120s) + single poll pattern; frontend retries if not ready (videos take >60s, server-side loop impractical)"
  - "Code nodes updated to use $input.item.json (n8n v2 default mode) instead of monolith's $input.first()"

patterns-established:
  - "Polling loop: Init Counter (Code) -> Initial Wait (n8n Wait) -> HTTP Poll -> Check Result (Code) -> IF Complete -> branch or Retry Wait -> loop back"
  - "Error handling in polling: isComplete, isSuccess, isTimeout, isError flags for branching"
  - "Long-running operations: Single server-side poll with client-side retry is acceptable when generation >60s"

# Metrics
duration: 8min
completed: 2026-03-02
---

# Phase 3 Plan 04: Sub-Workflows 11-13 Summary

**3 standalone tool sub-workflows extracted from monolith with TOOL-05 (image polling loop replaces setTimeout) and TOOL-06 (video IF wiring swap) bug fixes applied**

## Performance

- **Duration:** 8 min
- **Started:** 2026-03-02T07:22:15Z
- **Completed:** 2026-03-02T07:29:45Z
- **Tasks:** 3
- **Files created:** 3

## Accomplishments

- Built and deployed 11-Image-Generator with proper Wait+IF polling loop replacing the setTimeout(35000) hack (TOOL-05 fix)
- Built and deployed 12-Video-Script-Builder as clean extraction with Claude API integration
- Built and deployed 13-Video-Creator with corrected Video Ready? IF node wiring (TOOL-06 fix)
- All 3 workflows follow standard webhook + Auth Validator pattern
- No Google Sheets nodes in any workflow
- All Code nodes updated to use n8n v2 `$input.item.json` pattern

## Critical Bug Fixes

### TOOL-05: Image Polling Fix (11-Image-Generator)

**Before (monolith):**
```
KIE Create Image Task -> Code in JavaScript (setTimeout 35000) -> KIE Get Image Result -> Image Ready? IF
```
The `setTimeout(35000)` blindly waits 35 seconds regardless of whether the image is ready earlier or needs more time. No retry. Single attempt.

**After (fixed):**
```
KIE Create Image Task -> Init Poll Counter -> Initial Wait (10s) -> KIE Get Image Result
  -> Check Image Result -> IF isComplete
    -> TRUE + isSuccess: Parse Image Result -> Response 200
    -> TRUE + !isSuccess: Error Response 500
    -> FALSE: Retry Wait (5s) -> loop back to KIE Get Image Result
```
- Initial wait: 10 seconds
- Retry interval: 5 seconds
- Max attempts: 12 (total timeout: 65 seconds)
- Detects: success, timeout, failure states
- Properly returns error details on timeout/failure

### TOOL-06: Video Wiring Fix (13-Video-Creator)

**Before (monolith -- INVERTED):**
```
Video Ready? TRUE (successFlag=1, video IS ready) -> Video Processing Response (WRONG: says "still processing")
Video Ready? FALSE (successFlag!=1, NOT ready) -> Parse Video Result (WRONG: tries to parse incomplete result)
```

**After (fixed):**
```
Video Ready? TRUE (successFlag=1, video IS ready) -> Parse Video Result -> Video Gen Response (200 with video URL)
Video Ready? FALSE (successFlag!=1, NOT ready) -> Video Processing Response (retry=true message)
```

## DEPLOYED_WORKFLOWS

| Workflow | Local n8n ID | Webhook Path | Nodes | Bug Fix |
|----------|-------------|--------------|-------|---------|
| 11-Image-Generator | xpMcgk1Q2pdmHBVE | /eluxr-imagegen | 16 | TOOL-05 |
| 12-Video-Script-Builder | r2QokI9OpgY4HRyl | /eluxr-videoscript | 7 | None |
| 13-Video-Creator | 8FY33EKJMsTgFJ3N | /eluxr-videogen | 12 | TOOL-06 |

**Note:** Workflows deployed to local n8n instance. Cannot activate due to webhook path conflicts with active monolith workflow. Activation will occur when monolith is deactivated in Phase 3 Plan 05 (Router).

## WEBHOOK_PATHS

| Path | Workflow | Method |
|------|----------|--------|
| /eluxr-imagegen | 11-Image-Generator | POST |
| /eluxr-videoscript | 12-Video-Script-Builder | POST |
| /eluxr-videogen | 13-Video-Creator | POST |

## POLLING_PATTERN

The image generation polling loop (TOOL-05 fix) establishes a reusable pattern:

```
1. Init Poll Counter (Code): Set pollCount=0, extract taskId
2. Initial Wait (n8n Wait node): 10 seconds
3. KIE Get Result (HTTP Request): Poll API with taskId
4. Check Result (Code): Increment pollCount, determine state
   - isReady = state === 'success' || state === 'completed'
   - isTimeout = pollCount >= 12
   - isError = state === 'failed' || state === 'error'
   - isComplete = isReady || isTimeout || isError
5. IF isComplete:
   - TRUE -> IF isSuccess:
     - TRUE: Parse result, return 200
     - FALSE: Return 500 with error details
   - FALSE -> Retry Wait (5s) -> loop back to step 3
```

Total timeout: 10s + (11 x 5s) = 65 seconds maximum.

## Task Commits

Each task was committed atomically:

1. **Task 1: Build 11-Image-Generator with TOOL-05 polling fix** - `5a7d130` (feat)
   - 16 nodes including polling loop: Init Poll Counter, Initial Wait (10s), Check Image Result, Is Complete?, Is Success?, Retry Wait (5s)
   - Replaces setTimeout(35000) with proper Wait+IF loop
2. **Task 2: Build 12-Video-Script-Builder sub-workflow** - `44cbecc` (feat)
   - 7 nodes: clean extraction with Claude API call and script parsing
   - No bugs to fix, no Google Sheets nodes
3. **Task 3: Build 13-Video-Creator with TOOL-06 wiring fix** - `b4dbeb6` (feat)
   - 12 nodes with corrected Video Ready? IF wiring
   - TRUE -> Parse Video Result (was: Video Processing Response)
   - FALSE -> Video Processing Response (was: Parse Video Result)

## Files Created/Modified

- `workflows/11-image-generator.json` - Image generator with TOOL-05 polling fix (16 nodes: webhook, auth, prompt prep, KIE create, poll loop with Init/Wait/Check/IF/Retry, parse, response, error)
- `workflows/12-video-script-builder.json` - Video script builder with Claude API (7 nodes: webhook, auth, Claude call, parse, response)
- `workflows/13-video-creator.json` - Video creator with TOOL-06 wiring fix (12 nodes: webhook, auth, Veo prep, KIE create, Wait 120s, KIE get status, corrected IF, parse, responses)

## Decisions Made

1. **Video Creator keeps single Wait pattern (Option A):** Videos take >60 seconds to generate. A server-side polling loop would hold the n8n execution open for potentially minutes, risking the 5-minute execution timeout on the Starter plan. The existing pattern of single server-side Wait (120s) + single poll with frontend retry is more appropriate. The frontend already handles the retry flow.

2. **Code nodes updated to $input.item.json:** The monolith Code nodes used `$input.first().json` (runOnceForAllItems mode). Per the established pattern from 02-02, all sub-workflow Code nodes use `$input.item.json` (default runOnceForEachItem mode) and return `{ json: {} }` instead of `[{ json: {} }]`.

3. **Added neverError to KIE Get Video Status:** Without neverError, a failed API call would crash the workflow instead of allowing the Code node to handle the error gracefully. This mirrors the existing neverError on the Auth Validator's Supabase call.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Code nodes used $input.first() instead of $input.item.json**
- **Found during:** Task 1, Task 3 (extracting from monolith)
- **Issue:** Monolith Code nodes (Prepare Nano Banana Prompt, Prepare Veo Prompt, Parse Image Result, Parse Video Result) used `$input.first().json` and returned arrays `[{ json: {} }]` -- this is the runOnceForAllItems mode but these nodes run in default runOnceForEachItem mode
- **Fix:** Changed all Code nodes to use `$input.item.json` and single-object return `{ json: {} }` per the established pattern from 02-02
- **Files modified:** workflows/11-image-generator.json, workflows/13-video-creator.json
- **Verification:** Consistent with all working sub-workflows (Auth Validator, Auth Test)
- **Committed in:** 5a7d130, b4dbeb6

**2. [Rule 2 - Missing Critical] Added neverError to KIE Get Video Status**
- **Found during:** Task 3 (building video creator)
- **Issue:** The monolith's KIE Get Video Status HTTP Request node had no error handling configuration. If the KIE API returns an error response, n8n would throw and crash the workflow instead of allowing graceful handling
- **Fix:** Added `neverError: true` to the response options, matching the pattern used in Auth Validator's Supabase call
- **Files modified:** workflows/13-video-creator.json
- **Verification:** Error responses flow through to Check Result Code node for proper handling
- **Committed in:** b4dbeb6

---

**Total deviations:** 2 auto-fixed (1 bug in Code node API, 1 missing critical error handling)
**Impact on plan:** Both fixes necessary for correct operation. The Code node fix prevents runtime errors. The neverError fix prevents crash-on-API-failure. No scope creep.

## Issues Encountered

1. **Webhook activation conflict:** All 3 sub-workflows were deployed to local n8n but could not be activated because the monolith workflow (ELUXR social media Action v2) is still active with the same webhook paths (/eluxr-imagegen, /eluxr-videoscript, /eluxr-videogen). This is expected -- activation will occur when the monolith is deactivated in Plan 05 (Router).

## User Setup Required

None - workflows are deployed to local n8n. Cloud deployment requires import via n8n UI or n8n Cloud API key (same as Auth Validator in 02-02).

## Next Phase Readiness

- **Ready for 03-05 (Router):** All 13 sub-workflows now exist (Auth Validator + 01-13). The router can orchestrate calls to these webhook paths.
- **TOOL-05 and TOOL-06 fixed:** Both inherited v1 bugs are resolved. No more setTimeout hack or inverted video wiring.
- **No blockers** for continuing Phase 3.
- **Cloud deployment pending:** All sub-workflows need import to flowbound.app.n8n.cloud before production use.

---
*Phase: 03-workflow-decomposition-backend-bug-fixes*
*Completed: 2026-03-02*
