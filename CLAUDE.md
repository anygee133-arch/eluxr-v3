# ELUXR Magic Content Engine v3

## What This Is

Multi-tenant SaaS social media content platform. Businesses enter their URL, get AI-powered ICP analysis, and receive a complete 30-day Netflix-model social media campaign (LinkedIn, Instagram, X, YouTube) with AI-generated text, images, and video scripts.

## Tech Stack

- **Frontend:** Vanilla HTML/CSS/JS — single `index.html` (~9,150 lines), no framework
- **Backend:** n8n Cloud (flowbound.app.n8n.cloud) — 16 workflows + 1 orchestrator
- **Database:** Supabase (PostgreSQL + Auth + Realtime + RLS)
- **Hosting:** Vercel (static site)
- **AI:** Claude (content), Perplexity (research/trends), image/video generation
- **Design:** Premium glassmorphism aesthetic — frosted glass cards, animated gradient orbs, green (#16a34a) + purple (#7c3aed) accents

## Architecture

- Config-driven via `config.js` — auto-detects dev/prod by hostname
- Auth: Supabase email/password → JWT → `authenticatedFetch()` → n8n webhooks with Auth Validator
- All API keys live in n8n credential store, never in frontend
- Row-Level Security in Supabase for multi-tenant isolation

## File Structure

```
index.html          — Main app (all HTML/CSS/JS)
config.js           — Supabase + n8n endpoint config
vercel.json         — Deployment config
workflows/          — n8n workflow JSONs (01-14)
supabase/           — Config, migrations, tests
scripts/            — Deployment/test scripts
tests/              — Verification docs
.planning/          — GSD planning artifacts (PROJECT.md, ROADMAP.md, STATE.md)
```

## Key Workflows (n8n)

01-icp-analyzer, 02-theme-generator, 03-themes-list, 04-content-studio, 05-content-submit, 06-approval-list, 07-approval-action, 08-clear-pending, 09-calendar-sync, 10-chat, 11-image-generator, 12-video-script-builder, 13-video-creator, 14-pipeline-orchestrator, 15-generate-topics, 16-regenerate-topic

## Current State (March 2026)

- **v3 Revision Spec M1 in progress** — restructured from 5 steps to 7 sections
- 7-section app flow: Login → Business Profile → ICP Output → Products → Campaign Setup → Weekly Topics → Content Review → Posting Calendar
- Business analysis decoupled from campaign planning (Section 1 vs Section 4)
- Campaign Theme (single for all weeks) replaces per-week storytelling theme
- Brand Voice + Document Upload in Section 4 (Campaign Setup)
- Image themes (Product on Model, Hero Shot, Nature) in Section 6
- Image-before-approval gate, inline post editing, regeneration popup
- Date-based week navigation (WeekNav) with partial week support across Sections 5-7
- Fixed stats bar at bottom with clickable navigation
- Zernio integration planned for Milestone 2 (DB tables created, API calls deferred)
- New DB tables: image_themes, brand_documents, platform_connections
- ICP generation: Jina scraping → Perplexity research ×3 → Claude synthesis → Supabase
- Content generation: variable topics/week × selected platforms = dynamic content items per week

## Obsidian Second Brain (REQUIRED)

**Before making ANY changes to this project, you MUST read the relevant Obsidian brain docs first.**

Brain vault: `/Users/andrewgershan/Documents/eluxr-brain/01_Projects/eluxr/architecture/`

| Changing... | Read first |
|-------------|-----------|
| index.html JS functions | `frontend-functions.md` |
| n8n webhook payloads | `api-contracts.md` |
| n8n workflow nodes | `n8n-workflows.md` |
| Database schema | `data-model.md` |
| Content generation flow | `creative-pipeline.md` |
| Section structure/navigation | `system-overview.md`, `index-html-map.md` |
| Auth or data flow | `auth-flow.md`, `dependency-map.md` |

This is non-negotiable. The brain has architecture docs, data flow diagrams, and API contracts that prevent bugs caused by missing context (e.g., forgetting to pass data through a chain of n8n nodes). Read first, code second.

## Coding Conventions

- No build step — edit `index.html` directly
- CSS variables in `:root` for theming (glass, green, purple tokens)
- All UI uses glassmorphism: `backdrop-filter: blur()`, `rgba()` backgrounds, inset glows
- Smooth transitions: `cubic-bezier(0.22, 1, 0.36, 1)`, GPU-accelerated with `will-change`
- Functions are vanilla JS, no modules — all in `<script>` tags in index.html
- Supabase client loaded via CDN
- Test with `python3 -m http.server 8888` or `npx serve .`

## Services

| Service | Location |
|---------|----------|
| n8n Cloud | flowbound.app.n8n.cloud |
| Supabase | Configured in config.js |
| GitHub | github.com/anygee133-arch/eluxr-v3 |
| Vercel | Static deployment target |
