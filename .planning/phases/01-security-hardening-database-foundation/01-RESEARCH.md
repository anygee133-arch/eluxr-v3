# Phase 1 Research: Security Hardening + Database Foundation

**Researched:** 2026-02-27
**Phase Goal:** The Supabase database exists with tenant-isolated tables, and all API keys are secured in the n8n credential store -- establishing the infrastructure every subsequent phase depends on.
**Research Flag:** LOW (confirmed -- all patterns are well-documented)

---

## Table of Contents

1. [Research Question](#research-question)
2. [Work Area A: KIE API Key Migration (INFRA-05)](#work-area-a-kie-api-key-migration-infra-05)
3. [Work Area B: Supabase Database Schema (INFRA-01)](#work-area-b-supabase-database-schema-infra-01)
4. [Work Area C: Row-Level Security (INFRA-02)](#work-area-c-row-level-security-infra-02)
5. [Work Area D: Supabase CLI Migrations (MOD-7)](#work-area-d-supabase-cli-migrations-mod-7)
6. [Work Area E: Test Accounts + Tenant Isolation Verification](#work-area-e-test-accounts--tenant-isolation-verification)
7. [Work Area F: n8n Supabase Credential Setup](#work-area-f-n8n-supabase-credential-setup)
8. [Pitfall Mitigations](#pitfall-mitigations)
9. [Open Questions Resolved](#open-questions-resolved)
10. [Dependencies and Ordering Constraints](#dependencies-and-ordering-constraints)
11. [Sources](#sources)

---

## Research Question

**"What do I need to know to PLAN this phase well?"**

This phase has three distinct work areas that must be executed in a specific order:

1. **Security fix (INFRA-05):** Migrate KIE API key from hardcoded plaintext to n8n credential store -- must happen FIRST before any workflow splitting in Phase 3 to prevent propagating the flaw
2. **Database creation (INFRA-01):** Create all Supabase tables with `user_id` columns -- must happen before any other phase can write data
3. **Tenant isolation (INFRA-02):** Enable RLS on every table and write isolation policies -- must happen at table creation time, never "later"

The research flag is LOW because these are well-documented patterns. The risk is not in the technical complexity but in execution discipline: missing a `user_id` column, forgetting RLS on one table, or leaving a second copy of the hardcoded key creates security holes that compound through all subsequent phases.

---

## Work Area A: KIE API Key Migration (INFRA-05)

### Current State (Confirmed via Workflow JSON Analysis)

The KIE API key `7f48c3109ae4ee6aee94ba7389bdcaa4` appears as a plaintext `Bearer` token in **5 HTTP Request nodes** (not 4 as originally estimated):

| Line | Node Name | Node ID | API Endpoint | Purpose |
|------|-----------|---------|-------------|---------|
| 183 | `KIE -- Create Image Task` | `2c44ddce-f441-499d-bc61-95e49da42316` | `POST api.kie.ai/api/v1/jobs/createTask` | Standalone image generation (nano-banana-pro) |
| 215 | `KIE -- Get Image Result` | `4f2a54ae-b572-44e1-a39a-acdc3435f4c2` | `GET api.kie.ai/api/v1/jobs/recordInfo?taskId=...` | Poll standalone image status |
| 349 | `KIE -- Create Video Task` | (at line 340) | `POST api.kie.ai/api/v1/veo/generate` | Standalone video generation (veo3_fast) |
| 415 | `KIE -- Get Video Status` | `83a8020f-d588-4480-a22b-6afae6f9b5ed` | `GET api.kie.ai/api/v1/veo/record-info?taskId=...` | Poll standalone video status |
| 1121 | `KIE -- Generate Content Image` | `c4368be5-2b98-4905-a7a9-cb091162483b` | `POST api.kie.ai/api/v1/jobs/createTask` | Pipeline content image generation (nano-banana-pro) |

### Other API Key Status (Verified)

| API | Current Status | Action Needed |
|-----|---------------|---------------|
| **Anthropic Claude** | Already in credential store (`anthropicApi`, ID: `cZwkXj4ZfHTkpBtT`) | None |
| **Perplexity AI** | Already in credential store (`perplexityApi`, ID: `3rYRY1C2K9o0DDXI`) | None |
| **KIE AI** | HARDCODED in 5 nodes | Create Header Auth credential, update all 5 nodes |
| **Google Sheets** | Already in credential store (`googleSheetsOAuth2Api`, ID: `DfLuGqHDJkGpiO8P`) | Keep until Phase 3 migration |
| **Google Calendar** | Already in credential store (`googleCalendarOAuth2Api`, ID: `FJBcOjKITBIaEqRV`) | None |

### Migration Procedure: n8n Header Auth Credential

The KIE API uses a standard `Authorization: Bearer <token>` header pattern. n8n supports this via the **Header Auth** credential type (or **Bearer Auth** which is a convenience wrapper).

**Step-by-step procedure:**

1. **Create the credential in n8n:**
   - Go to Credentials in n8n Cloud (flowbound.app.n8n.cloud)
   - Click "Add Credential"
   - Search for "Header Auth" (generic credential type)
   - Name: `KIE AI API`
   - Header Name: `Authorization`
   - Header Value: `Bearer 7f48c3109ae4ee6aee94ba7389bdcaa4`
   - Save

   **Alternative:** Use "Bearer Auth" credential type instead of "Header Auth"
   - This is a convenience wrapper that auto-prepends "Bearer " to the value
   - Name: `KIE AI API`
   - Token: `7f48c3109ae4ee6aee94ba7389bdcaa4` (no "Bearer " prefix needed)
   - Save

2. **Update each HTTP Request node (5 nodes):**
   - Open the node
   - Change Authentication from "None" to "Predefined Credential Type"
   - Select credential type: `httpHeaderAuth` (or `httpBearerAuth` if using Bearer Auth)
   - Select credential: `KIE AI API`
   - Remove the manual `Authorization` header from `headerParameters`
   - Keep any other headers (e.g., `Content-Type: application/json`)
   - Save

3. **Verify each node still works:**
   - Test `KIE -- Create Image Task` with a simple prompt
   - Test `KIE -- Get Image Result` with a known taskId
   - Test `KIE -- Create Video Task` with a simple prompt
   - Test `KIE -- Get Video Status` with a known taskId
   - Test `KIE -- Generate Content Image` (pipeline node)

4. **Audit the workflow JSON for remaining secrets:**
   - Export the workflow JSON
   - Search for `7f48c3109ae4ee6aee94ba7389bdcaa4` -- should return zero matches
   - Search for `Bearer ` followed by alphanumeric strings -- should only find credential references
   - Search for any other API key patterns (long hex/alphanumeric strings in header values)

### KIE API Endpoints Summary (For Reference)

| Endpoint | Method | Purpose | Model |
|----------|--------|---------|-------|
| `https://api.kie.ai/api/v1/jobs/createTask` | POST | Create image generation task | nano-banana-pro |
| `https://api.kie.ai/api/v1/jobs/recordInfo?taskId={id}` | GET | Poll image task status | -- |
| `https://api.kie.ai/api/v1/veo/generate` | POST | Create video generation task | veo3_fast |
| `https://api.kie.ai/api/v1/veo/record-info?taskId={id}` | GET | Poll video task status | -- |

### Risk Assessment

- **Effort:** LOW (1-2 hours)
- **Risk:** LOW (straightforward credential migration)
- **Blocking:** Must complete BEFORE Phase 3 workflow splitting, otherwise the key propagates to 13 sub-workflows

---

## Work Area B: Supabase Database Schema (INFRA-01)

### Supabase Project Status

The Supabase project already exists:
- **URL:** `https://llpnwaoxisfwptxvdfed.supabase.co`
- **Project Reference ID:** `llpnwaoxisfwptxvdfed` (extracted from URL)
- **Anon Key:** `sb_publishable_9gnLO_J9HBxVta1f8Ecvxw_KO8huPYQ`

### Required Tables (10 tables)

Based on the architecture research, these tables are needed. All have `user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE` except `profiles` which uses `id` as the FK.

| # | Table | Purpose | Key Columns | Unique Constraint |
|---|-------|---------|-------------|-------------------|
| 1 | `profiles` | Extends auth.users with business data | `id` (PK = FK to auth.users), email, display_name, business_url, industry | `id` is unique (PK) |
| 2 | `icps` | ICP analysis results | user_id, business_url, industry, icp_summary, demographics (JSONB), psychographics (JSONB), content_preferences (JSONB), competitors (JSONB), content_opportunities (JSONB), recommended_hashtags (JSONB), raw_research | `UNIQUE(user_id)` -- one active ICP per user |
| 3 | `campaigns` | Monthly content campaigns | user_id, month (TEXT like '2026-03'), status | `UNIQUE(user_id, month)` |
| 4 | `themes` | Weekly "shows" (4 per campaign) | user_id, campaign_id (FK), week_number, theme_name, theme_description, show_concept, hook, content_types (JSONB) | -- |
| 5 | `content_items` | Individual posts | user_id, campaign_id (FK), theme_id (FK), title, content, content_type, platform, scheduled_date, scheduled_time, status, image_url, video_url, image_prompt, feedback | -- |
| 6 | `pipeline_runs` | Real-time progress tracking | user_id, pipeline_type, status, current_step, total_steps, step_label, step_progress, error_message, started_at, completed_at, metadata (JSONB) | -- |
| 7 | `chat_conversations` | Conversation threads | user_id, title | -- |
| 8 | `chat_messages` | Individual chat messages | user_id, conversation_id (FK), role, content, actions_taken (JSONB), phase_context | -- |
| 9 | `trend_alerts` | Weekly trend research results | user_id, trend_topic, relevance_score, summary, suggested_content (JSONB), source, status | -- |
| 10 | `tool_outputs` | Standalone tool history | user_id, tool_type, input_params (JSONB), output_data (JSONB) | -- |

### Profiles Table: Auto-Creation Trigger

When a user signs up via Supabase Auth, a row must be auto-created in `profiles`. This is the standard Supabase pattern using a database trigger:

```sql
-- Function to auto-create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.profiles (id, email)
  VALUES (new.id, new.email);
  RETURN new;
END;
$$;

-- Trigger fires after new user inserted into auth.users
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
```

**Critical warning:** If this trigger function fails (e.g., due to a bug in the SQL), it will block ALL signups. Test thoroughly before enabling in production. The function uses `SECURITY DEFINER` to run with elevated privileges and `SET search_path = ''` to prevent search path injection.

### Mapping: Google Sheets to Supabase Tables

The v1 workflow uses a single Google Sheets spreadsheet (`1zlIBLhRt_5VSe3Aw8qTp-9p5hpA8j_1ItUrvUBbULjU`) with multiple tabs. Here is the mapping:

| Google Sheet Tab | Supabase Table | Notes |
|-----------------|---------------|-------|
| ELUXR_ICP | `icps` | ICP analysis results (one row per user in v2) |
| ELUXR_Themes | `campaigns` + `themes` | Split into normalized tables |
| ELUXR_Content | `content_items` | All generated posts |
| ELUXR_Approval_Queue | `content_items` (status column) | Approval is a status on content_items, not a separate table |
| ELUXR_Calendar | `content_items` (scheduled_date) | Calendar view queries content_items by date |
| Chat history | `chat_conversations` + `chat_messages` | New tables (v1 has no persistent chat) |

### Column Type Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Primary keys | `UUID DEFAULT gen_random_uuid()` | Standard Supabase pattern. `gen_random_uuid()` is a PostgreSQL built-in (no extension needed). |
| Timestamps | `TIMESTAMPTZ DEFAULT NOW()` | Timezone-aware. `NOW()` captures insertion time. |
| Status columns | `TEXT` with `CHECK` constraint | Simpler than enum types. Easier to add new statuses via migration. |
| Platform column | `TEXT` with `CHECK` constraint | `CHECK (platform IN ('linkedin', 'instagram', 'x', 'youtube'))` -- lowercase for consistency. |
| JSONB columns | `JSONB` (not `JSON`) | JSONB supports indexing and is faster for queries. Used for flexible data (ICP sections, content types, action logs). |
| Month column | `TEXT` (e.g., '2026-03') | Simpler than date types for month-level granularity. Easy to query and display. |

---

## Work Area C: Row-Level Security (INFRA-02)

### RLS Policy Pattern

Every table gets the same base isolation policy. The pattern is simple and performant:

```sql
-- For tables with user_id column:
CREATE POLICY "Users can view own data" ON public.<table>
    FOR SELECT USING ((select auth.uid()) = user_id);

CREATE POLICY "Users can insert own data" ON public.<table>
    FOR INSERT WITH CHECK ((select auth.uid()) = user_id);

CREATE POLICY "Users can update own data" ON public.<table>
    FOR UPDATE USING ((select auth.uid()) = user_id);

CREATE POLICY "Users can delete own data" ON public.<table>
    FOR DELETE USING ((select auth.uid()) = user_id);

-- For profiles table (where id IS the user_id):
CREATE POLICY "Users can view own profile" ON public.profiles
    FOR SELECT USING ((select auth.uid()) = id);

CREATE POLICY "Users can update own profile" ON public.profiles
    FOR UPDATE USING ((select auth.uid()) = id);
```

### Performance Optimization: The `(select auth.uid())` Pattern

**This is critical.** The Supabase documentation explicitly recommends wrapping `auth.uid()` in a `SELECT` subquery:

- **Naive:** `USING (auth.uid() = user_id)` -- calls `auth.uid()` for EVERY ROW in the table
- **Optimized:** `USING ((select auth.uid()) = user_id)` -- calls `auth.uid()` ONCE, caches the result via PostgreSQL `initPlan`

The performance difference is dramatic on large tables (100x+ improvement reported). The `(select ...)` wrapper causes the PostgreSQL query planner to evaluate the function once and reuse the result, rather than re-executing per row.

**Use this pattern for ALL RLS policies in this project.**

Source: [Supabase RLS Performance and Best Practices](https://supabase.com/docs/guides/troubleshooting/rls-performance-and-best-practices-Z5Jjwv)

### Required Indexes for RLS Performance

Every column referenced in an RLS policy MUST be indexed. Without the index, RLS forces a sequential scan on every query.

```sql
-- Single-column indexes on user_id for RLS enforcement
CREATE INDEX idx_icps_user_id ON public.icps(user_id);
CREATE INDEX idx_campaigns_user_id ON public.campaigns(user_id);
CREATE INDEX idx_themes_user_id ON public.themes(user_id);
CREATE INDEX idx_content_items_user_id ON public.content_items(user_id);
CREATE INDEX idx_pipeline_runs_user_id ON public.pipeline_runs(user_id);
CREATE INDEX idx_chat_conversations_user_id ON public.chat_conversations(user_id);
CREATE INDEX idx_chat_messages_user_id ON public.chat_messages(user_id);
CREATE INDEX idx_trend_alerts_user_id ON public.trend_alerts(user_id);
CREATE INDEX idx_tool_outputs_user_id ON public.tool_outputs(user_id);

-- Composite indexes for common query patterns (beyond RLS)
CREATE INDEX idx_content_items_user_status ON public.content_items(user_id, status);
CREATE INDEX idx_content_items_user_campaign ON public.content_items(user_id, campaign_id);
CREATE INDEX idx_content_items_user_date ON public.content_items(user_id, scheduled_date);
CREATE INDEX idx_pipeline_runs_user_status ON public.pipeline_runs(user_id, status);
CREATE INDEX idx_chat_messages_conversation ON public.chat_messages(conversation_id, created_at);
CREATE INDEX idx_trend_alerts_user_status ON public.trend_alerts(user_id, status);
CREATE INDEX idx_themes_campaign ON public.themes(campaign_id);
```

**Note:** The single-column `user_id` indexes may seem redundant with the composite indexes, but PostgreSQL can use a composite index for the leading column. However, explicit single-column indexes ensure the RLS policy check is always optimized regardless of query pattern. The overhead of maintaining these indexes is negligible for the expected data volumes.

### Two-Key Access Pattern

| Key | Used By | Bypasses RLS | Storage Location |
|-----|---------|-------------|-----------------|
| `anon` key | Frontend (browser) | NO -- RLS enforced on every query | Embedded in HTML (safe -- RLS protects data) |
| `service_role` key | n8n backend | YES -- full access to all rows | n8n credential store (NEVER in frontend) |

This is the correct and standard Supabase multi-tenant pattern:
- **Frontend reads** go through the `anon` key + user JWT -- RLS automatically filters to the authenticated user's rows
- **n8n writes** go through the `service_role` key -- RLS is bypassed because n8n is a trusted backend that explicitly sets `user_id` on every insert/update

### Supabase Realtime Configuration

The `pipeline_runs` table must have Supabase Realtime enabled for real-time progress tracking (used in Phase 4). This is configured via:

1. Supabase Dashboard: Database > Replication > Enable for `pipeline_runs`
2. Or via SQL: `ALTER PUBLICATION supabase_realtime ADD TABLE public.pipeline_runs;`

**Do this during Phase 1** even though the frontend subscription is not built until Phase 4. The table schema should be complete from the start.

---

## Work Area D: Supabase CLI Migrations (MOD-7)

### Why Migrations Matter for This Project

Every schema change must be captured in a migration file so that:
- Changes are reproducible across environments (staging, production)
- The schema is version-controlled alongside the code
- Rollbacks are possible if a migration causes issues
- Multiple developers (or Claude sessions) can see the current schema state

### Supabase CLI Setup Procedure

```bash
# 1. Install Supabase CLI (if not already installed)
brew install supabase/tap/supabase   # macOS
# or: npm install -g supabase       # via npm

# 2. Login to Supabase
supabase login    # Opens browser for Personal Access Token

# 3. Initialize local project (from project root)
cd ~/workflow/eluxr-v2
supabase init     # Creates supabase/ directory with config.toml

# 4. Link to the existing remote project
supabase link --project-ref llpnwaoxisfwptxvdfed

# 5. Pull any existing remote schema (if tables already exist)
supabase db pull  # Creates supabase/migrations/<timestamp>_remote_schema.sql
```

### Migration Workflow for Phase 1

```bash
# Create the initial schema migration
supabase migration new create_initial_schema

# This creates: supabase/migrations/<timestamp>_create_initial_schema.sql
# Edit this file to contain ALL table definitions, RLS policies, indexes, and triggers

# Validate locally (if local Supabase is running)
supabase db reset  # Applies all migrations from scratch locally

# Push to remote production
supabase db push   # Applies new migrations to the linked remote project
```

### Migration File Strategy

For Phase 1, create a **single migration file** containing:
1. All 10 table definitions (CREATE TABLE)
2. All RLS enable statements (ALTER TABLE ... ENABLE ROW LEVEL SECURITY)
3. All RLS policies (CREATE POLICY)
4. All indexes (CREATE INDEX)
5. The `handle_new_user()` trigger function and trigger

**Rationale for single file:** These are all interdependent (tables reference each other via FKs, indexes reference tables, RLS references tables). Splitting them across multiple migrations adds complexity with no benefit for the initial schema.

### File Structure After Setup

```
~/workflow/eluxr-v2/
  supabase/
    config.toml              # Supabase CLI config (auto-generated)
    migrations/
      <timestamp>_create_initial_schema.sql   # Phase 1 schema
    seed.sql                  # Optional: test data for development
```

Source: [Supabase Database Migrations](https://supabase.com/docs/guides/deployment/database-migrations), [Supabase CLI Getting Started](https://supabase.com/docs/guides/local-development/cli/getting-started)

---

## Work Area E: Test Accounts + Tenant Isolation Verification

### Test Account Setup

Create two test accounts in Supabase Auth to verify tenant isolation:

| Account | Email | Purpose |
|---------|-------|---------|
| Test User A | `testuser-a@eluxr.test` | Primary test account |
| Test User B | `testuser-b@eluxr.test` | Cross-tenant isolation verification |

**Creation method:** Use the Supabase Dashboard (Authentication > Users > Add User) or the SQL Editor:

```sql
-- Create test users via Supabase Auth API (Dashboard is easier)
-- After creation, note the UUIDs for both users
```

### Tenant Isolation Verification Procedure

After tables and RLS are in place, run these verification queries from the Supabase SQL Editor:

```sql
-- 1. Insert test data for User A
INSERT INTO public.icps (user_id, business_url, industry, icp_summary)
VALUES ('<user_a_uuid>', 'https://example-a.com', 'Tech', 'Test ICP for User A');

-- 2. Insert test data for User B
INSERT INTO public.icps (user_id, business_url, industry, icp_summary)
VALUES ('<user_b_uuid>', 'https://example-b.com', 'Finance', 'Test ICP for User B');

-- 3. Simulate User A querying (should see ONLY their data)
SET request.jwt.claims = '{"sub": "<user_a_uuid>", "role": "authenticated"}';
SET ROLE authenticated;
SELECT * FROM public.icps;
-- EXPECTED: 1 row (User A's ICP only)

-- 4. Verify User A cannot see User B's data
SELECT * FROM public.icps WHERE user_id = '<user_b_uuid>';
-- EXPECTED: 0 rows (RLS blocks this)

-- 5. Simulate User B querying
SET request.jwt.claims = '{"sub": "<user_b_uuid>", "role": "authenticated"}';
SET ROLE authenticated;
SELECT * FROM public.icps;
-- EXPECTED: 1 row (User B's ICP only)

-- 6. Reset role
RESET ROLE;

-- 7. Repeat for ALL tables (campaigns, themes, content_items, etc.)
```

### Automated Verification Script

To systematically verify all 10 tables, run the isolation check for each table. The verification passes when:
- User A sees exactly 1 row (their own)
- User A sees exactly 0 rows belonging to User B
- User B sees exactly 1 row (their own)
- User B sees exactly 0 rows belonging to User A

### What to Test Beyond Basic Isolation

| Test | What It Proves | SQL Pattern |
|------|---------------|-------------|
| SELECT isolation | User can only read own rows | `SELECT * FROM table` as authenticated user |
| INSERT protection | User cannot insert rows with another user's ID | `INSERT INTO table (user_id, ...) VALUES ('<other_user_uuid>', ...)` -- should fail |
| UPDATE protection | User cannot modify another user's rows | `UPDATE table SET ... WHERE user_id = '<other_user_uuid>'` -- should update 0 rows |
| DELETE protection | User cannot delete another user's rows | `DELETE FROM table WHERE user_id = '<other_user_uuid>'` -- should delete 0 rows |
| Service role bypass | n8n (service_role) can access all rows | Query with `service_role` key -- should see all rows |

---

## Work Area F: n8n Supabase Credential Setup

### Credential: Supabase Service Role Key

The `service_role` key is needed for n8n to write to Supabase (bypassing RLS). This key must be stored in the n8n credential store.

**Setup procedure:**

1. Get the `service_role` key from Supabase Dashboard:
   - Project Settings > API > Service Role Key (keep secret)

2. Create credential in n8n:
   - Go to Credentials in n8n Cloud
   - Add Credential > Search for "Supabase"
   - If n8n has a native Supabase credential type: use it
   - If not: Create a "Header Auth" credential:
     - Name: `Supabase Service Role`
     - Header Name: `apikey`
     - Header Value: `<service_role_key>`

3. For HTTP Request nodes that write to Supabase, the request pattern is:

```
Method: POST/PATCH/DELETE
URL: https://llpnwaoxisfwptxvdfed.supabase.co/rest/v1/<table_name>
Headers:
  Authorization: Bearer <service_role_key>
  apikey: <service_role_key>
  Content-Type: application/json
  Prefer: return=minimal (or return=representation)
```

**Note:** Supabase REST API requires BOTH `Authorization` and `apikey` headers. This means a single Header Auth credential is not sufficient. Options:

- **Option A (recommended):** Use n8n's native Supabase node (if available and capable) -- it handles auth automatically
- **Option B:** Use a Custom Auth credential with both headers:
  ```json
  {
    "headers": {
      "Authorization": "Bearer <service_role_key>",
      "apikey": "<service_role_key>"
    }
  }
  ```
- **Option C:** Store the service_role key as an n8n environment variable and reference it in HTTP Request nodes -- `{{$env.SUPABASE_SERVICE_ROLE_KEY}}`

This detail needs to be resolved during planning, but the key point is: the `service_role` key goes into the n8n credential store, never into node parameters.

---

## Pitfall Mitigations

### CRIT-1: Missing Tenant Isolation

| Aspect | Mitigation |
|--------|-----------|
| **What could go wrong** | Forgetting `user_id` on one table, or not enabling RLS, allowing cross-tenant data access |
| **Prevention** | The migration file contains ALL tables with `user_id` + RLS + policies in a single atomic migration. No table exists without isolation. |
| **Verification** | Tenant isolation test procedure (Work Area E) must pass for ALL 10 tables before Phase 1 is considered complete |

### CRIT-2: Hardcoded KIE API Key

| Aspect | Mitigation |
|--------|-----------|
| **What could go wrong** | Missing one of the 5 occurrences, or the key being present in workflow exports |
| **Prevention** | Exact line numbers documented (183, 215, 349, 415, 1121). Post-migration audit searches for the key string. |
| **Verification** | Export workflow JSON, search for `7f48c3109ae4ee6aee94ba7389bdcaa4` -- must return zero matches |

### CRIT-4: RLS Performance

| Aspect | Mitigation |
|--------|-----------|
| **What could go wrong** | Slow queries on large tables due to RLS policy execution overhead |
| **Prevention** | Use `(select auth.uid())` caching pattern in ALL policies. Index ALL `user_id` columns. Keep policies simple (direct column comparison only, no joins or subqueries). |
| **Verification** | Test with `EXPLAIN ANALYZE` on tables with seed data (100+ rows) to confirm index scans, not sequential scans |

### MOD-7: Migration Strategy

| Aspect | Mitigation |
|--------|-----------|
| **What could go wrong** | Schema drift between environments due to Dashboard-only edits |
| **Prevention** | Initialize Supabase CLI and migration files in Phase 1. ALL schema changes go through migration files. Zero Dashboard SQL edits in production. |
| **Verification** | `supabase db push` applies cleanly. Migration files are in version control. |

---

## Open Questions Resolved

| Question | Answer | Confidence |
|----------|--------|-----------|
| How many nodes have the hardcoded KIE key? | **5 nodes** (not 4 as originally estimated). Found at lines 183, 215, 349, 415, and 1121. | HIGH (direct JSON analysis) |
| Is the Perplexity API key hardcoded? | **No.** It uses `predefinedCredentialType: perplexityApi` with credential ID `3rYRY1C2K9o0DDXI`. Already secure. | HIGH (direct JSON analysis) |
| What credential type for KIE in n8n? | **Header Auth** (name: Authorization, value: Bearer <token>) or **Bearer Auth** (convenience wrapper). Both are built-in n8n credential types. | HIGH (verified via n8n docs) |
| What is the Supabase project reference ID? | **`llpnwaoxisfwptxvdfed`** (extracted from the Supabase URL). Needed for `supabase link --project-ref`. | HIGH |
| How many webhooks are in the v1 workflow? | **14 webhook endpoints** (13 named + 1 internal Wait webhook). All use `allowedOrigins: "*"`. Securing these is Phase 2 work. | HIGH (direct JSON analysis) |
| Should `(select auth.uid())` be used instead of `auth.uid()` in RLS? | **Yes.** Supabase official docs recommend `(select auth.uid())` for performance caching. 100x improvement on large tables. | HIGH (Supabase docs) |

### Questions Still Open (Not Blocking Phase 1)

| Question | Why It's Not Blocking | When to Resolve |
|----------|----------------------|----------------|
| Does n8n have a native Supabase node with UPSERT support? | Phase 1 only creates schema; n8n writes start in Phase 3 | Before Phase 3 |
| What are n8n Cloud execution limits? | Not relevant until pipeline execution in Phase 3+ | Before Phase 3 |
| Does n8n Cloud handle CORS preflight for auth headers? | Not relevant until frontend auth in Phase 2 | Before Phase 2 |

---

## Dependencies and Ordering Constraints

### Internal Ordering (Within Phase 1)

```
Step 1: KIE API key migration in n8n (INFRA-05)
    |-- No prerequisite. Do this first.
    |-- Blocks: nothing in Phase 1, but blocks Phase 3 workflow splitting
    |
Step 2: Supabase CLI setup + migration file creation
    |-- No prerequisite (Supabase project already exists)
    |
Step 3: Run migration (create tables + RLS + indexes + triggers)
    |-- Requires: Step 2 (migration file must exist)
    |
Step 4: Create test accounts
    |-- Requires: Step 3 (profiles trigger must exist)
    |
Step 5: Verify tenant isolation
    |-- Requires: Step 3 (tables + RLS), Step 4 (test accounts)
    |
Step 6: Set up Supabase service_role credential in n8n
    |-- Can happen anytime (independent of schema)
    |-- Blocks: Phase 3 (n8n needs to write to Supabase)
```

Steps 1 and 2 can run in parallel. Steps 5 and 6 can run in parallel after Step 4.

### External Dependencies (Blocking Other Phases)

| Phase 1 Deliverable | Phases It Unblocks |
|---------------------|--------------------|
| Tables with user_id + RLS | Phase 2 (Auth needs profiles table), Phase 3+ (all data writes) |
| KIE credential migration | Phase 3 (workflow splitting -- prevents key propagation) |
| Supabase service_role in n8n | Phase 3 (n8n writes to Supabase) |
| Test accounts | Phase 2 (used for auth testing) |
| CLI migration setup | All future phases (schema changes via migrations) |

---

## Success Criteria Checklist (For Plan Validation)

The plan must produce deliverables that satisfy ALL of the following:

- [ ] Supabase project has all 10 tables created, each containing a `user_id` column (or `id` for profiles) referencing `auth.users(id)`
- [ ] RLS is enabled on every table with `(select auth.uid()) = user_id` policies (using the caching pattern)
- [ ] All `user_id` columns are indexed for RLS performance
- [ ] The `handle_new_user()` trigger auto-creates a profile row on signup
- [ ] The KIE API key `7f48c3109ae4ee6aee94ba7389bdcaa4` no longer appears anywhere in any n8n workflow JSON
- [ ] All 5 KIE HTTP Request nodes use the n8n credential store
- [ ] The Supabase `service_role` key is stored in n8n credential store
- [ ] Two test accounts exist and tenant isolation is verified (cross-account queries return zero rows)
- [ ] Supabase CLI is initialized with migration files for the complete schema
- [ ] `pipeline_runs` table has Realtime enabled (for Phase 4)

---

## Sources

### Primary Sources (Direct Analysis)
- v1 workflow JSON (`ELUXR social media Action v2 (3).json`) -- KIE key locations, credential references, webhook endpoints
- Existing research documents (SUMMARY.md, ARCHITECTURE.md, PITFALLS.md, STACK.md)

### Verified Documentation
- [Supabase RLS Performance and Best Practices](https://supabase.com/docs/guides/troubleshooting/rls-performance-and-best-practices-Z5Jjwv) -- `(select auth.uid())` caching pattern, index recommendations
- [Supabase Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security) -- Policy syntax and patterns
- [Supabase User Management](https://supabase.com/docs/guides/auth/managing-user-data) -- Profiles table trigger pattern
- [Supabase Database Migrations](https://supabase.com/docs/guides/deployment/database-migrations) -- CLI migration workflow
- [Supabase CLI Getting Started](https://supabase.com/docs/guides/local-development/cli/getting-started) -- Setup procedure
- [Supabase CLI Best Practices](https://bix-tech.com/supabase-cli-best-practices-how-to-boost-security-and-control-in-your-development-workflow/) -- Production migration practices
- [n8n HTTP Request Credentials](https://docs.n8n.io/integrations/builtin/credentials/httprequest/) -- Header Auth credential setup
- [n8n Header Auth Community Discussion](https://community.n8n.io/t/http-request-node-header-auth-how-to-securely-save-credentials/42402) -- Practical Header Auth usage
- [Multi-Tenant RLS on Supabase (AntStack)](https://www.antstack.com/blog/multi-tenant-applications-with-rls-on-supabase-postgress/) -- Multi-tenant patterns
- [Supabase RLS Complete Guide 2026 (DesignRevision)](https://designrevision.com/blog/supabase-row-level-security) -- Updated RLS guide

---

*Research completed: 2026-02-27*
*Ready for: Planning phase (02-PLAN.md)*
