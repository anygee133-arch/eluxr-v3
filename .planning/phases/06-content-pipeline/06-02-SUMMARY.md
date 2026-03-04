---
phase: 06-content-pipeline
plan: 02
subsystem: api, ai
tags: [n8n, jina-ai, perplexity, claude, icp, products, supabase, webhook-callback]

# Dependency graph
requires:
  - phase: 06-content-pipeline
    provides: products table with RLS, enriched ICP columns, orchestrator callback pattern
  - phase: 02-authentication
    provides: Auth Validator sub-workflow pattern
provides:
  - ICP Analyzer workflow with Jina Reader scraping for product extraction
  - Claude-powered product parsing from website content
  - 3-call Perplexity deep research pipeline (industry, audience, content)
  - Claude ICP synthesis with all enriched JSONB fields
  - Products batch insert/delete lifecycle management
  - Orchestrator callback integration (step=1 complete/error)
affects: [06-03-frontend-products, 06-04-theme-generator, 06-05-content-studio, 06-06-verification]

# Tech tracking
tech-stack:
  added: [jina-reader-api]
  patterns: [robust-json-parsing, code-then-http-request-pair, sequential-api-chain, error-callback-pattern]

key-files:
  created: []
  modified:
    - workflows/01-icp-analyzer.json

key-decisions:
  - "Jina Reader API via HTTP GET (not n8n native node) for zero-config website scraping"
  - "Claude extracts products from Jina output with system prompt adapting to non-e-commerce sites"
  - "Delete-then-insert pattern for products instead of UPSERT (clean slate per scrape)"
  - "Has Products? IF node skips Save Products when extraction returns empty array"
  - "Sequential Perplexity research (not parallel) to stay within rate limits and pass context forward"
  - "Error handler catches failures and calls orchestrator callback with error status"

patterns-established:
  - "Code node + HTTP Request pair: Code prepares API body, HTTP sends it with predefinedCredentialType"
  - "Robust JSON parsing: try raw -> strip markdown fences -> regex extract JSON object/array"
  - "Data passthrough: each Code node carries forward all context (user_id, pipeline_run_id, callback_url)"
  - "Error callback pattern: Handle Error -> Has Callback URL? -> Error Callback -> Respond Error"

requirements-completed: [PIPE-01]

# Metrics
duration: 4min
completed: 2026-03-04
---

# Phase 6 Plan 02: ICP Analyzer Overhaul Summary

**Three-service ICP pipeline (Jina Reader + 3x Perplexity sonar-pro + 2x Claude) with product extraction, enriched ICP synthesis, and orchestrator callback integration**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-04T03:45:31Z
- **Completed:** 2026-03-04T03:49:27Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- Overhauled 01-ICP-Analyzer from 11-node single-Perplexity workflow to 30-node three-service pipeline
- Added Jina Reader API scraping with Claude product extraction (up to 12000 chars analyzed)
- Added 3 sequential Perplexity research calls covering industry landscape, audience psychology, and content opportunities
- Added Claude ICP synthesis producing all enriched JSONB fields (content_pillars, pain_points, desires, objections, buying_triggers)
- Integrated orchestrator callback (step=1 complete/error) with shared secret header

## Task Commits

Each task was committed atomically:

1. **Task 1: Build Jina scraping + Claude product extraction pipeline** - `4ff6a24` (feat)

## Files Created/Modified
- `workflows/01-icp-analyzer.json` - Complete overhaul from 11 to 30 nodes: Auth chain preserved, Jina Reader scraping, Claude product extraction, products DB lifecycle, 3x Perplexity research, Claude ICP synthesis, Save ICP with all enriched fields, callback to orchestrator, error handling path

## Decisions Made
- **Jina Reader via HTTP GET:** Used plain HTTP Request to `r.jina.ai/{url}` instead of n8n native Jina node. Simpler, no credential setup, free tier (20 RPM).
- **Claude for product extraction:** System prompt adapted for non-e-commerce sites ("treat service packages, consulting tiers, software plans, or menu items as products").
- **Delete-then-insert for products:** DELETE all user products before INSERT (not UPSERT). Ensures clean slate on each scrape, handles removed products correctly.
- **Has Products? gate:** IF node skips Save Products HTTP call when product array is empty, preventing empty POST to Supabase.
- **Sequential Perplexity research:** Three calls run sequentially (not parallel) to respect rate limits and allow each Code node to accumulate research context for the final synthesis.
- **Error callback pattern:** Separate error path catches failures, extracts pipeline_run_id/callback_url from earlier nodes, calls orchestrator callback with error status so pipeline can be marked failed.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Added Has Products? gate and Prepare Save Products node**
- **Found during:** Task 1
- **Issue:** Plan specified "Skip if products array is empty" but the workflow structure needed an IF node to conditionally route around Save Products
- **Fix:** Added Prepare Save Products code node to set skipped flag and Has Products? IF node to route around Save Products
- **Files modified:** workflows/01-icp-analyzer.json
- **Verification:** Both paths (with/without products) reconnect at Prepare Research 1
- **Committed in:** 4ff6a24

**2. [Rule 2 - Missing Critical] Added error handling with callback on failure**
- **Found during:** Task 1
- **Issue:** Plan specified error handling but didn't detail node structure. Added Handle Error -> Has Callback URL? -> Error Callback -> Respond Error path
- **Fix:** Created 4 error handling nodes (Handle Error code node, Has Callback URL? IF, Error Callback HTTP, Respond Error webhook response)
- **Files modified:** workflows/01-icp-analyzer.json
- **Verification:** Error path calls orchestrator callback with status=error before responding 500
- **Committed in:** 4ff6a24

---

**Total deviations:** 2 auto-fixed (2 missing critical)
**Impact on plan:** Both additions are correctness requirements from the plan's error handling and empty-array specifications. No scope creep.

## Issues Encountered

None

## User Setup Required

The updated workflow JSON must be imported to n8n Cloud. This will be handled during 06-06 (E2E verification plan).

## Next Phase Readiness
- ICP Analyzer now produces enriched ICP data in Supabase icps table (content_pillars, pain_points, etc.)
- Products stored in products table per-tenant with clean delete-before-insert lifecycle
- Orchestrator callback integration complete (step=1 fires on both success and error)
- Ready for 06-03 (frontend products card) to display scraped products on Setup tab
- Ready for 06-04 (theme generator) which reads ICP + products from Supabase

---
*Phase: 06-content-pipeline*
*Completed: 2026-03-04*
