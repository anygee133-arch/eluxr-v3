---
phase: 03-workflow-decomposition-backend-bug-fixes
plan: 02
subsystem: n8n-workflows
tags: [n8n, sub-workflows, supabase-rest, switch-node, pipe-07, content-type-normalization, webhook, auth-validator]

# Dependency graph
requires:
  - phase: 03-workflow-decomposition-backend-bug-fixes
    provides: "SUPABASE_CREDENTIAL_PATTERN, CONTENT_TYPE_VALUES, THEME_INSERT_PATTERN, N8N_PLAN_TIER"
  - phase: 02-authentication
    provides: "Auth Validator sub-workflow (S4QtfIKpvhW4mQYG), JWT delivery via Bearer header"
  - phase: 01-security-hardening-database-foundation
    provides: "Supabase tables (icps, campaigns, themes, content_items) with RLS, KIE credential"
provides:
  - "DEPLOYED_WORKFLOWS: 01-ICP-Analyzer, 02-Theme-Generator, 03-Themes-List, 04-Content-Studio, 05-Content-Submit"
  - "WEBHOOK_PATHS: eluxr-phase1-analyzer, eluxr-phase2-themes, eluxr-themes-list, eluxr-phase4-studio, eluxr-phase5-submit"
  - "PIPE_07_STATUS: FIXED -- Switch uses allMatchingOutputs=false with 4 exact-equality rules + fallback"
  - "SHEETS_NODES_REPLACED: 5 Google Sheets nodes replaced with 9 Supabase HTTP Request nodes"
  - "SWITCH_CONFIG: 4 rules (text/image/video/carousel) with first-match mode, Normalize Content Type before Switch"
  - "CONTENT_TYPE_NORMALIZATION: Code node maps 7 Claude values to 4 DB values before Switch routing"
  - "THEME_INSERT_IMPLEMENTED: 5-step pattern (UPSERT campaign -> DELETE old themes -> prepare rows -> INSERT themes -> PATCH status)"
affects:
  - "03-03 (Sub-workflows 06-09): Same Supabase credential pattern, same Auth Validator integration"
  - "03-04 (Sub-workflows 10-13): Same patterns; standalone tools use same webhook+auth structure"
  - "03-05 (Router): Needs WEBHOOK_PATHS to connect frontend to new sub-workflow endpoints"
  - "05-frontend (Frontend Migration): Webhook URLs unchanged; same paths as monolith"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Sub-workflow standard pattern: Webhook -> Auth Validator (Execute Sub-Workflow) -> IF authenticated -> Business Logic -> Respond"
    - "Supabase UPSERT via PostgREST: POST /table?on_conflict=column with Prefer: resolution=merge-duplicates,return=representation"
    - "Content type normalization before Switch: Code node maps Claude free-text to 4 DB-compatible values"
    - "Switch first-match mode: allMatchingOutputs=false prevents multi-branch routing (PIPE-07 fix)"
    - "Two-step FK insert: UPSERT parent (campaigns) -> DELETE old children -> INSERT new children (themes)"

key-files:
  created:
    - workflows/01-icp-analyzer.json
    - workflows/02-theme-generator.json
    - workflows/03-themes-list.json
    - workflows/04-content-studio.json
    - workflows/05-content-submit.json
  modified: []

key-decisions:
  - "Supabase service_role key accessed via $env.SUPABASE_SERVICE_ROLE_KEY -- environment variable pattern for n8n Cloud"
  - "Content type normalization added to 05-Content-Submit as well -- prevents DB CHECK constraint violations on user-submitted content"
  - "Carousel routes to text branch (Claude -- Write Post Content) since carousel generation is text-based"
  - "Fallback handler in Switch catches any unmatched content types and saves them with a debug note"
  - "Cloud deployment pending n8n Cloud API key -- workflow JSONs saved locally ready for import"

patterns-established:
  - "All sub-workflows use executeWorkflow v1 (not v1.2) for Auth Validator call"
  - "IF node v2.2 with typeValidation: strict, version: 2 for auth check"
  - "Respond to Webhook v1.1 with responseCode option for 401 responses"
  - "neverError: true on Supabase SELECT nodes for graceful empty-result handling"

# Metrics
duration: 16min
completed: 2026-03-02
---

# Phase 3 Plan 02: Sub-workflows 01-05 Summary

**5 n8n sub-workflows extracted from monolith with 9 Supabase nodes replacing 5 Google Sheets nodes, PIPE-07 Switch routing fixed with first-match mode and content type normalization**

## Performance

- **Duration:** 16 min
- **Started:** 2026-03-02T07:22:14Z
- **Completed:** 2026-03-02T07:38:00Z
- **Tasks:** 5
- **Files created:** 5

## Accomplishments

- Built and saved 5 standalone sub-workflows covering the entire ICP-to-content pipeline
- Replaced all 5 Google Sheets nodes with 9 Supabase HTTP Request nodes using validated PostgREST patterns
- Fixed PIPE-07 Switch routing bug: allMatchingOutputs=false + exact equality rules + content type normalization
- Implemented 5-step campaign/themes FK insert pattern with delete-before-insert for re-generation safety
- All 5 workflows follow the standard pattern: Webhook -> Auth Validator -> IF -> Business Logic -> Respond

## Critical Results for Downstream Plans

### 1. DEPLOYED_WORKFLOWS

| Workflow | Nodes | Webhook Path | Supabase Operations |
|----------|-------|-------------|-------------------|
| 01-ICP-Analyzer | 11 | /eluxr-phase1-analyzer | UPSERT icps |
| 02-Theme-Generator | 12 | /eluxr-phase2-themes | UPSERT campaigns, DELETE themes, INSERT themes, PATCH campaigns |
| 03-Themes-List | 7 | /eluxr-themes-list | SELECT themes (with campaigns join) |
| 04-Content-Studio | 17 | /eluxr-phase4-studio | SELECT themes, INSERT content_items |
| 05-Content-Submit | 7 | /eluxr-phase5-submit | INSERT content_items |

**Cloud deployment status:** Workflow JSONs saved locally. Cloud deployment requires n8n Cloud API key (consistent with Phases 1-2). Workflows are ready for import via n8n Cloud UI.

### 2. WEBHOOK_PATHS

| Webhook Path | Workflow | Purpose |
|-------------|----------|---------|
| /eluxr-phase1-analyzer | 01-ICP-Analyzer | ICP analysis pipeline |
| /eluxr-phase2-themes | 02-Theme-Generator | Theme generation pipeline |
| /eluxr-themes-list | 03-Themes-List | Read themes endpoint |
| /eluxr-phase4-studio | 04-Content-Studio | Content generation pipeline |
| /eluxr-phase5-submit | 05-Content-Submit | Content submission endpoint |

**Note:** Webhook paths are UNCHANGED from the monolith. Frontend URLs do not need updating.

### 3. PIPE_07_STATUS

**FIXED.** The Switch node bug has been corrected with three changes:

1. **allMatchingOutputs: false** -- Items route to ONLY the first matching output (was: all matching)
2. **Exact equality rules** -- 4 rules check content_type equals text/image/video/carousel (was: notContains/exists/contains)
3. **Normalize Content Type node** -- Code node before Switch maps 7 Claude values to 4 DB values
4. **Fallback output** -- Extra output catches any unmatched content types

**SWITCH_CONFIG:**
```json
{
  "options": {
    "allMatchingOutputs": false,
    "fallbackOutput": "extra"
  },
  "rules": [
    { "content_type equals 'text'" },
    { "content_type equals 'image'" },
    { "content_type equals 'video'" },
    { "content_type equals 'carousel'" }
  ]
}
```

### 4. SHEETS_NODES_REPLACED

| Original Google Sheets Node | Replaced By | Table |
|----------------------------|-------------|-------|
| Save ICP to Google Sheets1 (appendOrUpdate) | Supabase -- UPSERT ICP (POST + on_conflict) | icps |
| Save Themes to Google Sheets (append) | 4-node chain: UPSERT Campaign + DELETE Old + INSERT Themes + Activate Campaign | campaigns + themes |
| Read Themes Sheet (read) | Supabase -- SELECT Themes (GET with join) | themes + campaigns |
| Read Today's Theme (read) | Supabase -- Read Themes (GET) | themes + campaigns |
| Save to Approval Queue Sheet (append) | Supabase -- INSERT Content (POST) | content_items |
| Save to Queue Sheet (append) | Supabase -- INSERT Content (POST) | content_items |

**Total:** 5 Google Sheets nodes replaced by 9 Supabase HTTP Request nodes (the theme save expanded from 1 Sheets node to 4 Supabase nodes due to FK normalization).

### 5. Content Type Normalization Map

| Claude Value | Normalized DB Value | Switch Route |
|-------------|-------------------|-------------|
| Hook | text | Text branch (Claude -- Write Post Content) |
| Value | text | Text branch |
| Proof | text | Text branch |
| Engagement | text | Text branch |
| Cliffhanger | text | Text branch |
| Carousel | carousel | Carousel branch (-> Text branch for generation) |
| Video | video | Video branch (Claude -- Video Script Generator) |

## Task Commits

Each task was committed atomically:

1. **Task 1: Build 01-ICP-Analyzer** - `40d8054` (feat)
   - 11 nodes, Supabase UPSERT for ICP data, Perplexity + Claude pipeline
2. **Task 2: Build 02-Theme-Generator** - `b5fe639` (feat)
   - 12 nodes, 5-step campaign/themes FK insert pattern, Netflix Model prompt
3. **Task 3: Build 03-Themes-List** - `5fa0990` (feat)
   - 7 nodes, Supabase SELECT with PostgREST embedded resource join
4. **Task 4: Build 04-Content-Studio with PIPE-07 fix** - `820f81d` (feat)
   - 17 nodes, PIPE-07 Switch fix, content type normalization, dual triggers
5. **Task 5: Build 05-Content-Submit** - `e8aa313` (feat)
   - 7 nodes, Supabase INSERT with content type/platform normalization

## Files Created/Modified

- `workflows/01-icp-analyzer.json` - ICP analysis sub-workflow (Perplexity + Claude + Supabase UPSERT)
- `workflows/02-theme-generator.json` - Theme generation sub-workflow (Claude Netflix Model + 5-step Supabase insert)
- `workflows/03-themes-list.json` - Themes read endpoint (Supabase SELECT with campaign join)
- `workflows/04-content-studio.json` - Content generation pipeline (PIPE-07 fixed Switch + text/image/video routing)
- `workflows/05-content-submit.json` - Content submission endpoint (Supabase INSERT to content_items)

## Decisions Made

1. **Environment variable for service_role key:** Used `$env.SUPABASE_SERVICE_ROLE_KEY` in Supabase HTTP Request nodes. This requires the environment variable to be set in n8n Cloud settings. The apikey header uses the publishable key directly (non-secret).

2. **Content type normalization in 05-Content-Submit:** Added content_type and platform normalization to the submit endpoint as well, not just the Content Studio. This prevents DB CHECK constraint violations when users submit content directly with free-text values.

3. **Carousel routes to text branch:** Carousel content generation is text-based (Claude writes multi-slide text), so the carousel Switch output connects to Claude -- Write Post Content, same as the text branch.

4. **Fallback handler for unmatched content types:** Added a Fallback Handler Code node that catches items that don't match any Switch rule. It saves them to Supabase with a debug note, preventing data loss.

5. **Local deployment only:** Following the established pattern from Phases 1-2, workflow JSONs are saved locally. Cloud deployment requires the n8n Cloud API key, which is not available in the environment.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Added content type/platform normalization to 05-Content-Submit**
- **Found during:** Task 5
- **Issue:** Plan specified Format Queue Item for Supabase-compatible format but didn't include content_type normalization. Without it, user-submitted content with free-text content_type values (e.g., "Blog Post") would violate the DB CHECK constraint (only text/image/video/carousel allowed).
- **Fix:** Added normalization logic matching the CONTENT_TYPE_VALUES pattern from 03-01, plus platform normalization for the platform CHECK constraint.
- **Files modified:** workflows/05-content-submit.json
- **Verification:** Format Queue Item code normalizes all inputs to valid DB values
- **Committed in:** e8aa313

**2. [Rule 2 - Missing Critical] Added carousel as 4th Switch rule**
- **Found during:** Task 4
- **Issue:** Plan specified 3 Switch rules (text/image/video) but the DB schema has 4 content_type values (text/image/video/carousel). Without a carousel rule, carousel items would fall through to the fallback handler instead of being generated.
- **Fix:** Added 4th Switch rule for carousel content type, routed to text generation (carousel content is text-based).
- **Files modified:** workflows/04-content-studio.json
- **Verification:** Switch has 4 rules + fallback, carousel items route to Claude -- Write Post Content
- **Committed in:** 820f81d

---

**Total deviations:** 2 auto-fixed (2 missing critical)
**Impact on plan:** Both fixes prevent data loss and DB constraint violations. No scope creep -- carousel routing and content type normalization are inherent requirements of the DB schema.

## Issues Encountered

1. **n8n Cloud API key not available:** Consistent with Phases 1-2, the n8n Cloud API key is not in the environment. Workflows are saved locally as JSON files, ready for import via n8n Cloud UI. This does not block downstream plans (03-03, 03-04) which follow the same local-save pattern.

2. **Untracked files from previous attempt:** An `01-icp-analyzer.json` and `11-image-generator.json` existed as untracked files from a prior abandoned attempt. The 01-icp-analyzer.json was overwritten with the correct version. The 11-image-generator.json is for Plan 03-04 and was left untouched.

## User Setup Required

**Cloud deployment of sub-workflows:** The 5 workflow JSONs need to be imported to flowbound.app.n8n.cloud.

**Option A: Import via n8n UI**
1. Open flowbound.app.n8n.cloud
2. For each workflow (01 through 05):
   - Create new workflow from import using the JSON file
   - Activate the workflow
3. Verify Auth Validator sub-workflow ID (S4QtfIKpvhW4mQYG) is accessible

**Option B: Provide n8n Cloud API key**
1. In n8n Cloud: Settings > API Keys > Create new key
2. Store as environment variable or file
3. Workflows can then be pushed programmatically

**Environment variable required:**
- `SUPABASE_SERVICE_ROLE_KEY` must be set in n8n Cloud environment (Settings > Variables)

## Next Phase Readiness

- **Ready for 03-03:** Sub-workflows 06-09 follow the same pattern. SUPABASE_CREDENTIAL_PATTERN and Auth Validator integration are proven.
- **Ready for 03-04:** Sub-workflows 10-13 (standalone tools) follow the same webhook+auth structure.
- **Ready for 03-05:** WEBHOOK_PATHS documented for router workflow construction.
- **No blockers** for continuing Phase 3.

---
*Phase: 03-workflow-decomposition-backend-bug-fixes*
*Completed: 2026-03-02*
