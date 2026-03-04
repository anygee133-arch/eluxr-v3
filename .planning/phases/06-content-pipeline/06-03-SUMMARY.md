---
phase: 06-content-pipeline
plan: 03
subsystem: ui
tags: [vanilla-js, supabase, glassmorphism, products, platform-selector, frontend]

# Dependency graph
requires:
  - phase: 06-content-pipeline
    provides: products table with RLS (plan 01), orchestrator callback pattern
  - phase: 05-frontend-migration-ui-polish
    provides: ICP card pattern, glassmorphism card-glass styling, loadICP/renderICPCard patterns
provides:
  - products dropdown card UI with inline editing, add/remove/save functionality
  - platform selector with toggle buttons (LinkedIn, Instagram, X, YouTube)
  - loadProducts() fetching from Supabase products table
  - getSelectedPlatforms() and getSelectedMonth() for pipeline trigger enrichment
  - handleFormSubmit sending platforms and month to orchestrator
affects: [06-04-theme-generator, 06-05-content-studio, 06-06-verification]

# Tech tracking
tech-stack:
  added: []
  patterns: [collapsible-card with CSS max-height transition, platform-toggle checkbox styling, products CRUD via Supabase client]

key-files:
  created: []
  modified:
    - index.html

key-decisions:
  - "Platform selector promoted from Advanced Options to primary form element for visibility"
  - "Products textarea removed; products now come from Supabase products table, not form text"
  - "All 4 platforms default to checked (LinkedIn, Instagram, X, YouTube)"
  - "Products card collapsed by default, expands on click with smooth CSS transition"
  - "Product removal uses is_active=false soft delete, not actual delete"

patterns-established:
  - "Products card: collapsible glassmorphism card with header click toggle via CSS max-height"
  - "Platform toggle: checkbox-style buttons with active class toggling on change event"
  - "Inline editing: input fields inside list items, markModified pattern with save button visibility"

requirements-completed: [PIPE-01, PIPE-03, PIPE-06]

# Metrics
duration: 3min
completed: 2026-03-04
---

# Phase 6 Plan 03: Frontend Products Card + Platform Selector Summary

**Collapsible products dropdown card with inline editing + promoted platform selector with toggle buttons + enriched pipeline trigger sending platforms and month to orchestrator**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-04T03:46:18Z
- **Completed:** 2026-03-04T03:49:57Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- Added collapsible products dropdown card below ICP card with glassmorphism styling, inline product name editing, add/remove/save functionality
- Promoted platform selector from hidden Advanced Options to primary form element with styled toggle buttons (all 4 defaulting to checked)
- Updated handleFormSubmit to validate platforms (>= 1 required) and send platforms + month to orchestrator via getSelectedPlatforms() and getSelectedMonth()
- Products card auto-loads on SIGNED_IN and refreshes when pipeline step 1 (ICP analysis) completes

## Task Commits

Each task was committed atomically:

1. **Task 1: Add products dropdown card and platform selector to Setup tab** - `926dbbb` (feat)

## Files Created/Modified
- `index.html` - Added 522 lines: products card CSS (glassmorphism, collapsible, inline editing), platform selector CSS (toggle buttons), products card HTML, platform selector HTML (promoted from Advanced Options), JavaScript functions (loadProducts, renderProductsCard, toggleProductsCard, saveProductChanges, addCustomProduct, removeProduct, getSelectedPlatforms, getSelectedMonth, validatePlatforms), updated handleFormSubmit and renderProgress

## Decisions Made
- **Platform selector promoted to primary visibility:** Moved from inside `<details>` Advanced Options to be a top-level form element. Users need to see and configure platforms before generation.
- **Products textarea removed:** The old free-text products textarea in Advanced Options was removed. Products now come from the Supabase products table (scraped by ICP Analyzer), not from manual text entry.
- **All 4 platforms default to checked:** LinkedIn, Instagram, X, and YouTube all start checked. Users deselect platforms they don't use rather than having to opt-in.
- **Soft delete for product removal:** Clicking remove toggles the `inactive` class (visual strikethrough + opacity). Saving sets `is_active=false` in Supabase rather than deleting the row.
- **Products card collapsed by default:** Uses CSS max-height transition for smooth expand/collapse. Shows product count badge in header so users know how many products exist without expanding.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## User Setup Required

None - no external service configuration required. The products table was already created in Plan 01.

## Next Phase Readiness
- Products card ready to display products scraped by ICP Analyzer (06-02)
- Platform selection data available via getSelectedPlatforms() for content generation workflows (06-04, 06-05)
- Month selection data available via getSelectedMonth() for pipeline trigger
- Products card will auto-refresh when pipeline progress reaches step 2 (ICP analysis complete)

---
*Phase: 06-content-pipeline*
*Completed: 2026-03-04*
