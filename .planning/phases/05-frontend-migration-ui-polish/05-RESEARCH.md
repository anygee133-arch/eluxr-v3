# Phase 5: Frontend Migration + UI Polish - Research

**Researched:** 2026-03-03
**Domain:** Vanilla HTML/CSS/JS frontend, Supabase data layer, CSS animations, static hosting
**Confidence:** HIGH (all code examined directly; no external unknowns)

## Summary

Phase 5 transforms the frontend from a hybrid state (localStorage + n8n webhook data + mock data fallbacks) into a clean architecture where Supabase is the single source of truth, with premium animations and Vercel deployment. The codebase is a single 4,856-line `index.html` file containing all HTML, CSS, and JavaScript (no build step, no frameworks, CDN-loaded supabase-js).

The work has three distinct domains: (1) **Data layer migration** -- replace all localStorage, mock data, and global mutable arrays with Supabase queries via supabase-js; (2) **Animation and UI polish** -- add stagger classes 5-10, glassmorphism effects, tab slide transitions, micro-animations, and progress bar polish; (3) **ICP state persistence** -- load ICP from Supabase `icps` table and display as a structured card on the Setup tab; plus (4) **Deployment** -- config.js environment detection and Vercel static site deployment.

The primary technical challenge is the **atomic migration**: the current code has deep entanglement between localStorage session management, the global `contentData` array, `saveSession()` calls scattered across 12+ functions, and a `generateMockData()` fallback. A surgical replacement is viable because the data flow is linear (fetch -> contentData -> render), but every function that mutates `contentData` or calls `saveSession()` must be updated.

**Primary recommendation:** Targeted replacement (not clean rewrite) of the data layer within the existing file structure, because the HTML structure, auth system, and Realtime progress tracking are already correct and working. The animation/polish work is purely additive CSS + minor JS. The ICP feature requires a new HTML section and a Supabase query. Deployment is configuration-only.

---

## Work Area A: Data Layer Migration (Kill localStorage, Mock Data, Global Arrays)

### Current State Analysis

The frontend currently has **three data sources** that must all be replaced:

**1. localStorage persistence (7 usage sites):**
- `localStorage.getItem('eluxr_business_context')` -- loads saved business form data (line 2350)
- `localStorage.setItem('eluxr_business_context', ...)` -- saves business form data (line 2434)
- `localStorage.getItem('eluxr_current_session')` -- loads saved session with contentData (line 2355)
- `localStorage.setItem('eluxr_current_session', ...)` -- saves session (via `saveSession()`, line 4577)
- `localStorage.setItem('eluxr_active_pipeline_run', ...)` -- saves active pipeline run ID (line 3105)
- `localStorage.getItem('eluxr_active_pipeline_run')` -- loaded implicitly via pipeline logic
- `localStorage.removeItem(...)` -- cleanup on start-over and pipeline completion (lines 3445, 4755)

**2. `saveSession()` function (called from 10 sites):**
```javascript
function saveSession(sessionId, data) {
  localStorage.setItem('eluxr_current_session', JSON.stringify({ sessionId, ...data }));
}
```
Called from: `fetchAndDisplayCalendar`, `changeMonth`, `goToCurrentMonth`, `approveContent`, `rejectContent`, `editContent`, `clearPendingContent`, `generateMockData`, and two content manipulation functions.

**3. `generateMockData()` function (1 site, line 3326):**
Called as fallback when `fetchAndDisplayCalendar()` fails and `silent` is false. Generates fake content with `picsum.photos` images. This entire function must be removed and replaced with an empty-state UI.

**4. Global mutable state variables (line 2328-2339):**
```javascript
let weeklyThemes = [];
let currentPhase = 1;
let currentSessionId = null;
let contentData = [];          // <-- PRIMARY: all content lives here
let selectedItems = new Set();
let currentPreviewDay = null;
let currentMonth = new Date().toISOString().slice(0, 7);
let currentScript = null;
let generatedVideoUrl = null;
let businessContext = null;     // <-- Stores business info from Step 1
```

`contentData` is the core array -- every rendering function reads from it, and 10+ functions mutate it. `businessContext` stores form input but is also saved to localStorage.

### Target State

| Current | Target |
|---------|--------|
| `contentData` populated by `fetchCalendarData()` -> n8n webhook -> response.all | `contentData` populated by `supabase.from('content_items').select(...)` |
| `saveSession()` after every mutation | Remove entirely -- Supabase is the source of truth |
| `localStorage` for business context | `supabase.from('profiles').select(...)` for business_url, industry |
| `localStorage` for session resume | `checkActivePipeline()` already uses Supabase (working) |
| `generateMockData()` fallback | Empty-state UI with CTA ("Generate your first campaign") |
| `fetchCalendarData()` via n8n webhook | Direct Supabase query: `supabase.from('content_items').select('*')` |
| `submitApproval()` via n8n webhook | Keep n8n webhook (approval has backend logic) OR direct Supabase update |
| `loadScheduleThemes()` via n8n webhook | Direct Supabase query: `supabase.from('themes').select('*')` |

### Data Flow: Current vs Target

**Current flow:**
```
Form submit -> authenticatedFetch(n8n/eluxr-generate-content) -> 202
   -> Realtime subscription on pipeline_runs (KEEP)
   -> On complete: fetchAndDisplayCalendar()
      -> authenticatedFetch(n8n/eluxr-approval-list) -> response.json()
      -> contentData = response.all
      -> saveSession(localStorage)
      -> renderCalendar(contentData)
```

**Target flow:**
```
Form submit -> authenticatedFetch(n8n/eluxr-generate-content) -> 202
   -> Realtime subscription on pipeline_runs (KEEP)
   -> On complete: loadContentFromSupabase()
      -> supabase.from('content_items').select('*, themes(*)').eq('user_id', user.id)
      -> contentData = data
      -> renderCalendar(contentData)
```

### Supabase Queries Needed

**Content items (replaces `fetchCalendarData` + `eluxr-approval-list` webhook):**
```javascript
const { data, error } = await window.supabase
  .from('content_items')
  .select('*')
  .order('scheduled_date', { ascending: true });
// RLS automatically filters by auth.uid() = user_id
```

**Themes (replaces `eluxr-themes-list` webhook):**
```javascript
const { data, error } = await window.supabase
  .from('themes')
  .select('*, campaigns(month)')
  .order('week_number', { ascending: true });
```

**ICP (new -- for UI-04):**
```javascript
const { data, error } = await window.supabase
  .from('icps')
  .select('*')
  .single();
// UNIQUE(user_id) constraint means at most 1 row per user
```

**Profile (replaces localStorage business context):**
```javascript
const { data, error } = await window.supabase
  .from('profiles')
  .select('business_url, industry')
  .single();
```

**Approval actions (keep n8n webhook OR direct update):**
Option A (keep webhook -- simpler, preserves backend logic):
```javascript
await authenticatedFetch(`${API_BASE}/eluxr-approval-action`, { ... });
// Then re-fetch from Supabase to update local state
```
Option B (direct Supabase update -- fewer network hops):
```javascript
const { error } = await window.supabase
  .from('content_items')
  .update({ status: 'approved' })
  .eq('id', contentId);
```

**Confidence: HIGH** -- All these tables exist (verified in schema SQL), RLS policies are in place, and supabase-js is already loaded and authenticated.

### Functions That Must Change

| Function | Current Behavior | Target Behavior |
|----------|-----------------|-----------------|
| `DOMContentLoaded` handler | Loads from localStorage, offers resume | Load from Supabase (profile, content_items) |
| `handleFormSubmit()` | Saves businessContext to localStorage | Save to profiles table (business_url, industry) |
| `fetchCalendarData()` | Calls n8n webhook `eluxr-approval-list` | Direct `supabase.from('content_items').select()` |
| `fetchAndDisplayCalendar()` | Calls fetchCalendarData + saveSession | Calls Supabase query + no saveSession |
| `loadScheduleThemes()` | Calls n8n webhook `eluxr-themes-list` + `eluxr-approval-list` | Direct `supabase.from('themes').select()` + `content_items` |
| `saveSession()` | Writes to localStorage | **DELETE ENTIRELY** |
| `generateMockData()` | Generates fake content | **DELETE ENTIRELY** -- show empty state |
| `startOver()` | Clears localStorage | No localStorage to clear -- just reset state vars |
| `clearPendingContent()` | Calls n8n webhook + filters local array | Direct `supabase.from('content_items').delete().eq('status', 'pending_review')` or keep webhook |
| `approveContent()` | Calls webhook + mutates local array | Calls webhook (or direct update) + re-fetch |
| `rejectContent()` | Calls webhook + mutates local array | Same pattern |
| `changeMonth()` / `goToCurrentMonth()` | Updates month + saveSession | Updates month only (no saveSession) |
| `renderProgress()` on complete | Calls `fetchAndDisplayCalendar()` | Calls new Supabase-based content loader |
| `checkActivePipeline()` | Already uses Supabase | **No change needed** |
| `subscribeToProgress()` | Already uses Supabase Realtime | **No change needed** |
| `cleanupProgress()` | Removes localStorage pipeline run | Remove only the localStorage line |
| `generateContent()` | Already calls n8n orchestrator | **Minimal change** -- remove localStorage.setItem for pipeline run |

### Key Observation: Content Field Mapping

The current `contentData` array items have these fields (from the n8n approval-list webhook response):
```
id, day_number, date, platform, theme, content_type, post_text, content, hashtags,
image_url, video_url, status, row_number
```

The Supabase `content_items` table has:
```
id, user_id, campaign_id, theme_id, title, content, content_type, platform,
scheduled_date, scheduled_time, status, image_url, video_url, image_prompt, feedback
```

**Field mapping issues to resolve:**
- `day_number` does not exist in DB -- compute from `scheduled_date`
- `date` in frontend vs `scheduled_date` in DB
- `post_text` vs `content` -- both are used inconsistently in current code
- `theme` (string) in current data vs `theme_id` (UUID FK) in DB -- need a join or denormalization
- `hashtags` -- not a separate column in DB; may be inside the `content` JSON blob
- `row_number` -- Google Sheets artifact, not in DB
- `status` values differ: frontend uses `pending`, DB uses `pending_review`

This mapping must be handled in the data loading layer to avoid breaking all rendering functions.

### Anti-Patterns to Remove

1. **Mock data fallback** (line 3326): `generateMockData(...)` on API failure -- replace with empty-state UI
2. **Session resume via localStorage** (lines 2355-2370): `confirm('You have a previous session...')` -- delete entirely; use Supabase as source of truth
3. **Double data loading** (DOMContentLoaded calls `fetchAndDisplayCalendar(true)` which duplicates the auth state handler's work)
4. **localStorage pipeline run tracking** (lines 3105, 3445, 3475): `eluxr_active_pipeline_run` -- `checkActivePipeline()` already queries Supabase directly, so localStorage is redundant
5. **Comments referencing Google Sheets** (lines 2327, 3594, 3999): "Themes from Google Sheets", "Fetch themes from Google Sheets via n8n", "Wait for content to be saved to Google Sheets"

---

## Work Area B: CSS Animation + UI Polish

### Current Animation State

**Existing animations (6 total):**
1. `@keyframes shimmer` -- progress bar shine effect (line 220)
2. `@keyframes pulse` -- active step icon pulsing (line 248)
3. `@keyframes slideDown` -- content list panel reveal (line 268)
4. `@keyframes pulse-dot` -- chat dot pulsing (line 480)
5. `@keyframes msgSlideIn` -- chat message entrance (line 490)
6. `@keyframes fadeInUp` -- staggered element entrance (line 656)

**Existing stagger classes (4 defined, 6 used):**
```css
.fade-in-up { opacity: 0; transform: translateY(20px); animation: fadeInUp 0.5s var(--transition) forwards; }
.stagger-1 { animation-delay: 0.05s; }
.stagger-2 { animation-delay: 0.1s; }
.stagger-3 { animation-delay: 0.15s; }
.stagger-4 { animation-delay: 0.2s; }
/* stagger-5 and stagger-6 are USED in HTML but NOT DEFINED in CSS */
```

**HTML elements using stagger classes:**
- `stagger-1`: Setup card, progress card, content schedule (3 uses)
- `stagger-2`: Setup chatbox, video script tool, stats row, calendar container (4 uses)
- `stagger-3`: Image gen tool, calendar chatbox (2 uses)
- `stagger-4`: Video gen tool (1 use)
- `stagger-5`: Content gen tool (1 use) -- **BROKEN: no CSS definition**
- `stagger-6`: Generate tab chatbox (1 use) -- **BROKEN: no CSS definition**

### Bug Fix: UI-03 (stagger classes 5-10)

Add CSS definitions for stagger-5 through stagger-10:
```css
.stagger-5 { animation-delay: 0.25s; }
.stagger-6 { animation-delay: 0.3s; }
.stagger-7 { animation-delay: 0.35s; }
.stagger-8 { animation-delay: 0.4s; }
.stagger-9 { animation-delay: 0.45s; }
.stagger-10 { animation-delay: 0.5s; }
```

**Confidence: HIGH** -- Straightforward CSS addition. Pattern established by existing stagger-1 through stagger-4.

### New Animations Required (UI-01)

**1. Glassmorphism card effects:**
Cards need a frosted-glass treatment. Compatible with the dark (#0f172a) / green (#16a34a) palette:
```css
.card-glass {
  background: rgba(255, 255, 255, 0.7);
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
  border: 1px solid rgba(255, 255, 255, 0.3);
}
```
Note: `backdrop-filter` has >95% browser support (caniuse). Safari requires `-webkit-` prefix. Apply selectively -- not every card needs glassmorphism. Best candidates: progress card, ICP summary card, stat cards.

**2. Tab slide transitions (Setup -> Generate -> Calendar):**
Currently, tab switching uses opacity + translateY (fade up). The decision is to use directional slides:
- Tab 1 -> Tab 2: content slides left, new content slides in from right
- Tab 2 -> Tab 3: same
- Tab 3 -> Tab 2: content slides right, new content slides in from left
- Tab 2 -> Tab 1: same

Implementation approach:
```css
.page-section { display: none; }
.page-section.active { display: block; }
.page-section.slide-in-left { animation: slideInLeft 0.4s ease forwards; }
.page-section.slide-in-right { animation: slideInRight 0.4s ease forwards; }
@keyframes slideInLeft { from { opacity: 0; transform: translateX(-30px); } to { opacity: 1; transform: translateX(0); } }
@keyframes slideInRight { from { opacity: 0; transform: translateX(30px); } to { opacity: 1; transform: translateX(0); } }
```
The `goToPhase(n)` function (line 2385) needs to compare `n` with `currentPhase` to determine slide direction.

**3. Button micro-animations:**
```css
.btn { transition: all 0.25s var(--transition); }
.btn:hover { transform: translateY(-2px) scale(1.02); }
.btn:active { transform: translateY(0) scale(0.98); }
```
Note: `.btn-primary:hover` already has `transform: translateY(-1px)` -- needs to be consolidated.

**4. Progress bar polish:**
Current progress bar already has shimmer and gradient. Enhancements:
- Glow effect: `box-shadow: 0 0 20px rgba(22, 163, 74, 0.4)` on the bar
- Smoother step transitions: increase `transition: width` duration from `0.5s` to `0.8s ease`
- Gradient refinement: add a third color stop for more depth

**5. Loading states:**
- Skeleton cards for content lists (pulsing gray rectangles)
- Spinner for action buttons (already exists: `.spinner` class at line 548)
- ICP skeleton card (per context decision: "gray placeholder card with pulsing sections")

### Animation Performance Notes

- All animations use `transform` and `opacity` (GPU-composited, no layout thrash)
- `backdrop-filter` can cause performance issues on low-end devices -- use sparingly
- Stagger delays should not exceed ~0.5s total (stagger-10 at 0.5s is the upper bound)
- `will-change: transform` on frequently animated elements can help GPU compositing

---

## Work Area C: ICP State Persistence (UI-04)

### Problem Statement

Currently, when the pipeline runs ICP analysis (Step 1), the result is stored in the Supabase `icps` table by the n8n backend, but the frontend never reads it back. The `businessContext` variable stores only the form input (URL, industry, products, brand_voice) -- not the ICP analysis output. When the user navigates away from the Setup tab and back, no ICP data is displayed.

### ICP Table Schema

```sql
CREATE TABLE public.icps (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  business_url TEXT,
  industry TEXT,
  icp_summary TEXT,           -- Main summary text
  demographics JSONB,          -- Target audience demographics
  psychographics JSONB,        -- Values, interests, pain points
  content_preferences JSONB,   -- Preferred content types and formats
  competitors JSONB,           -- Competitive landscape
  content_opportunities JSONB, -- Content gap analysis
  recommended_hashtags JSONB,  -- Hashtag suggestions
  raw_research TEXT,           -- Full Perplexity research output
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  UNIQUE(user_id)             -- One ICP per user
);
```

### Implementation Design

**HTML: ICP summary card on Setup tab (Phase 1 section)**
Add below the business form, above the chatbox:
```html
<div id="icp-card" class="card fade-in-up stagger-2" style="display: none;">
  <div class="icp-card-header">
    <h3>Your Business Profile</h3>
    <span id="icp-last-analyzed" class="icp-meta"></span>
  </div>
  <div id="icp-card-body">
    <!-- Structured sections: target audience, pain points, messaging angles, recommended hashtags -->
  </div>
</div>
```

**CSS: ICP card styling**
- Sections with labels (small caps) and values
- Optional glassmorphism treatment
- Skeleton loading state (pulsing gray blocks)

**JavaScript: Load ICP on login**
```javascript
async function loadICP() {
  const { data, error } = await window.supabase
    .from('icps')
    .select('*')
    .single();

  if (data) {
    renderICPCard(data);
  }
  // If no data, card stays hidden -- user hasn't run analysis yet
}
```

Call `loadICP()` in the `SIGNED_IN` handler (after `showDashboard()`).

**Structured display fields:**
From the `icps` table JSONB columns:
1. **Target Audience** -- from `demographics` (age, role, company size)
2. **Pain Points** -- from `psychographics` (challenges, frustrations)
3. **Messaging Angles** -- from `content_opportunities` (what resonates)
4. **Recommended Hashtags** -- from `recommended_hashtags`
5. **Summary** -- from `icp_summary` (overview text)
6. **Last Analyzed** -- from `updated_at` (timestamp)

**Re-run behavior:** Per context decision, re-running the pipeline overwrites the ICP (UNIQUE constraint). The card updates after pipeline completion.

### ICP Skeleton Loading State

Show while ICP analysis is running (pipeline step 1):
```html
<div class="icp-skeleton">
  <div class="skeleton-line" style="width: 60%;"></div>
  <div class="skeleton-line" style="width: 80%;"></div>
  <div class="skeleton-line" style="width: 45%;"></div>
  <div class="skeleton-line" style="width: 70%;"></div>
</div>
```
```css
.skeleton-line {
  height: 16px;
  background: linear-gradient(90deg, var(--border) 25%, var(--border-light) 50%, var(--border) 75%);
  background-size: 200% 100%;
  animation: skeleton-pulse 1.5s ease-in-out infinite;
  border-radius: 4px;
  margin-bottom: 12px;
}
@keyframes skeleton-pulse {
  0% { background-position: 200% 0; }
  100% { background-position: -200% 0; }
}
```

### Integration with Pipeline Progress

When pipeline reaches step 1 completion (ICP analysis done), re-fetch ICP:
```javascript
// In renderProgress(), after step 1 completes:
if (run.current_step >= 1 && !icpLoaded) {
  loadICP();  // Refresh ICP card with new analysis
  icpLoaded = true;
}
```

**Confidence: HIGH** -- Schema exists, data is written by backend, query is straightforward.

---

## Work Area D: Environment Config + Vercel Deployment (UI-06)

### Current Config State

The Supabase credentials and n8n webhook URLs are currently hardcoded:
```javascript
// In module script (line 1990-1991):
const SUPABASE_URL = 'https://llpnwaoxisfwptxvdfed.supabase.co'
const SUPABASE_ANON_KEY = 'sb_publishable_9gnLO_J9HBxVta1f8Ecvxw_KO8huPYQ'

// In non-module script (line 2324-2325):
const API_BASE = 'https://flowbound.app.n8n.cloud/webhook';
const N8N_BASE_URL = 'https://flowbound.app.n8n.cloud/webhook';
```

### Target: config.js with Environment Detection

Per context decision: "single config.js file -- detects environment by hostname"

```javascript
// config.js -- loaded before all other scripts
window.ELUXR_CONFIG = (() => {
  const hostname = window.location.hostname;

  if (hostname === 'localhost' || hostname === '127.0.0.1') {
    return {
      SUPABASE_URL: 'https://llpnwaoxisfwptxvdfed.supabase.co',
      SUPABASE_ANON_KEY: 'sb_publishable_9gnLO_J9HBxVta1f8Ecvxw_KO8huPYQ',
      N8N_WEBHOOK_BASE: 'https://flowbound.app.n8n.cloud/webhook',
      ENV: 'development'
    };
  }

  // Production (Vercel deployed domain)
  return {
    SUPABASE_URL: 'https://llpnwaoxisfwptxvdfed.supabase.co',
    SUPABASE_ANON_KEY: 'sb_publishable_9gnLO_J9HBxVta1f8Ecvxw_KO8huPYQ',
    N8N_WEBHOOK_BASE: 'https://flowbound.app.n8n.cloud/webhook',
    ENV: 'production'
  };
})();
```

Note: For this project, dev and prod use the same Supabase instance and n8n instance. The config separation is future-proofing for when separate environments exist.

### Vercel Deployment

**Requirements:**
- Static site (no build step, no framework)
- Git-connected (push to main = auto-deploy)
- Single `index.html` + `config.js` in root

**Vercel configuration (vercel.json):**
```json
{
  "buildCommand": null,
  "outputDirectory": ".",
  "rewrites": [
    { "source": "/(.*)", "destination": "/index.html" }
  ],
  "headers": [
    {
      "source": "/(.*)",
      "headers": [
        { "key": "X-Content-Type-Options", "value": "nosniff" },
        { "key": "X-Frame-Options", "value": "DENY" }
      ]
    }
  ]
}
```

The rewrite rule ensures that direct navigation to any path serves `index.html` (relevant if deep linking is added later). The security headers are best practice.

**Files to deploy:**
- `index.html` -- the entire application
- `config.js` -- environment config
- `vercel.json` -- Vercel configuration

**Files to NOT deploy (need .gitignore):**
- `workflows/` -- n8n workflow JSON files (contain sensitive data patterns)
- `supabase/` -- migration files (server-side only)
- `.planning/` -- planning artifacts
- `tests/` -- test results
- `scripts/` -- deployment scripts
- `*.json` (root level) -- workflow exports
- `*.pdf` -- documentation
- `*.py` -- utility scripts

A `.gitignore` should be created (or updated) to exclude these from the git repo that Vercel connects to.

### CORS Considerations

The Supabase client connects directly to `llpnwaoxisfwptxvdfed.supabase.co` -- Supabase handles CORS for all origins by default. The n8n webhooks have `allowedOrigins: "*"` -- no CORS issues with any deployment domain.

**Confidence: HIGH** -- Standard Vercel static site deployment pattern.

---

## Work Area E: Tab Transition + Empty States

### Tab Transition System

Current implementation (`goToPhase()`, line 2385):
```javascript
function goToPhase(n) {
  currentPhase = n;
  // Update nav items
  // Hide all sections, show target
  const target = document.getElementById(`phase-${n}`);
  target.classList.add('active');
  requestAnimationFrame(() => requestAnimationFrame(() => target.classList.add('visible')));
}
```

This uses a double-rAF trick to trigger the CSS transition. The current transition is fade + translate-up:
```css
.page-section { display: none; opacity: 0; transform: translateY(12px); transition: opacity 0.5s, transform 0.5s; }
.page-section.active { display: block; }
.page-section.visible { opacity: 1; transform: translateY(0); }
```

**Upgrade to directional slide:**
Track the previous phase number. If navigating forward (phase N+1), slide content from right. If backward (phase N-1), slide from left. This requires replacing the `visible` class system with animation classes.

### Empty States

Current behavior: if API fails, `generateMockData()` is called. The "no content" state in the schedule grid shows "No content scheduled" per card.

Target: illustrated empty states with CTA. Three empty-state contexts:
1. **Setup tab (no ICP yet):** "Analyze your business to get started" with form highlight
2. **Generate tab (no pipeline running):** Tools section is always visible; progress section hidden
3. **Calendar tab (no content yet):** "No content generated yet. Start by analyzing your business." with a button to go to Setup tab

### Content Data Refresh Strategy

Per context decision, Claude's discretion per tab:
- **Setup tab:** Load ICP once on login; re-fetch after pipeline completes
- **Generate tab:** Realtime subscription already handles this (no change)
- **Calendar tab:** Fetch on tab switch; auto-refresh every 30s (current behavior, keep it but change data source from n8n webhook to Supabase query)

---

## Common Pitfalls

### Pitfall 1: Field Name Mismatch Between n8n Response and Supabase Schema

**What goes wrong:** The rendering functions (`renderCalendar`, `renderScheduleGrid`, `openScheduleCard`) use field names from the n8n webhook response format (`date`, `post_text`, `theme`, `day_number`, `row_number`), but direct Supabase queries return DB column names (`scheduled_date`, `content`, `theme_id`, no `day_number`, no `row_number`).

**Why it happens:** Phase 3 built n8n workflows that transform DB rows into a frontend-friendly format. Bypassing n8n means the frontend must handle the transformation.

**How to avoid:**
- Create a `mapContentItem(dbRow)` function that normalizes DB rows to the format the rendering functions expect
- Map `scheduled_date` -> `date`, `content` -> `post_text`, compute `day_number` from date, join `themes` to get `theme` name
- Apply this mapper right after the Supabase query, before setting `contentData`

**Warning signs:** Calendar shows no content despite data existing in Supabase; undefined errors in console for `item.date` or `item.post_text`.

### Pitfall 2: Status Value Mismatch (pending vs pending_review)

**What goes wrong:** The DB uses `pending_review` (per Phase 3 decision, CHECK constraint). The frontend code checks for `status === 'pending'` in multiple places (`updateStats`, `showContentList`, `renderScheduleGrid`, `clearPendingContent`).

**Why it happens:** The n8n approval-list webhook transformed `pending_review` to `pending` for the frontend. Direct Supabase queries return the raw DB value.

**How to avoid:** Either:
(a) Normalize in the mapper: `status: dbRow.status === 'pending_review' ? 'pending' : dbRow.status`
(b) Update all frontend code to use `pending_review` instead of `pending`

Option (a) is safer because it requires changes in one place rather than 6+.

### Pitfall 3: Supabase Query Without Auth Session

**What goes wrong:** `supabase.from('content_items').select('*')` returns empty results or errors if the user's session has expired.

**Why it happens:** RLS requires an authenticated session. If the token expired and auto-refresh hasn't kicked in, the query fails silently (returns empty array, not an error).

**How to avoid:**
- Always check `supabase.auth.getSession()` before making data queries
- Use the existing `authenticatedFetch` pattern as a reference -- but for Supabase client queries, the client handles auth automatically if the session is valid
- The existing `onAuthStateChange` handler refreshes tokens, so this should be handled -- but add error checking on query responses

### Pitfall 4: Breaking the Working Pipeline Progress UI

**What goes wrong:** While refactoring the data layer, accidentally removing or breaking the Realtime progress subscription, `renderProgress()`, or `checkActivePipeline()` -- which are already working correctly.

**Why it happens:** These functions share global state (`progressChannel`, `currentPipelineRunId`) and touch some of the same variables being migrated.

**How to avoid:**
- Explicitly identify functions that DO NOT need changes: `subscribeToProgress()`, `renderProgress()`, `checkActivePipeline()`, `resetProgressUI()`, `cleanupProgress()` (minus localStorage line)
- Test pipeline progress before and after migration

### Pitfall 5: Single-File Architecture Merge Conflicts

**What goes wrong:** The entire app is one 4,856-line file. Any parallel work on CSS, HTML, and JS would conflict.

**Why it happens:** No build step, no file splitting, all-in-one architecture.

**How to avoid:** This is acknowledged as a constraint ("No frameworks, no build step"). Changes must be sequential within the file. Consider splitting into phases within this phase: CSS first, then HTML structure, then JS data layer. The file STAYS as a single index.html per project constraints.

### Pitfall 6: ICP JSONB Fields Are Empty/Null

**What goes wrong:** The ICP card renders with empty sections because the pipeline hasn't populated the JSONB columns (`demographics`, `psychographics`, etc.) -- it may only fill `icp_summary` and `raw_research`.

**Why it happens:** The n8n ICP Analyzer workflow (01-ICP-Analyzer) may store everything as a text blob in `icp_summary` rather than structured JSONB.

**How to avoid:**
- Check the actual data in the `icps` table for an existing user
- Design the ICP card to gracefully degrade: show `icp_summary` as the primary display, and only show individual JSONB sections if they exist
- The structured card layout should fall back to showing the summary text if JSONB fields are null

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Data fetching from Supabase | Custom fetch wrapper | `window.supabase.from().select()` | supabase-js already loaded, handles auth/RLS automatically |
| Environment detection | Complex env system | `window.location.hostname` check in config.js | No build step means no .env files; hostname is reliable |
| CSS animations | JavaScript animation libraries | CSS `@keyframes` + `animation-delay` | Zero dependencies; GPU-composited; matches existing patterns |
| Glassmorphism | CSS-in-JS or libraries | `backdrop-filter: blur()` + `rgba` backgrounds | Native CSS; >95% browser support |
| Skeleton loading | Library (react-loading-skeleton etc.) | CSS `@keyframes` with gradient backgrounds | No framework; ~10 lines of CSS |
| Deployment pipeline | Custom CI/CD | Vercel Git integration | Push-to-deploy; zero config for static sites |
| State management | Redux/Zustand/etc. | Global variables + Supabase as source of truth | No framework; existing pattern works; Supabase is the store |

---

## Dependency Analysis

### What Phase 5 Depends On (Verified Complete)

| Dependency | Phase | Status | Verified |
|------------|-------|--------|----------|
| Supabase schema (all 10 tables) | Phase 1 | Complete | Schema SQL reviewed |
| RLS policies on all tables | Phase 1 | Complete | Policies verified in SQL |
| Auth UI (login, signup, password reset) | Phase 2 | Complete | HTML + JS reviewed in index.html |
| authenticatedFetch() wrapper | Phase 2 | Complete | Implementation at line 2248 |
| Supabase client (supabase-js) loaded | Phase 2 | Complete | Module script at line 1986 |
| Auth state management (onAuthStateChange) | Phase 2 | Complete | Handler at line 2204 |
| Pipeline Orchestrator (returns 202) | Phase 4 | Complete | generateContent() at line 3081 |
| Realtime progress subscription | Phase 4 | Complete | subscribeToProgress() at line 3358 |
| checkActivePipeline() on login | Phase 4 | Complete | Called from SIGNED_IN handler |

### What Depends on Phase 5

| Downstream Phase | What It Needs |
|-----------------|---------------|
| Phase 6 (Content Pipeline) | Frontend must display real content from Supabase; ICP card must show analysis results |
| Phase 7 (Approval Queue) | Frontend must load content_items from Supabase to approve/reject |
| Phase 8 (Calendar) | Calendar tab must render from content_items with scheduled_date |
| Phase 11 (Trend Intelligence) | Dashboard notification banner needs the frontend infrastructure |

---

## Migration Scope Estimate

### CSS/Animation Work (UI-01, UI-02, UI-03)
- Add stagger-5 through stagger-10: **~6 lines CSS**
- Glassmorphism classes: **~15 lines CSS**
- Tab slide transitions: **~20 lines CSS + ~10 lines JS** (modify goToPhase)
- Button micro-animations: **~10 lines CSS** (consolidate with existing hover styles)
- Progress bar polish: **~5 lines CSS**
- Skeleton loading styles: **~15 lines CSS**
- Total: **~70 lines CSS, ~10 lines JS**

### Data Layer Migration
- New data loading functions (Supabase queries): **~60 lines JS**
- Data mapper (DB fields -> frontend fields): **~30 lines JS**
- Remove/replace saveSession calls (10 sites): **~20 lines delta**
- Remove generateMockData: **-40 lines JS**
- Remove localStorage business context: **-10 lines JS**
- Update DOMContentLoaded handler: **~15 lines JS**
- Update fetchAndDisplayCalendar: **~20 lines JS**
- Update loadScheduleThemes: **~20 lines JS**
- Empty state HTML: **~30 lines HTML**
- Total: **~150 lines new JS, ~80 lines removed, ~30 lines HTML**

### ICP State Persistence (UI-04)
- ICP card HTML: **~30 lines**
- ICP card CSS: **~40 lines**
- ICP load/render JS: **~60 lines**
- ICP skeleton loading: **~15 lines CSS**
- Total: **~30 lines HTML, ~55 lines CSS, ~60 lines JS**

### Deployment (UI-06)
- config.js: **~20 lines**
- vercel.json: **~15 lines**
- .gitignore: **~15 lines**
- Script tag for config.js in index.html: **~1 line**
- Replace hardcoded URLs with config refs: **~5 lines JS**
- Total: **~50 lines across new files, ~6 lines modified in index.html**

---

## Open Questions (All Resolvable During Implementation)

1. **What data does the ICP Analyzer actually store?**
   - Need to check: does 01-ICP-Analyzer populate `demographics`, `psychographics`, etc. as structured JSONB, or does it dump everything into `icp_summary`?
   - Impact: Determines whether the ICP card shows structured sections or a formatted text block
   - Resolution: Query `icps` table for a test user, or read the 01-ICP-Analyzer workflow JSON

2. **Does the approval-action webhook have logic beyond a status update?**
   - Need to check: does `eluxr-approval-action` do anything besides `UPDATE content_items SET status = ?`?
   - Impact: If it's a simple status update, we can use direct Supabase queries. If it has side effects (logging, notifications), keep the webhook.
   - Resolution: Read the 07-approval-action.json workflow

3. **Git repo readiness for Vercel**
   - Need to check: is the repo connected to GitHub/GitLab? Does it have a remote?
   - Impact: Vercel Git deployment requires a remote repository
   - Resolution: `git remote -v` and `git status`

4. **Should content_items Realtime be enabled?**
   - Currently only `pipeline_runs` has Realtime enabled (line 314 of schema SQL)
   - If approval actions from other sessions should reflect instantly, `content_items` would need Realtime too
   - For Phase 5 scope: not needed (single user, single browser). Can be added later.

---

## Sources

### Primary (HIGH confidence -- direct codebase analysis)
- `/home/andrew/workflow/eluxr-v2/index.html` -- complete frontend (4,856 lines)
- `/home/andrew/workflow/eluxr-v2/supabase/migrations/20260228044505_create_initial_schema.sql` -- database schema
- `/home/andrew/workflow/eluxr-v2/.planning/STATE.md` -- project state and decisions
- `/home/andrew/workflow/eluxr-v2/.planning/REQUIREMENTS.md` -- all 50 requirements
- `/home/andrew/workflow/eluxr-v2/.planning/ROADMAP.md` -- phase dependencies
- `/home/andrew/workflow/eluxr-v2/.planning/phases/05-frontend-migration-ui-polish/05-CONTEXT.md` -- phase context + decisions
- `/home/andrew/workflow/eluxr-v2/.planning/phases/04-async-pipeline-real-time-progress-tracking/04-RESEARCH.md` -- Realtime patterns
- `/home/andrew/workflow/eluxr-v2/.planning/research/ARCHITECTURE.md` -- system architecture

### Secondary (MEDIUM confidence -- established web patterns)
- Vercel static site deployment: standard zero-config pattern
- CSS `backdrop-filter` support: >95% per caniuse (as of training data)
- CSS animation performance: `transform` + `opacity` are GPU-composited

---

## Metadata

**Confidence breakdown:**
- Data layer migration: HIGH -- all code paths traced, all functions identified, Supabase schema verified
- Animation/CSS: HIGH -- purely additive, no unknowns
- ICP persistence: HIGH (implementation), MEDIUM (data shape in `icps` table -- may need adaptation)
- Deployment: HIGH -- standard Vercel static site pattern
- Field mapping: HIGH risk area -- requires careful mapper function, well-understood

**Research date:** 2026-03-03
**Valid until:** 2026-04-03 (30 days -- stable domain, no fast-moving changes expected)
