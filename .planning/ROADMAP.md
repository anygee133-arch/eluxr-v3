# Roadmap: ELUXR Magic Content Engine v2

**Created:** 2026-02-27
**Depth:** Comprehensive
**Phases:** 11
**Coverage:** 50/50 v2 requirements mapped

## Overview

ELUXR v2 transforms a working single-user AI content pipeline into a multi-tenant SaaS. The roadmap follows a strict dependency chain: security and database foundation first (everything depends on Supabase), then authentication (gates all user access), then backend decomposition (maintainability + async patterns), then frontend migration (connects to new data layer), and finally feature delivery in natural order -- content generation, approval, calendar, chat, tools, and trend intelligence.

The build order is driven by three hard constraints: (1) the KIE API key must be secured before any workflow splitting to prevent propagating the flaw, (2) the database schema and RLS must exist before any feature writes data, and (3) the async pipeline pattern must be operational before content generation to prevent execution timeouts.

---

## Phase 1: Security Hardening + Database Foundation

**Goal:** The Supabase database exists with tenant-isolated tables, and all API keys are secured in the n8n credential store -- establishing the infrastructure every subsequent phase depends on.

**Dependencies:** None (first phase)

**Requirements:**
- INFRA-01: Supabase database with tables for users, ICP data, themes, content queue, and chat history
- INFRA-02: Row-Level Security (RLS) policies on all tables enforcing tenant isolation via user_id
- INFRA-05: All API keys stored in n8n credential store -- zero hardcoded secrets (fix KIE key in 4 nodes)

**Success Criteria:**
1. Supabase project is live with all 8+ tables created, each containing a `user_id` column referencing `auth.users(id)`
2. RLS is enabled on every table with `USING (auth.uid() = user_id)` policies -- a query from User A returns zero rows belonging to User B
3. The KIE API key (`7f48c3109ae4ee6aee94ba7389bdcaa4`) no longer appears anywhere in any n8n workflow JSON -- all API keys use n8n credential store
4. Two test accounts exist in Supabase and tenant isolation is verified with manual cross-account queries
5. Supabase CLI migration files exist for every schema change (no dashboard-only edits)

**Research Flags:** LOW -- Supabase multi-tenant RLS patterns are well-documented.

**Pitfalls:** CRIT-1 (tenant isolation), CRIT-2 (hardcoded KIE key), CRIT-4 (RLS performance), MOD-7 (migration strategy)

**Plans:** 3 plans in 2 waves

Plans:
- [x] 01-01-PLAN.md -- Supabase schema migration (10 tables, RLS, indexes, trigger)
- [x] 01-02-PLAN.md -- n8n credential migration (KIE API key + Supabase service role)
- [x] 01-03-PLAN.md -- Tenant isolation verification (test accounts + cross-tenant queries)

---

## Phase 2: Authentication

**Goal:** Users can sign up, log in, reset passwords, and access a protected dashboard -- with every n8n webhook validating their identity before processing requests.

**Dependencies:** Phase 1 (database tables + RLS must exist)

**Requirements:**
- AUTH-01: User can sign up with email and password
- AUTH-02: User can log in and access their dashboard
- AUTH-03: User can reset password via email link
- AUTH-04: Unauthenticated users are redirected to login page (protected routes)
- AUTH-05: Each user's data is isolated -- users cannot see other tenants' content
- INFRA-04: Every n8n webhook validates Supabase JWT before processing requests

**Success Criteria:**
1. A new user can sign up with email/password, receive confirmation, and land on their dashboard
2. A returning user can log in and their session persists across browser tabs (JWT in memory, not localStorage)
3. A user who forgot their password receives a reset email and can set a new password
4. Visiting any dashboard URL while logged out redirects to the login page
5. An Auth Validator sub-workflow exists in n8n that all webhook workflows call as their first step -- requests without valid JWT return 401

**Research Flags:** MEDIUM -- CORS behavior of n8n Cloud webhooks with auth headers needs early verification.

**Pitfalls:** CRIT-3 (unauthenticated webhooks), HIGH-3 (CORS with auth headers), MOD-1 (token refresh in vanilla JS)

**Plans:** 5 plans in 4 waves

Plans:
- [x] 02-01-PLAN.md -- CORS test, Supabase auth config, n8n JWT credential
- [x] 02-02-PLAN.md -- Auth Validator sub-workflow in n8n (INFRA-04)
- [x] 02-03-PLAN.md -- Frontend auth UI: login, signup, password reset, protected routes
- [x] 02-04-PLAN.md -- authenticatedFetch() wrapper + webhook integration (all 13 endpoints)
- [x] 02-05-PLAN.md -- End-to-end verification of all Phase 2 success criteria

---

## Phase 3: Workflow Decomposition + Backend Bug Fixes [COMPLETE]

**Goal:** The monolithic 116KB n8n workflow is split into focused, independently testable sub-workflows -- with all known backend bugs fixed before new feature development begins.

**Dependencies:** Phase 1 (Supabase tables to write to), Phase 2 (Auth Validator sub-workflow)

**Requirements:**
- INFRA-03: All 16 Google Sheets nodes in n8n replaced with Supabase queries
- INFRA-06: n8n monolithic workflow split into separate per-phase sub-workflows
- PIPE-07: Fix Switch node routing bug -- ensure text/image/video branches are mutually exclusive
- TOOL-05: Fix image polling (replace hacky setTimeout with proper polling/wait pattern)
- TOOL-06: Fix video branch wiring (true/false paths appear inverted in v1)

**Success Criteria:**
1. The monolithic workflow is replaced by 13 focused sub-workflows, each independently deployable and testable
2. No n8n workflow references Google Sheets -- all data reads/writes target Supabase
3. The Switch node in the Content Studio workflow routes to exactly one branch (text OR image OR video) per content item -- never triggers multiple branches simultaneously
4. Image generation uses proper n8n Wait/polling nodes instead of `setTimeout(35000)` -- completion is detected, not guessed
5. The video generation branch fires on the correct true/false condition (not inverted)

**Research Flags:** HIGH -- Verify n8n Cloud execution limits, Supabase native node capabilities, sub-workflow data size limits.

**Pitfalls:** HIGH-2 (data passing between sub-workflows), MOD-5 (Switch routing)

**Plans:** 6 plans in 4 waves

Plans:
- [x] 03-01-PLAN.md -- Prerequisites: n8n plan verification, Supabase API validation, content_type tracing, theme insert design
- [x] 03-02-PLAN.md -- Build sub-workflows 01-05 (ICP, Themes, Content Studio) + PIPE-07 Switch fix
- [x] 03-03-PLAN.md -- Build sub-workflows 06-10 (Approval, Calendar, Chat) + Sheets collapse
- [x] 03-04-PLAN.md -- Build sub-workflows 11-13 (Standalone Tools) + TOOL-05 polling fix + TOOL-06 video wiring fix
- [x] 03-05-PLAN.md -- Cutover: activate sub-workflows, deactivate monolith, update frontend URLs
- [x] 03-06-PLAN.md -- End-to-end verification of all 5 Phase 3 requirements

---

## Phase 4: Async Pipeline + Real-Time Progress Tracking

**Goal:** Long-running operations return immediately with a job ID and report real progress step-by-step via Supabase Realtime -- replacing all fake progress simulation.

**Dependencies:** Phase 3 (sub-workflows must exist to update progress)

**Requirements:**
- PROG-01: Real-time progress bar that advances when each pipeline step actually completes (not simulated)
- PROG-02: Each of 6 steps (analyze business, create themes, write posts, generate images, create videos, sync calendar) reports completion individually
- PROG-03: Checkmark appears next to each completed step
- PROG-04: Progress state persisted in Supabase via Realtime -- survives page refresh
- UI-05: Remove fake "estimated time remaining" from progress bar

**Success Criteria:**
1. When a user triggers content generation, the webhook returns within 2 seconds with a session ID (HTTP 202) -- the browser never waits for the full pipeline
2. Each of the 6 pipeline steps updates its status in `pipeline_runs` and the frontend receives the update via Supabase Realtime WebSocket within 3 seconds
3. The progress bar advances only when real steps complete -- no simulated timing, no "estimated time remaining" text
4. A checkmark icon appears next to each step name as it completes
5. Refreshing the page mid-generation restores the current progress state from Supabase (not reset to zero)

**Research Flags:** MEDIUM -- Verify Supabase Realtime connection limits on the chosen plan tier.

**Pitfalls:** CRIT-5 (execution timeouts), HIGH-6 (webhook response timeouts)

**Plans:** 3 plans in 2 waves

Plans:
- [x] 04-01-PLAN.md -- Build n8n Pipeline Orchestrator workflow (respond 202, execute 6 steps with progress updates)
- [x] 04-02-PLAN.md -- Frontend Realtime progress UI (replace fake simulation with Supabase Realtime subscription)
- [x] 04-03-PLAN.md -- E2E verification of all 5 Phase 4 success criteria + user walkthrough

---

## Phase 5: Frontend Migration + UI Polish

**Goal:** The frontend is rebuilt to use Supabase as its single source of truth, enhanced with premium animations, and deployed to static hosting -- ready to display real data from the pipeline.

**Dependencies:** Phase 2 (auth UI), Phase 4 (Realtime subscriptions for progress)

**Requirements:**
- UI-01: Premium animations -- staggered reveals, glassmorphism touches, smooth transitions
- UI-02: Keep existing color scheme (#16a34a green, #0f172a dark) and 3-tab layout
- UI-03: Fix CSS stagger animation classes 5-6 (only 1-4 defined in v1)
- UI-04: Store ICP summary from Phase 1 response in frontend state (currently lost)
- UI-06: Deploy frontend to Vercel or Netlify as static site

**Success Criteria:**
1. All content data loads from Supabase queries -- no `generateMockData()`, no `saveSession()` to localStorage, no global mutable content arrays
2. The 3-tab layout (Setup/Generate/Calendar) is preserved with the existing green (#16a34a) and dark (#0f172a) color scheme
3. Page elements animate in with staggered reveals (classes 1 through 10 all work), glassmorphism card effects are visible, and transitions between tabs are smooth
4. The ICP summary from the analysis step is stored in frontend state and displayed on the Setup tab without disappearing on navigation
5. The frontend is live on Vercel or Netlify with `window.ELUXR_CONFIG` pointing to production Supabase and n8n endpoints

**Research Flags:** LOW -- Standard patterns, clear migration sequence.

**Pitfalls:** HIGH-5 (state desync), MIN-2 (single file architecture), MIN-3 (generic error messages)

**Plans:** 4 plans in 4 waves

Plans:
- [ ] 05-01-PLAN.md -- CSS animations, stagger fix, glassmorphism, tab transitions, config.js, Vercel files
- [ ] 05-02-PLAN.md -- Data layer migration: Supabase replaces localStorage, mock data, n8n webhook reads
- [ ] 05-03-PLAN.md -- ICP card on Setup tab: load from Supabase, structured display, skeleton loading
- [ ] 05-04-PLAN.md -- E2E verification of all 5 success criteria + Vercel deployment + user checkpoint

---

## Phase 6: Content Pipeline

**Goal:** A user can enter their business URL and receive a complete 30-day, 4-platform content campaign -- ICP analysis, Netflix-model themes, and daily posts with images and video scripts -- all stored per-tenant in Supabase.

**Dependencies:** Phase 3 (split workflows), Phase 4 (async pattern), Phase 5 (frontend to trigger/display)

**Requirements:**
- PIPE-01: ICP analysis via Perplexity market research + Claude synthesis, stored in Supabase per-tenant
- PIPE-02: 30-day Netflix-model theme generation with 4 weekly themed "shows" per month
- PIPE-03: Daily content generation producing platform-specific posts for LinkedIn, Instagram, X, YouTube
- PIPE-04: AI image prompt generation for each post via Claude
- PIPE-05: Video script generation (hook/setup/value/CTA structure) via Claude
- PIPE-06: One post per platform per day (4 platforms = 4 posts/day max)

**Success Criteria:**
1. A user enters their business URL and industry, triggers generation, and receives an ICP analysis stored in the `icps` table -- viewable on the Setup tab
2. The ICP feeds into theme generation producing exactly 4 weekly "shows" (themes) per campaign month, stored in the `themes` table
3. Content generation produces one post per platform per day (4 posts/day, ~120 posts/month) with platform-specific formatting (LinkedIn professional tone, Instagram visual-first, X concise, YouTube long-form)
4. Each text post has an accompanying AI-generated image prompt, and image generation via KIE produces viewable images stored as URLs in `content_items`
5. Video-eligible posts have structured scripts (hook/setup/value/CTA) generated via Claude, stored in `content_items`

**Research Flags:** MEDIUM -- Verify n8n Cloud execution limits for batch sizes, KIE API async polling pattern.

**Pitfalls:** CRIT-5 (execution limits), HIGH-4 (AI response parsing), MOD-3 (hallucinated research), MOD-6 (rate limits)

**Plans:** 1/6 plans executed

Plans:
- [ ] 06-01-PLAN.md -- Schema migration (products table + column additions) + orchestrator callback restructure
- [ ] 06-02-PLAN.md -- ICP Analyzer overhaul (Jina scraping + Perplexity research + Claude synthesis + products)
- [ ] 06-03-PLAN.md -- Frontend: products card, platform selector, month selector, updated pipeline trigger
- [ ] 06-04-PLAN.md -- Theme Generator overhaul (Netflix model, show naming, product assignment, progressive arc)
- [ ] 06-05-PLAN.md -- Content Studio overhaul (weekly batch posts + hero images + video scripts + trending audio)
- [ ] 06-06-PLAN.md -- E2E verification: migration, deployment, pipeline test, user checkpoint

---

## Phase 7: Approval Queue

**Goal:** Users can review all generated content, approve or reject individual items or batches, edit text before approving, and manage their content pipeline from pending to published.

**Dependencies:** Phase 6 (content must exist to approve)

**Requirements:**
- APPR-01: User can view all content organized by status (pending/approved/rejected)
- APPR-02: User can approve individual content items
- APPR-03: User can reject individual content items
- APPR-04: User can edit content text before approving
- APPR-05: User can batch approve/reject multiple items
- APPR-06: Fix schedule edit ID mismatch bug (schedule-edit-content vs schedule-edit-content-{idx})

**Success Criteria:**
1. The approval queue displays all generated content organized into pending, approved, and rejected sections -- with accurate counts
2. A user can click approve on a single content item and its status updates to "approved" in real time (reflected in both the queue and calendar)
3. A user can click reject on a single content item and its status updates to "rejected"
4. A user can edit the text of a content item inline and then approve the edited version -- the edited text persists in Supabase
5. A user can select multiple content items via checkboxes and batch approve or batch reject them in one action

**Research Flags:** LOW -- Standard CRUD patterns.

**Pitfalls:** APPR-06 ID mismatch bug must be fixed (schedule-edit-content vs schedule-edit-content-{idx}).

---

## Phase 8: Calendar + Scheduling

**Goal:** Users can visualize their content calendar in multiple views, see platform-specific scheduling at a glance, sync approved content to Google Calendar, and export their data.

**Dependencies:** Phase 7 (approved content to display on calendar)

**Requirements:**
- CAL-01: Monthly calendar view showing content per day with platform-colored dots and status indicators
- CAL-02: Weekly content schedule grid with day cards showing theme, platform, and status
- CAL-03: Google Calendar sync for approved content (post scheduled events)
- CAL-04: CSV export of all content data

**Success Criteria:**
1. A monthly calendar view renders with colored dots per platform (distinct colors for LinkedIn, Instagram, X, YouTube) and status indicators (pending/approved/rejected) on each day
2. A weekly grid view shows day cards with the theme name, platform icon, post preview, and approval status
3. Approved content syncs to Google Calendar as scheduled events (or exports as .ics file if per-user OAuth is infeasible)
4. A user can export all content data as a CSV file containing post text, platform, status, scheduled date, and media URLs

**Research Flags:** MEDIUM -- Google Calendar per-user OAuth feasibility needs verification. May descope to .ics export.

**Pitfalls:** MOD-4 (Google Calendar multi-tenant -- likely needs .ics fallback)

---

## Phase 9: AI Chat

**Goal:** Users have a unified AI chatbot accessible from every tab that understands their business context and adapts its behavior based on where the user is in the workflow.

**Dependencies:** Phase 6 (content data for chat context), Phase 2 (auth for chat persistence)

**Requirements:**
- CHAT-01: Unified chatbot accessible from all tabs (single conversation thread)
- CHAT-02: Chat is context-aware -- loads user's ICP, themes, and content data before responding
- CHAT-03: Chat adjusts behavior based on which tab the user is on (setup/generate/calendar)

**Success Criteria:**
1. A single chat widget appears on all three tabs (Setup/Generate/Calendar) with a persistent conversation thread -- messages from the Setup tab are visible on the Generate tab
2. The chatbot references the user's actual ICP, themes, and content data in its responses -- not generic advice (e.g., "Based on your ICP targeting [specific audience]...")
3. On the Setup tab, the chat focuses on business analysis and ICP refinement; on Generate, it discusses content and themes; on Calendar, it helps with scheduling and approvals

**Research Flags:** LOW -- Chat patterns are straightforward with Supabase-stored context.

**Pitfalls:** None critical. Chat memory persistence deferred to post-v2 (CHAT-F02).

---

## Phase 10: Standalone Tools

**Goal:** Users can independently generate video scripts, images, videos, and content posts outside the main pipeline -- with proper authentication and output history.

**Dependencies:** Phase 2 (auth), Phase 3 (tool workflows migrated)

**Requirements:**
- TOOL-01: Video Script Builder -- generate structured video scripts from topic, platform, style
- TOOL-02: Image Generator -- generate images via KIE Nano Banana Pro with aspect ratio and style options
- TOOL-03: Video Creator -- generate videos via KIE Veo with prompt and reference image support
- TOOL-04: Content Generator -- generate individual posts for any platform with tone/length options

**Success Criteria:**
1. A user can open the Video Script Builder, enter a topic/platform/style, and receive a structured video script (hook/setup/value/CTA) saved to `tool_outputs`
2. A user can open the Image Generator, enter a prompt with aspect ratio and style options, and receive a generated image displayed inline -- with proper polling (not setTimeout)
3. A user can open the Video Creator, enter a prompt with optional reference image, and receive a generated video
4. A user can open the Content Generator, select a platform and tone/length, and receive a formatted post ready to copy or add to their campaign

**Research Flags:** LOW -- Tools already exist in v1, just need auth + Supabase migration.

**Pitfalls:** None beyond already-fixed bugs from Phase 3.

---

## Phase 11: Trend Intelligence

**Goal:** The system proactively researches trending topics in each user's industry weekly and surfaces opportunities for content pivots -- keeping campaigns fresh and relevant.

**Dependencies:** Phase 6 (ICP data for industry context), Phase 5 (frontend for notifications)

**Requirements:**
- TREND-01: Weekly trend research via Perplexity scanning for trending topics in user's industry
- TREND-02: Dynamic mid-month content pivots -- suggest swapping upcoming posts when major trends detected
- TREND-03: Dashboard notification banner when trending topics are detected

**Success Criteria:**
1. A weekly scheduled n8n workflow runs Perplexity research against each user's ICP industry and stores scored trend alerts in the `trend_alerts` table
2. When a high-relevance trend is detected, the dashboard shows a notification banner with the trend topic, relevance explanation, and a "pivot content" action button
3. A user can accept a trend pivot suggestion and the system proposes replacement posts for upcoming unscheduled days -- without overwriting already-approved content

**Research Flags:** MEDIUM -- Perplexity API rate limits for batch processing across tenants.

**Pitfalls:** None critical. This is an enhancement layer on top of stable infrastructure.

---

## Progress

| Phase | Name | Requirements | Status |
|-------|------|-------------|--------|
| 1 | Security Hardening + Database Foundation | INFRA-01, INFRA-02, INFRA-05 | Complete |
| 2 | Authentication | AUTH-01, AUTH-02, AUTH-03, AUTH-04, AUTH-05, INFRA-04 | Complete |
| 3 | Workflow Decomposition + Backend Bug Fixes | INFRA-03, INFRA-06, PIPE-07, TOOL-05, TOOL-06 | Complete |
| 4 | Async Pipeline + Real-Time Progress Tracking | PROG-01, PROG-02, PROG-03, PROG-04, UI-05 | Complete |
| 5 | Frontend Migration + UI Polish | UI-01, UI-02, UI-03, UI-04, UI-06 | Not Started |
| 6 | 1/6 | In Progress|  |
| 7 | Approval Queue | APPR-01, APPR-02, APPR-03, APPR-04, APPR-05, APPR-06 | Not Started |
| 8 | Calendar + Scheduling | CAL-01, CAL-02, CAL-03, CAL-04 | Not Started |
| 9 | AI Chat | CHAT-01, CHAT-02, CHAT-03 | Not Started |
| 10 | Standalone Tools | TOOL-01, TOOL-02, TOOL-03, TOOL-04 | Not Started |
| 11 | Trend Intelligence | TREND-01, TREND-02, TREND-03 | Not Started |

---

## Dependency Graph

```
Phase 1 (Foundation)
  |
  v
Phase 2 (Auth)
  |
  +---> Phase 3 (Workflow Decomposition)
  |       |
  |       v
  |     Phase 4 (Progress Tracking)
  |       |
  |       v
  |     Phase 5 (Frontend Migration)
  |       |
  |       v
  |     Phase 6 (Content Pipeline)
  |       |
  |       v
  |     Phase 7 (Approval Queue)
  |       |
  |       v
  |     Phase 8 (Calendar)
  |
  +---> Phase 9 (AI Chat) -- after Phase 6
  +---> Phase 10 (Standalone Tools) -- after Phase 3
  +---> Phase 11 (Trend Intelligence) -- after Phase 6
```

**Critical path:** 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 8
**Parallel opportunities:** Phase 9, 10, 11 can start once their dependencies are met.

---
*Roadmap created: 2026-02-27*
*Last updated: 2026-03-03*
