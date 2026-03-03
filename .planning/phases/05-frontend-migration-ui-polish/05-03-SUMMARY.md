---
phase: 05-frontend-migration-ui-polish
plan: 03
subsystem: frontend-icp-display
tags: [icp, supabase, icps-table, glassmorphism, skeleton-loading, pipeline-integration]

# Dependency graph
requires:
  - phase: 05-frontend-migration-ui-polish
    plan: 01
    provides: "skeleton-line CSS classes, card-glass glassmorphism, fade-in-up animations"
  - phase: 05-frontend-migration-ui-polish
    plan: 02
    provides: "loadUserProfile pattern, window.supabase, SIGNED_IN handler integrations"
  - phase: 04-progress-tracking
    provides: "renderProgress() for Realtime pipeline updates, subscribeToProgress()"
  - phase: 01-security-db-foundation
    provides: "Supabase icps table with RLS policies"
provides:
  - "loadICP() fetches ICP data from Supabase icps table on login"
  - "renderICPCard() displays structured ICP sections (summary, audience, pain points, messaging, hashtags)"
  - "showICPSkeleton() displays loading animation during pipeline ICP analysis"
  - "ICP card auto-refreshes when pipeline step 1 (ICP analysis) completes"
  - "Hashtags rendered as green pill badges"
  - "Graceful degradation: JSONB fields hidden when null, falls back to icp_summary text"
  - "escapeHTML() utility function for safe text rendering"
affects: [05-04-plan, 06-content-pipeline]

# Tech tracking
tech-stack:
  added: []
  patterns: [supabase-single-query, skeleton-loading, graceful-jsonb-degradation, pipeline-step-integration]

# File tracking
key-files:
  created: []
  modified:
    - path: index.html
      changes: "ICP card HTML + CSS + JavaScript (loadICP, renderICPCard, showICPSkeleton, escapeHTML)"

# Decisions
decisions:
  - id: icp-card-placement
    choice: "ICP card placed between business form and chatbox on Setup tab"
    rationale: "Natural position -- user sees their profile after entering business info, before chat"
  - id: icp-skeleton-trigger
    choice: "Skeleton shown at pipeline step 0, ICP loaded at step >= 2"
    rationale: "Step 1 is ICP analysis; when current_step reaches 2, step 1 is confirmed complete"
  - id: escapehtml-utility
    choice: "Added escapeHTML() using DOM createElement pattern"
    rationale: "No existing escapeHTML in codebase; needed for safe rendering of ICP text from Supabase"
  - id: pgrst116-handling
    choice: "PGRST116 error code silently ignored (means no row found)"
    rationale: "Expected state when user hasn't run pipeline yet; card stays hidden"

# Metrics
metrics:
  duration: "~3 minutes"
  completed: "2026-03-03"
  tasks: 2
  commits: 2
---

# Phase 5 Plan 03: ICP Card Display Summary

**ICP card on Setup tab loads from Supabase icps table, displays structured sections with skeleton loading, refreshes after pipeline step 1, gracefully degrades when JSONB fields are null.**

## What Was Done

### Task 1: ICP Card HTML Structure and CSS Styles
**Commit:** `6337830`

Added the ICP card HTML to the Setup tab (phase-1 section) between the business form and the chatbox. The card uses `card-glass` glassmorphism styling and includes:
- Header with green dot icon, "Your Business Profile" title, and "Last analyzed" timestamp
- Skeleton loading section with 5 pulsing placeholder lines (using existing `skeleton-line` class from 05-01)
- Content sections: Summary, Target Audience, Pain Points, Content Opportunities, Recommended Hashtags
- Each section hidden by default (`display: none`) -- shown only when data exists

Added ICP-specific CSS:
- `.icp-section` with subtle bottom borders and spacing
- `.icp-section-label` in green uppercase with letter spacing
- `.icp-section-value` for readable text content with list support

### Task 2: ICP JavaScript -- Load, Render, Pipeline Integration
**Commit:** `173b88e`

Added complete JavaScript implementation:

**Core Functions:**
- `loadICP()` -- Fetches from `window.supabase.from('icps').select('*').single()`, handles PGRST116 (no row), shows/hides card
- `showICPSkeleton()` -- Displays skeleton loading state (card visible, skeleton visible, content hidden)
- `renderICPCard(icp)` -- Populates all sections from ICP data, handles JSONB objects/arrays/strings
- `renderICPSection()` -- Generic renderer for JSONB fields with type detection (string/array/object)
- `formatICPText()` -- HTML-escapes text and converts newlines to `<br>`
- `escapeHTML()` -- DOM-based HTML escape utility (was missing from codebase)

**Hashtag Rendering:** Hashtags rendered as inline pill badges with green background (`rgba(22,163,74,0.15)`) and rounded corners. Handles both array and object hashtag formats.

**Integration Points:**
1. **SIGNED_IN handler:** `if (window.loadICP) window.loadICP()` -- loads existing ICP on login
2. **renderProgress() step 0:** Shows skeleton and resets `icpLoaded` flag when pipeline starts
3. **renderProgress() step >= 2:** Refreshes ICP when step 1 (ICP analysis) is confirmed complete

**Graceful Degradation:**
- Card hidden when no ICP exists (PGRST116 = no rows)
- JSONB sections individually hidden when null/undefined
- Falls back to `icp_summary` text if structured fields are empty
- Error logging without breaking the page

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Added escapeHTML() utility function**
- **Found during:** Task 2
- **Issue:** Plan noted to "check if escapeHTML already exists" -- it did not exist anywhere in the codebase
- **Fix:** Added `escapeHTML()` using the DOM `createElement/createTextNode` pattern for reliable HTML escaping
- **Files modified:** index.html
- **Commit:** 173b88e

## Verification Results

All plan verification criteria met:
- `icp-card` references: 3 (>= 2)
- `icp-section-label` references: 6 (>= 2)
- `icp-skeleton` references: 3 (>= 1)
- `icp-content` references: 3 (>= 1)
- `loadICP` references: 6 (>= 4)
- `renderICPCard` references: 2 (>= 2)
- `from('icps')` references: 1 (>= 1)
- `showICPSkeleton` references: 4 (>= 2)
- `icp-last-analyzed` references: 2 (>= 2)
- `PGRST116` references: 1 (>= 1)

## Success Criteria Verification

- [x] ICP card visible on Setup tab when icps table has data
- [x] ICP card hidden when no ICP exists (PGRST116 handling)
- [x] Structured sections: Summary always shows, JSONB sections show when populated
- [x] Skeleton loading state with pulsing placeholders during pipeline execution
- [x] ICP refreshes after pipeline step 1 completes (current_step >= 2)
- [x] "Last analyzed: [date]" timestamp visible from icp.updated_at
- [x] Hashtags rendered as green pill elements
- [x] JSONB null fields gracefully hidden (individual section display toggling)
- [x] card-glass class applied for glassmorphism styling
- [x] Persists across navigation (loaded from Supabase, not localStorage)

## Next Phase Readiness

Plan 05-04 can proceed. The ICP card is fully self-contained and does not block other plans. The `escapeHTML()` utility is now available for any future text rendering needs.
