# ELUXR Magic Content Engine v2

## What This Is

A multi-tenant SaaS social media marketing agent that automates organic content creation for businesses. Companies enter their website URL and industry, get their Ideal Customer Profile (ICP) analyzed via AI market research, and receive a complete 30-day social media campaign following the Netflix model — 4 weekly themed "shows" per month with hooks and continuity across posts. Covers LinkedIn, Instagram, X/Twitter, and YouTube with AI-generated text, images, and video scripts.

## Core Value

A business can go from entering their URL to having a full month of platform-specific, trend-aware social media content generated, reviewed, and ready to post — with zero manual content creation.

## Requirements

### Validated

- v ICP analysis via Perplexity market research + Claude synthesis — existing (v1, needs migration to Supabase)
- v 30-day Netflix model theme generation with weekly shows — existing (v1, needs migration to Supabase)
- v Daily content generation (text posts, image prompts, video scripts) — existing (v1, needs migration to Supabase)
- v Approval queue (approve/reject/edit content) — existing (v1, needs migration to Supabase)
- v Google Calendar sync for approved content — existing (v1)
- v Standalone tools: Video Script Builder, Image Generator, Video Creator, Content Generator — existing (v1)
- v AI chat assistant per phase — existing (v1, being upgraded)
- v 3-tab UI: Setup, Generate, Calendar — existing (v1)

### Active

- [ ] **AUTH**: Multi-tenant Supabase Auth (email + password signup/login)
- [ ] **DB**: Migrate all data storage from Google Sheets to Supabase (ICP, Themes, Approval Queue, Chat History)
- [ ] **DB**: Design Supabase schema with Row-Level Security for multi-tenant isolation
- [ ] **SECURITY**: Move ALL API keys into n8n credential store — zero hardcoded keys
- [ ] **PROGRESS**: Real-time progress tracking — each of 6 pipeline steps reports actual completion to frontend
- [ ] **CHAT**: Unified action-capable chatbot across all tabs with persistent memory in Supabase
- [ ] **CHAT**: Chat can approve/reject content, regenerate posts, edit themes, trigger generation
- [ ] **TRENDS**: Weekly trend research via Perplexity with dynamic mid-month content pivots
- [ ] **TRENDS**: Dashboard notification banner + proactive chat suggestions when trends detected
- [ ] **NETFLIX**: Strengthen themed weeks structure — weekly theme with flexible individual posts within it
- [ ] **N8N**: Split monolithic workflow into separate workflows per phase (ICP, Themes, Content, Approval, Chat, Tools)
- [ ] **UI**: Premium animations — staggered reveals, glassmorphism touches, smooth transitions, wow factor
- [ ] **UI**: Keep existing color scheme (green accent #16a34a, dark #0f172a) and layout structure
- [ ] **UI**: Fix v1 bugs: progress bar fake timing, schedule edit ID mismatch, ICP summary not stored, stagger animations 5-6 undefined, video branch wiring
- [ ] **FRONTEND**: Deploy to Vercel/Netlify as static site
- [ ] **TESTING**: Automated API tests for every n8n webhook endpoint
- [ ] **VOLUME**: One post per platform per day (LinkedIn, Instagram, X, YouTube)

### Out of Scope

- Auto-publishing to social platforms — manual posting only for v2 (structure for future)
- Telegram/push notifications — dashboard-only approval flow
- TikTok and Facebook platforms — focusing on 4 core platforms (LinkedIn, Instagram, X, YouTube)
- Stripe billing / subscription tiers — free for now, structure for future
- Supabase Storage for media — using KIE-hosted URLs directly
- Video generation in content pipeline — keep as standalone tool only
- Mobile app — responsive web only

## Context

### Existing v1 Codebase

**Frontend:** Single `index.html` file (~154KB, ~2,500 lines vanilla JS). 3-tab UI (Setup/Generate/Calendar) with custom CSS using Playfair Display, DM Sans, and JetBrains Mono fonts. No frameworks. All state in localStorage + in-memory variables.

**Backend:** Single n8n workflow (`ELUXR social media Action v2 (3).json`, ~116KB) with 13 webhook endpoints, 5-phase pipeline + standalone tools. Currently stores all data in Google Sheets (spreadsheet `1zlIBLhRt_5VSe3Aw8qTp-9p5hpA8j_1ItUrvUBbULjU`).

**n8n Instance:** `flowbound.app.n8n.cloud` (cloud-hosted, MCP configured)

### External APIs (keeping all)

| Service | Purpose | Model |
|---------|---------|-------|
| Anthropic Claude | ICP generation, themes, posts, scripts, chat | claude-sonnet-4 |
| Perplexity AI | Market research, trend research | sonar-pro |
| KIE AI (Nano Banana Pro) | Image generation | nano-banana-pro |
| KIE AI (Veo) | Video generation | veo3_fast |
| Google Calendar | Post scheduling sync | Calendar API |

### Known v1 Bugs to Fix

1. Video branch wiring appears inverted in n8n (true/false paths swapped)
2. KIE API key hardcoded as plaintext Bearer token (security risk)
3. Progress bar is fake — uses simulated timing, not real step completion
4. `saveScheduleEdit()` has ID mismatch (`schedule-edit-content` vs `schedule-edit-content-{idx}`)
5. ICP summary from Phase 1 response never stored in frontend state
6. CSS stagger animation classes 5-6 undefined (only 1-4 exist)
7. Image polling uses hacky `setTimeout(35000)` instead of proper Wait node
8. Phase 4 Switch routing can trigger both image + text/video branches simultaneously

### Netflix Content Model

Each month is its own campaign. 4 weeks = 4 "shows" (themed content series). Each week has a distinct theme based on the business's products, industry trends, and content psychology. Individual posts within a themed week are flexible but stay on-theme. Posts include hooks at the end to drive continuity and audience retention across the series.

## Constraints

- **Tech Stack**: n8n backend (cloud-hosted) + vanilla HTML/CSS/JS frontend + Supabase (database + auth) — no frontend frameworks
- **AI Models**: Claude Sonnet 4 for all AI tasks — consistency over cost optimization
- **Platform**: 4 platforms only — LinkedIn, Instagram, X/Twitter, YouTube
- **Hosting**: Static deployment (Vercel or Netlify)
- **Security**: All API keys must live in n8n credential store — zero hardcoded secrets
- **Design**: Keep existing color scheme (#16a34a green, #0f172a dark) and 3-tab layout — enhance with animations, don't redesign

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Supabase over Google Sheets | Multi-tenant SaaS needs proper DB, RLS, auth — Sheets doesn't scale | -- Pending |
| Split n8n into per-phase workflows | Monolithic workflow is 116KB and hard to debug/maintain | -- Pending |
| Email+password auth (no OAuth) | Simpler to implement, Google OAuth not needed since Calendar sync is server-side via n8n | -- Pending |
| KIE URLs for media (no Supabase Storage) | Simpler architecture, fewer moving parts — revisit if URLs expire | -- Pending |
| One unified chatbot (not 3 per tab) | Better UX, single conversation thread, action-capable across all features | -- Pending |
| Weekly trend research (not daily/monthly) | Balance between freshness and API cost — with dynamic pivot capability for breaking trends | -- Pending |
| Real-time per-step progress | Each pipeline step updates Supabase status row, frontend polls for completion | -- Pending |
| Manual posting only | Avoid complexity of platform API integrations for v2 — structure for future auto-publish | -- Pending |
| No billing for v2 | Get product working first, add Stripe later | -- Pending |
| Premium animations | Wow factor differentiates ELUXR as a premium SaaS product | -- Pending |

---
*Last updated: 2026-02-27 after initialization*
