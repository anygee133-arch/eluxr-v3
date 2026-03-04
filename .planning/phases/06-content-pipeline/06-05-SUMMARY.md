---
phase: 06-content-pipeline
plan: 05
subsystem: api, ai
tags: [n8n, claude, perplexity, kie, supabase, content-generation, batch-processing, image-generation, video-scripts, webhook-callback]

# Dependency graph
requires:
  - phase: 06-content-pipeline
    provides: products table with RLS, enriched ICP columns, orchestrator callback pattern
  - phase: 06-content-pipeline
    provides: Theme Generator writing Netflix model themes with daily product assignments to Supabase
provides:
  - Weekly batch content generation (7 days x N platforms) with platform-specific tone and product CTA
  - 7 hero images per week via KIE Nano Banana Pro with Wait+IF polling loop
  - 3-4 video scripts per week with Perplexity trending audio recommendations
  - Batch content_items insert to Supabase with correct types, dates, product_ids
  - Orchestrator callback with step number (week_number + 2)
affects: [06-06-verification]

# Tech tracking
tech-stack:
  added: []
  patterns: [weekly-batch-generation, split-in-batches-loop, perplexity-trending-audio, kie-polling-within-loop, has-video-days-routing]

key-files:
  created: []
  modified:
    - workflows/04-content-studio.json

key-decisions:
  - "Single Claude call per day generates all platform posts plus image prompt in one response"
  - "Has Video Days? IF node routes to skip-video path when no video days exist"
  - "KIE image polling loop embedded inside Image Generation Loop (not separate workflow)"
  - "Batch insert all content_items for the week in a single POST request"
  - "Video days are 2, 4, 6 (3 scripts) or 2, 4, 6, 7 (4 scripts on even weeks)"

patterns-established:
  - "SplitInBatches + Rate Limit Wait pattern for Claude API calls (2s gap)"
  - "Perplexity trending audio -> video script prompt enrichment pipeline"
  - "KIE polling loop inside outer SplitInBatches loop with Image Gap Wait between tasks"
  - "Collect All Day Content aggregates loop results via named node reference $('Parse Day Content').all()"
  - "Skip-video path via IF node for weeks with no video assignments"

requirements-completed: [PIPE-03, PIPE-04, PIPE-05, PIPE-06]

# Metrics
duration: 5min
completed: 2026-03-04
---

# Phase 6 Plan 05: Content Studio Overhaul Summary

**Weekly batch content generation pipeline: 7-day Claude post loop (N platforms each), Perplexity trending audio research, 3-4 video scripts, batch Supabase insert, 7 KIE hero images with polling, orchestrator callback**

## Performance

- **Duration:** 5 min
- **Started:** 2026-03-04T03:59:11Z
- **Completed:** 2026-03-04T04:05:00Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- Overhauled 04-Content-Studio from 17-node single-day workflow to 49-node weekly batch generation pipeline
- Phase A loads context (theme with daily assignments, ICP, products) from Supabase via 3 HTTP GET requests
- Phase B generates platform-specific posts for 7 days via Claude loop (all platforms in single call per day, with 2s rate limit gap)
- Phase C researches trending audio via Perplexity sonar-pro, then generates 3-4 detailed video scripts via Claude loop
- Phase D batch-inserts all content_items (text posts + video items) in a single Supabase POST
- Phase E generates 7 hero images via KIE Nano Banana Pro with embedded Wait+IF polling loop (10s initial, 5s retry, max 12 attempts), then PATCHes image_url on matching content_items
- Phase F calls orchestrator callback with step = week_number + 2
- Full error handling path mirrors 01-ICP-Analyzer pattern (Handle Error -> Has Callback URL? -> Error Callback -> Respond Error)

## Task Commits

Each task was committed atomically:

1. **Task 1: Build weekly batch content generation pipeline** - `68ba3c5` (feat)

## Files Created/Modified
- `workflows/04-content-studio.json` - Complete overhaul from 17 to 49 nodes: Auth chain preserved, Extract Params, Read Theme/ICP/Products, Prepare Daily Content Loop (builds Claude prompts with platform rules), Day Content Loop (SplitInBatches), Generate Day Content (Claude), Parse Day Content (robust JSON), Rate Limit Wait, Collect All Day Content, Prepare Trending Audio Prompt, Research Trending Audio (Perplexity), Prepare Video Script Prompts, Has Video Days? IF, Prepare Video Loop Items, Video Script Loop, Generate Video Script (Claude), Parse Video Script, Video Rate Limit Wait, Collect Video Content, Skip Video Path, Prepare Batch Insert, Batch Insert Content, Prepare Image Loop Items, Image Generation Loop, Create KIE Task, Init Image Poll, Image Initial Wait, Poll KIE Result, Check KIE Result, IF Complete, Image Retry Wait, IF Success, Update Image URL, Skip Failed Image, Image Gap Wait, Prepare Callback, Callback to Orchestrator, Respond Success, Handle Error, Has Callback URL?, Error Callback, Respond Error

## Decisions Made
- **Single Claude call per day for all platforms:** Instead of 1 call per platform, one call generates posts for all selected platforms plus the hero image prompt. Reduces Claude API calls from 28 to 7 per week.
- **Has Video Days? IF node:** Added routing node between Prepare Video Script Prompts and Video Script Loop. When no video days exist, the Skip Video Path bypasses the video loop entirely and goes straight to batch insert.
- **KIE polling embedded in loop:** Rather than calling the standalone 11-Image-Generator workflow 7 times (7 separate executions), the KIE polling pattern is embedded inside the Image Generation Loop. This keeps all 7 image generations within a single n8n execution, saving execution budget.
- **Video day selection:** Days 2, 4, 6 always get video scripts (3 per week). Even-numbered weeks also include day 7 (4 per week). This provides variety without hardcoding.
- **Batch insert all content at once:** All text posts (7 days x N platforms) and video content items (3-4 per week) are merged into a single JSON array and POSTed to Supabase in one request, minimizing DB round trips.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Added Has Video Days? IF node for routing**
- **Found during:** Task 1
- **Issue:** Plan specified video generation for 3-4 days per week but didn't detail the routing when a week has zero video days. Without an IF node, the Video Script Loop would receive empty items.
- **Fix:** Added Has Video Days? IF node between Prepare Video Script Prompts and Prepare Video Loop Items. TRUE path goes to video loop; FALSE path goes to Skip Video Path which bypasses directly to Prepare Batch Insert.
- **Files modified:** workflows/04-content-studio.json
- **Committed in:** 68ba3c5

**2. [Rule 2 - Missing Critical] Added Skip Failed Image node**
- **Found during:** Task 1
- **Issue:** Plan specified "If KIE image generation fails for a day, skip and leave image_url null" but no node existed to handle the IF Success FALSE path. Without it, the loop would break on failed images.
- **Fix:** Added Skip Failed Image code node on IF Success FALSE path, which continues to Image Gap Wait to resume the loop.
- **Files modified:** workflows/04-content-studio.json
- **Committed in:** 68ba3c5

**3. [Rule 2 - Missing Critical] Added error handling path with callback on failure**
- **Found during:** Task 1
- **Issue:** Plan specified error handling but didn't detail node structure. Without it, failures would leave pipeline_run stuck in "running" state.
- **Fix:** Added 4-node error path: Handle Error (recovers pipeline_run_id/callback_url from Extract Params), Has Callback URL? (IF), Error Callback (POST with error status + shared secret), Respond Error (500).
- **Files modified:** workflows/04-content-studio.json
- **Committed in:** 68ba3c5

---

**Total deviations:** 3 auto-fixed (3 missing critical)
**Impact on plan:** All additions are correctness requirements for proper routing, error handling, and graceful degradation. No scope creep.

## Issues Encountered

None

## User Setup Required

The updated workflow JSON must be imported to n8n Cloud. This will be handled during 06-06 (E2E verification plan).

## Next Phase Readiness
- Content Studio now generates weekly batches of platform-specific posts, hero images, and video scripts
- All content_items stored in Supabase with correct types (text/video), scheduled_dates, product_ids, hashtags, first_comment, video_script JSONB
- Orchestrator receives step 3-6 callbacks (one per week) to trigger next pipeline stage
- Ready for 06-06 (E2E verification) to validate full pipeline flow

## Self-Check: PASSED

- [x] `workflows/04-content-studio.json` exists (49 nodes)
- [x] Commit `68ba3c5` exists in git log
- [x] Verification script passes (Loop, KIE, Callback, Perplexity all detected)
- [x] JSON is valid and parseable
- [x] All 8 verification criteria pass
- [x] All node connections reference existing nodes (0 errors)

---
*Phase: 06-content-pipeline*
*Completed: 2026-03-04*
