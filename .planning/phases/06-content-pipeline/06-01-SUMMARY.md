---
phase: 06-content-pipeline
plan: 01
subsystem: database, infra
tags: [supabase, postgresql, n8n, webhook, callback, pipeline, migration, rls]

# Dependency graph
requires:
  - phase: 01-security-db-foundation
    provides: initial schema with 10 tables, RLS policies
  - phase: 04-async-pipeline
    provides: pipeline orchestrator workflow with progress tracking
provides:
  - products table with RLS for scraped product storage
  - content_items columns for video_script, hashtags, first_comment, product_id
  - campaigns show_name column for Netflix model
  - themes season_arc and inspirational_theme columns
  - icps content_pillars, pain_points, desires, objections, buying_triggers JSONB columns
  - orchestrator webhook callback pattern eliminating 5-minute timeout risk
affects: [06-02-icp-analyzer, 06-03-frontend-products, 06-04-theme-generator, 06-05-content-studio, 06-06-verification]

# Tech tracking
tech-stack:
  added: []
  patterns: [webhook-callback orchestration, fire-and-forget with neverError, shared-secret callback auth]

key-files:
  created:
    - supabase/migrations/20260303_add_products_and_pipeline_columns.sql
  modified:
    - workflows/14-pipeline-orchestrator.json

key-decisions:
  - "Webhook callback pattern replaces synchronous sub-workflow chaining in orchestrator"
  - "Shared secret (X-Pipeline-Secret header) protects callback endpoint instead of Auth Validator"
  - "Auth token stored in pipeline_runs metadata for passthrough to sub-workflows on callback"
  - "Fire-and-forget uses 10s timeout with neverError to avoid blocking orchestrator"

patterns-established:
  - "Callback pattern: sub-workflow receives callback_url + pipeline_run_id, POSTs back on completion"
  - "Route Next Stage: Code node maps completed step to next stage webhook + metadata"
  - "Action Switch: fire_next / mark_complete / mark_failed branching on callback"

requirements-completed: [PIPE-01, PIPE-02, PIPE-03]

# Metrics
duration: 4min
completed: 2026-03-03
---

# Phase 6 Plan 01: Schema Migration + Orchestrator Callback Restructure Summary

**Products table with RLS, 12 column additions across 4 tables, and orchestrator restructured from synchronous 10-20min chain to webhook callback pattern (< 30s per execution)**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-04T03:39:00Z
- **Completed:** 2026-03-04T03:43:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Created products table with full RLS (SELECT/INSERT/UPDATE/DELETE) and user_id index for scraped product data storage
- Added 12 columns across content_items (4), campaigns (1), themes (2), and icps (5) to support Netflix model, video scripts, and enriched ICP data
- Restructured pipeline orchestrator from synchronous 6-stage chain (10-20min, guaranteed timeout) to webhook callback pattern where each execution completes in under 30 seconds

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Supabase migration for products table and column additions** - `2ab20c6` (feat)
2. **Task 2: Restructure Pipeline Orchestrator to webhook callback pattern** - `969e5ee` (feat)

## Files Created/Modified
- `supabase/migrations/20260303_add_products_and_pipeline_columns.sql` - Products table CREATE, RLS policies, index, and ALTER TABLE additions to content_items, campaigns, themes, icps
- `workflows/14-pipeline-orchestrator.json` - Restructured from 24-node synchronous chain to 26-node dual-webhook architecture (entry + callback)

## Decisions Made
- **Webhook callback pattern over synchronous chaining:** Each sub-workflow receives a callback_url and pipeline_run_id, then POSTs back to the orchestrator when complete. This keeps each n8n execution under 30 seconds, well within the 5-minute Starter plan timeout.
- **Shared secret instead of Auth Validator on callback:** The callback webhook uses X-Pipeline-Secret header check ("eluxr-pipeline-internal-2024") rather than Auth Validator because callbacks come from other n8n workflows, not the browser.
- **Auth token in pipeline_runs metadata:** The original user's Authorization header is stored in the pipeline_run metadata during creation, then recovered and forwarded to each sub-workflow via the callback routing. This ensures sub-workflows can validate the user.
- **Fire-and-forget with 10s timeout:** The fire-and-forget HTTP Requests use a 10-second timeout with neverError:true. The orchestrator does not wait for or depend on the sub-workflow's response.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## User Setup Required

The migration file must be applied to Supabase. This will be handled during 06-06 (E2E verification). The orchestrator workflow JSON needs to be imported to n8n Cloud, also handled in the verification plan.

## Next Phase Readiness
- Products table ready for 06-02 (ICP Analyzer) to store scraped products
- Column additions ready for 06-02 (ICP enrichment fields), 06-04 (Netflix model fields), 06-05 (video scripts, hashtags)
- Orchestrator callback pattern ready for sub-workflows to POST completion callbacks
- Sub-workflows (01, 02, 04) need updates to accept callback_url/pipeline_run_id and POST back on completion (handled in 06-02, 06-04, 06-05)

---
*Phase: 06-content-pipeline*
*Completed: 2026-03-03*
