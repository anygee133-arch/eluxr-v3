# Research Summary: ELUXR Magic Content Engine v2

**Synthesized:** 2026-02-27
**Sources:** STACK.md, FEATURES.md, ARCHITECTURE.md, PITFALLS.md
**Overall Confidence:** MEDIUM-HIGH (primary sources are v1 codebase + established platform patterns; web verification unavailable)

---

## Executive Summary

ELUXR v2 is a brownfield upgrade of a working single-user AI content pipeline into a multi-tenant SaaS. The v1 system already delivers the product's core differentiators -- a Netflix-model content calendar, end-to-end AI generation pipeline (business URL to 30 days of posts, images, and videos), and phase-aware AI chat -- none of which competitors have replicated. The v2 upgrade is primarily infrastructure work: replace Google Sheets with Supabase (auth + database + realtime), decompose the monolithic 116KB n8n workflow into per-phase sub-workflows, add JWT-based authentication to every webhook, and enforce tenant isolation via Supabase Row-Level Security. The stack stays entirely within the project constraints: vanilla HTML/CSS/JS frontend, n8n Cloud backend, no framework, no build step.

The most important architectural decision is the async job pattern: n8n webhooks immediately return a job ID and process asynchronously, with the frontend tracking real progress via Supabase Realtime subscriptions rather than the current fake `simulateProgress()` timer. This pattern also solves the n8n execution timeout problem that would otherwise silently truncate long-running content generation campaigns. The migration path is additive -- the AI prompts, content model, and frontend visual design are preserved; only the data layer and security model are rebuilt from scratch.

Three issues in v1 are pre-production blockers that must be resolved before any users touch v2: the KIE API key is hardcoded in plaintext in 4 n8n nodes, all 13 webhooks accept unauthenticated requests from anywhere, and the data schema has zero tenant isolation. These are not refactors -- they are the first things to build.

---

## Stack Recommendations

### Core Technology Decisions

| Technology | Decision | Rationale |
|------------|----------|-----------|
| **Supabase** | Replace Google Sheets | Provides auth + PostgreSQL + realtime + RLS in one product. The single-service approach avoids the complexity of a separate auth provider + separate database + separate realtime layer. |
| **Supabase Auth** (email/password) | New | PROJECT.md constraint. No OAuth providers. Supabase JWTs double as the authentication token forwarded to n8n webhooks for identity verification. |
| **Supabase Realtime** | Replace `simulateProgress()` | Frontend subscribes to `pipeline_runs` table via WebSocket. n8n updates step status. Frontend receives real progress. Eliminates fake timers and webhook response timeouts. |
| **Supabase RLS** | New (tenant isolation) | Every data table gets `user_id UUID REFERENCES auth.users(id)`. Standard `USING (auth.uid() = user_id)` policies enforce isolation at the database layer. n8n writes using `service_role` key which bypasses RLS -- this is correct. |
| **n8n sub-workflows** | Replace monolithic workflow | Decompose the 116KB, 93-node, 13-webhook monolith into 13 focused workflows. Each is independently testable and debuggable. Shared sub-workflows handle JWT validation and progress updates. |
| **Vercel** | New hosting | Static HTML, no build step. `vercel.json` with `buildCommand: null`, `outputDirectory: "."`. The anon Supabase key and n8n base URL go directly in the HTML via `window.ELUXR_CONFIG`. |
| **@supabase/supabase-js@2** (CDN) | New | Loaded via ESM CDN (`esm.sh`). No npm, no bundler. Compatible with the existing no-build-step frontend. |
| **Anthropic Claude Sonnet 4** | Keep | Already in n8n credential store. `claude-sonnet-4-20250514` confirmed in v1 workflow JSON. |
| **Perplexity sonar-pro** | Keep + migrate to credential store | Currently likely hardcoded. Move to n8n Header Auth credential before v2 work begins. |
| **KIE AI (nano-banana-pro + veo3_fast)** | Keep + credential migration required | `7f48c3109ae4ee6aee94ba7389bdcaa4` is hardcoded in plaintext at 4+ nodes. This is a security blocker. |
| **Google Calendar** | Keep, but re-evaluate for multi-tenant | The v1 uses a single OAuth credential writing to the workflow owner's calendar. Per-user calendar sync requires per-user OAuth consent which n8n cannot dynamically handle. May need to descope to `.ics` export for v2. |

### What NOT to Add

The v1 constraint of "no frameworks, no build step" is correct and should be maintained. Do not add: React/Vue/Svelte, npm/Vite/webpack, GSAP, Axios, jQuery, Tailwind, or date-fns. Everything needed is achievable with vanilla JS, CSS `@keyframes`, `IntersectionObserver`, and native `fetch()`.

---

## Feature Landscape

### What ELUXR v1 Already Has (Preserve These)

| Feature | Status | Notes |
|---------|--------|-------|
| Netflix-model content calendar (4 weekly themed "shows") | STRONG | No competitor offers this. Primary moat. |
| End-to-end AI generation pipeline (URL -> 30-day campaign) | STRONG | No competitor covers the full pipeline. |
| AI image generation per post (KIE Nano Banana Pro) | WORKING | ~$0.02/image. Keep. |
| AI video generation (KIE Veo3) | WORKING | ~$0.60/video. Offer as premium tier feature. |
| ICP-driven content strategy (Perplexity + Claude) | WORKING | Unique value proposition. |
| Platform-specific content adaptation (LinkedIn/Instagram/X/YouTube) | WORKING | Becoming table stakes; ELUXR ahead of curve. |
| Approval workflow (approve/reject/edit/regenerate + batch) | SOLID | Needs role-based access for multi-tenant. |
| Real-time progress UI (6-step with animated progress bar) | PRESENT | Replace fake timers with Supabase Realtime. |
| Phase-aware AI chatbot (7 system prompts) | WORKING | Upgrade to persistent memory + action capability. |
| CSV export + Google Calendar sync | WORKING | Keep. Calendar sync needs multi-tenant redesign. |
| Standalone creative tools (video script, image gen, content gen) | WORKING | Add JWT auth and Supabase output storage. |

### Critical Gaps for Multi-Tenant SaaS Launch

| Gap | Priority | Notes |
|-----|----------|-------|
| User authentication (email/password login) | P0 | Everything depends on this. Build first. |
| Tenant-isolated database | P0 | Supabase replaces Google Sheets + localStorage. |
| Webhook authentication (JWT validation) | P0 | Security blocker. All 13 webhooks are currently unauthenticated. |
| KIE API key migration to credential store | P0 | Security blocker. Hardcoded plaintext key in production. |
| Billing / subscription management | P1 | Required before public launch. Stripe integration. |
| Media library (upload + organize brand assets) | P2 | Users need to bring existing brand visuals. |
| Platform-native content preview | P2 | Users want WYSIWYG before approving. |
| Mobile-responsive approval workflow | P2 | Content managers review on mobile. |

### Deliberate Anti-Features (Do Not Build)

- Native social media publishing (Meta/LinkedIn/X APIs): massive engineering effort, shifting API policies, Meta review required. Use CSV export + Zapier/Make integration instead.
- Social inbox / unified messaging: different product domain.
- Complex RBAC: start with three roles (Owner, Manager, Creator).
- Real-time collaborative editing: approval workflow is sufficient; posts are short.
- Stock photo library: undermines the AI generation value proposition.

### Recommended Pricing Structure

| Tier | Price | Key Limits |
|------|-------|-----------|
| Starter | $0/mo | 1 brand, 5 AI posts/month, no images/video |
| Creator | $29-39/mo | 1 brand, 30 posts, AI images, basic approval |
| Business | $79-99/mo | 3 brands, unlimited posts, limited video, 3 users |
| Agency | $199-299/mo | 10 brands, unlimited, priority generation, 10 users |

Charge per brand (not per seat). Meter video generation separately due to $0.60/video cost.

---

## Architecture Decisions

### System Topology

Three tiers with clear boundaries:

```
[Vercel: Static HTML/JS]
   |-- Direct reads: Supabase DB (RLS enforced, anon key)
   |-- Auth: Supabase Auth (email/password, JWT in memory)
   |-- Realtime: Supabase WebSocket (progress + content updates)
   |-- Writes: n8n webhooks (JWT forwarded in Authorization header)

[n8n Cloud: flowbound.app.n8n.cloud]
   |-- Validates JWT via Supabase auth.getUser() endpoint
   |-- Writes to Supabase using service_role key (bypasses RLS)
   |-- Calls: Claude API, Perplexity API, KIE API, Google Calendar
   |-- Updates pipeline_runs table (triggers Realtime to frontend)

[Supabase: Hosted PostgreSQL + Auth + Realtime]
   |-- All persistent data (isolated by user_id + RLS)
   |-- Auth JWT issuance and session management
   |-- Realtime broadcast of database changes
```

### Component Responsibilities

**Frontend:** Auth UI, direct Supabase reads, realtime subscriptions, n8n webhook triggers. Never writes to Supabase directly. Never holds API keys.

**Supabase:** Auth, data persistence, tenant isolation (RLS), realtime progress broadcasting. Never calls AI APIs.

**n8n:** AI pipeline orchestration, external API calls, writing results to Supabase. Never serves the frontend. Does not issue JWTs -- only validates them.

### n8n Workflow Decomposition (v1 -> v2)

Break the monolithic workflow (93 nodes, 116KB, 13 webhooks) into 13 focused workflows:

| Workflow | Type | Purpose |
|----------|------|---------|
| Auth Validator | Shared sub-workflow | Called by all webhook flows as first step. Validates JWT via Supabase. |
| Progress Updater | Shared sub-workflow | UPSERT to `pipeline_runs` table. Called by pipeline flows between steps. |
| ICP Pipeline | Webhook | Phase 1: Perplexity research -> Claude ICP analysis -> Supabase UPSERT |
| Theme Generator | Webhook | Phase 2: Read ICP -> Claude Netflix themes -> Supabase INSERT |
| Content Studio | Webhook | Phase 4: Read themes -> Switch(text/image/video) -> Claude/KIE -> Supabase INSERT |
| Calendar Sync | Webhook | Phase 3: Read approved items -> Google Calendar events |
| Approval Queue | Webhook (GET+POST) | Read/update content_items status |
| Chat | Webhook | Read history+context -> Claude -> parse actions -> execute -> Supabase INSERT |
| Trend Research | Scheduled (cron) | Weekly: Perplexity per user ICP -> Claude relevance -> INSERT trend_alerts |
| Image Gen Tool | Webhook | Standalone: KIE image generation + tool_outputs save |
| Video Gen Tool | Webhook | Standalone: KIE video generation + tool_outputs save |
| Video Script Tool | Webhook | Standalone: Claude script + tool_outputs save |
| Content Gen Tool | Webhook | Standalone: Claude content + tool_outputs save |

### Key Data Flow Pattern

Supabase is the "bus" between sub-workflows -- sub-workflows read from and write to Supabase rather than passing large JSON payloads directly between them. This prevents data size limit issues and enables the progress tracking system.

**Read pattern:** Frontend reads directly from Supabase (fast, no n8n hop, RLS protects).
**Write pattern:** Frontend calls n8n webhook -> n8n validates + processes -> n8n writes to Supabase -> Supabase Realtime notifies frontend.

### Async Job Pattern (Critical Architecture Decision)

All long-running operations (ICP analysis, theme generation, content generation) must use the async pattern:

1. Webhook receives request, immediately returns `{session_id, status: "accepted"}` (HTTP 202)
2. n8n creates row in `pipeline_runs` table
3. Frontend subscribes to that row via Supabase Realtime
4. n8n processes each phase, updates `pipeline_runs` after each step
5. Frontend receives real-time updates via WebSocket
6. On completion, frontend reads results from Supabase

This pattern eliminates webhook response timeouts (PITFALL HIGH-6) and the fake progress simulation.

### Database Schema Summary

Eight tables, all with `user_id UUID REFERENCES auth.users(id)` + RLS:

- `profiles` -- extends Supabase auth.users with business data
- `icps` -- ICP analysis results (one per user)
- `campaigns` -- monthly content campaigns (one per user per month)
- `themes` -- 4 weekly shows per campaign
- `content_items` -- individual posts with status, image_url, video_url
- `pipeline_runs` -- real-time progress tracking (Realtime enabled)
- `chat_messages` + `chat_conversations` -- persistent AI memory
- `trend_alerts` -- weekly trend research results per user
- `tool_outputs` -- standalone tool history

### Security Architecture

| Secret | Location | Notes |
|--------|----------|-------|
| Supabase anon key | Frontend HTML | Safe. RLS enforces data access. |
| Supabase service_role key | n8n credential store | Never in frontend. Bypasses RLS for trusted writes. |
| User JWT | Browser memory only | Sent per-request in Authorization header. Not in localStorage. |
| Claude, Perplexity, KIE keys | n8n credential store | KIE key must be migrated from hardcoded to credential store. |

---

## Critical Pitfalls

### Top 5 Must-Prevent Pitfalls

**1. Missing tenant isolation (CRIT-1) -- Severity: CRITICAL**

The v1 schema has no concept of ownership. Migrating Google Sheets directly to Supabase without adding `user_id` to every table and enabling RLS immediately creates a system where Tenant A can read Tenant B's data. This cannot be retrofitted safely after launch.

Prevention: Design ALL tables with `user_id UUID REFERENCES auth.users(id)` before writing a single query. Enable RLS on every table at creation time. Test tenant isolation with two test accounts before any other feature work.

**2. Hardcoded KIE API key (CRIT-2) -- Severity: CRITICAL**

The key `7f48c3109ae4ee6aee94ba7389bdcaa4` is in plaintext at 4 nodes in the v1 workflow JSON. When the workflow is split into sub-workflows, this key will propagate to multiple new workflows.

Prevention: Create a Header Auth credential in n8n for KIE AI. Replace all hardcoded headers before any workflow splitting begins. Run a JSON search for `Bearer ` + alphanumeric strings before any commit.

**3. Unauthenticated webhooks (CRIT-3) -- Severity: CRITICAL**

All 13 current webhook endpoints accept requests from any caller with zero authentication. Anyone who discovers a webhook URL can generate unlimited AI content at the account's expense or manipulate any user's data.

Prevention: Build the Auth Validator sub-workflow first. Every other webhook workflow calls it as step 1. Lock `allowedOrigins` to the Vercel production domain. Test CORS with auth headers early (HIGH-3 CORS pitfall is related).

**4. n8n execution timeouts breaking the pipeline (CRIT-5) -- Severity: CRITICAL**

A 30-day content campaign (120+ Claude calls + 120 KIE image calls) can easily exceed n8n Cloud's execution time limit, silently failing mid-generation. Users see partial content with no error.

Prevention: Implement the async job pattern (webhook returns job ID immediately). Use batch-and-resume: generate in batches of 5 days, store progress in Supabase, trigger next batch. Make generation idempotent (each content piece has a unique key, re-runs skip completed items).

**5. Frontend state desync during Supabase migration (HIGH-5) -- Severity: HIGH**

The v1 frontend mixes localStorage, in-memory global variables (`contentData`, `weeklyThemes`), and API endpoint data. Incremental migration creates two sources of truth: user edits content in the calendar but the approval queue shows stale data.

Prevention: Supabase is the ONLY source of truth from day one of v2 frontend work. Remove `generateMockData()`, remove `saveSession()` localStorage writes, remove global mutable content arrays. Fetch from Supabase on demand.

### Additional High-Priority Pitfalls

- **HIGH-2 (Sub-workflow data passing):** Pass only IDs between sub-workflows. Store rich data in Supabase. Never pass 30-day content arrays between workflows.
- **HIGH-4 (AI response parsing fragility):** With 120+ chained Claude calls per campaign, even a 5% failure rate means near-certain pipeline breakage. Build a shared parsing utility with robust JSON extraction and per-item error handling before implementing content generation.
- **MOD-4 (Google Calendar multi-tenant):** The v1 writes to the workflow owner's calendar. For multi-tenant, each user needs their own Google Calendar OAuth. This is architecturally incompatible with n8n's credential model. Plan to descope to `.ics` export for v2 launch.
- **MOD-7 (Database migration strategy):** Use Supabase CLI migration files from day one. Never modify schema directly in the Dashboard for production.

---

## Recommended Build Order

### Phase 0: Security Hardening (Pre-Work, Not a Feature Phase)

Do this before any new development. These are existing vulnerabilities.

**Deliverables:**
- KIE API key migrated from hardcoded to n8n Header Auth credential
- Perplexity API key verified or migrated to credential store
- n8n workflow JSON audited: no plaintext API keys remain

**Rationale:** If the workflow JSON gets committed to version control or exported during v2 work, the key must already be safe. This takes 1-2 hours and unblocks everything.

**Pitfalls to avoid:** CRIT-2

---

### Phase 1: Supabase Foundation

**Deliverables:**
- Supabase project created
- All 8+ tables created with `user_id` columns
- RLS enabled and policies written for every table
- Supabase CLI migration files checked into project repo
- `service_role` key added to n8n credential store
- Two test accounts created; tenant isolation verified

**Rationale:** Every other phase depends on the schema. Auth cannot be built without tables. n8n sub-workflows cannot be built without knowing where to write. Build this first and get it right -- retrofitting multi-tenancy is the most expensive mistake possible.

**Pitfalls to avoid:** CRIT-1 (tenant isolation), CRIT-4 (RLS performance: keep policies to simple `user_id = auth.uid()`, index all `user_id` columns), MOD-7 (migration strategy)

**Research flag:** LOW -- Supabase multi-tenant patterns are well-documented. RLS syntax is stable. The schema design in STACK.md and ARCHITECTURE.md is production-ready.

---

### Phase 2: Authentication

**Deliverables:**
- Frontend: login/signup forms with Supabase Auth
- `supabase.auth.onAuthStateChange()` listener for session management
- `callN8n()` wrapper that attaches JWT to every webhook request
- Auth Validator sub-workflow in n8n (validates JWT via Supabase `auth.getUser()`)
- Frontend redirects: logged-out users see login, logged-in users see dashboard
- CORS verified: auth headers work from Vercel domain to n8n Cloud webhooks

**Rationale:** Auth gates access to everything. The Auth Validator sub-workflow is a shared dependency of all 11 other webhook workflows -- build it before any pipeline workflow.

**Pitfalls to avoid:** CRIT-3 (unauthenticated webhooks), HIGH-3 (CORS with auth headers -- test early before full frontend is built), MOD-1 (token refresh in vanilla JS)

**Research flag:** MEDIUM -- JWT validation via Supabase HTTP endpoint is straightforward. CORS behavior of n8n Cloud webhooks should be verified early in development.

---

### Phase 3: n8n Workflow Decomposition

**Deliverables:**
- 13 focused sub-workflows replacing the monolithic v1
- Progress Updater sub-workflow operational
- Async job pattern implemented: all webhooks return job ID within 2 seconds
- `pipeline_runs` table enabled for Supabase Realtime
- Frontend subscribes to progress via Supabase Realtime (replaces `simulateProgress()`)
- Polling fallback implemented for Realtime failures
- Shared JSON parsing utility built for AI responses
- Switch node routing bugs fixed (mutually exclusive conditions)
- All credentials configured in each sub-workflow independently

**Rationale:** The monolithic workflow is unmaintainable and will fail for real users due to execution timeouts. This phase is the core technical upgrade. The async job pattern and batch processing must be designed before implementation starts.

**Pitfalls to avoid:** CRIT-5 (execution timeouts), HIGH-2 (data passing between sub-workflows), HIGH-4 (AI response parsing), HIGH-6 (webhook response timeouts), MOD-5 (Switch routing bugs)

**Research flag:** HIGH -- Verify n8n Cloud plan execution limits before designing batch sizes. Verify n8n Supabase native node capabilities vs HTTP Request fallback. Verify sub-workflow data size limits.

---

### Phase 4: Frontend Migration

**Deliverables:**
- Single HTML file split into ES modules: `auth.js`, `supabase.js`, `pipeline.js`, `calendar.js`, `chat.js`, `approvals.js`
- All global mutable state (`contentData`, `weeklyThemes`, etc.) removed
- `generateMockData()` removed; real loading states and error messages replace it
- `saveSession()` localStorage writes replaced with Supabase reads
- Supabase as single source of truth for all content state
- Error classification system (auth errors -> login, rate limit errors -> retry timer, etc.)
- Stagger animation classes fixed (generate up to `.stagger-10`)
- Multi-tenant Supabase queries: all reads filtered by `user_id` via RLS

**Rationale:** The frontend migration must happen atomically (not incrementally) to avoid state desync. Splitting into modules first -- before adding features -- prevents the 5,000-line monolith problem.

**Pitfalls to avoid:** HIGH-5 (state desync), MIN-2 (single file architecture), MIN-3 (generic error messages)

**Research flag:** LOW -- Standard patterns. Frontend migration sequence is clear.

---

### Phase 5: Content Pipeline Per-Tenant

**Deliverables:**
- Phase 1 (ICP) workflow: Perplexity -> Claude -> Supabase `icps` table, scoped to authenticated user
- Phase 2 (Themes) workflow: reads ICP -> Claude Netflix themes -> `campaigns` + `themes` tables
- Phase 4 (Content Studio) workflow: batch generation (5 days/execution), idempotent content keys, Switch routing fixed
- Image generation with polling pattern (KIE jobs are async)
- Per-tenant rate limiting (Supabase-based request counting)
- ICP editing capability (users can override AI-generated ICP before content generation)

**Rationale:** The content pipeline is the product. Phase 5 is where the v1 AI capabilities become v2 multi-tenant features. The batch-and-resume pattern for content generation is the critical implementation detail.

**Pitfalls to avoid:** CRIT-5 (execution limits), HIGH-4 (AI parsing), MOD-3 (hallucinated market research -- add date constraints to Perplexity prompts, source attribution in ICP output), MOD-6 (per-tenant rate limits)

**Research flag:** MEDIUM -- Verify current n8n Cloud execution limits for the specific plan. Verify KIE API async polling pattern and timeout behavior.

---

### Phase 6: Approval Workflow + Calendar

**Deliverables:**
- Role-based approval: Owner can approve, Manager can approve, Creator cannot
- Approval notification (in-app indicator for pending items)
- Inline feedback comments on rejected posts
- Calendar: drag-and-drop rescheduling (reschedules `scheduled_date` in Supabase)
- Calendar: Day/Week/Month view toggle
- Calendar: Platform filter (show only LinkedIn posts, etc.)
- Google Calendar sync: evaluate and either implement per-user OAuth flow or replace with `.ics` export

**Rationale:** The approval workflow is table stakes for team use. Calendar UX gaps (drag-and-drop, filters) are expected by content managers who have used Buffer/Hootsuite. Google Calendar sync needs architectural decision before implementation.

**Pitfalls to avoid:** MOD-4 (Google Calendar per-user OAuth -- likely needs to be descoped to .ics export)

**Research flag:** LOW for approval workflow. MEDIUM for Google Calendar (verify if per-user OAuth token storage in Supabase + dynamic credential switching in n8n is feasible, or descope).

---

### Phase 7: Billing and Launch Preparation

**Deliverables:**
- Stripe integration (Checkout for signup, Customer Portal for management)
- Plan-based feature gating (video generation is premium tier only)
- Usage metering for video generation (credit-based)
- Vercel production deployment configured
- Environment configuration (`window.ELUXR_CONFIG`) for production vs. staging
- Supabase staging project mirroring production schema
- KIE URL longevity test completed (determine if URL re-hosting is needed)

**Rationale:** Billing must be in place before any public users access the product. Stripe Checkout minimizes PCI scope. Feature gating on video generation controls the highest per-unit cost.

**Pitfalls to avoid:** MOD-2 (KIE URL expiry -- test before launch, not after)

**Research flag:** LOW -- Stripe integration patterns are well-established. Vercel static deployment is straightforward.

---

### Phase 8: Intelligence Layer (Post-Launch)

**Deliverables:**
- Weekly trend research workflow (scheduled cron, Perplexity per-user ICP, Claude relevance scoring)
- Trend alerts in frontend (notification banner with suggested content pivots)
- Persistent AI chat memory (conversation history persisted, loaded as context)
- Enhanced brand voice (auto-detect from business URL, fine-tuning interface)
- Netflix model enhancements: episode numbering, show analytics (requires analytics infra)

**Rationale:** These features require a stable multi-tenant core and real user data to be meaningful. Trend research is valuable but not launch-blocking. Persistent chat memory requires the chat infrastructure from Phase 3 to be solid first.

**Research flag:** MEDIUM -- Trend research scheduling and per-tenant processing at scale. Verify Perplexity API rate limits for batch processing across all tenants.

---

## Confidence Assessment

| Area | Confidence | Basis |
|------|------------|-------|
| Stack choices | HIGH | Driven by existing v1 codebase constraints and well-established Supabase/n8n patterns |
| Feature categorization | HIGH | Cross-referenced against 6 competitors from direct v1 code review |
| Architecture (3-tier, RLS, async job) | HIGH | Standard patterns; Supabase multi-tenant RLS is well-documented |
| n8n sub-workflow decomposition | MEDIUM-HIGH | Pattern is established; exact data size limits and execution limits need plan verification |
| CORS behavior of n8n Cloud webhooks | MEDIUM | Known behavior but must be tested early with auth headers |
| Google Calendar multi-tenant | LOW | Current v1 approach is fundamentally incompatible; redesign or descope required |
| Pricing recommendations | LOW | Based on competitor pricing from training data; verify before launch |
| KIE URL longevity | LOW | Unknown; must be tested empirically |

---

## Open Questions Requiring Verification

| Question | Why It Matters | When to Resolve |
|----------|---------------|----------------|
| What are the exact execution time limits for the current n8n Cloud plan? | Determines batch size for content generation (5-day batches assumed) | Before Phase 3 |
| Does the n8n Supabase native node support UPSERT/UPDATE? | May replace HTTP Request nodes for Supabase writes, simplifying workflow code | Before Phase 3 |
| Do n8n Cloud Code nodes have access to any npm modules or only n8n built-ins? | Affects JWT validation approach (base64 decode vs. proper library) | Before Phase 2 |
| Does n8n Cloud handle OPTIONS preflight for webhooks with `allowedOrigins` set? | If not, a proxy layer is needed between Vercel and n8n | Very early in Phase 2 |
| What are Supabase Realtime connection limits on the chosen plan tier? | Determines if single-channel-per-user multiplexing is required | Before Phase 3 |
| How long do KIE AI image/video URLs remain accessible? | Determines if Supabase Storage is needed for media re-hosting | Before Phase 7 launch |
| Has any competitor launched a Netflix-model content feature since May 2025? | Affects competitive positioning; verifies if primary moat is still unique | Before Phase 7 launch |
| What are current KIE API rate limits and pricing (post-May 2025)? | Affects per-tenant rate limiting design and pricing tier math | Before Phase 5 |
| Is per-user Google Calendar OAuth feasible via n8n credential store, or must it be descoped? | Determines whether to build or replace the Calendar sync feature | Before Phase 6 |

---

## Sources

| Source | Type | Confidence |
|--------|------|-----------|
| `index.html` (v1 frontend, 2,500+ lines) | Primary -- direct analysis | HIGH |
| `ELUXR social media Action v2 (3).json` (v1 n8n workflow, 116KB) | Primary -- direct analysis | HIGH |
| `PROJECT.md` (project constraints and v1 known bugs) | Primary -- constraints | HIGH |
| Supabase documentation (training data, May 2025 cutoff) | Training data | MEDIUM |
| n8n documentation (training data) | Training data -- sub-workflow patterns stable | MEDIUM |
| Competitor feature sets (Buffer, Hootsuite, Later, Jasper, Lately.ai, ContentStudio) | Training data (May 2025) | MEDIUM |
| Multi-tenant RLS patterns | Domain-stable knowledge | HIGH |
| CORS/JWT web standards | Standards-based -- stable | HIGH |
