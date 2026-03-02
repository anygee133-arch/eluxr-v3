---
phase: 03-workflow-decomposition-backend-bug-fixes
plan: 01
subsystem: infra
tags: [supabase-rest-api, postrest, content-type, switch-node, pipe-07, campaign-themes, upsert, n8n-cloud]

# Dependency graph
requires:
  - phase: 01-security-hardening-database-foundation
    provides: "Supabase project, 10 tables with RLS, test accounts, dual-header auth pattern"
  - phase: 02-authentication
    provides: "Auth Validator sub-workflow, JWT delivery via Bearer header, user_id in pipeline"
provides:
  - "N8N_PLAN_TIER: Starter ($24/mo) with unlimited active workflows -- no upgrade needed"
  - "SUPABASE_CREDENTIAL_PATTERN: Authorization: Bearer SERVICE_ROLE_KEY + apikey: sb_publishable_9gnLO_J9HBxVta1f8Ecvxw_KO8huPYQ"
  - "SUPABASE_URL: https://llpnwaoxisfwptxvdfed.supabase.co/rest/v1/{table}"
  - "SUPABASE_UPSERT_PATTERN: POST /table?on_conflict=column with Prefer: resolution=merge-duplicates,return=representation"
  - "CONTENT_TYPE_VALUES: Claude generates Hook/Value/Proof/Carousel/Video/Engagement/Cliffhanger, normalize to text/image/video/carousel"
  - "PIPE_07_ROOT_CAUSE: Switch node notContains/exists rules cause non-exclusive routing, images never reach Output 1"
  - "THEME_INSERT_PATTERN: UPSERT campaign -> DELETE old themes -> batch INSERT themes -> update campaign status"
  - "CLAUDE_RESPONSE_FORMAT: content[0].text JSON array of 30 objects with day_number, date, content_type, platform, hook, etc."
affects:
  - "03-02 (Sub-workflows 01-05): Uses SUPABASE_CREDENTIAL_PATTERN, CONTENT_TYPE_VALUES, THEME_INSERT_PATTERN"
  - "03-03 (Sub-workflows 06-09): Uses SUPABASE_CREDENTIAL_PATTERN for all Supabase queries"
  - "03-04 (Sub-workflows 10-13): Uses SUPABASE_CREDENTIAL_PATTERN for all Supabase queries"
  - "03-05 (Router): Needs N8N_PLAN_TIER confirmation for unlimited active workflows"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Supabase REST API dual-header auth: Authorization + apikey for all operations"
    - "PostgREST UPSERT: POST with ?on_conflict=column and Prefer: resolution=merge-duplicates"
    - "PostgREST Prefer header: return=representation for getting row data back"
    - "Content type normalization: Claude free-text -> DB CHECK-compatible values via Code node"

key-files:
  created:
    - tests/supabase-api-test-results.md
    - tests/03-01-content-type-trace-and-campaign-design.md
  modified: []

key-decisions:
  - "n8n Cloud Starter plan supports unlimited active workflows -- no upgrade needed (Plan assumption was wrong)"
  - "UPSERT requires ?on_conflict=column query parameter -- without it, PostgREST returns 409 Conflict"
  - "Content type normalization must happen in Code node BEFORE Switch, not in Switch rules"
  - "Campaign/themes insert uses 5-step pattern: UPSERT campaign, DELETE old themes, prepare 4 weekly rows, batch INSERT, update status"
  - "Claude generates 7 content_type values that map to 4 DB values via normalization"
  - "themes table stores 4 weekly rows (not 30 daily rows) with content_types JSONB for daily details"

patterns-established:
  - "Supabase CRUD from n8n: dual-header auth + Prefer headers for all 5 operations"
  - "UPSERT requires on_conflict query parameter for PostgREST"
  - "content_type normalization: lowercase + map to text/image/video/carousel"
  - "Campaign/themes FK pattern: UPSERT parent, DELETE children, INSERT children batch"

# Metrics
duration: 17min
completed: 2026-03-02
---

# Phase 3 Plan 01: Prerequisites Summary

**Validated Supabase REST API 5-CRUD patterns with on_conflict UPSERT discovery, traced 7 Claude content_type values through pipeline to PIPE-07 Switch bug root cause, designed 5-step campaign/themes FK insert pattern**

## Performance

- **Duration:** 17 min
- **Started:** 2026-03-02T06:55:33Z
- **Completed:** 2026-03-02T07:12:34Z
- **Tasks:** 3 (1 checkpoint + 2 auto)
- **Files created:** 2

## Accomplishments

- Confirmed n8n Cloud Starter plan has unlimited active workflows (plan's assumption of 5-limit was incorrect)
- Validated all 5 Supabase REST CRUD operations (SELECT, INSERT, UPSERT, PATCH, DELETE) with live API calls
- Discovered critical UPSERT requirement: `?on_conflict=column` query parameter is mandatory for PostgREST
- Traced content_type values from Claude prompt through Parse & Split Theme Days to Switch node, documenting the full data flow
- Identified PIPE-07 root cause: Switch node rules use notContains/exists/contains operators that prevent mutual exclusivity
- Designed complete normalization map: 7 Claude values -> 4 DB-compatible values
- Designed 5-step campaign/themes FK insert pattern with delete-before-insert for re-generation safety

## Critical Results for Downstream Plans

### 1. N8N_PLAN_TIER

- **Plan:** Starter ($24/mo, billed monthly)
- **Active workflows:** Unlimited (all n8n Cloud plans)
- **Executions:** 2,500/month with unlimited steps
- **Concurrent executions:** 5
- **Impact:** No upgrade needed. The 14 sub-workflows can all be active simultaneously.
- **Runtime concern for Phase 4:** 2.5k executions/month and 5 concurrent limits may affect batch content generation. Not a blocker for Phase 3 workflow construction.

### 2. SUPABASE_CREDENTIAL_PATTERN

All Supabase REST API calls require TWO headers:

```
Authorization: Bearer <SERVICE_ROLE_KEY or USER_JWT>
apikey: sb_publishable_9gnLO_J9HBxVta1f8Ecvxw_KO8huPYQ
```

| Operation | Method | Extra Headers | Status Code |
|-----------|--------|---------------|-------------|
| SELECT | GET | (none) | 200 |
| INSERT | POST | Content-Type + Prefer: return=representation | 201 |
| UPSERT | POST | Content-Type + Prefer: resolution=merge-duplicates,return=representation | 200 |
| PATCH | PATCH | Content-Type + Prefer: return=representation | 200 |
| DELETE | DELETE | (none) | 204 |

**UPSERT CRITICAL:** Must include `?on_conflict=column` in the URL. Without it, PostgREST returns 409.

### 3. SUPABASE_URL

Base URL for all REST API calls:
```
https://llpnwaoxisfwptxvdfed.supabase.co/rest/v1/{table}
```

### 4. CONTENT_TYPE_VALUES

Claude generates 7 values that must be normalized before the Switch node:

| Claude Value | DB Value | Switch Route |
|-------------|----------|-------------|
| Hook | text | Text branch |
| Value | text | Text branch |
| Proof | text | Text branch |
| Carousel | carousel | Text branch (generation is text-based) |
| Video | video | Video branch |
| Engagement | text | Text branch |
| Cliffhanger | text | Text branch |

**Normalization code (before Switch):**
```javascript
const ct = (item.content_type || '').toLowerCase().trim();
item.original_content_type = item.content_type;
if (ct.includes('video') || ct.includes('reel')) item.content_type = 'video';
else if (ct.includes('carousel') || ct.includes('thread')) item.content_type = 'carousel';
else if (ct.includes('image')) item.content_type = 'image';
else item.content_type = 'text';
```

**PIPE-07 Root Cause:** Switch node uses `notContains "Video"` as first rule, which catches everything except Video items. Image items never reach the Image output (Output 1) because they match Rule 0 first.

**Fix:** Normalize content_type to lowercase before Switch, then use exact equality rules with fallback.

### 5. THEME_INSERT_PATTERN

Five-step pattern for campaign/themes Supabase insert:

```
1. UPSERT Campaign:     POST /campaigns?on_conflict=user_id,month
                         Prefer: resolution=merge-duplicates,return=representation
                         Body: { user_id, month, status: "generating" }
                         Returns: campaign row with id

2. Delete Old Themes:   DELETE /themes?campaign_id=eq.{campaign_id}
                         (clears previous themes for re-generation)

3. Prepare Theme Rows:  Code node maps 30 daily items -> 4 weekly theme rows
                         Each row has: user_id, campaign_id, week_number, theme_name,
                         theme_description, show_concept, hook, content_types (JSONB)

4. Batch INSERT Themes: POST /themes
                         Prefer: return=representation
                         Body: JSON array of 4 theme rows

5. Update Campaign:     PATCH /campaigns?id=eq.{campaign_id}
                         Body: { status: "active" }
```

**Claude Response Format:** `content[0].text` contains JSON array of 30 objects with: day_number, date, day_of_week, week_number, weekly_show_name, theme, content_type, platform, secondary_platform, hook, cta, hashtags, notes.

## Task Commits

Each task was committed atomically:

1. **Task 1: Verify n8n Cloud plan tier** - N/A (checkpoint, resolved by user)
   - Confirmed: Starter plan with unlimited active workflows
2. **Task 2: Validate Supabase REST API patterns** - `8ef67cc` (test)
   - All 5 CRUD operations tested against live Supabase
   - Discovered on_conflict requirement for UPSERT
3. **Task 3: Trace content_type values and design campaign/themes insert** - `d0f88b5` (docs)
   - 7 Claude content_type values traced through pipeline
   - PIPE-07 root cause documented
   - 5-step campaign/themes insert pattern designed

## Files Created/Modified

- `tests/supabase-api-test-results.md` - Complete REST API test results with all 5 CRUD operations, response formats, and n8n HTTP Request templates
- `tests/03-01-content-type-trace-and-campaign-design.md` - Full content_type data flow trace, normalization map, PIPE-07 analysis, and campaign/themes insert design

## Decisions Made

1. **n8n Cloud Starter sufficient:** The plan assumed Starter = 5 active workflows. Testing showed all n8n Cloud plans have unlimited active workflows. No upgrade needed for 14 sub-workflows.

2. **UPSERT requires on_conflict parameter:** PostgREST does not auto-detect UNIQUE constraints. The `?on_conflict=column` query parameter must be explicitly specified. For composite keys: `?on_conflict=user_id,month`.

3. **Content type normalization before Switch:** Rather than complex Switch rules, normalize content_type to lowercase DB values in a Code node before the Switch. This makes Switch rules simple exact-equality checks.

4. **Themes stored as 4 weekly rows, not 30 daily rows:** The themes table represents weekly "shows" with a `content_types` JSONB column containing the daily content details. This matches the Netflix Model (4 weekly shows per month).

5. **Delete-before-insert for theme re-generation:** When a user re-generates themes for the same month, the campaign UPSERT updates the existing campaign, but old themes persist. DELETE old themes before INSERT new ones prevents duplicates.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] UPSERT pattern incorrect in plan**
- **Found during:** Task 2 (testing)
- **Issue:** Plan specified UPSERT with only `Prefer: resolution=merge-duplicates` header. PostgREST actually requires `?on_conflict=column` query parameter to specify which UNIQUE constraint to use.
- **Fix:** Added `?on_conflict=user_id` to UPSERT URL. Documented the pattern for all tables.
- **Files modified:** tests/supabase-api-test-results.md
- **Verification:** UPSERT returns 200 with updated row (without on_conflict, returns 409)
- **Committed in:** 8ef67cc

---

**Total deviations:** 1 auto-fixed (1 bug in planned UPSERT pattern)
**Impact on plan:** Critical finding -- without this fix, every UPSERT in Plans 02-04 would fail with 409.

## Issues Encountered

1. **Service role key not available in environment:** The Supabase service_role key is stored only in the n8n cloud credential store, not in any local file or environment variable. Tests were run using an authenticated user JWT instead, which validates the same REST API patterns (URL format, Prefer headers, response structure). The dual-header pattern with service_role was previously confirmed in Phase 1 tenant isolation testing.

2. **Supabase CLI not authenticated:** The `supabase` CLI could not retrieve project API keys because no access token was configured. This didn't block testing since the publishable key and user JWT authentication path was sufficient for validating all 5 CRUD patterns.

## User Setup Required

None - no external service configuration required for this plan.

## Next Phase Readiness

- **Ready for 03-02:** All 5 CRUD patterns validated, content_type values documented, campaign/themes insert designed. Plan 02 can build sub-workflows 01-05.
- **Ready for 03-03 through 03-06:** SUPABASE_CREDENTIAL_PATTERN and SUPABASE_URL confirmed for all downstream plans.
- **No blockers** for continuing Phase 3.
- **Runtime concern (Phase 4):** 2.5k executions/month on Starter plan may need monitoring during batch content generation. Not a Phase 3 blocker.

---
*Phase: 03-workflow-decomposition-backend-bug-fixes*
*Completed: 2026-03-02*
