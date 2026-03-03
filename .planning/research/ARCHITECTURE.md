# Architecture Patterns: ELUXR v2 Multi-Tenant SaaS

**Domain:** Multi-tenant SaaS social media automation (n8n + Supabase + vanilla frontend)
**Researched:** 2026-02-27
**Overall Confidence:** MEDIUM-HIGH (based on training data for Supabase, n8n, and multi-tenant SaaS patterns; WebSearch/WebFetch unavailable for verification of latest API changes)

---

## System Overview

ELUXR v2 is a three-tier system where the **frontend** (static HTML/JS on Vercel/Netlify) authenticates through **Supabase** (database, auth, realtime) and triggers AI orchestration pipelines in **n8n** (workflow engine). The key architectural challenge is that n8n cloud does not natively understand Supabase Auth tokens, so a validation bridge pattern is required.

```
+------------------+       +------------------+       +------------------+
|                  |       |                  |       |                  |
|  Static Frontend |<----->|    Supabase      |<----->|   n8n Cloud      |
|  (Vercel/Netlify)|       |  (DB + Auth +    |       |  (AI Pipeline    |
|                  |       |   Realtime)      |       |   Orchestrator)  |
+------------------+       +------------------+       +------------------+
        |                         |                          |
        |  Auth (JWT)             |  RLS-protected           |  External APIs
        |  Realtime (WS)          |  tables                  |  Claude, Perplexity
        |  Direct DB reads        |  Progress tracking       |  KIE, Google Calendar
        +-------------------------+                          |
                                                             |
                                  +------------------+       |
                                  |  Supabase Client |<------+
                                  |  (n8n HTTP nodes)|
                                  +------------------+
```

---

## Component Boundaries

### Component 1: Frontend (Static HTML/JS)

**Responsibility:** User interface, auth UI, direct reads from Supabase, triggering n8n workflows via webhooks, receiving realtime updates.

**Talks to:**
- Supabase directly (auth, reads, realtime subscriptions)
- n8n webhooks (write operations, pipeline triggers)

**Does NOT:**
- Write to Supabase directly (all writes go through n8n for data integrity)
- Store API keys (zero secrets in frontend)
- Call external AI APIs directly

**State management:** Supabase session token in memory (supabase-js handles this). No localStorage for auth tokens. Business context and UI state can remain in localStorage for convenience.

| Operation | Target | Auth |
|-----------|--------|------|
| Login/signup | Supabase Auth | Email + password |
| Read ICP, themes, content | Supabase DB | JWT (RLS) |
| Subscribe to progress | Supabase Realtime | JWT (RLS) |
| Trigger pipeline phase | n8n webhook | Bearer token (JWT forwarded) |
| Chat message | n8n webhook | Bearer token (JWT forwarded) |
| Approve/reject content | n8n webhook | Bearer token (JWT forwarded) |

### Component 2: Supabase

**Responsibility:** Authentication, persistent data storage (all tenant data), Row-Level Security for isolation, realtime progress broadcasting, session management.

**Subcomponents:**

| Subcomponent | Role |
|-------------|------|
| Supabase Auth | JWT issuance, email+password, session refresh |
| PostgreSQL + RLS | All data storage with per-tenant isolation |
| Realtime | Broadcast database changes to subscribed frontends |
| Edge Functions (optional) | JWT validation helper for n8n (see Auth section) |

**Does NOT:**
- Orchestrate AI pipelines (that is n8n's job)
- Call external APIs (except through Edge Functions if needed)

### Component 3: n8n Cloud (Workflow Engine)

**Responsibility:** AI pipeline orchestration, external API calls (Claude, Perplexity, KIE), writing processed results to Supabase, updating progress status.

**Talks to:**
- Supabase (via HTTP Request nodes using service_role key for writes)
- External AI APIs (Claude, Perplexity, KIE)
- Google Calendar API

**Does NOT:**
- Serve the frontend
- Handle authentication (validates tokens, does not issue them)
- Store persistent data (all state lives in Supabase)

### Component 4: External AI Services

**Responsibility:** Content generation, market research, image/video creation.

| Service | Called By | Purpose |
|---------|-----------|---------|
| Claude (claude-sonnet-4) | n8n | ICP generation, themes, posts, chat |
| Perplexity (sonar-pro) | n8n | Market research, trend research |
| KIE (nano-banana-pro) | n8n | Image generation |
| KIE (veo3_fast) | n8n | Video generation |
| Google Calendar | n8n | Schedule sync |

---

## Data Flow Diagrams

### Flow 1: Authentication

```
Frontend                    Supabase                   n8n
   |                           |                        |
   |-- signUp(email, pass) --->|                        |
   |<-- session + JWT ---------|                        |
   |                           |                        |
   |-- Store JWT in memory     |                        |
   |                           |                        |
   |-- (later) API call -------|----------------------->|
   |   Authorization:          |                        |
   |   Bearer <JWT>            |                        |-- Validate JWT
   |                           |                        |   (see Auth section)
   |                           |                        |-- Extract user_id
   |                           |                        |-- Proceed with request
```

### Flow 2: Pipeline Execution (e.g., Phase 1 - ICP Analysis)

```
Frontend                  n8n                      Supabase           Claude/Perplexity
   |                       |                          |                    |
   |-- POST /eluxr-v2/     |                          |                    |
   |   phase1-analyze      |                          |                    |
   |   {business_url,      |                          |                    |
   |    industry,          |                          |                    |
   |    jwt_token}         |                          |                    |
   |                       |-- Validate JWT --------->|                    |
   |                       |<-- user_id --------------|                    |
   |                       |                          |                    |
   |                       |-- INSERT progress ------>|                    |
   |                       |   (status: 'researching')|                    |
   |                       |                          |                    |
   |<== Realtime update ===|==========================|                    |
   |   (progress: 20%)     |                          |                    |
   |                       |-- Market research -------|----------->|       |
   |                       |<-- Research results -----|-----------|       |
   |                       |                          |                    |
   |                       |-- UPDATE progress ------>|                    |
   |                       |   (status: 'analyzing')  |                    |
   |                       |                          |                    |
   |<== Realtime update ===|==========================|                    |
   |   (progress: 50%)     |                          |                    |
   |                       |-- ICP generation --------|----------->|       |
   |                       |<-- ICP data -------------|-----------|       |
   |                       |                          |                    |
   |                       |-- UPSERT icp ----------->|                    |
   |                       |-- UPDATE progress ------>|                    |
   |                       |   (status: 'complete')   |                    |
   |                       |                          |                    |
   |<== Realtime update ===|==========================|                    |
   |   (progress: 100%)    |                          |                    |
   |                       |                          |                    |
   |-- SELECT icp ---------|------------------------->|                    |
   |<-- ICP data ----------|--------------------------|                    |
```

### Flow 3: Chat with Action Capability

```
Frontend                  n8n                      Supabase               Claude
   |                       |                          |                      |
   |-- POST /eluxr-v2/     |                          |                      |
   |   chat                |                          |                      |
   |   {message, phase,    |                          |                      |
   |    jwt_token}         |                          |                      |
   |                       |-- Validate JWT --------->|                      |
   |                       |-- SELECT chat_history -->|                      |
   |                       |-- SELECT context ------->|                      |
   |                       |   (ICP, themes, etc.)    |                      |
   |                       |                          |                      |
   |                       |-- Chat with context -----|--------------------->|
   |                       |<-- Response + actions ---|---------------------|
   |                       |                          |                      |
   |                       |-- IF action detected:    |                      |
   |                       |   Execute sub-workflow   |                      |
   |                       |   (approve, regenerate,  |                      |
   |                       |    edit theme, etc.)     |                      |
   |                       |                          |                      |
   |                       |-- INSERT chat_message -->|                      |
   |                       |-- INSERT action_log ---->|                      |
   |                       |                          |                      |
   |<-- Response JSON -----|                          |                      |
   |   {message, actions   |                          |                      |
   |    taken, results}    |                          |                      |
```

### Flow 4: Real-Time Progress Tracking

```
Frontend                           Supabase                    n8n
   |                                  |                         |
   |-- supabase.channel('progress')   |                         |
   |   .on('postgres_changes',        |                         |
   |       {table: 'pipeline_runs',   |                         |
   |        filter: user_id})         |                         |
   |   .subscribe()                   |                         |
   |                                  |                         |
   |   [User triggers pipeline]       |                         |
   |-- POST webhook -----------------|------------------------>|
   |                                  |                         |
   |                                  |<-- UPSERT status -------|
   |                                  |   step: 1, label:       |
   |                                  |   'Market Research',    |
   |                                  |   progress: 0           |
   |                                  |                         |
   |<== postgres_changes broadcast ===|                         |
   |   (render progress bar step 1)   |                         |
   |                                  |                         |
   |                                  |<-- UPDATE status -------|
   |                                  |   step: 1, progress: 100|
   |                                  |   step: 2, progress: 0  |
   |                                  |                         |
   |<== postgres_changes broadcast ===|                         |
   |   (render progress bar step 2)   |                         |
   |                                  |                         |
   |   ... (repeats for each step)    |                         |
```

### Flow 5: Weekly Trend Research Pipeline

```
Schedule Trigger (n8n)         n8n                   Supabase         Perplexity
   |                            |                       |                 |
   |-- Cron: every Monday ----->|                       |                 |
   |                            |-- SELECT all -------->|                 |
   |                            |   active tenants      |                 |
   |                            |                       |                 |
   |                            |-- FOR EACH tenant:    |                 |
   |                            |   SELECT icp -------->|                 |
   |                            |                       |                 |
   |                            |-- Trend research -----|---------------->|
   |                            |<-- Trend data --------|----------------|
   |                            |                       |                 |
   |                            |-- Claude: analyze     |                 |
   |                            |   relevance to ICP    |                 |
   |                            |                       |                 |
   |                            |-- INSERT trend ------>|                 |
   |                            |   alerts              |                 |
   |                            |                       |                 |
   |                            |   (Frontend shows     |                 |
   |                            |    notification banner |                 |
   |                            |    on next page load)  |                 |
```

---

## Supabase Schema Design

### Multi-Tenant Strategy: Shared Tables with RLS

**Recommendation:** Use shared tables with a `user_id` column on every table, enforced by Row-Level Security policies. This is the standard Supabase multi-tenant pattern and is simpler and more maintainable than per-tenant schemas.

**Why shared tables (not per-tenant schemas):**
- Supabase RLS is purpose-built for this pattern
- Simpler migrations (one schema to update)
- Supabase Realtime works naturally with RLS
- No schema-per-tenant management overhead
- Supabase's `auth.uid()` function makes policies trivial

### Table Structure

```sql
-- =============================================
-- CORE TABLES
-- =============================================

-- User profiles (extends Supabase auth.users)
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    display_name TEXT,
    business_url TEXT,
    industry TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ICP (Ideal Customer Profile) - one per user
CREATE TABLE public.icps (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    business_url TEXT NOT NULL,
    industry TEXT NOT NULL,
    icp_summary TEXT,
    demographics JSONB,
    psychographics JSONB,
    content_preferences JSONB,
    competitors JSONB,
    content_opportunities JSONB,
    recommended_hashtags JSONB,
    raw_research TEXT,             -- Perplexity raw output
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id)               -- One active ICP per user
);

-- Monthly campaigns
CREATE TABLE public.campaigns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    month TEXT NOT NULL,           -- '2026-03'
    status TEXT DEFAULT 'draft',   -- draft, active, completed
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, month)
);

-- Weekly themes (4 per campaign)
CREATE TABLE public.themes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    campaign_id UUID REFERENCES public.campaigns(id) ON DELETE CASCADE,
    week_number INT NOT NULL,      -- 1-4
    theme_name TEXT NOT NULL,
    theme_description TEXT,
    show_concept TEXT,             -- Netflix "show" concept
    hook TEXT,                     -- Continuity hook
    content_types JSONB,          -- Array of content types for the week
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Individual content items
CREATE TABLE public.content_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    campaign_id UUID REFERENCES public.campaigns(id) ON DELETE CASCADE,
    theme_id UUID REFERENCES public.themes(id) ON DELETE SET NULL,
    title TEXT,
    content TEXT NOT NULL,
    content_type TEXT NOT NULL,    -- 'text', 'image', 'video_script'
    platform TEXT NOT NULL,        -- 'LinkedIn', 'Instagram', 'X', 'YouTube'
    scheduled_date DATE,
    scheduled_time TIME,
    status TEXT DEFAULT 'pending', -- pending, approved, rejected, published
    image_url TEXT,                -- KIE-generated image URL
    video_url TEXT,                -- KIE-generated video URL
    image_prompt TEXT,
    feedback TEXT,                 -- Reviewer feedback
    created_at TIMESTAMPTZ DEFAULT NOW(),
    reviewed_at TIMESTAMPTZ,
    published_at TIMESTAMPTZ
);

-- =============================================
-- PROGRESS TRACKING
-- =============================================

-- Pipeline run status (realtime updates)
CREATE TABLE public.pipeline_runs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    pipeline_type TEXT NOT NULL,    -- 'icp_analysis', 'theme_generation',
                                   -- 'content_generation', 'trend_research'
    status TEXT DEFAULT 'running',  -- running, completed, failed
    current_step INT DEFAULT 1,
    total_steps INT NOT NULL,
    step_label TEXT,               -- Human-readable current step
    step_progress INT DEFAULT 0,   -- 0-100 for current step
    error_message TEXT,
    started_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    metadata JSONB                 -- Step-specific data
);

-- =============================================
-- CHAT
-- =============================================

-- Chat conversations
CREATE TABLE public.chat_conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Chat messages
CREATE TABLE public.chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    conversation_id UUID REFERENCES public.chat_conversations(id) ON DELETE CASCADE,
    role TEXT NOT NULL,             -- 'user', 'assistant'
    content TEXT NOT NULL,
    actions_taken JSONB,           -- [{action: 'approve', target: 'content_123', result: 'success'}]
    phase_context INT,             -- Which phase/tab was active
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================
-- TREND RESEARCH
-- =============================================

CREATE TABLE public.trend_alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    trend_topic TEXT NOT NULL,
    relevance_score FLOAT,         -- 0-1, how relevant to user's ICP
    summary TEXT,
    suggested_content JSONB,       -- Suggested content pivots
    source TEXT,                   -- 'perplexity_weekly', 'manual'
    status TEXT DEFAULT 'new',     -- new, seen, acted_on, dismissed
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================
-- STANDALONE TOOLS HISTORY
-- =============================================

CREATE TABLE public.tool_outputs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    tool_type TEXT NOT NULL,        -- 'video_script', 'image_gen', 'video_gen', 'content_gen'
    input_params JSONB NOT NULL,
    output_data JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### Row-Level Security Policies

```sql
-- Pattern: Every table gets the same base RLS policy.
-- Users can only see/modify their own rows.

-- Enable RLS on ALL tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.icps ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.themes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pipeline_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trend_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tool_outputs ENABLE ROW LEVEL SECURITY;

-- Standard user isolation policy (repeated per table)
-- Example for content_items (apply same pattern to all):

CREATE POLICY "Users can view own content"
    ON public.content_items FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own content"
    ON public.content_items FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own content"
    ON public.content_items FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own content"
    ON public.content_items FOR DELETE
    USING (auth.uid() = user_id);

-- CRITICAL: n8n uses the service_role key, which BYPASSES RLS.
-- This is correct and intentional -- n8n is a trusted backend.
-- The service_role key must NEVER be exposed to the frontend.

-- For profiles table, use auth.uid() = id (not user_id)
CREATE POLICY "Users can view own profile"
    ON public.profiles FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
    ON public.profiles FOR UPDATE
    USING (auth.uid() = id);
```

**Key RLS insight:** n8n writes to Supabase using the `service_role` key, which bypasses RLS entirely. This is correct -- n8n is a trusted backend that always includes `user_id` in its writes. The frontend reads via the `anon` key + JWT, which enforces RLS. This creates a clean separation:
- Frontend reads are tenant-isolated by RLS automatically
- n8n writes are trusted and include user_id explicitly

### Database Indexes

```sql
-- Performance indexes for common query patterns
CREATE INDEX idx_content_items_user_status ON public.content_items(user_id, status);
CREATE INDEX idx_content_items_user_campaign ON public.content_items(user_id, campaign_id);
CREATE INDEX idx_content_items_user_date ON public.content_items(user_id, scheduled_date);
CREATE INDEX idx_pipeline_runs_user_status ON public.pipeline_runs(user_id, status);
CREATE INDEX idx_chat_messages_conversation ON public.chat_messages(conversation_id, created_at);
CREATE INDEX idx_trend_alerts_user_status ON public.trend_alerts(user_id, status);
CREATE INDEX idx_themes_campaign ON public.themes(campaign_id);
```

---

## Authentication Flow

### The n8n Webhook Authentication Problem

**Problem:** n8n cloud webhook endpoints are public URLs. Anyone who knows the URL can call them. With multi-tenant data, every webhook call must be authenticated to identify which user is making the request.

**Solution: JWT Forwarding + Supabase Verification**

The frontend sends the Supabase JWT as a Bearer token in every n8n webhook call. The n8n workflow validates this JWT by calling Supabase's `auth.getUser()` endpoint before processing.

### Authentication Architecture

```
Frontend                           n8n Webhook                    Supabase Auth
   |                                  |                              |
   |-- Authorization: Bearer <jwt> -->|                              |
   |                                  |                              |
   |                                  |-- GET /auth/v1/user -------->|
   |                                  |   Authorization: Bearer <jwt>|
   |                                  |   apikey: <anon_key>         |
   |                                  |                              |
   |                                  |<-- 200: {id, email, ...} ----|
   |                                  |   OR                         |
   |                                  |<-- 401: invalid token -------|
   |                                  |                              |
   |                                  |-- Extract user_id            |
   |                                  |-- Proceed with pipeline      |
   |                                  |                              |
   |<-- 401 Unauthorized -------------|  (if JWT invalid)            |
```

### n8n JWT Validation Sub-Workflow

Create a reusable sub-workflow called "Validate JWT" that every webhook workflow calls first.

```
[Webhook] --> [Validate JWT Sub-Workflow] --> [If Valid?]
                                                 |
                                          Yes ---+--> [Continue pipeline]
                                                 |
                                          No ----+--> [Respond 401]
```

**Validate JWT Sub-Workflow internals:**

```
[Execute Workflow Trigger]
    --> [HTTP Request: GET {SUPABASE_URL}/auth/v1/user]
        Headers:
          Authorization: Bearer {{ $json.jwt }}
          apikey: {{ $env.SUPABASE_ANON_KEY }}
    --> [If status == 200?]
        Yes --> [Return {valid: true, user_id: response.id, email: response.email}]
        No  --> [Return {valid: false}]
```

### Frontend Auth Code Pattern

```javascript
// Initialize Supabase client (anon key is safe to expose)
const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// Auth helper: get current JWT for n8n calls
async function getAuthToken() {
    const { data: { session } } = await supabase.auth.getSession();
    if (!session) throw new Error('Not authenticated');
    return session.access_token;
}

// Wrapper for all n8n webhook calls
async function callN8n(endpoint, body = {}) {
    const token = await getAuthToken();
    const response = await fetch(`${N8N_BASE_URL}/${endpoint}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify(body)
    });
    if (response.status === 401) {
        // Token expired, redirect to login
        await supabase.auth.signOut();
        window.location.href = '/login';
        return;
    }
    return response.json();
}
```

### Security Boundaries Summary

| Secret | Where Stored | Who Uses It | Exposed to Frontend? |
|--------|-------------|-------------|---------------------|
| Supabase anon key | Frontend code | Frontend (supabase-js) | YES (safe by design -- RLS protects data) |
| Supabase service_role key | n8n credentials | n8n only | NO (bypasses RLS, must be protected) |
| Supabase URL | Frontend + n8n | Both | YES (safe) |
| User JWT | In-memory (frontend) | Frontend sends to n8n | Sent per-request (not in localStorage) |
| Claude API key | n8n credentials | n8n only | NO |
| Perplexity API key | n8n credentials | n8n only | NO |
| KIE API key | n8n credentials | n8n only | NO (v1 bug: was hardcoded) |
| Google Calendar creds | n8n credentials | n8n only | NO |

---

## n8n Workflow Decomposition

### Current State (v1)

One monolithic workflow with 93 nodes and 13 webhook endpoints. All code, all phases, all tools in a single workflow. This is unmaintainable and hard to debug.

### Target State (v2): Per-Domain Workflows

Split into separate workflows connected via n8n's **Execute Workflow** node (sub-workflow pattern).

```
+-------------------------------------------+
|          Orchestrator Workflows            |
|  (each has its own webhook endpoint)       |
+-------------------------------------------+
|                                           |
|  1. Auth Validator (sub-workflow)          |  <-- Called by ALL other workflows
|  2. ICP Pipeline Workflow                 |  <-- POST /eluxr-v2/phase1-analyze
|  3. Theme Generator Workflow              |  <-- POST /eluxr-v2/phase2-themes
|  4. Content Studio Workflow               |  <-- POST /eluxr-v2/phase4-studio
|  5. Calendar Sync Workflow                |  <-- POST /eluxr-v2/phase3-calendar
|  6. Approval Queue Workflow               |  <-- GET/POST /eluxr-v2/approval-*
|  7. Chat Workflow                         |  <-- POST /eluxr-v2/chat
|  8. Trend Research Workflow               |  <-- Scheduled (cron) + manual trigger
|  9. Image Generator Workflow              |  <-- POST /eluxr-v2/tool-image
| 10. Video Generator Workflow              |  <-- POST /eluxr-v2/tool-video
| 11. Video Script Workflow                 |  <-- POST /eluxr-v2/tool-script
| 12. Content Generator Workflow            |  <-- POST /eluxr-v2/tool-content
| 13. Progress Updater (sub-workflow)       |  <-- Called by pipeline workflows
|                                           |
+-------------------------------------------+
```

### Workflow Decomposition Detail

#### Shared Sub-Workflows (no webhook, called by Execute Workflow)

**1. Auth Validator**
- Input: JWT token string
- Process: Call Supabase `/auth/v1/user` endpoint
- Output: `{valid: boolean, user_id: string, email: string}`
- Called by: Every webhook workflow as first step

**2. Progress Updater**
- Input: `{user_id, pipeline_type, step, label, progress}`
- Process: UPSERT to `pipeline_runs` table via Supabase REST API
- Output: confirmation
- Called by: ICP Pipeline, Theme Generator, Content Studio

#### Pipeline Workflows

**3. ICP Pipeline (Phase 1)**
```
[Webhook: POST /eluxr-v2/phase1-analyze]
  --> [Execute: Auth Validator]
  --> [If valid?]
      Yes --> [Execute: Progress Updater (step 1: "Market Research")]
          --> [HTTP: Perplexity market research]
          --> [Execute: Progress Updater (step 2: "ICP Analysis")]
          --> [HTTP: Claude ICP generation]
          --> [Code: Parse ICP JSON]
          --> [HTTP: Supabase UPSERT icp]
          --> [Execute: Progress Updater (complete)]
          --> [Respond: {success: true}]
      No  --> [Respond: 401]
```

**4. Theme Generator (Phase 2)**
```
[Webhook: POST /eluxr-v2/phase2-themes]
  --> [Execute: Auth Validator]
  --> [If valid?]
      Yes --> [HTTP: Supabase SELECT icp (for context)]
          --> [Execute: Progress Updater (step 1: "Generating Themes")]
          --> [HTTP: Claude Netflix theme generation]
          --> [Code: Parse & split 30 theme days]
          --> [HTTP: Supabase INSERT themes]
          --> [HTTP: Supabase INSERT campaign]
          --> [Execute: Progress Updater (complete)]
          --> [Respond: {success: true}]
      No  --> [Respond: 401]
```

**5. Content Studio (Phase 4)**
```
[Webhook: POST /eluxr-v2/phase4-studio]
  --> [Execute: Auth Validator]
  --> [If valid?]
      Yes --> [HTTP: Supabase SELECT themes for day]
          --> [Execute: Progress Updater (step 1)]
          --> [Switch: content type (text/image/video)]
              text  --> [HTTP: Claude write post] --> [Merge]
              image --> [HTTP: KIE create image] --> [Wait/Poll] --> [Merge]
              video --> [HTTP: Claude script] --> [Merge]
          --> [HTTP: Supabase INSERT content_items]
          --> [Execute: Progress Updater (complete)]
          --> [Respond: {success: true}]
      No  --> [Respond: 401]
```

**6. Calendar Sync (Phase 3)**
```
[Webhook: POST /eluxr-v2/phase3-calendar]
  --> [Execute: Auth Validator]
  --> [HTTP: Supabase SELECT approved content_items]
  --> [Code: Format calendar events]
  --> [SplitInBatches: Loop over days]
      --> [Google Calendar: Create event]
  --> [Respond: {success: true, events_created: N}]
```

**7. Approval Queue**
```
[Webhook: GET /eluxr-v2/approval-list]
  --> [Execute: Auth Validator]
  --> [HTTP: Supabase SELECT content_items WHERE status IN ('pending','approved','rejected')]
  --> [Code: Organize by status]
  --> [Respond: {pending: [...], approved: [...], rejected: [...]}]

[Webhook: POST /eluxr-v2/approval-action]
  --> [Execute: Auth Validator]
  --> [Switch: action (approve/reject/edit)]
      approve --> [HTTP: Supabase UPDATE status='approved']
      reject  --> [HTTP: Supabase UPDATE status='rejected']
      edit    --> [HTTP: Supabase UPDATE content]
  --> [Respond: {success: true}]
```

**8. Chat Workflow**
```
[Webhook: POST /eluxr-v2/chat]
  --> [Execute: Auth Validator]
  --> [HTTP: Supabase SELECT chat_history (last 20 messages)]
  --> [HTTP: Supabase SELECT relevant context (ICP, themes, content)]
  --> [Code: Build system prompt with context + action instructions]
  --> [HTTP: Claude chat with tool-use prompt]
  --> [Code: Parse response, detect action intents]
  --> [If action detected?]
      Yes --> [Execute: Action sub-workflow (approve, regenerate, etc.)]
      No  --> [Continue]
  --> [HTTP: Supabase INSERT chat_messages]
  --> [Respond: {message, actions_taken}]
```

**9. Trend Research (Scheduled)**
```
[Schedule Trigger: Every Monday 6 AM]
  --> [HTTP: Supabase SELECT all active users with ICPs]
  --> [SplitInBatches: For each user]
      --> [HTTP: Perplexity trend research for user's industry]
      --> [HTTP: Claude analyze relevance to user's ICP]
      --> [If relevance_score > 0.7?]
          Yes --> [HTTP: Supabase INSERT trend_alert]
          No  --> [Skip]
  --> [End]
```

#### Standalone Tool Workflows

**10-12. Image Gen, Video Gen, Video Script**
- Each is a simple webhook -> process -> respond workflow
- All validate JWT first
- All save output to `tool_outputs` table
- Same structure as v1 but with auth and Supabase storage added

### n8n Webhook Path Convention

Use a versioned, consistent path structure:

```
Base: https://flowbound.app.n8n.cloud/webhook

Pipeline endpoints:
  POST /eluxr-v2/phase1-analyze
  POST /eluxr-v2/phase2-themes
  POST /eluxr-v2/phase3-calendar
  POST /eluxr-v2/phase4-studio

Approval endpoints:
  GET  /eluxr-v2/approval-list
  POST /eluxr-v2/approval-action
  POST /eluxr-v2/approval-clear

Chat endpoint:
  POST /eluxr-v2/chat

Tool endpoints:
  POST /eluxr-v2/tool-image
  POST /eluxr-v2/tool-video
  POST /eluxr-v2/tool-script
  POST /eluxr-v2/tool-content

Data endpoints:
  GET  /eluxr-v2/themes-list
  GET  /eluxr-v2/trend-alerts
```

---

## Real-Time Progress Architecture

### Pattern: Supabase Realtime Postgres Changes

**How it works:**
1. n8n UPSERTs rows in `pipeline_runs` table (using service_role key, bypassing RLS)
2. Supabase Realtime detects the INSERT/UPDATE
3. Frontend subscribes to changes on `pipeline_runs` filtered by `user_id`
4. Frontend receives change events via WebSocket and updates the progress UI

### Frontend Subscription Code

```javascript
// Subscribe to pipeline progress for the current user
function subscribeToPipeline(pipelineType) {
    const userId = supabase.auth.getUser().then(u => u.data.user.id);

    const channel = supabase
        .channel('pipeline-progress')
        .on(
            'postgres_changes',
            {
                event: '*',                           // INSERT and UPDATE
                schema: 'public',
                table: 'pipeline_runs',
                filter: `user_id=eq.${userId}`
            },
            (payload) => {
                const run = payload.new;
                updateProgressUI({
                    step: run.current_step,
                    totalSteps: run.total_steps,
                    label: run.step_label,
                    progress: run.step_progress,
                    status: run.status,
                    error: run.error_message
                });
            }
        )
        .subscribe();

    return channel; // Save reference to unsubscribe later
}
```

### Enabling Realtime on the Table

```sql
-- In Supabase Dashboard or via SQL:
-- Enable realtime for the pipeline_runs table
ALTER PUBLICATION supabase_realtime ADD TABLE public.pipeline_runs;
```

**IMPORTANT (Confidence: HIGH):** Supabase Realtime respects RLS policies. Since the frontend connects with the user's JWT, the Realtime subscription will only receive changes for rows where `auth.uid() = user_id`. This means tenant isolation is automatic for Realtime too.

### n8n Progress Update Pattern

In each pipeline workflow, use the Progress Updater sub-workflow at each step:

```javascript
// n8n Code node: Update progress helper
// Called via Execute Workflow node with these params
const progressUpdate = {
    user_id: $json.user_id,
    pipeline_type: 'icp_analysis',
    current_step: 2,
    total_steps: 4,
    step_label: 'Analyzing with Claude',
    step_progress: 50,
    status: 'running'
};
return [{ json: progressUpdate }];
```

The Progress Updater sub-workflow does:
```
[Execute Workflow Trigger]
  --> [HTTP Request: PATCH {SUPABASE_URL}/rest/v1/pipeline_runs]
       Headers:
         apikey: service_role_key
         Authorization: Bearer service_role_key
         Content-Type: application/json
         Prefer: resolution=merge-duplicates
       Body: {user_id, pipeline_type, current_step, ...}
       URL params: ?on_conflict=user_id,pipeline_type
```

### Fallback: Polling (if Realtime has issues)

If Supabase Realtime proves unreliable (unlikely but possible), a polling fallback is trivial:

```javascript
// Polling fallback (use only if Realtime fails)
async function pollProgress(pipelineType) {
    const { data } = await supabase
        .from('pipeline_runs')
        .select('*')
        .eq('pipeline_type', pipelineType)
        .order('started_at', { ascending: false })
        .limit(1)
        .single();

    updateProgressUI(data);
    if (data.status === 'running') {
        setTimeout(() => pollProgress(pipelineType), 2000);
    }
}
```

---

## Chat Architecture: Action-Capable Chatbot

### Design: Claude Tool-Use Prompt Pattern

The chatbot uses Claude's structured output to detect action intents, then n8n executes those actions.

**Why not Claude's native tool_use?** The actions are executed by n8n, not by Claude. Claude's role is to understand the user's intent and output structured action requests. n8n then routes those to the appropriate sub-workflow.

### Chat System Prompt Structure

```
You are the ELUXR AI assistant. You can help users with their social media content strategy.

AVAILABLE ACTIONS:
You can take actions on behalf of the user. When the user asks you to do something,
include an "actions" array in your response JSON.

Available actions:
- {"action": "approve_content", "content_id": "..."}
- {"action": "reject_content", "content_id": "...", "reason": "..."}
- {"action": "regenerate_post", "content_id": "...", "instructions": "..."}
- {"action": "edit_theme", "theme_id": "...", "changes": {...}}
- {"action": "trigger_generation", "date": "...", "platform": "..."}

CURRENT CONTEXT:
- User's ICP: {icp_summary}
- Active themes: {themes_summary}
- Pending content count: {pending_count}
- Recent trends: {trend_alerts}

Respond with JSON: {"message": "your response", "actions": [...]}
If no actions needed, return empty actions array.
```

### n8n Chat Workflow Action Routing

```
[Parse Claude Response]
  --> [Code: Extract actions array]
  --> [If actions.length > 0?]
      Yes --> [SplitInBatches: For each action]
              --> [Switch: action.action]
                  approve_content  --> [HTTP: Supabase UPDATE content_items SET status='approved']
                  reject_content   --> [HTTP: Supabase UPDATE content_items SET status='rejected']
                  regenerate_post  --> [Execute Workflow: Content Studio]
                  edit_theme       --> [HTTP: Supabase UPDATE themes]
                  trigger_gen      --> [Execute Workflow: Content Studio]
              --> [Collect results]
      No  --> [Continue]
  --> [HTTP: Supabase INSERT chat_messages (with actions_taken)]
  --> [Respond]
```

### Chat Memory

Store conversation history in `chat_messages` table. Load last N messages as context for each new chat call.

```javascript
// n8n Code node: Build chat messages array
const history = $json.chat_history; // From Supabase SELECT
const messages = history.map(msg => ({
    role: msg.role,
    content: msg.content
}));
// Add new user message
messages.push({
    role: 'user',
    content: $json.new_message
});
return [{ json: { messages } }];
```

---

## Patterns to Follow

### Pattern 1: Frontend Reads Supabase, Writes via n8n

**What:** The frontend reads data directly from Supabase (protected by RLS) but sends all write operations through n8n webhooks.

**Why:** This gives you the best of both worlds:
- Reads are fast (no n8n hop), RLS-protected, and can use Realtime
- Writes go through n8n where business logic, AI processing, and data validation happen
- n8n uses service_role key for writes, so it can write to any user's data (with proper validation)

**When:** Always. This is the core data flow pattern.

```javascript
// Frontend READ (direct to Supabase)
const { data: icp } = await supabase
    .from('icps')
    .select('*')
    .single();

// Frontend WRITE (via n8n)
await callN8n('eluxr-v2/phase1-analyze', {
    business_url: 'https://example.com',
    industry: 'SaaS'
});
```

### Pattern 2: Sub-Workflow for Shared Logic

**What:** Extract common logic (auth validation, progress updates, error handling) into n8n sub-workflows called via Execute Workflow node.

**Why:** DRY principle. Every webhook needs auth validation -- put it in one place.

**Implementation:**
- Create the sub-workflow with an "Execute Workflow Trigger" node (not a Webhook)
- Call it from parent workflows using the "Execute Workflow" node
- Pass data via the Execute Workflow node's input
- Receive results back in the parent workflow

### Pattern 3: Optimistic UI with Realtime Confirmation

**What:** After the user triggers a pipeline, immediately show a "processing" state. Realtime updates from Supabase then fill in actual progress.

**Why:** The n8n webhook response may take a moment. The user should see immediate feedback.

```javascript
// 1. Show processing state immediately
showProgressBar('Starting...');

// 2. Fire n8n webhook (don't await for pipeline completion)
callN8n('eluxr-v2/phase1-analyze', params);

// 3. Realtime subscription already active -- it will update the UI
// (set up during page load, not per-request)
```

### Pattern 4: Idempotent Pipeline Runs

**What:** Pipeline runs should be idempotent -- running the same pipeline twice with the same inputs should not create duplicate data.

**Why:** Network issues, user double-clicks, or retry logic could cause duplicate calls.

**Implementation:**
- Use UPSERT (ON CONFLICT) for ICP data (one per user)
- Use campaign month uniqueness constraint
- Check for existing pipeline_run before starting a new one
- Use unique content_item constraints (user_id + campaign_id + platform + scheduled_date)

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Frontend Writes Directly to Supabase

**What:** Having the frontend INSERT/UPDATE rows in Supabase without going through n8n.

**Why bad:** Bypasses business logic, AI processing, and data validation. Creates two sources of truth for writes. Makes it hard to add processing steps later.

**Exception:** Profile updates (display_name, etc.) can go directly to Supabase since they don't need AI processing.

### Anti-Pattern 2: Storing JWT in localStorage

**What:** Saving the Supabase session token to localStorage.

**Why bad:** XSS vulnerability. If any script on the page is compromised, the attacker gets the auth token.

**Instead:** Use supabase-js's built-in session management, which handles storage securely. If you must persist sessions, use httpOnly cookies (requires a server, so not applicable here -- supabase-js handles it in-memory with refresh).

**Note:** supabase-js v2 does use localStorage by default for session persistence. This is a known tradeoff for SPAs without a backend. It is acceptable for this use case but worth noting. The key mitigation is: the JWT expires (default 1 hour) and the refresh token rotates.

### Anti-Pattern 3: n8n Webhook Returns Full Pipeline Result

**What:** Making the frontend wait for the entire AI pipeline to complete before getting a response.

**Why bad:** AI pipelines take 30-120 seconds. HTTP connections may timeout. Users see a spinner with no feedback.

**Instead:** Webhook returns immediately with `{success: true, pipeline_run_id: "..."}`. Progress comes via Supabase Realtime. Final data is read from Supabase after completion.

**IMPORTANT CAVEAT:** n8n cloud webhooks are synchronous by default -- the workflow runs and then responds. For long-running pipelines, the webhook should still respond quickly. Two approaches:

**Option A (Simpler):** Keep synchronous but update progress along the way. The webhook responds only after completion, but the frontend gets Realtime updates during execution. The response confirms completion.

**Option B (Better UX):** Use a "fire and forget" pattern where the webhook responds immediately after validation, then continues processing asynchronously. In n8n, this requires the "Respond to Webhook" node placed early in the flow (after auth validation), with the rest of the workflow continuing after it.

**Recommendation:** Option B. Place the "Respond to Webhook" node right after auth validation. The pipeline continues asynchronously. The frontend tracks progress via Realtime.

```
[Webhook] --> [Auth Validator] --> [Respond to Webhook: {accepted: true}]
                                        |
                                        v (workflow continues)
                                  [Progress Update: step 1]
                                  [AI Processing...]
                                  [Progress Update: step 2]
                                  [...]
                                  [Progress Update: complete]
```

### Anti-Pattern 4: One Giant Supabase Query from n8n

**What:** Loading all of a user's data in one query to pass as context.

**Why bad:** Wastes bandwidth, may hit response size limits, and sends unnecessary data to Claude (wasting tokens).

**Instead:** Query only what's needed for the current pipeline step. For chat context, summarize rather than dump raw data.

### Anti-Pattern 5: Hardcoded Webhook URLs in Frontend

**What:** Scattering webhook URLs throughout the frontend code (as in v1).

**Why bad:** Hard to update, easy to miss one, version changes break things.

**Instead:** Single configuration object:

```javascript
const ELUXR_API = {
    base: 'https://flowbound.app.n8n.cloud/webhook/eluxr-v2',
    endpoints: {
        phase1:     '/phase1-analyze',
        phase2:     '/phase2-themes',
        phase3:     '/phase3-calendar',
        phase4:     '/phase4-studio',
        approvalList:   '/approval-list',
        approvalAction: '/approval-action',
        chat:       '/chat',
        toolImage:  '/tool-image',
        toolVideo:  '/tool-video',
        toolScript: '/tool-script',
        toolContent:'/tool-content',
        themesList: '/themes-list',
        trendAlerts:'/trend-alerts'
    }
};
```

---

## Scalability Considerations

| Concern | 1-10 Users (MVP) | 100 Users | 1000+ Users |
|---------|-------------------|-----------|-------------|
| n8n concurrent executions | Fine on cloud plan | Check plan limits, may need queue | Need enterprise or self-hosted |
| Supabase connections | Fine on free tier | Pro tier recommended | Pro tier + connection pooling |
| Claude API rate limits | No issue | Monitor token usage | Need usage-based billing or tier limits |
| Perplexity weekly research | No issue | 100 calls/week | 1000 calls/week, cost concern |
| KIE image generation | No issue | Monitor queue times | May need dedicated capacity |
| Supabase Realtime connections | Fine | Fine (10K concurrent on Pro) | Fine |
| Frontend static hosting | Free tier | Free tier | Free tier (it's static) |

**First scaling bottleneck:** n8n cloud execution limits. The cloud plan has concurrent execution limits. If 50 users trigger ICP analysis simultaneously, executions queue up. Mitigations:
- Pipeline workflows are async (respond immediately, process in background)
- Most users won't be running pipelines simultaneously
- Add a "pipeline already running" check to prevent duplicate runs
- Long-term: consider n8n self-hosted for unlimited executions

---

## Build Order (Dependencies)

The architecture has clear dependency chains that dictate build order.

### Layer 0: Foundation (must be first)
1. **Supabase project setup** -- Create project, configure auth settings
2. **Database schema** -- All tables, RLS policies, indexes
3. **n8n credentials** -- Supabase service_role key, API keys in n8n credential store

**Rationale:** Everything depends on the database existing and n8n being able to talk to it.

### Layer 1: Auth + Data (depends on Layer 0)
4. **Auth Validator sub-workflow** -- Reusable JWT validation in n8n
5. **Frontend auth flow** -- Login/signup UI with supabase-js
6. **Progress Updater sub-workflow** -- Reusable progress tracking in n8n

**Rationale:** Every subsequent workflow needs auth validation. Every pipeline needs progress updates.

### Layer 2: Core Pipeline (depends on Layer 1)
7. **ICP Pipeline workflow** -- Phase 1 (no dependencies on other pipelines)
8. **Theme Generator workflow** -- Phase 2 (depends on ICP existing)
9. **Content Studio workflow** -- Phase 4 (depends on themes existing)
10. **Approval Queue workflow** -- Depends on content existing

**Rationale:** Each pipeline builds on the output of the previous one. ICP -> Themes -> Content -> Approval is the natural flow.

### Layer 3: Enhancements (depends on Layer 2)
11. **Calendar Sync workflow** -- Depends on approved content
12. **Real-time progress UI** -- Supabase Realtime subscriptions in frontend
13. **Chat workflow** -- Needs all data in Supabase for context
14. **Standalone tool workflows** -- Independent but benefit from auth and Supabase storage

### Layer 4: Advanced Features (depends on Layer 3)
15. **Chat action capability** -- Chat can trigger other workflows
16. **Trend research pipeline** -- Scheduled, needs ICP data
17. **Trend notification UI** -- Frontend banner, chat integration
18. **Premium animations** -- Polish, no backend dependencies

### Diagram

```
Layer 0: [Supabase Setup] --> [Schema + RLS] --> [n8n Credentials]
              |
Layer 1: [Auth Validator] --> [Frontend Auth] --> [Progress Updater]
              |
Layer 2: [ICP Pipeline] --> [Theme Generator] --> [Content Studio] --> [Approval Queue]
              |
Layer 3: [Calendar Sync] + [Realtime Progress] + [Chat] + [Standalone Tools]
              |
Layer 4: [Chat Actions] + [Trend Research] + [Trend UI] + [Animations]
```

---

## n8n-to-Supabase Communication Pattern

All n8n workflows communicate with Supabase via its REST API (PostgREST). This is the standard approach.

### HTTP Request Node Configuration for Supabase

```
URL: https://<project-ref>.supabase.co/rest/v1/<table_name>

Headers (for all requests):
  apikey: {{$env.SUPABASE_SERVICE_ROLE_KEY}}
  Authorization: Bearer {{$env.SUPABASE_SERVICE_ROLE_KEY}}
  Content-Type: application/json

For SELECT:
  Method: GET
  URL params: ?select=*&user_id=eq.{user_id}

For INSERT:
  Method: POST
  Headers (additional): Prefer: return=representation
  Body: [{...row data...}]

For UPDATE:
  Method: PATCH
  URL params: ?id=eq.{row_id}
  Headers (additional): Prefer: return=representation
  Body: {...fields to update...}

For UPSERT:
  Method: POST
  Headers (additional): Prefer: resolution=merge-duplicates,return=representation
  URL params: ?on_conflict=<unique_columns>
  Body: [{...row data...}]

For DELETE:
  Method: DELETE
  URL params: ?id=eq.{row_id}
```

### Storing Supabase Config in n8n

Store as n8n environment variables (or in the Header Auth credentials):
- `SUPABASE_URL`: `https://<project-ref>.supabase.co`
- `SUPABASE_SERVICE_ROLE_KEY`: The service_role key (NOT anon key)
- `SUPABASE_ANON_KEY`: For JWT validation calls only

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Supabase RLS multi-tenant pattern | HIGH | Well-established pattern, core Supabase feature, extensively documented |
| n8n sub-workflow / Execute Workflow | HIGH | Standard n8n feature, used extensively in production |
| Supabase Realtime for progress | MEDIUM-HIGH | Well-documented feature; exact behavior with RLS filtering confirmed in docs as of training data |
| n8n async webhook (Respond to Webhook early) | HIGH | Standard n8n pattern, "Respond to Webhook" node is purpose-built for this |
| JWT forwarding pattern | MEDIUM | Common pattern for n8n + external auth; Supabase `/auth/v1/user` endpoint verified in training data |
| Chat action routing | MEDIUM | Custom architecture decision; Claude structured output is reliable but action execution complexity depends on implementation |
| Trend research scheduling | HIGH | n8n Schedule Trigger is straightforward; per-tenant batch processing is standard |
| Schema design | MEDIUM-HIGH | Based on domain understanding; may need iteration once actual data shapes from v1 migration are confirmed |

---

## Gaps to Address

1. **n8n cloud execution limits** -- Need to verify the specific plan's concurrent execution limit. If too low, async + queuing becomes critical.
2. **Supabase Realtime RLS behavior** -- Confirmed in training data that Realtime respects RLS, but should verify with a quick test during implementation.
3. **KIE URL expiration** -- PROJECT.md notes "revisit if URLs expire." Architecture currently assumes URLs are permanent. If they expire, need a caching/proxy strategy.
4. **Claude token costs at scale** -- Chat with full context (ICP + themes + content + history) could be expensive. Need to design context summarization early.
5. **n8n environment variables on cloud** -- Verify how to set environment variables on n8n cloud (may need to use credential store instead of `$env`).
6. **Supabase free tier limits** -- Verify database size limits, API rate limits, and Realtime connection limits for the chosen plan.

---

## Sources

- v1 workflow analysis: `/home/andrew/workflow/eluxr-v2/ELUXR social media Action v2 (3).json` (93 nodes, 13 webhooks, 16 Google Sheets operations)
- v1 frontend analysis: `/home/andrew/workflow/eluxr-v2/index.html` (4097 lines, vanilla JS, all fetch calls mapped)
- Project requirements: `/home/andrew/workflow/eluxr-v2/.planning/PROJECT.md`
- Supabase RLS, Auth, Realtime: Training data (Supabase documentation, well-established patterns)
- n8n Execute Workflow, Respond to Webhook: Training data (n8n documentation)
- Multi-tenant SaaS patterns: Training data (industry-standard patterns)
- **Note:** WebSearch and WebFetch were unavailable during this research. All findings are based on training data (cutoff: May 2025) and direct analysis of the v1 codebase. Confidence levels reflect this limitation.
