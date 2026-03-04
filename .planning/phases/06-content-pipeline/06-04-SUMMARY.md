---
phase: 06-content-pipeline
plan: 04
subsystem: api, ai
tags: [n8n, claude, supabase, netflix-model, theme-generation, product-assignment, webhook-callback]

# Dependency graph
requires:
  - phase: 06-content-pipeline
    provides: products table with RLS, enriched ICP columns, orchestrator callback pattern
  - phase: 06-content-pipeline
    provides: ICP Analyzer writing enriched ICP + products to Supabase
provides:
  - Netflix model theme generation with AI show name, 4 seasons, progressive arc
  - Product-per-day assignment across 28 days with theme coherence clustering
  - Campaign UPSERT with show_name column populated
  - 4 theme rows with season_arc, inspirational_theme, and daily product assignments in content_types JSONB
  - Orchestrator callback integration (step=2 complete/error)
affects: [06-05-content-studio, 06-06-verification]

# Tech tracking
tech-stack:
  added: []
  patterns: [netflix-model-prompt-engineering, product-rotation-assignment, extract-params-code-node]

key-files:
  created: []
  modified:
    - workflows/02-theme-generator.json

key-decisions:
  - "Extract Params code node added to cleanly separate auth data from pipeline params"
  - "Extract Campaign ID code node added between UPSERT and Delete to safely handle array response"
  - "Error handling path mirrors 01-ICP-Analyzer pattern: Handle Error -> Has Callback URL? -> Error Callback -> Respond Error"

patterns-established:
  - "Netflix model prompt: show_name + 4 seasons with progressive arc (intro/deepen/challenge/celebrate)"
  - "Product rotation: fewer than 30 repeat evenly, more than 30 Claude selects top 30 by ICP relevance"
  - "Daily assignment: each day gets 1 product_id + product_name + topic + content_angle"

requirements-completed: [PIPE-02]

# Metrics
duration: 3min
completed: 2026-03-04
---

# Phase 6 Plan 04: Theme Generator Overhaul Summary

**Netflix model theme generation with AI show name, 4-season progressive arc, and per-day product + topic assignment via Claude, stored in Supabase with orchestrator callback**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-04T03:53:07Z
- **Completed:** 2026-03-04T03:56:07Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- Overhauled 02-Theme-Generator from 12-node generic theme workflow to 23-node Netflix model pipeline
- Reads enriched ICP (content_pillars, pain_points, desires) and active products from Supabase
- Claude generates creative show name, show concept, 4 seasons with progressive arc (intro/deepen/challenge/celebrate)
- Each of 28 days assigned 1 product (by UUID) + 1 inspirational topic + content angle
- Campaign UPSERT stores show_name; 4 theme rows store season_arc, inspirational_theme, and daily assignments in content_types JSONB
- Orchestrator callback fires with step=2 on success or error

## Task Commits

Each task was committed atomically:

1. **Task 1: Build Netflix model theme generation with product assignment** - `4bb4deb` (feat)

## Files Created/Modified
- `workflows/02-theme-generator.json` - Complete overhaul from 12 to 23 nodes: Auth chain preserved, Extract Params, Read ICP, Read Products, Prepare Theme Prompt (comprehensive Netflix model instructions), Generate Themes (Claude), Parse Theme Response (robust JSON parsing with validation), UPSERT Campaign (with show_name), Extract Campaign ID, Delete Old Themes, Prepare Theme Rows (4 rows with season_arc/inspirational_theme/content_types JSONB), Insert Themes, Update Campaign Status, Prepare Callback, Callback to Orchestrator (step=2), Respond Success, plus 4-node error handling path

## Decisions Made
- **Extract Params code node before Read ICP:** Cleanly separates auth data (user_id from Auth Validator) from pipeline params (month, industry, pipeline_run_id, callback_url from body). Prevents downstream nodes from needing complex nested references.
- **Extract Campaign ID code node after UPSERT:** PostgREST UPSERT returns array; dedicated Code node safely extracts campaign_id and carries forward all context. Prevents fragile inline expressions.
- **Error handling mirrors 01-ICP-Analyzer pattern:** Same 4-node error path (Handle Error -> Has Callback URL? -> Error Callback -> Respond Error) ensures consistent failure behavior across pipeline sub-workflows.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Added Extract Params node**
- **Found during:** Task 1
- **Issue:** Plan did not specify a parameter extraction node between Auth OK? and Read ICP. Without it, downstream nodes would need complex nested references like `$('Auth OK?').item.json.body.month`.
- **Fix:** Added Extract Params code node that cleanly extracts user_id, month, industry, platforms, pipeline_run_id, and callback_url into a flat object.
- **Files modified:** workflows/02-theme-generator.json
- **Committed in:** 4bb4deb

**2. [Rule 2 - Missing Critical] Added Extract Campaign ID node**
- **Found during:** Task 1
- **Issue:** Plan specified UPSERT Campaign followed directly by Delete Old Themes, but PostgREST UPSERT returns an array. A Code node is needed to safely extract campaign_id and carry all theme data forward.
- **Fix:** Added Extract Campaign ID code node between UPSERT Campaign and Delete Old Themes.
- **Files modified:** workflows/02-theme-generator.json
- **Committed in:** 4bb4deb

**3. [Rule 2 - Missing Critical] Added error handling path**
- **Found during:** Task 1
- **Issue:** Plan mentioned error handling ("If Claude returns unparseable JSON... callback with status: error") but did not detail node structure. Without it, failures would leave pipeline_run stuck in "running" state.
- **Fix:** Added 4-node error path: Handle Error (recovers pipeline_run_id/callback_url), Has Callback URL? (IF), Error Callback (POST with error status), Respond Error (500).
- **Files modified:** workflows/02-theme-generator.json
- **Committed in:** 4bb4deb

---

**Total deviations:** 3 auto-fixed (3 missing critical)
**Impact on plan:** All additions are correctness requirements implicit in the plan's specifications. No scope creep.

## Issues Encountered

None

## User Setup Required

The updated workflow JSON must be imported to n8n Cloud. This will be handled during 06-06 (E2E verification plan).

## Next Phase Readiness
- Theme Generator now produces Netflix model campaign data in Supabase
- Campaign has show_name for frontend display
- 4 theme rows have season_arc, inspirational_theme, and content_types JSONB with daily product assignments
- Content Studio (06-05) can read themes + products for per-day content generation
- Orchestrator receives step=2 callback to trigger next pipeline stage

---
*Phase: 06-content-pipeline*
*Completed: 2026-03-04*
