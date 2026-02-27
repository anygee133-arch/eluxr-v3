# Domain Pitfalls

**Project:** ELUXR Magic Content Engine v2
**Domain:** Multi-tenant SaaS social media automation (n8n + Supabase + AI pipeline)
**Researched:** 2026-02-27
**Confidence:** MEDIUM (based on codebase analysis + training knowledge; WebSearch/WebFetch unavailable for verification)

---

## Critical Pitfalls

Mistakes that cause rewrites, security breaches, or production outages.

---

### CRIT-1: Incomplete Tenant Isolation During Google Sheets to Supabase Migration

**What goes wrong:** During migration from Google Sheets (inherently single-tenant) to Supabase (multi-tenant), developers forget to add `user_id` or `tenant_id` columns to every table. Some tables get RLS, others do not. The result is data leaking between tenants -- one user can see another user's ICP analysis, content calendar, or approval queue.

**Why it happens:** The v1 Google Sheets schema has no concept of ownership. Every row in `ELUXR_Approval_Queue`, `ELUXR_Themes`, and `ELUXR_ICP` sheets belongs to the single user. When migrating to Supabase, it is tempting to replicate the flat schema first and "add auth later." But RLS policies cannot be retrofitted safely if the schema was not designed for multi-tenancy from day one.

**Evidence from codebase:** The current workflow uses a single hardcoded spreadsheet ID (`1zlIBLhRt_5VSe3Aw8qTp-9p5hpA8j_1ItUrvUBbULjU`) across all 14+ Google Sheets nodes. There is zero user identification in any webhook request body -- the frontend sends content payloads without user context. This means the entire data layer must be redesigned, not just migrated.

**Consequences:**
- Tenant data leaks (severe legal/trust issue)
- Impossible to fix without schema redesign and data backfill
- Must re-test every query path after adding RLS

**Warning signs:**
- Any Supabase table without a `user_id` column
- Any Supabase query that does not include auth context
- n8n workflows that do not extract and pass `user_id` from webhook headers/body
- Frontend fetch calls that do not include auth tokens

**Prevention:**
1. Design the Supabase schema with `user_id UUID REFERENCES auth.users(id)` on EVERY data table before writing a single query
2. Enable RLS on every table immediately after creation -- never "plan to add it later"
3. Write RLS policies using `auth.uid()` so Supabase automatically filters by the authenticated user
4. Create a migration checklist: for each Google Sheet tab, document the corresponding Supabase table WITH the `user_id` column
5. Test tenant isolation with two test accounts BEFORE any other feature work

**Phase mapping:** Must be addressed in the very first database/auth phase. This is foundational -- every subsequent feature depends on correct tenant isolation.

**Severity:** CRITICAL

---

### CRIT-2: Hardcoded API Keys Surviving the Migration

**What goes wrong:** The v1 KIE API key (`7f48c3109ae4ee6aee94ba7389bdcaa4`) is hardcoded as a Bearer token in at least 4 HTTP Request nodes. During the v2 migration, developers copy these nodes to new sub-workflows and the hardcoded keys persist. If the n8n workflow JSON is ever committed to a public repo, shared, or exported, the keys are exposed.

**Evidence from codebase:** The KIE Bearer token appears in plaintext at lines 183, 215, 349, and 415 of the workflow JSON in nodes `KIE -- Create Image Task`, `KIE -- Get Image Result`, `KIE -- Create Video Task`, and `KIE -- Get Video Status`. Meanwhile, the Anthropic API correctly uses `predefinedCredentialType` with credential ID `cZwkXj4ZfHTkpBtT`.

**Why it happens:** KIE AI does not have a native n8n credential type, so the developer used raw HTTP headers. This is a common pattern when integrating non-standard APIs. The danger is that HTTP Request header values are stored in plaintext in the workflow JSON and are visible to anyone who can export or view the workflow.

**Consequences:**
- API key exposure in workflow exports, backups, or version control
- Credential theft if n8n instance is compromised
- No credential rotation without editing every node manually
- Violates the project's own constraint: "All API keys must live in n8n credential store"

**Warning signs:**
- Any `Authorization` header with a literal `Bearer` value in HTTP Request nodes
- Any node parameter containing strings that look like API keys
- Workflow JSON files in git repos

**Prevention:**
1. Create a custom "Header Auth" credential in n8n for the KIE API (n8n supports generic Header Auth credentials that store the token securely)
2. Replace all hardcoded Bearer headers with the credential reference
3. Add a pre-deployment check: search workflow JSON for `Bearer ` followed by alphanumeric strings
4. Never commit workflow JSON files with credentials to version control
5. Use n8n's environment variables feature for any values that should not be in the workflow definition

**Phase mapping:** Must be the first task in the security/infrastructure phase. Should be completed before any workflow splitting begins, since splitting will propagate the hardcoded keys to multiple sub-workflows.

**Severity:** CRITICAL

---

### CRIT-3: n8n Webhook Endpoints Accessible Without Authentication

**What goes wrong:** All 13 webhook endpoints in the current workflow are completely unauthenticated -- anyone who knows the URL can trigger ICP analysis, generate content, approve/reject posts, or clear the approval queue. In a multi-tenant SaaS, this means any user can manipulate any other user's data, and external attackers can abuse the AI pipeline to run up API costs.

**Evidence from codebase:** Every webhook node uses `responseMode: "responseNode"` and `allowedOrigins: "*"`. The frontend makes fetch calls without any auth headers -- just `Content-Type: application/json`. There is no middleware, no API key checking, no JWT validation, and no rate limiting on any endpoint.

**Why it happens:** In a single-user prototype, webhook security is not a concern. The obscurity of the webhook URL provides minimal protection. When converting to multi-tenant SaaS, teams often add auth to the frontend but forget that the n8n webhooks are the actual attack surface.

**Consequences:**
- Unauthorized API usage (someone discovers a webhook URL and generates unlimited AI content at your expense)
- Data manipulation (approve, reject, or delete any user's content)
- Cost explosion from AI API abuse (Claude + Perplexity + KIE calls are not free)
- Complete bypass of frontend auth if backend is unprotected

**Warning signs:**
- Webhook URLs discoverable in browser DevTools Network tab
- No auth token validation in any n8n workflow node
- Frontend sends requests without `Authorization` header
- No rate limiting on expensive AI operations

**Prevention:**
1. Implement JWT validation in every n8n webhook: add a Code node at the start of every webhook flow that validates the Supabase JWT from the `Authorization` header
2. Extract `user_id` from the validated JWT and use it for all database operations
3. Add rate limiting via a Supabase `api_calls` table that tracks per-user request counts
4. Lock down `allowedOrigins` to the actual frontend domain (not `"*"`)
5. Create a shared "Auth Guard" sub-workflow that all webhook flows call first
6. Consider n8n's built-in webhook authentication (Basic Auth, Header Auth) as an additional layer

**Phase mapping:** Must be implemented in the auth phase, immediately after Supabase Auth setup. Every webhook must be secured before any public deployment.

**Severity:** CRITICAL

---

### CRIT-4: Supabase RLS Policies That Kill Query Performance

**What goes wrong:** Naive RLS policies use subqueries or function calls that prevent PostgreSQL from using indexes. Every query on RLS-enabled tables becomes a sequential scan. At 100+ users with thousands of content rows each, the database slows to a crawl.

**Why it happens:** The simplest RLS policy pattern `USING (user_id = auth.uid())` is actually performant, but developers often write complex policies with joins, subqueries (e.g., checking team membership in a separate table), or use `EXISTS` clauses. PostgreSQL cannot push these predicates into index scans.

**Consequences:**
- 10-100x slower queries on large tables
- Timeout errors on content listing endpoints
- Poor user experience (loading spinners everywhere)
- Difficult to diagnose because EXPLAIN plans look different with RLS enabled

**Warning signs:**
- RLS policies that reference other tables (joins/subqueries)
- Missing indexes on `user_id` columns
- Queries that are fast when RLS is disabled but slow when enabled
- `EXPLAIN ANALYZE` showing sequential scans on large tables

**Prevention:**
1. Keep RLS policies simple: `USING (user_id = auth.uid())` -- direct column comparison only
2. Add a `CREATE INDEX` on `user_id` for every table with RLS
3. If you need team/org-based access, store the `org_id` directly on the row (denormalize) rather than joining to a membership table in the RLS policy
4. Test with `EXPLAIN ANALYZE` on tables with 10K+ rows early, not after launch
5. Use `security definer` functions carefully -- they bypass RLS and can mask performance issues
6. Monitor Supabase Dashboard query performance tab regularly

**Phase mapping:** Address during database schema design. Create performance tests during the content generation phase when data volume increases.

**Severity:** CRITICAL

---

### CRIT-5: n8n Cloud Execution Limits Breaking the AI Pipeline

**What goes wrong:** n8n Cloud has execution time limits (varies by plan, typically 2-5 minutes per execution) and memory limits. The current content pipeline chains multiple AI API calls sequentially: ICP analysis (Perplexity + Claude) then theme generation (Claude) then 30 days of post generation (Claude x 30) then image generation (KIE x 30). This can easily exceed execution limits, causing the pipeline to silently fail mid-way through content generation.

**Evidence from codebase:** The current workflow processes everything in a single execution path. Phase 4 uses `splitInBatches` to loop through days, calling Claude for each post and KIE for each image. With 30 days x 4 platforms = 120 content pieces, each requiring a Claude call (10-30 seconds) and potentially an image generation call (7-35 seconds), a single execution could take 20+ minutes.

**Why it happens:** In local n8n or during testing with small batches, execution limits are not hit. Developers build the pipeline for the happy path (5 days of content) and do not test with full 30-day campaigns.

**Consequences:**
- Pipeline fails silently after generating 15 of 30 days
- Partial content in the database with no indication of incompleteness
- Users see some content but not all, with no error message
- Retry logic re-generates already-completed content (wasting API credits)

**Warning signs:**
- Workflow executions that succeed for small inputs but fail for full campaigns
- "Execution timed out" errors in n8n execution logs
- Content data that is inconsistent or partially complete
- n8n cloud plan documentation on execution limits

**Prevention:**
1. Split the monolithic pipeline into separate sub-workflows per phase (this is already planned)
2. Within the content generation phase, use a batch-and-resume pattern: generate 5 days per execution, store progress in Supabase, trigger the next batch
3. Use n8n's Wait node with webhook resume for long-running AI operations (image/video generation)
4. Implement idempotent content generation: each content piece has a unique key, re-running skips already-generated pieces
5. Add execution monitoring: track which step the pipeline is on in Supabase so the frontend can show real progress
6. Check your n8n Cloud plan's specific execution limits and design batching around them

**Phase mapping:** Must be the primary concern during n8n workflow splitting phase. The batch-and-resume pattern should be designed before implementation begins.

**Severity:** CRITICAL

---

## High Pitfalls

Mistakes that cause significant rework, poor user experience, or architectural debt.

---

### HIGH-1: Supabase Realtime Channel Limits for Progress Tracking

**What goes wrong:** Supabase Realtime has limits on concurrent connections and channels per project (free tier: 200 concurrent connections, paid: 500+). If each user opens a progress tracking subscription AND a content update subscription AND a chat subscription, you hit limits fast. Additionally, Realtime has a message rate limit (roughly 100 messages/second on free tier).

**Why it happens:** Developers design the progress tracking system to push frequent updates (e.g., "step 3 of 6 at 45%") which creates high message volume. Multiply by concurrent users each watching their own pipeline run.

**Consequences:**
- Connection drops during pipeline execution
- Progress bar freezes or jumps erratically
- Realtime subscriptions silently disconnect
- Other users' subscriptions may be evicted

**Warning signs:**
- Realtime connection count approaching plan limits
- Messages being dropped or delayed
- Frontend reconnection loops
- Supabase dashboard showing high realtime usage

**Prevention:**
1. Use a single Realtime channel per user, multiplexing progress + content updates onto one subscription
2. Throttle progress updates: write to Supabase at most once per major step change (not per percentage point)
3. Use polling as a fallback when Realtime disconnects
4. Design the progress table to hold just 1 row per pipeline run (update in place, not append)
5. Consider server-sent events (SSE) from n8n as an alternative to Supabase Realtime for pipeline progress
6. Implement heartbeat/reconnection logic in the frontend

**Phase mapping:** Address during the progress tracking phase. Design the Realtime schema and subscription strategy before implementing.

**Severity:** HIGH

---

### HIGH-2: Sub-Workflow Data Passing and Credential Scoping in n8n

**What goes wrong:** When splitting the monolithic workflow into sub-workflows, developers discover that sub-workflows in n8n have restrictions on data passing. Large payloads (full 30-day content plans) can exceed n8n's inter-workflow data limits. Additionally, credentials configured in the parent workflow may not be automatically available to sub-workflows -- each sub-workflow needs its own credential references.

**Evidence from codebase:** The current workflow passes large JSON payloads between nodes (e.g., 30 days of content themes, full ICP analysis results). When these become sub-workflow calls, the data must fit within n8n's execution data size limits.

**Why it happens:** The monolithic workflow design passes rich data between adjacent nodes. When nodes are in different workflows, the data passing mechanism changes from in-memory references to serialized payloads.

**Consequences:**
- Data truncation when large payloads exceed sub-workflow input limits
- Credential errors when sub-workflows cannot access parent credentials
- Debugging difficulty when data silently loses fields during sub-workflow calls
- Need to redesign data flow architecture

**Warning signs:**
- Sub-workflow receiving `undefined` or truncated data
- Credential authentication errors in sub-workflows that worked in the parent
- n8n execution data exceeding memory limits
- JSON payloads larger than ~5MB being passed between workflows

**Prevention:**
1. Store intermediate results in Supabase rather than passing them between sub-workflows (this also enables progress tracking)
2. Pass only IDs and small metadata between sub-workflows, not full content payloads
3. Configure credentials explicitly in each sub-workflow -- do not assume credential inheritance
4. Design the sub-workflow contract: define the exact input/output schema for each sub-workflow
5. Test sub-workflow calls with full-size production data, not minimal test payloads
6. Use Supabase as the "bus" between sub-workflows: one writes, the next reads

**Phase mapping:** Address during the n8n workflow splitting phase. Design the inter-workflow communication pattern before splitting any workflows.

**Severity:** HIGH

---

### HIGH-3: CORS and Auth Token Handling Between Static Frontend and n8n Cloud

**What goes wrong:** The static frontend (Vercel/Netlify) makes cross-origin requests to n8n Cloud webhooks. While the current setup uses `allowedOrigins: "*"`, tightening this for security creates a cascade of CORS issues. Preflight (OPTIONS) requests fail because n8n webhook nodes do not automatically respond to OPTIONS requests. Auth tokens must be included in headers, which triggers preflight for every request.

**Evidence from codebase:** All webhook nodes set `allowedOrigins: "*"`. The frontend uses simple `fetch()` calls with only `Content-Type: application/json`. Adding an `Authorization` header will convert every request from a "simple request" to a "preflighted request," which requires the n8n endpoint to respond to OPTIONS with the right CORS headers.

**Why it happens:** CORS is invisible during development when frontend and backend share an origin, or when `allowedOrigins` is `"*"`. The problem surfaces when you add auth headers and restrict origins.

**Consequences:**
- All API calls fail with CORS errors after adding auth
- Users see a blank/broken UI with console errors
- Difficult to debug because the error is in the browser's preflight, not the actual request
- May require an API gateway or proxy to fix

**Warning signs:**
- Browser console showing `Access-Control-Allow-Origin` errors
- OPTIONS requests returning 404 or 405
- Requests working in Postman but failing in the browser
- Auth token not reaching the n8n webhook

**Prevention:**
1. Test CORS with auth headers early in development, not after the frontend is complete
2. n8n Cloud webhook nodes (v2) support `allowedOrigins` -- set this to the exact frontend domain (e.g., `https://eluxr.vercel.app`)
3. Verify that n8n Cloud automatically handles OPTIONS preflight for webhook endpoints (test this explicitly)
4. If n8n does not handle OPTIONS, consider a Vercel/Netlify serverless function as a proxy that forwards requests to n8n (this also hides the n8n URL from the browser)
5. Include `Authorization` in the `Access-Control-Allow-Headers` response
6. Test from the actual production domain, not localhost

**Phase mapping:** Must be validated during the auth integration phase. Set up a test endpoint with auth headers early.

**Severity:** HIGH

---

### HIGH-4: AI API Response Parsing Fragility Across Chained Calls

**What goes wrong:** The content pipeline chains Claude -> Perplexity -> Claude -> KIE in sequence. Each API returns different response formats. Claude's response is wrapped in `content[0].text`, which contains a JSON string that must be parsed. When the AI returns malformed JSON (missing closing braces, markdown code fences around JSON, extra text before/after JSON), the pipeline crashes and all downstream steps fail.

**Evidence from codebase:** Multiple nodes use fragile parsing patterns:
- `Parse Script Response` (line 37): tries `JSON.parse(script)`, falls back to regex `script.match(/\{[\s\S]*\}/)`
- `Merge All Content` (line 609): tries `item.json.content[0].text`, falls back to `JSON.stringify(item.json)`
- No consistent error handling pattern across parsing nodes

**Why it happens:** AI models are non-deterministic. Claude usually returns valid JSON when asked, but occasionally wraps it in markdown code fences, adds explanatory text, or produces JSON with trailing commas. The probability of any single call failing is low (5-10%), but with 30+ chained calls per campaign, the probability of at least one failure is very high (78-96%).

**Consequences:**
- Pipeline fails at a random content piece, leaving partial data
- Silent data corruption when regex fallback matches the wrong JSON block
- Expensive retry of the entire pipeline for a single parse failure
- Inconsistent content quality when fallback parsing drops fields

**Warning signs:**
- Intermittent pipeline failures that succeed on retry
- Content entries with `raw` field instead of structured data
- `JSON.parse` errors in n8n execution logs
- Content with missing fields (no hashtags, no image_prompt, etc.)

**Prevention:**
1. Standardize AI response parsing into a single shared utility function / Code node
2. Implement robust JSON extraction: strip markdown fences, find the outermost `{...}` or `[...]`, handle trailing commas
3. Add schema validation after parsing: verify required fields exist before passing data downstream
4. Use Claude's "prefill" technique: start the assistant response with `{` to force JSON output
5. Set `response_format` if available, or include explicit "respond ONLY with valid JSON, no explanations" in prompts
6. Implement per-item error handling: if one day's content fails to parse, skip it and continue (do not abort the entire pipeline)
7. Log parse failures with the raw response for debugging

**Phase mapping:** Address during the content generation pipeline redesign. Create the shared parsing utility before building any new content generation flows.

**Severity:** HIGH

---

### HIGH-5: Frontend State Desync When Supabase Replaces localStorage

**What goes wrong:** The v1 frontend stores session data in `localStorage` and in-memory variables (`contentData`, `currentSessionId`, `weeklyThemes`). When migrating to Supabase as the source of truth, developers partially migrate -- some state comes from Supabase, some from localStorage, some from in-memory. The result is state conflicts: user edits content in the calendar, but the approval queue shows stale data, or vice versa.

**Evidence from codebase:** The frontend has a `saveSession()` function that persists to localStorage, a `contentData` global array that holds all calendar content, and multiple places that read from different sources (approval list from n8n endpoint, themes from a different endpoint, calendar from local memory). The `generateMockData()` fallback further complicates by creating fake data when API calls fail.

**Why it happens:** Incremental migration naturally creates two sources of truth. The developer updates the content generation to use Supabase but the calendar rendering still reads from the in-memory `contentData` array. Or the approval action updates Supabase but the calendar view does not re-fetch.

**Consequences:**
- User approves content but calendar still shows "pending"
- Edits disappear on page refresh because they were only in memory
- Mock data appears instead of real data (confusing users)
- Race conditions when Supabase update and local state update happen independently

**Warning signs:**
- Content status different in calendar vs. approval queue
- Data loss on page refresh
- Console logs showing "using local data" or mock data being generated
- Multiple `fetch()` calls to different endpoints for the same underlying data

**Prevention:**
1. Migrate state management atomically: Supabase is the ONLY source of truth from day one of the v2 frontend
2. Remove `localStorage` session persistence entirely (use Supabase for session state)
3. Remove `generateMockData()` -- show real loading states and error messages instead
4. Implement a single data fetching layer: all components read from the same Supabase queries
5. Use Supabase Realtime to push state changes to the frontend instead of manual re-fetching
6. Remove global mutable variables (`contentData`, `weeklyThemes`) -- fetch from Supabase on demand

**Phase mapping:** Address during the frontend migration phase. Design the data flow architecture (single source of truth) before rewriting any frontend components.

**Severity:** HIGH

---

### HIGH-6: n8n Cloud Webhook Response Timeout for Long AI Operations

**What goes wrong:** n8n webhook nodes with `responseMode: "responseNode"` have a timeout (typically 30 seconds on cloud, configurable up to 5-10 minutes depending on plan). The content pipeline makes multiple Claude API calls that each take 10-30 seconds. If the total time exceeds the webhook timeout, the frontend receives a timeout error, but the n8n workflow continues executing in the background. The content is generated but the user sees an error.

**Evidence from codebase:** The current workflow sets HTTP Request timeouts to 120 seconds for Claude calls. The Phase 2 themes flow calls Claude with a complex prompt that generates 30 days of themes -- this single call can take 30-60 seconds. Phase 4 then loops through each day calling Claude again.

**Why it happens:** The `responseNode` pattern is designed for quick webhook-to-response flows. When the processing between webhook trigger and response node takes too long, the HTTP connection times out. The n8n execution continues, but the HTTP response is lost.

**Consequences:**
- User sees "request failed" while content is actually being generated
- Frontend error handling triggers (potentially showing mock data or error state)
- User retries, triggering duplicate content generation (wasting API credits)
- No way to correlate the "failed" request with the still-running execution

**Warning signs:**
- 504 Gateway Timeout errors in browser console
- n8n executions that complete successfully but the frontend shows failure
- Duplicate content entries in the database
- Users complaining about "errors" that actually worked

**Prevention:**
1. Implement an async job pattern: webhook immediately returns a `job_id`, frontend polls for completion
2. Store pipeline status in Supabase: `pipeline_runs` table with `status`, `current_step`, `result`
3. Use Supabase Realtime to push completion events instead of holding the HTTP connection open
4. Design the frontend to handle the "accepted but processing" state (HTTP 202 pattern)
5. Make content generation idempotent so accidental retries do not create duplicates
6. Return the job ID immediately (within 1-2 seconds), then process asynchronously

**Phase mapping:** This is the core architecture decision for the pipeline redesign. Must be designed during the workflow splitting phase.

**Severity:** HIGH

---

## Moderate Pitfalls

Mistakes that cause delays, technical debt, or degraded user experience.

---

### MOD-1: Supabase Auth Session Expiry and Token Refresh in Vanilla JS

**What goes wrong:** Supabase Auth uses short-lived JWTs (typically 1 hour) with refresh tokens. In a vanilla JS frontend (no framework), developers must manually handle token refresh. If the token expires mid-session, all Supabase queries and n8n webhook calls fail silently. The user's content pipeline stops working and they see generic errors.

**Why it happens:** Frameworks like Next.js have Supabase auth helpers that handle refresh automatically. In vanilla JS, you must set up the `onAuthStateChange` listener, intercept 401 errors, and refresh tokens yourself. The Supabase JS client handles some of this, but edge cases remain (multiple tabs, backgrounded tabs, network interruptions).

**Prevention:**
1. Use `supabase.auth.onAuthStateChange()` to listen for `TOKEN_REFRESHED` and `SIGNED_OUT` events
2. Wrap all fetch calls to n8n in a helper that checks token validity and refreshes if needed
3. Handle the case where refresh fails (redirect to login)
4. Test the token expiry flow explicitly (set a short JWT expiry during development)
5. Consider using Supabase's `persistSession` option to survive page refreshes

**Phase mapping:** Address during the auth implementation phase.

**Severity:** MODERATE

---

### MOD-2: Image/Video URL Expiry from KIE AI

**What goes wrong:** KIE AI hosted image and video URLs may expire after a certain period (hours, days, or weeks -- this varies by provider and is not always documented). Content approved today may have broken images next month when the user tries to post it.

**Evidence from codebase:** The project explicitly decided against Supabase Storage (`"KIE URLs for media (no Supabase Storage) -- Simpler architecture, fewer moving parts -- revisit if URLs expire"`). This is a known risk that has been accepted but not mitigated.

**Prevention:**
1. Test KIE URL longevity: generate an image, wait 7/30/90 days, check if the URL still works
2. If URLs expire, add a background workflow to download and re-host media (either Supabase Storage or a CDN)
3. Store the original prompt alongside the URL so images can be regenerated if URLs expire
4. Add a "media health check" routine that validates URLs periodically
5. Display a clear "image unavailable" placeholder rather than a broken img tag

**Phase mapping:** Test during the content generation phase. Mitigate if/when URLs expire.

**Severity:** MODERATE

---

### MOD-3: Perplexity + Claude Chain Producing Hallucinated Market Research

**What goes wrong:** The ICP analysis uses Perplexity for market research, then Claude to synthesize findings. Perplexity's web search results may include outdated, biased, or incorrect information. Claude then presents these findings as authoritative analysis, potentially including fabricated statistics, incorrect competitor names, or outdated market trends.

**Why it happens:** The AI chain amplifies errors: Perplexity may return a 2-year-old article about market size, Claude treats it as current data and builds an entire ICP around it. Neither model validates the other's output.

**Prevention:**
1. Include date metadata in Perplexity prompts: "Find information from the last 6 months only"
2. Add a validation step: Claude should flag low-confidence claims explicitly
3. Present ICP results with source attribution ("Based on [source]") so users can verify
4. Include a confidence score or "freshness" indicator in the ICP output
5. Let users edit/override AI-generated ICP data before it drives content generation
6. Store the raw Perplexity sources alongside the synthesized ICP

**Phase mapping:** Address during the ICP pipeline redesign phase.

**Severity:** MODERATE

---

### MOD-4: Google Calendar OAuth Scope and Per-User Calendar Access

**What goes wrong:** The v1 workflow uses a single Google Calendar OAuth credential to create events on a "primary" calendar. In multi-tenant v2, each user needs events on their own calendar. The current single-credential approach cannot write to different users' calendars without each user authorizing Google Calendar access.

**Evidence from codebase:** The Calendar node uses credential `googleCalendarOAuth2Api` with ID `FJBcOjKITBIaEqRV` and writes to `"primary"` calendar. This is the workflow owner's calendar, not the end user's.

**Why it happens:** Google Calendar requires per-user OAuth consent. n8n cannot dynamically switch credentials per webhook request. Each user would need their own Google Calendar credential stored in n8n, which does not scale.

**Prevention:**
1. Consider removing Google Calendar direct sync for v2 multi-tenant (it was designed for single-user)
2. Instead, generate `.ics` files or provide a "Copy to Calendar" link per post
3. If Calendar sync is required, implement it via the Google Calendar API directly from a Code node, using per-user OAuth tokens stored in Supabase
4. This may be better suited as a future feature with proper OAuth consent flow in the frontend

**Phase mapping:** Re-evaluate during the Calendar/scheduling phase. May need to be descoped or redesigned.

**Severity:** MODERATE

---

### MOD-5: Switch Node Routing Ambiguity in Content Type Branching

**What goes wrong:** The current Phase 4 Switch node can trigger both image and text/video branches simultaneously (documented bug #8). This is a fundamental pattern error where Switch conditions are not mutually exclusive. When splitting into sub-workflows, this bug may be replicated or create even subtler issues with parallel execution paths.

**Evidence from codebase:** The Switch node at lines 762-799 uses `notContains "Video"` for the first branch and `exists` for the second branch. These conditions are not mutually exclusive -- a content type of "Educational" would match both (it does not contain "Video" AND it exists). This causes dual execution: both text post generation AND content processing fire for the same item.

**Prevention:**
1. Use explicit, mutually exclusive conditions in all Switch nodes
2. Document the routing logic with a truth table: for each content type, which branch fires
3. Use the "fallback" output of Switch nodes as the default path
4. Test routing with every possible content type value, not just the expected ones
5. Add logging at the start of each branch to detect dual-firing

**Phase mapping:** Fix during the n8n workflow splitting phase as part of the bug fixes.

**Severity:** MODERATE

---

### MOD-6: Rate Limiting on AI APIs Not Enforced Per-Tenant

**What goes wrong:** In multi-tenant SaaS, one user triggering a full 30-day campaign (120+ AI calls) can exhaust the shared API rate limits, blocking other users' requests. Claude's API has rate limits per API key (typically requests per minute and tokens per minute). A single heavy user can monopolize the quota.

**Why it happens:** All tenant requests share the same API key and the same n8n execution queue. There is no per-tenant throttling, queuing, or quota management.

**Prevention:**
1. Implement a per-tenant queue in Supabase: track pending requests per user and enforce limits
2. Add a global rate limiter in n8n: use a Code node to check request count before calling AI APIs
3. Design the content pipeline to batch and pace AI calls (e.g., max 10 Claude calls per minute per user)
4. Show users queue position and estimated wait time
5. Consider per-tenant API key allocation for scaling (future)

**Phase mapping:** Address during the content generation pipeline phase.

**Severity:** MODERATE

---

### MOD-7: Supabase Database Migrations and Schema Changes Without a Strategy

**What goes wrong:** As the project evolves, the Supabase schema needs changes (new columns, new tables, renamed fields). Without a migration strategy, developers make changes directly in the Supabase Dashboard, creating schema drift between environments. Staging has different columns than production. Deployments break.

**Why it happens:** Supabase Dashboard makes it easy to "just add a column." In early development this feels productive, but it creates undocumented schema changes that cannot be reproduced.

**Prevention:**
1. Use Supabase CLI and migration files (`supabase migration new`) for ALL schema changes
2. Never modify schema directly in the Dashboard for production
3. Store migration files in the project repo alongside the frontend code
4. Set up a staging Supabase project that mirrors production
5. Test migrations on staging before applying to production
6. Include seed data scripts for development environments

**Phase mapping:** Establish migration practices during the initial database setup phase.

**Severity:** MODERATE

---

## Minor Pitfalls

Mistakes that cause annoyance, confusion, or minor rework.

---

### MIN-1: CSS Stagger Animation Classes Not Scaling

**What goes wrong:** The v1 CSS only defines stagger classes 1-4 (`.stagger-1` through `.stagger-4`), but the code references `.stagger-5` and `.stagger-6` which are undefined. This creates elements that appear without animation, breaking the visual flow.

**Evidence from codebase:** Known bug #6 in PROJECT.md. The HTML uses `class="fade-in-up stagger-5"` but only `stagger-1` through `stagger-4` have corresponding CSS animation delays defined.

**Prevention:**
1. Generate stagger classes dynamically or use CSS custom properties (`--stagger-index`)
2. Use `calc(var(--stagger-index) * 0.1s)` for animation delay instead of individual classes
3. Or simply define classes up to stagger-10 for safety

**Phase mapping:** Fix during the UI/animation enhancement phase.

**Severity:** MINOR

---

### MIN-2: Single index.html File Becoming Unmaintainable

**What goes wrong:** The v1 frontend is a single 2,500+ line file with inline CSS, HTML, and JavaScript. Adding auth, Supabase integration, Realtime subscriptions, and new UI features will push this past 5,000+ lines. Debugging, testing, and collaboration become nearly impossible.

**Why it happens:** The project constraint is "vanilla HTML/CSS/JS -- no frontend frameworks." But "no frameworks" does not mean "one file." The constraint was interpreted too literally in v1.

**Prevention:**
1. Split into multiple files: `index.html`, `styles.css`, `app.js`, `auth.js`, `supabase.js`, `pipeline.js`, `calendar.js`, `chat.js`
2. Use ES modules (`import`/`export`) for JavaScript organization
3. Use a simple build step (even just file concatenation) if needed for deployment
4. Vercel/Netlify can serve multiple static files natively

**Phase mapping:** Address at the start of the frontend migration phase, before any feature work.

**Severity:** MINOR (but compounds quickly)

---

### MIN-3: Error Messages Shown as Generic Toast Notifications

**What goes wrong:** The current frontend shows `showToast('Error: ' + error.message, 'error')` for all failures. In v2 with multiple failure modes (auth expired, rate limited, AI timeout, Supabase error, CORS error), users need specific, actionable error messages.

**Prevention:**
1. Create an error classification system: auth errors redirect to login, rate limit errors show retry timer, AI errors offer retry button, network errors suggest checking connection
2. Log detailed errors to console/Supabase for debugging
3. Show user-friendly messages (not raw error strings)
4. Add a "retry" button to error states where appropriate

**Phase mapping:** Address during the frontend migration phase alongside state management.

**Severity:** MINOR

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Severity | Mitigation |
|---|---|---|---|
| Database/Schema Design | CRIT-1: Missing tenant isolation | CRITICAL | Design all tables with `user_id`, enable RLS immediately |
| Database/Schema Design | CRIT-4: Slow RLS policies | CRITICAL | Keep policies simple, index `user_id` columns |
| Database/Schema Design | MOD-7: No migration strategy | MODERATE | Use Supabase CLI migrations from day one |
| Security/Credentials | CRIT-2: Hardcoded KIE API key | CRITICAL | Move to n8n credentials before workflow splitting |
| Auth Implementation | CRIT-3: Unauthenticated webhooks | CRITICAL | JWT validation in every webhook flow |
| Auth Implementation | HIGH-3: CORS with auth headers | HIGH | Test preflight requests early |
| Auth Implementation | MOD-1: Token refresh in vanilla JS | MODERATE | Implement `onAuthStateChange` listener |
| n8n Workflow Splitting | CRIT-5: Execution limits | CRITICAL | Async job pattern with Supabase status tracking |
| n8n Workflow Splitting | HIGH-2: Data passing limits | HIGH | Use Supabase as data bus between workflows |
| n8n Workflow Splitting | HIGH-6: Webhook response timeout | HIGH | Return job ID immediately, process async |
| n8n Workflow Splitting | MOD-5: Switch routing bugs | MODERATE | Mutually exclusive conditions, truth table |
| Progress Tracking | HIGH-1: Realtime connection limits | HIGH | Single channel per user, throttle updates |
| Content Pipeline | HIGH-4: AI response parsing fragility | HIGH | Shared parsing utility with schema validation |
| Content Pipeline | MOD-3: Hallucinated market research | MODERATE | Date constraints, source attribution |
| Content Pipeline | MOD-6: Per-tenant rate limits | MODERATE | Queue system with per-user throttling |
| Frontend Migration | HIGH-5: State desync | HIGH | Supabase as single source of truth |
| Frontend Migration | MIN-2: Single file architecture | MINOR | Split into modules before feature work |
| Calendar/Scheduling | MOD-4: Google Calendar per-user | MODERATE | Consider descoping or redesigning |
| Media/Assets | MOD-2: KIE URL expiry | MODERATE | Test longevity, store regeneration data |

---

## Sources and Confidence Notes

| Finding | Source | Confidence |
|---|---|---|
| Hardcoded KIE API key in 4 nodes | Direct codebase analysis (workflow JSON lines 183, 215, 349, 415) | HIGH |
| All webhooks use `allowedOrigins: "*"` with no auth | Direct codebase analysis (workflow JSON) | HIGH |
| Fake progress bar with `simulateProgress()` | Direct codebase analysis (index.html lines 2672-2700) | HIGH |
| Switch node dual-firing bug | Direct codebase analysis (workflow JSON lines 762-799) | HIGH |
| `saveScheduleEdit` ID mismatch | Direct codebase analysis (index.html line 3131 vs 3319) | HIGH |
| 14+ Google Sheets nodes with single spreadsheet ID | Direct codebase analysis (workflow JSON) | HIGH |
| Supabase RLS performance patterns | Training knowledge (Supabase docs) | MEDIUM |
| n8n Cloud execution limits | Training knowledge (n8n docs) | MEDIUM |
| Supabase Realtime connection limits | Training knowledge (Supabase docs) | MEDIUM |
| n8n sub-workflow data passing limits | Training knowledge (n8n docs) | MEDIUM |
| CORS preflight behavior with auth headers | Training knowledge (web standards) | HIGH |
| AI response non-determinism rates | Training knowledge + industry patterns | MEDIUM |

**Note:** WebSearch and WebFetch were unavailable during this research. All Supabase and n8n platform-specific limits (exact numbers for connection limits, execution timeouts, data size limits) should be verified against current documentation for the specific plan tiers being used. These are marked MEDIUM confidence and flagged for validation.

---

*Last updated: 2026-02-27*
