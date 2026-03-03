---
phase: 05-frontend-migration-ui-polish
plan: 02
subsystem: frontend-data-layer
tags: [supabase, data-migration, localStorage-removal, mapContentItem, profiles, content-items, themes]

# Dependency graph
requires:
  - phase: 05-frontend-migration-ui-polish
    plan: 01
    provides: "config.js with ELUXR_CONFIG, CSS animations, deployment files"
  - phase: 01-security-db-foundation
    provides: "Supabase tables (content_items, themes, profiles, pipeline_runs) with RLS"
  - phase: 02-authentication
    provides: "supabase-js auth, authenticatedFetch wrapper, module/window pattern"
provides:
  - "mapContentItem() normalizer bridging DB schema to frontend field format"
  - "fetchCalendarData() queries Supabase content_items directly (not n8n webhook)"
  - "loadScheduleThemes() queries Supabase themes directly (not n8n webhook)"
  - "loadUserProfile() loads business profile from Supabase profiles on login"
  - "handleFormSubmit() saves business profile to Supabase profiles via upsert"
  - "showCalendarEmptyState() for zero-content display"
  - "Zero localStorage for session/content/business/pipeline data"
  - "Approval functions re-fetch from Supabase after webhook success"
affects: [05-03-plan, 05-04-plan, 06-content-pipeline, 07-approval-queue]

# Tech tracking
tech-stack:
  added: []
  patterns: [supabase-direct-query, data-normalizer-pattern, re-fetch-after-mutation]

key-files:
  created: []
  modified:
    - "index.html"

key-decisions:
  - "mapContentItem normalizes pending_review->pending status for all frontend rendering"
  - "fetchCalendarData returns {all, approved, pending, rejected} structure from Supabase query"
  - "Approval/reject/batch functions re-fetch from Supabase after webhook success (not local state mutation)"
  - "Business profile saved to Supabase profiles table on form submit (replaces localStorage)"
  - "Profile loaded from Supabase on SIGNED_IN event (replaces localStorage resume)"
  - "checkActivePipeline uses in-memory currentPipelineRunId only (no localStorage)"
  - "loadScheduleThemes fetches themes with campaign month join"

patterns-established:
  - "mapContentItem() as the single normalizer between DB rows and frontend objects"
  - "Re-fetch from Supabase after mutations instead of local state updates"
  - "showCalendarEmptyState() for empty content display"

# Metrics
duration: 6min
completed: 2026-03-03
---

# Plan 02: Supabase Data Layer Migration Summary

**Replaced all localStorage, saveSession, generateMockData, and n8n webhook data fetches with direct Supabase queries via supabase-js; mapContentItem() normalizer bridges DB schema to frontend rendering expectations**

## Performance

- **Duration:** 6 min
- **Started:** 2026-03-03T05:37:55Z
- **Completed:** 2026-03-03T05:44:10Z

## Task Results

| # | Task | Commit | Key Files |
|---|------|--------|-----------|
| 1 | Create mapContentItem normalizer and replace data fetching with Supabase | 73a4fd2 | index.html |
| 2 | Remove all saveSession, localStorage, and generateMockData | f070962 | index.html |

## What Was Built

### Task 1: Data Normalizer + Supabase Queries

- **mapContentItem()**: Normalizes Supabase `content_items` rows to frontend format:
  - `scheduled_date` -> `date`
  - `pending_review` -> `pending` (status mapping)
  - Joins `themes.name` for theme display
  - Extracts hashtags from content text via regex
  - Maps all 17 DB fields to frontend-expected properties
- **fetchCalendarData()**: Replaced n8n webhook call with `window.supabase.from('content_items').select('*, themes(name)')`, returns `{all, approved, pending, rejected}`
- **loadScheduleThemes()**: Replaced n8n webhook call with `window.supabase.from('themes').select('*, campaigns(month)')`, populates `weeklyThemes` array
- **showCalendarEmptyState()**: Renders "No content generated yet" with Setup tab CTA when content_items query returns empty
- **loadUserProfile()**: Loads `business_url` and `industry` from Supabase `profiles` table, pre-fills form inputs
- **SIGNED_IN handler**: Now calls `loadUserProfile()` after login

### Task 2: Comprehensive Cleanup

- **saveSession()**: Function deleted entirely; all 11 call sites removed
- **generateMockData()**: Function deleted entirely (44 lines); fallback in fetchAndDisplayCalendar replaced with `showCalendarEmptyState()`
- **localStorage removed**: All reads/writes eliminated:
  - `eluxr_current_session` (session resume dialog)
  - `eluxr_business_context` (business profile persistence)
  - `eluxr_active_pipeline_run` (pipeline run tracking)
- **handleFormSubmit()**: Now upserts business profile to Supabase `profiles` table
- **Approval functions** (approveContent, rejectContent, approveSelected): Now re-fetch from Supabase after webhook success instead of mutating local state
- **clearPendingContent()**: Re-fetches from Supabase after clearing
- **startOver()**: Resets in-memory state only, no localStorage
- **Google Sheets references**: All comment references updated to Supabase

## Deviations from Plan

None -- plan executed exactly as written.

## Must-Haves Verification

| Must-Have | Status |
|-----------|--------|
| fetchCalendarData() queries supabase.from('content_items') | PASS |
| loadScheduleThemes() queries supabase.from('themes') | PASS |
| No calls to saveSession() exist | PASS (0 occurrences) |
| No calls to generateMockData() exist | PASS (0 occurrences) |
| No localStorage eluxr_current_session | PASS (0 occurrences) |
| No localStorage eluxr_business_context | PASS (0 occurrences) |
| mapContentItem() normalizes DB rows to frontend format | PASS (3 occurrences) |
| Calendar shows "No content generated yet" empty state | PASS (2 occurrences) |
| Business profile loads from supabase.from('profiles') on login | PASS (2 occurrences: load + upsert) |

## Next Plan Readiness

Plan 05-03 can proceed. The data layer is fully migrated to Supabase. All rendering functions continue to work because mapContentItem() translates DB field names. The authenticatedFetch() wrapper is preserved for approval POST/PUT operations and tool functions (video script, image gen, etc.).
