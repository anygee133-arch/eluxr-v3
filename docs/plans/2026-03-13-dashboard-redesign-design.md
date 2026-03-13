# ELUXR Dashboard Redesign — Design Document

**Date:** 2026-03-13
**Scope:** 6 changes to index.html + 2 n8n workflow modifications

---

## Change 1: Auto-assign 3 ICP Hashtags to Each Post

**Backend (n8n):** Modify `eluxr-phase4-studio` (workflow 04) to:
1. Fetch ICP `recommended_hashtags` from Supabase `icps` table at workflow start
2. Include hashtags in AI content generation prompt: "Pick exactly 3 most relevant hashtags from this list for each post"
3. Post-processing Code node extracts/validates 3 hashtags, saves to `content_items.hashtags` (JSON array)

**Frontend:**
- `assignRelevantHashtags(postTheme, postProductName, allHashtags, count=3)` — client-side fallback for items missing hashtags. Scores by keyword overlap, picks top 3.
- `openDayModal()` — show hashtag pills below each platform card
- `renderContentReview()` day cards — show hashtag presence indicator
- After fetching content, run fallback on any items with empty hashtags, update Supabase

## Change 2: 28 Products, 1 Per Day

**Product-to-day mapping:** `productOrder[0-6]` → Week 1, `productOrder[7-13]` → Week 2, etc.
- `generateTopicsFromProducts()` slices ordered products for current week
- Sends `assigned_products` array (7 objects) to n8n `eluxr-generate-topics`
- Modify n8n workflow 15 to use assigned product instead of server-side rotation
- Warning toast if fewer than 28 products available
- Display product name + thumbnail on topic cards (existing partial support)

## Change 3: Rename "Scraped Products"

Text replacements:
- "Scraped Products" → "Your Products" (line ~2429)
- Empty state: "No products found yet. Run the analysis to discover your products."
- Step empty: "Complete Step 1 to discover your products."
- Global search for "scrape"/"Scraped" in user-facing text

## Change 4: Smooth Step Transitions

- `userHasScrolled` flag + `smoothTransitionToStep(stepId, delay)` prevents auto-scroll if user is navigating
- Remove `goToPhase(2)` jump after content generation
- CSS transition on `.step-section`: opacity 0.4→1, translateY 8px→0 when `.locked` removed
- Flow: Step 1 ICP loads → wait 1s → scroll to Step 2 → products load → wait 1s → scroll to Step 3 (only if user hasn't scrolled)

## Change 5: Drag-to-Reorder + Flow Restructure

**5a.** Replace collapsible dropdown with expandable card panel (max-height 400px, overflow-y: auto)

**5b.** HTML5 native drag-and-drop:
- `productOrder[]` array tracks ordering
- Numbered badges (1-28), grip handle on each item
- Drag states: `.dragging` (opacity 0.5), `.drag-over` (border-top indicator)
- `reorderProducts(fromIndex, toIndex)` re-renders with new numbering

**5c.** "Generate Week N Topics" button moves to Step 2, below products panel. Shows after products loaded. `generateTopicsFromProducts()` slices products for current week, calls `generateTopics()` with assigned products.

**5d.** "Approve All & Generate Content" replaces "Lock In & Generate Content" in Step 3. Always enabled. Approves all pending topics, then calls `lockInAndGenerate()`.

## Change 6: Center Buttons + Step 4 Flow

**6a.** Audit all button containers for consistent `justify-content: center`

**6b.** Week completion screen shows:
- Primary: "View Generated Content" → `renderContentReview()` + scroll to Step 4
- Secondary: "Skip to Calendar" → scroll to Step 5
- Remove auto-scroll to calendar from `lockInAndGenerate()`
