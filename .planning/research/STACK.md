# Technology Stack

**Project:** ELUXR Magic Content Engine v2
**Researched:** 2026-02-27
**Mode:** Ecosystem (brownfield upgrade)
**Overall Confidence:** MEDIUM (web verification tools unavailable; versions based on training data through May 2025 + npm registry knowledge; flagged where uncertain)

---

## Executive Stack Summary

The v2 stack keeps the existing constraint of vanilla HTML/CSS/JS frontend + n8n cloud backend, replaces Google Sheets with Supabase (auth + database + realtime), and deploys the static frontend to Vercel. Every technology choice below is driven by what already exists in v1 and what the PROJECT.md constraints allow.

---

## Recommended Stack

### Frontend (Static HTML + Vanilla JS)

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| Vanilla HTML/CSS/JS | N/A | UI layer | Constraint from PROJECT.md. No framework. The existing 2,500-line index.html is the base. | HIGH (constraint) |
| @supabase/supabase-js | ^2.45.x (CDN) | Supabase client | Required for auth, DB queries, and realtime subscriptions from browser. Use CDN import, not npm — there is no build step. | MEDIUM (version may be higher now) |
| ES Modules via CDN | N/A | Module loading | Load Supabase SDK via `<script type="module">` and ESM CDN (esm.sh or unpkg). No bundler needed. | HIGH |

**CDN Import Pattern (recommended):**
```html
<script type="module">
  import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

  const supabase = createClient(
    'https://YOUR_PROJECT.supabase.co',
    'YOUR_ANON_KEY'  // This is safe to expose — RLS enforces security
  )

  // Make available globally for non-module scripts
  window.supabase = supabase
</script>
```

**Why CDN over npm:**
- The project has NO build step (no webpack, vite, esbuild). Adding a bundler to serve a single HTML file adds complexity with zero benefit.
- Supabase officially publishes ESM builds to CDNs.
- The anon key is safe to embed in client code — it only grants access that RLS policies allow.

**What NOT to use:**
| Avoid | Why |
|-------|-----|
| React/Vue/Svelte | PROJECT.md constraint: vanilla JS only. The existing 154KB index.html works. Adding a framework means rewriting everything. |
| npm + bundler (Vite, webpack) | No build step needed for a single HTML file. CDN imports are simpler and the existing index.html already loads external fonts/resources via CDN. |
| Supabase via `<script>` UMD bundle | The UMD bundle is larger and older. ESM via esm.sh is the modern pattern for no-build projects. |
| @supabase/auth-helpers-* | Those are framework-specific (Next.js, SvelteKit, etc.). For vanilla JS, use supabase-js directly — `supabase.auth.signInWithPassword()` etc. |

### Backend (n8n Cloud)

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| n8n Cloud | Latest (cloud-managed) | Workflow orchestration | Existing infrastructure at flowbound.app.n8n.cloud. Cloud version auto-updates. | HIGH |
| n8n Sub-workflows | Built-in feature | Split monolithic workflow | The current single 116KB workflow with 13 webhooks is unmaintainable. Sub-workflows allow per-phase isolation. | HIGH |
| n8n Credential Store | Built-in feature | API key management | Replaces the 5 hardcoded `Bearer 7f48c3109ae4ee6aee94ba7389bdcaa4` KIE tokens found in v1 workflow. | HIGH |
| n8n HTTP Request node | v4.2 (current in v1) | External API calls | Already in use for Anthropic/Perplexity/KIE calls. Use `predefinedCredentialType` with credential store. | HIGH |
| n8n Supabase node | Built-in | Database CRUD from workflows | n8n has a native Supabase integration node. Use it instead of HTTP Request for Supabase operations — handles auth automatically. | MEDIUM (need to verify current node capabilities) |

**n8n Sub-Workflow Architecture:**

Split the monolithic workflow into 7 independent workflows:

| Workflow | Webhook Endpoints | Purpose |
|----------|-------------------|---------|
| `eluxr-orchestrator` | None (internal) | Parent workflow that chains sub-workflows. Receives session context, calls each phase sequentially, updates progress in Supabase between phases. |
| `eluxr-phase1-icp` | `eluxr-phase1-analyzer` | ICP analysis via Perplexity + Claude. Writes ICP to Supabase `icp_profiles` table. |
| `eluxr-phase2-themes` | `eluxr-phase2-themes` | Theme generation via Claude. Reads ICP from Supabase, writes themes to `themes` table. |
| `eluxr-phase3-content` | `eluxr-phase4-studio` (keeping v1 name for migration compat) | Content generation. Reads themes, generates daily posts, writes to `content_items` table. |
| `eluxr-phase4-approval` | `eluxr-approval-list`, `eluxr-approval-action`, `eluxr-phase3-calendar` | Approval queue CRUD. Reads/writes `content_items` status. |
| `eluxr-tools` | `eluxr-videoscript`, `eluxr-imagegen`, `eluxr-videogen` | Standalone tools (video script, image gen, video gen). |
| `eluxr-chat` | `eluxr-chat` | Unified chatbot. Reads/writes `chat_messages` table. Action-capable. |

**Sub-Workflow Call Pattern:**
```
Execute Workflow node (built-in):
- Mode: "Call Another Workflow"
- Source: "Database" (reference by workflow ID)
- Pass data: JSON from previous node
- Wait for sub-workflow: Yes (for sequential pipeline)
                         No (for fire-and-forget like progress updates)
```

**Credential Store Pattern:**
All API keys MUST be in n8n credential store, never in node parameters:

| Credential Type | For | Current v1 Status |
|----------------|-----|------------------|
| `anthropicApi` | Claude Sonnet 4 | Already in credential store (good) |
| `httpHeaderAuth` | KIE AI (Nano Banana Pro, Veo) | HARDCODED as plaintext Bearer token in 5 HTTP Request nodes. Must migrate. |
| `httpHeaderAuth` | Perplexity AI (sonar-pro) | Need to verify — likely hardcoded |
| `supabaseApi` | Supabase service_role key | New credential for n8n-to-Supabase backend operations |
| `googleSheetsOAuth2Api` | Google Sheets (deprecating) | Currently in credential store. Remove after migration. |
| `googleCalendarOAuth2Api` | Google Calendar | Keep — calendar sync stays. |

**Webhook Authentication for v2:**

v1 webhooks have NO authentication — anyone with the URL can trigger them. For v2:

Option A (Recommended): **Header Auth via Supabase JWT**
```
1. Frontend calls n8n webhook with Authorization header containing Supabase JWT
2. n8n Code node validates JWT using Supabase JWT secret (stored in credential store)
3. Extract user_id from JWT payload for multi-tenant isolation
```

Option B: **n8n Webhook Auth** (simpler but weaker)
```
1. Use n8n's built-in webhook authentication (Header Auth)
2. Set a shared secret that frontend sends
3. Does NOT provide per-user identity — only proves request is from your frontend
```

**Recommendation:** Use Option A. The JWT carries the user_id, which is needed for multi-tenant data isolation. Without it, every webhook would need a separate `user_id` parameter that could be spoofed.

**JWT Validation in n8n Code Node:**
```javascript
// n8n Code node — validate Supabase JWT
const jwt = $input.first().json.headers.authorization?.replace('Bearer ', '');
if (!jwt) {
  return [{ json: { error: 'Unauthorized' }, statusCode: 401 }];
}

// Decode JWT (n8n has no native JWT verify, but the payload is base64)
// For production: use the jsonwebtoken library or verify via Supabase API
const payload = JSON.parse(Buffer.from(jwt.split('.')[1], 'base64').toString());
const userId = payload.sub; // Supabase user UUID

return [{ json: { ...($input.first().json), user_id: userId } }];
```

**Confidence note:** The JWT validation pattern above is MEDIUM confidence. In n8n cloud, you cannot install npm packages into Code nodes. The base64 decode approach works for extracting the user_id, but does NOT cryptographically verify the JWT signature. For true verification, you would need to call Supabase's `auth.getUser(token)` endpoint from n8n via HTTP Request. This is the recommended approach for production:

```
HTTP Request node → POST https://YOUR_PROJECT.supabase.co/auth/v1/user
Headers: Authorization: Bearer {jwt}, apikey: {supabase_anon_key}
Returns: user object with id, email, etc. (or 401 if invalid)
```

### Database & Auth (Supabase)

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| Supabase (hosted) | Latest cloud | PostgreSQL DB + Auth + Realtime | Replaces Google Sheets. Provides multi-tenant isolation via RLS, built-in auth, realtime subscriptions. | HIGH |
| Supabase Auth | Built into Supabase | Email/password authentication | PROJECT.md specifies email+password only, no OAuth. Supabase Auth handles signup, login, session refresh, JWT generation. | HIGH |
| Supabase RLS | Built into PostgreSQL | Multi-tenant data isolation | Row-Level Security ensures Tenant A cannot read Tenant B's data. Policies reference `auth.uid()` which maps to the authenticated user's JWT. | HIGH |
| Supabase Realtime | Built into Supabase | Progress tracking subscription | Frontend subscribes to `pipeline_runs` table changes. n8n updates step status, frontend receives updates via WebSocket. | HIGH |
| PostgREST | Built into Supabase | Auto-generated REST API | Frontend queries tables directly via Supabase client SDK. No need to build a separate API layer. | HIGH |

**Supabase Schema Design (Multi-Tenant):**

```sql
-- All tables have user_id for RLS tenant isolation
-- user_id references auth.users(id) automatically via Supabase Auth

-- User profiles (extends Supabase Auth)
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  business_name TEXT,
  business_url TEXT,
  industry TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ICP analysis results
CREATE TABLE icp_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  session_id TEXT NOT NULL,
  icp_data JSONB NOT NULL, -- Full ICP analysis from Claude
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Monthly themes (4 weekly "shows")
CREATE TABLE themes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  session_id TEXT NOT NULL,
  month TEXT NOT NULL, -- '2026-03'
  week_number INT NOT NULL CHECK (week_number BETWEEN 1 AND 4),
  theme_name TEXT NOT NULL,
  theme_data JSONB NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Individual content items (posts)
CREATE TABLE content_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  session_id TEXT NOT NULL,
  theme_id UUID REFERENCES themes(id),
  day_number INT NOT NULL,
  platform TEXT NOT NULL CHECK (platform IN ('linkedin', 'instagram', 'x', 'youtube')),
  post_text TEXT,
  image_prompt TEXT,
  image_url TEXT,
  video_script JSONB,
  hashtags TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'edited')),
  feedback TEXT,
  calendar_event_id TEXT, -- Google Calendar event ID after sync
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Chat messages (persistent per-user)
CREATE TABLE chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  session_id TEXT,
  role TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
  content TEXT NOT NULL,
  metadata JSONB, -- action taken, context, etc.
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Pipeline run progress tracking
CREATE TABLE pipeline_runs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  session_id TEXT NOT NULL UNIQUE,
  status TEXT DEFAULT 'running' CHECK (status IN ('running', 'completed', 'failed')),
  current_step INT DEFAULT 1,
  total_steps INT DEFAULT 6,
  step_details JSONB DEFAULT '[]'::JSONB, -- [{step: 1, name: "ICP Analysis", status: "completed", started_at, completed_at}]
  error TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for common queries
CREATE INDEX idx_icp_user_session ON icp_profiles(user_id, session_id);
CREATE INDEX idx_themes_user_month ON themes(user_id, month);
CREATE INDEX idx_content_user_session ON content_items(user_id, session_id);
CREATE INDEX idx_content_status ON content_items(user_id, status);
CREATE INDEX idx_chat_user_session ON chat_messages(user_id, session_id);
CREATE INDEX idx_pipeline_user ON pipeline_runs(user_id);
CREATE INDEX idx_pipeline_session ON pipeline_runs(session_id);
```

**RLS Policy Pattern:**

```sql
-- Enable RLS on every table
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE icp_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE themes ENABLE ROW LEVEL SECURITY;
ALTER TABLE content_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE pipeline_runs ENABLE ROW LEVEL SECURITY;

-- Standard tenant isolation pattern: user can only access their own rows
-- This single policy pattern applies to ALL tables above

-- SELECT: Users see only their own data
CREATE POLICY "Users read own data" ON icp_profiles
  FOR SELECT USING (auth.uid() = user_id);

-- INSERT: Users can only insert with their own user_id
CREATE POLICY "Users insert own data" ON icp_profiles
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- UPDATE: Users can only update their own rows
CREATE POLICY "Users update own data" ON icp_profiles
  FOR UPDATE USING (auth.uid() = user_id);

-- DELETE: Users can only delete their own rows
CREATE POLICY "Users delete own data" ON icp_profiles
  FOR DELETE USING (auth.uid() = user_id);

-- Repeat for ALL tables: themes, content_items, chat_messages, pipeline_runs, profiles

-- IMPORTANT: n8n backend uses the service_role key, which BYPASSES RLS.
-- This is correct — n8n operates as a trusted backend and sets user_id explicitly.
-- The service_role key must NEVER be exposed to the frontend.
```

**Two-Key Pattern:**
| Key | Used By | Bypasses RLS | Stored Where |
|-----|---------|-------------|-------------|
| `anon` key | Frontend (browser) | NO — RLS enforced | Embedded in HTML (safe) |
| `service_role` key | n8n backend | YES — full access | n8n credential store (NEVER in frontend) |

**Supabase Auth Integration (Frontend):**
```javascript
// Sign up
const { data, error } = await supabase.auth.signUp({
  email: 'user@example.com',
  password: 'securepassword'
})

// Sign in
const { data, error } = await supabase.auth.signInWithPassword({
  email: 'user@example.com',
  password: 'securepassword'
})

// Get current session (for passing JWT to n8n)
const { data: { session } } = await supabase.auth.getSession()
const jwt = session.access_token

// Pass JWT to n8n webhooks
await fetch(`${N8N_BASE_URL}/eluxr-phase1-analyzer`, {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${jwt}` // n8n validates this
  },
  body: JSON.stringify(formData)
})

// Listen for auth state changes (handle token refresh)
supabase.auth.onAuthStateChange((event, session) => {
  if (event === 'SIGNED_IN') showDashboard()
  if (event === 'SIGNED_OUT') showLoginScreen()
  if (event === 'TOKEN_REFRESHED') {
    // Session auto-refreshed — no action needed
    // supabase-js handles this automatically
  }
})
```

### Real-Time Progress Tracking

**Pattern: Supabase Realtime Subscriptions (not polling)**

The v1 fake progress simulation (`simulateProgress()` with hardcoded durations) is replaced with real progress updates:

```
Flow:
1. Frontend starts pipeline → calls n8n webhook
2. n8n creates row in pipeline_runs (status: 'running', step: 1)
3. Frontend subscribes to that pipeline_runs row via Supabase Realtime
4. After each phase completes, n8n updates the row (step: 2, 3, 4...)
5. Frontend receives update via WebSocket, updates progress UI
6. When status = 'completed', frontend shows results
```

**Frontend Subscription Code:**
```javascript
// Subscribe to pipeline progress
function subscribeToProgress(sessionId) {
  const channel = supabase
    .channel(`pipeline-${sessionId}`)
    .on(
      'postgres_changes',
      {
        event: 'UPDATE',
        schema: 'public',
        table: 'pipeline_runs',
        filter: `session_id=eq.${sessionId}`
      },
      (payload) => {
        const run = payload.new
        updateProgressUI(run.current_step, run.total_steps, run.step_details)

        if (run.status === 'completed') {
          channel.unsubscribe()
          showResults()
        }
        if (run.status === 'failed') {
          channel.unsubscribe()
          showError(run.error)
        }
      }
    )
    .subscribe()

  return channel // Store reference for cleanup
}
```

**n8n Progress Update (in each sub-workflow):**
```
HTTP Request node → PATCH https://YOUR_PROJECT.supabase.co/rest/v1/pipeline_runs?session_id=eq.{sessionId}
Headers:
  Authorization: Bearer {service_role_key}
  apikey: {service_role_key}
  Content-Type: application/json
  Prefer: return=minimal
Body: {
  "current_step": 2,
  "step_details": [...updated array...],
  "updated_at": "now()"
}
```

**Alternatively, use the n8n Supabase node** if it supports upsert/update operations. The HTTP Request approach is shown as a reliable fallback.

**Realtime Requirements:**
- Supabase Realtime must be enabled on the `pipeline_runs` table (it is by default for new tables, but verify in Supabase Dashboard under Database > Replication).
- RLS policies on `pipeline_runs` ensure users only receive updates for their own pipeline runs.

**Why NOT polling:**
- Polling every 2-3 seconds is 20-30 requests per minute per user. Realtime WebSocket is 1 persistent connection.
- Supabase Realtime is included in the free tier.
- Updates arrive instantly instead of with 2-3 second lag.
- However, implement a polling FALLBACK for environments where WebSockets fail (corporate firewalls, etc.):

```javascript
// Fallback polling (only if Realtime subscription fails)
function pollProgress(sessionId) {
  const interval = setInterval(async () => {
    const { data } = await supabase
      .from('pipeline_runs')
      .select('*')
      .eq('session_id', sessionId)
      .single()

    if (data) {
      updateProgressUI(data.current_step, data.total_steps, data.step_details)
      if (data.status === 'completed' || data.status === 'failed') {
        clearInterval(interval)
      }
    }
  }, 3000) // Poll every 3 seconds

  return interval
}
```

### Static Frontend Deployment

| Technology | Purpose | Why | Confidence |
|------------|---------|-----|------------|
| Vercel | Static hosting | Free tier, automatic HTTPS, instant deploys from Git, no build step needed for static HTML. | HIGH |

**Why Vercel over Netlify:**
Both work for static HTML. Vercel is recommended because:
1. Both have generous free tiers for static sites
2. Both support custom domains with automatic HTTPS
3. Both deploy from Git with zero configuration for static files
4. Vercel's edge network is slightly faster in most benchmarks
5. Either is fine — the choice is marginal for a single HTML file

**Vercel Configuration for Static HTML (no framework):**

Create `vercel.json` in project root:
```json
{
  "buildCommand": null,
  "outputDirectory": ".",
  "framework": null,
  "headers": [
    {
      "source": "/(.*)",
      "headers": [
        { "key": "X-Content-Type-Options", "value": "nosniff" },
        { "key": "X-Frame-Options", "value": "DENY" },
        { "key": "Referrer-Policy", "value": "strict-origin-when-cross-origin" }
      ]
    }
  ],
  "rewrites": [
    { "source": "/(.*)", "destination": "/index.html" }
  ]
}
```

**Key points:**
- `buildCommand: null` — no build step. Vercel serves the files as-is.
- `outputDirectory: "."` — the root directory IS the output.
- `framework: null` — tell Vercel this is not a framework project.
- The rewrite rule ensures any path serves `index.html` (SPA-like behavior for a single-page app).

**Environment Variables:**
- Supabase URL and anon key are NOT secrets — they go directly in the HTML.
- Do NOT use Vercel environment variables for Supabase client config. The HTML file needs them at runtime, not build time (there is no build).
- If you want configurability, use a `config.js` file loaded before the main script:

```html
<script src="config.js"></script>
<script type="module">
  // config.js defines: window.ELUXR_CONFIG = { supabaseUrl, supabaseAnonKey, n8nWebhookBase }
  const supabase = createClient(
    window.ELUXR_CONFIG.supabaseUrl,
    window.ELUXR_CONFIG.supabaseAnonKey
  )
</script>
```

### External AI APIs (Unchanged from v1)

| Service | Model | Purpose | Called From | Credential Storage |
|---------|-------|---------|-------------|-------------------|
| Anthropic Claude | claude-sonnet-4-20250514 | ICP gen, themes, posts, scripts, chat | n8n (HTTP Request) | n8n credential store (already set up) |
| Perplexity AI | sonar-pro | Market research, trend research | n8n (HTTP Request) | n8n credential store (must migrate) |
| KIE AI | nano-banana-pro | Image generation | n8n (HTTP Request) | n8n credential store (MUST migrate — currently hardcoded as `Bearer 7f48c3109ae4ee6aee94ba7389bdcaa4`) |
| KIE AI | veo3_fast | Video generation | n8n (HTTP Request) | n8n credential store (MUST migrate — same hardcoded token) |
| Google Calendar | Calendar API | Post scheduling sync | n8n (Google Calendar node) | n8n credential store (already set up) |

**CRITICAL SECURITY FIX:** The v1 workflow has the KIE API key hardcoded as a plaintext Bearer token in at least 5 HTTP Request nodes (lines 183, 215, 349, 415, 1121 of the workflow JSON). This must be migrated to a Header Auth credential in n8n's credential store before any public deployment.

### Supporting Libraries

| Library | Version | Purpose | How Loaded | Confidence |
|---------|---------|---------|------------|------------|
| Google Fonts (Playfair Display, DM Sans, JetBrains Mono) | N/A | Typography | CDN `<link>` tag (already in v1) | HIGH |
| No animation library | N/A | Premium animations | Use CSS `@keyframes` + `IntersectionObserver` for scroll-triggered animations. No library needed for the effects described in PROJECT.md. | HIGH |

**What NOT to add:**
| Library | Why Not |
|---------|---------|
| GSAP / Framer Motion / anime.js | Overkill for the animation requirements. CSS animations + `IntersectionObserver` handle staggered reveals, glassmorphism, and smooth transitions. Adding a 50KB+ animation library for what CSS does natively is wasteful. |
| Axios | `fetch()` is built into all modern browsers. The v1 already uses `fetch()` throughout. No reason to add Axios. |
| jQuery | Adds 87KB for nothing that vanilla JS cannot do. The v1 is already vanilla. |
| Tailwind CSS | No build step. Tailwind requires PostCSS processing. The existing custom CSS with CSS variables is clean and works. |
| date-fns / luxon / moment | The v1 uses `Date` and `toISOString()` which is sufficient. The calendar is month-level, not timezone-sensitive. |
| UUID library | Use `crypto.randomUUID()` (browser native) or let Supabase `gen_random_uuid()` handle it server-side. |

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Database | Supabase | PlanetScale / Neon | Supabase provides auth + realtime + RLS in one product. PlanetScale is MySQL (no RLS). Neon is just Postgres without auth/realtime. |
| Database | Supabase | Firebase | Firebase Firestore has weaker querying, no SQL, vendor lock-in to Google ecosystem. Supabase is open-source Postgres. |
| Auth | Supabase Auth | Auth0 / Clerk | Adding a separate auth provider when Supabase includes auth for free adds complexity and cost. Supabase Auth JWTs work natively with RLS. |
| Frontend hosting | Vercel | Netlify | Marginal difference. Both work. Vercel chosen for slight performance edge and simpler static config. |
| Frontend hosting | Vercel | Cloudflare Pages | Also viable. Vercel has better DX for quick deploys. Cloudflare Pages has stricter size limits. |
| Realtime | Supabase Realtime | Server-Sent Events from n8n | n8n webhooks are request-response, not streaming. SSE would require a separate server. Supabase Realtime is built-in and free. |
| Realtime | Supabase Realtime | Polling Supabase REST | Works but wasteful. 20-30 requests/min/user vs 1 WebSocket. Use polling only as fallback. |
| Backend orchestration | n8n sub-workflows | n8n + separate Express API | Adding a Node.js API server defeats the purpose of n8n. n8n handles the orchestration; Supabase handles the API layer. |
| CSS animations | CSS @keyframes + IntersectionObserver | GSAP | No build step, no dependencies, CSS animations are GPU-accelerated and sufficient for reveals/transitions. |

---

## Full Architecture Diagram (Text)

```
[Browser / Vercel-hosted HTML]
  |
  |-- Supabase Client SDK (CDN import)
  |     |-- Auth (signup/login/session)
  |     |-- DB queries (read content, update approvals)
  |     |-- Realtime (subscribe to pipeline_runs changes)
  |
  |-- n8n Webhooks (POST with JWT in Authorization header)
        |
        [n8n Cloud - flowbound.app.n8n.cloud]
          |-- Orchestrator workflow (chains sub-workflows)
          |     |-- Phase 1: ICP Analysis (Perplexity + Claude)
          |     |-- Phase 2: Theme Generation (Claude)
          |     |-- Phase 3: Content Generation (Claude + KIE)
          |     |-- Phase 4: Approval Queue (Supabase CRUD)
          |     |-- Progress updates after each phase (Supabase HTTP)
          |
          |-- Chat workflow (Claude + Supabase memory)
          |-- Tools workflows (standalone video/image gen)
          |
          |-- Supabase service_role key (bypasses RLS for backend writes)
          |-- Claude API key (credential store)
          |-- Perplexity API key (credential store)
          |-- KIE API key (credential store - MUST MIGRATE)
          |-- Google Calendar OAuth (credential store)
```

---

## Migration Path from v1 to v2

### What Changes

| Component | v1 | v2 | Migration Effort |
|-----------|-----|-----|-----------------|
| Data storage | Google Sheets (16 Sheet nodes) | Supabase PostgreSQL | HIGH — rewrite all read/write operations |
| Authentication | None | Supabase Auth (email/password) | MEDIUM — add auth UI + JWT passing |
| Multi-tenancy | None (single user) | RLS policies on all tables | MEDIUM — schema design + policy creation |
| Progress tracking | Fake `simulateProgress()` | Real Supabase Realtime | MEDIUM — new subscription + n8n progress writes |
| API security | No webhook auth, hardcoded KIE key | JWT auth + credential store | MEDIUM — add auth middleware + migrate credentials |
| Workflow structure | 1 monolithic (116KB, 13 webhooks) | 7 sub-workflows | HIGH — decompose and rewire all connections |
| Hosting | Local file:// or local server | Vercel static deployment | LOW — just push to Vercel |
| State management | localStorage + in-memory | Supabase DB + localStorage cache | MEDIUM — replace localStorage writes with Supabase |
| Chat memory | None (ephemeral) | Supabase `chat_messages` table | LOW — add read/write to existing chat endpoint |

### What Stays the Same

- Frontend framework: Vanilla HTML/CSS/JS (enhance, don't rewrite)
- AI models: Claude Sonnet 4, Perplexity sonar-pro, KIE nano-banana-pro
- n8n cloud instance: flowbound.app.n8n.cloud
- Google Calendar sync: Same OAuth credential, same Calendar node
- Color scheme, fonts, 3-tab layout structure
- Netflix content model (4 weekly shows, 30-day campaigns)
- Content generation prompts (refine, don't rewrite from scratch)

---

## Version Confidence Notes

| Technology | Stated Version | Confidence | Notes |
|------------|---------------|------------|-------|
| @supabase/supabase-js | ^2.45.x | MEDIUM | Was 2.45.x as of mid-2025. May be 2.47+ or even v3 by now. Using `@2` in CDN URL auto-resolves to latest 2.x. Verify before deployment. |
| n8n Cloud | Auto-managed | HIGH | Cloud instances auto-update. No version to pin. |
| n8n HTTP Request node | v4.2 | HIGH | Confirmed from v1 workflow JSON. |
| Supabase Realtime | v2 protocol | MEDIUM | Supabase Realtime has had protocol upgrades. The client SDK abstracts this. Using latest SDK ensures latest protocol. |
| Claude model | claude-sonnet-4-20250514 | HIGH | Confirmed from v1 workflow JSON line 78. |
| Vercel | Latest | HIGH | SaaS platform, no version to pin. |

**Action item:** Before starting development, run a quick version check:
1. Visit `https://esm.sh/@supabase/supabase-js` to confirm latest 2.x version
2. Check Supabase docs for any breaking changes since mid-2025
3. Verify n8n Supabase node capabilities in the n8n node library

---

## Installation / Setup Checklist

There is no `npm install` because this is a static HTML project with CDN imports. Setup steps:

### 1. Supabase Project
```
1. Create Supabase project at app.supabase.com
2. Run the schema SQL (from above) in SQL Editor
3. Enable RLS on all tables
4. Create RLS policies (from above)
5. Note the project URL and anon key (for frontend)
6. Note the service_role key (for n8n credential store ONLY)
7. Enable Realtime on pipeline_runs table (Database > Replication)
8. Configure Auth: enable email/password, disable all OAuth providers
```

### 2. n8n Credentials
```
1. Add Supabase credential (type: supabaseApi) with service_role key
2. Create Header Auth credential for KIE AI: name "KIE API", value "Bearer {key}"
3. Verify Anthropic credential exists (already there)
4. Verify/create Perplexity credential
5. Verify Google Calendar OAuth credential (already there)
6. Remove Google Sheets credential after migration complete
```

### 3. Frontend Config
```html
<!-- Add to index.html <head> before main script -->
<script>
  window.ELUXR_CONFIG = {
    supabaseUrl: 'https://YOUR_PROJECT.supabase.co',
    supabaseAnonKey: 'eyJ...', // Safe to expose
    n8nWebhookBase: 'https://flowbound.app.n8n.cloud/webhook'
  }
</script>
<script type="module">
  import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
  window.supabase = createClient(
    window.ELUXR_CONFIG.supabaseUrl,
    window.ELUXR_CONFIG.supabaseAnonKey
  )
</script>
```

### 4. Vercel Deployment
```
1. Push project to GitHub (or connect existing repo)
2. Import project in Vercel dashboard
3. Set Framework Preset: "Other"
4. Set Build Command: (leave empty)
5. Set Output Directory: "."
6. Deploy
7. Configure custom domain if desired
```

---

## Sources

| Source | Type | Confidence |
|--------|------|-----------|
| v1 workflow JSON (`ELUXR social media Action v2 (3).json`) | Primary source — analyzed directly | HIGH |
| v1 frontend (`index.html`) | Primary source — analyzed directly | HIGH |
| PROJECT.md | Primary source — project constraints | HIGH |
| Supabase documentation (training data, May 2025 cutoff) | Training data — may be stale | MEDIUM |
| n8n documentation (training data) | Training data — sub-workflow patterns well-established | MEDIUM |
| Vercel documentation (training data) | Training data — static hosting is stable | HIGH |

**Gaps requiring verification before development:**
- Exact latest @supabase/supabase-js version (use CDN `@2` to auto-resolve)
- n8n Supabase native node capabilities (may handle upsert/select/update, reducing HTTP Request usage)
- Supabase Realtime RLS interaction (verify subscriptions respect RLS in current version)
- n8n cloud Code node limitations (which built-in modules are available for JWT handling)
