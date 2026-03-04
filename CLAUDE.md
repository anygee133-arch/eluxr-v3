# ELUXR Magic Content Engine v3

## What This Is

Multi-tenant SaaS social media content platform. Businesses enter their URL, get AI-powered ICP analysis, and receive a complete 30-day Netflix-model social media campaign (LinkedIn, Instagram, X, YouTube) with AI-generated text, images, and video scripts.

## Tech Stack

- **Frontend:** Vanilla HTML/CSS/JS — single `index.html` (~5400 lines), no framework
- **Backend:** n8n Cloud (flowbound.app.n8n.cloud) — 13 decomposed sub-workflows + 1 orchestrator
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

01-icp-analyzer, 02-theme-generator, 03-themes-list, 04-content-studio, 05-content-submit, 06-approval-list, 07-approval-action, 08-clear-pending, 09-calendar-sync, 10-chat, 11-image-generator, 12-video-script-builder, 13-video-creator, 14-pipeline-orchestrator

## Current State

- Phase 5 of 11 (Frontend Migration + UI Polish) — 3/4 plans complete
- Phases 1-4 complete (Security, Auth, Workflow Decomposition, Progress Tracking)
- ~50% overall (25/50 requirements done)
- Next: Plan 05-04 (E2E verification + Vercel deployment), then Phase 6 (Content Pipeline)

## Coding Conventions

- No build step — edit `index.html` directly
- CSS variables in `:root` for theming (glass, green, purple tokens)
- All UI uses glassmorphism: `backdrop-filter: blur()`, `rgba()` backgrounds, inset glows
- Smooth transitions: `cubic-bezier(0.22, 1, 0.36, 1)`, GPU-accelerated with `will-change`
- Functions are vanilla JS, no modules — all in `<script>` tags in index.html
- Supabase client loaded via CDN
- Test with `python3 -m http.server 8080` or `npx serve .`

## Services

| Service | Location |
|---------|----------|
| n8n Cloud | flowbound.app.n8n.cloud |
| Supabase | Configured in config.js |
| GitHub | github.com/anygee133-arch/eluxr-v3 |
| Vercel | Static deployment target |
