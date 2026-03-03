# Phase 5: Frontend Migration + UI Polish - Context

**Gathered:** 2026-03-02
**Status:** Ready for planning

<domain>
## Phase Boundary

Rebuild the frontend to use Supabase as its single source of truth (kill all localStorage, mock data, and global mutable arrays), add premium animations and glassmorphism, fix CSS stagger classes 5-10, persist ICP state, and deploy to static hosting. This phase makes the frontend ready to display real data from the pipeline. No new features — just data layer migration, visual polish, and deployment.

</domain>

<decisions>
## Implementation Decisions

### Animation & visual polish
- Staggered reveals use **fade up + slide** (elements fade in while sliding up 10-20px)
- Glassmorphism intensity: **Claude's discretion** — balance with existing dark (#0f172a) and green (#16a34a) palette
- Tab transitions: **slide direction** — content slides left/right based on tab order (Setup -> Generate -> Calendar)
- Progress bar (Phase 4): **polish it** — add gradient fill, glow effect, smoother step transitions to match premium feel
- Buttons and interactive elements: **subtle micro-animations** — scale up slightly on hover, gentle press effect on click
- Loading states: **Claude's discretion** — pick per context (skeletons for lists, spinners for actions)
- Stagger timing: **Claude's discretion** — tune delay per element count and context
- Visual reference: no specific app reference — just premium feel with the existing green/dark palette

### Data layer migration
- Empty states: **illustrated + CTA** — friendly illustration with message and action button to start generating
- Error handling: **Claude's discretion** — pick error display per context (toasts for background failures, inline for blocking failures)
- Data refresh strategy: **Claude's discretion** — pick per tab (some benefit from auto-refresh on focus, some from caching)
- Migration approach: **Claude's discretion** — evaluate v1 code structure and pick clean rewrite vs targeted replacement based on state

### ICP state persistence
- ICP display: **structured card with sections** — key ICP fields (target audience, pain points, messaging angles) as scannable sections
- ICP loading: **load from Supabase on login** — returning users see their existing ICP immediately on the Setup tab
- ICP re-run behavior: **overwrite** — one ICP per user, re-running replaces the old one
- ICP loading UX: **skeleton card** — gray placeholder card with pulsing sections while ICP analysis runs
- ICP card: **read-only** — display only, re-run analysis to change
- ICP metadata: **show timestamp** — small "Last analyzed: [date]" below the card
- Re-analyze button: **no separate button** — user enters a new URL and hits Generate; the pipeline re-runs ICP as its first step

### Deployment & config
- Hosting: **Vercel** — static site deployment
- Config: **single config.js file** — detects environment by hostname (localhost = dev, deployed domain = prod)
- Domain: **Vercel default URL** for now — custom domain later
- Deploy mode: **Git-connected** — push to main = auto-deploy

### Claude's Discretion
- Glassmorphism intensity (balanced with dark/green palette)
- Loading state type per context (skeleton vs spinner)
- Stagger animation timing per element count
- Error display style per context (toast vs inline)
- Data refresh strategy per tab
- Data layer migration approach (clean rewrite vs targeted replacement)

</decisions>

<specifics>
## Specific Ideas

- Premium feel without a specific app reference — let the existing green (#16a34a) / dark (#0f172a) palette guide the aesthetic
- Progress bar should feel polished to match the rest of the UI (gradient, glow, smooth transitions)
- ICP card should show structured sections (audience, pain points, messaging angles) — not a wall of text
- Empty states should feel inviting, not broken — illustration + clear CTA
- No build step constraint: vanilla HTML/CSS/JS with CDN-loaded supabase-js (existing v1 constraint)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 05-frontend-migration-ui-polish*
*Context gathered: 2026-03-02*
