# State: ELUXR Magic Content Engine v2

## Project Reference

**Core Value:** A business can go from entering their URL to having a full month of platform-specific, trend-aware social media content generated, reviewed, and ready to post -- with zero manual content creation.

**Current Focus:** Phase 5 in progress (Frontend Migration + UI Polish). Plans 01-02 complete.

## Current Position

**Milestone:** v2 Multi-Tenant SaaS
**Phase:** 5 of 11 (Frontend Migration + UI Polish)
**Plan:** 2 of 4 in phase
**Status:** In progress -- Plan 05-02 complete (Supabase data layer migration)
**Last activity:** 2026-03-03 - Completed 05-02-PLAN.md (mapContentItem, Supabase queries, localStorage removal)

**Progress:**
```
Phase  1: Security + DB Foundation    [### COMPLETE ######## ] 3/3 plans
Phase  2: Authentication              [### COMPLETE ######## ] 5/5 plans
Phase  3: Workflow Decomposition      [### COMPLETE ######## ] 6/6 plans
Phase  4: Progress Tracking           [### COMPLETE ######## ] 3/3 plans
Phase  5: Frontend Migration + UI     [#####                 ] 2/4 plans
Phase  6: Content Pipeline            [ . . . . . . . . . . ] 0%
Phase  7: Approval Queue              [ . . . . . . . . . . ] 0%
Phase  8: Calendar + Scheduling       [ . . . . . . . . . . ] 0%
Phase  9: AI Chat                     [ . . . . . . . . . . ] 0%
Phase 10: Standalone Tools            [ . . . . . . . . . . ] 0%
Phase 11: Trend Intelligence          [ . . . . . . . . . . ] 0%

Overall: 24/50 requirements complete (48%)
```

## Performance Metrics

| Metric | Value |
|--------|-------|
| Requirements total | 50 |
| Requirements complete | 24 |
| Phases total | 11 |
| Phases complete | 4 |
| Current streak | 28 plans |

## Accumulated Context

### Key Decisions

| Decision | Rationale | Phase |
|----------|-----------|-------|
| Fix KIE key BEFORE splitting workflows | Prevents propagating hardcoded key to 13 sub-workflows | 1 |
| Use local n8n instance for programmatic workflow updates | Cloud instance requires API key not available in env; local instance has same workflow active | 1 |
| predefinedCredentialType + httpHeaderAuth for KIE nodes | Standard n8n pattern for external API auth via credential store | 1 |
| Supabase replaces Google Sheets entirely | Multi-tenant SaaS needs proper DB + RLS + auth -- Sheets cannot scale | 1 |
| Supabase REST API requires sb_publishable key in apikey header | Legacy JWT keys rejected by gateway; use sb_publishable for apikey + legacy JWT for Authorization | 1 |
| RLS tenant isolation verified across all 10 tables | SELECT, INSERT, UPDATE, DELETE all correctly enforced by auth.uid() policies | 1 |
| JWT algorithm is ES256 (not HS256) | Supabase newer projects use asymmetric ECDSA; n8n credential uses PEM public key | 2 |
| CORS allows Authorization header on n8n webhooks | Preflight returns access-control-allow-headers: Authorization; use standard Bearer header | 2 |
| JWT delivery via Authorization: Bearer header | CORS test confirmed; no token-in-body fallback needed | 2 |
| n8n JWT Auth credential ID: GjLV4iwAj88m95yP | ES256 PEM public key from Supabase JWKS endpoint | 2 |
| Email+password auth only (no OAuth) | Simpler; Google Calendar sync is server-side via n8n, not user-side | 2 |
| Async job pattern for all long-running ops | Prevents n8n execution timeouts; enables real progress tracking | 4 |
| Frontend migration is atomic, not incremental | Prevents state desync between localStorage/Sheets and Supabase | 5 |
| Google Calendar sync may descope to .ics export | Per-user OAuth is architecturally incompatible with n8n credential model | 8 |
| Content generation uses batch-and-resume | 120+ API calls per campaign would exceed single execution timeout | 6 |
| No frameworks, no build step | Existing constraint from v1 -- vanilla HTML/CSS/JS with CDN-loaded supabase-js | All |
| Module script + window export for supabase-js | Separate script type=module imports ESM; exposes to window for non-module scripts | 2 |
| Auth gating via show/hide containers | dashboard-container hidden when logged out, auth-container shown; reversed when logged in | 2 |
| Supabase HTTP API for JWT validation (not n8n JWT node) | Validates directly against Supabase /auth/v1/user; no JWT credential needed; returns user profile in same call | 2 |
| Auth Validator sub-workflow pattern | Webhook -> Execute Sub-Workflow(Auth Validator) -> IF authenticated -> process/401 | 2 |
| n8n Code node uses $input.item.json (default mode) | Default runOnceForEachItem mode; return single { json } not array | 2 |
| authenticatedFetch() wrapper for all n8n webhook calls | JWT via Authorization: Bearer header; 401 retry with token refresh; login redirect on failure | 2 |
| All 13 webhooks protected by Auth Validator | Every endpoint has Execute Sub-Workflow + IF + 401 Respond chain | 2 |
| Content-Type added by authenticatedFetch() automatically | Removed redundant headers from all 21 call sites | 2 |
| n8n Cloud Starter plan has unlimited active workflows | All Cloud plans (Starter/Pro/Enterprise) support unlimited active workflows; no upgrade needed | 3 |
| PostgREST UPSERT requires ?on_conflict=column parameter | Without it, returns 409 Conflict on duplicate keys; must specify constraint column(s) explicitly | 3 |
| Content type normalization before Switch node | Claude generates 7 free-text values; normalize to 4 DB values (text/image/video/carousel) in Code node | 3 |
| Themes stored as 4 weekly rows with JSONB daily details | 30 Claude daily items map to 4 themes table rows; content_types JSONB stores per-day info | 3 |
| Campaign/themes uses delete-before-insert for re-generation | UPSERT campaign keeps same ID; DELETE old themes then INSERT new ones prevents duplicates | 3 |
| Switch node replaces IF cascade for approval routing | Cleaner routing with first-match mode and fallback for unknown actions | 3 |
| DB status is pending_review not pending | v2 content_items CHECK constraint uses pending_review; updated from v1 Sheets convention | 3 |
| Google Calendar node preserved in calendar sync | Phase 8 will decide Calendar future; OAuth credential FJBcOjKITBIaEqRV kept | 3 |
| TOOL-05: Wait+IF polling loop replaces setTimeout(35000) | 10s initial, 5s retry, 12 max attempts; detects success/timeout/error states | 3 |
| TOOL-06: Video Ready? IF TRUE -> Parse Video Result | Monolith had inverted wiring; swapped TRUE/FALSE connections | 3 |
| Video Creator keeps single Wait + frontend retry | Videos take >60s; server-side loop impractical; frontend already handles retry | 3 |
| Supabase service_role key via $env.SUPABASE_SERVICE_ROLE_KEY | Environment variable pattern for n8n Cloud; apikey uses publishable key directly | 3 |
| Content type normalization also in 05-Content-Submit | Prevents DB CHECK constraint violations on user-submitted content with free-text values | 3 |
| Carousel routes to text branch for generation | Carousel content generation is text-based (Claude writes multi-slide text) | 3 |
| Switch fallback handler saves unmatched items | Prevents data loss for unexpected content_type values; saves with debug note | 3 |
| Monolith deactivated, not deleted | Kept as reference and rollback option; can reactivate in ~2 minutes | 3 |
| Cutover performed manually via n8n Cloud dashboard | n8n Cloud API key not available; user toggled workflows in dashboard | 3 |
| HTTP Request calls to sub-workflow webhooks (not Execute Sub-Workflow) | Sub-workflows need HTTP context for Auth Validator and respondToWebhook nodes | 4 |
| Auth token passthrough from orchestrator to sub-workflows | Original Authorization header captured and forwarded to all 6 HTTP calls | 4 |
| n8n Cloud Starter plan has no environment variables feature | Hardcoded Supabase URL and service_role key directly in workflow JSON | 4 |
| Named node reference $('Extract Run ID') for all PATCH URLs | Execute Sub-Workflow output replaces $json; named ref recovers pipeline_run_id | 4 |
| checkActivePipeline() in SIGNED_IN handler (no setTimeout) | Avoids race condition where session may not be available on slow connections | 4 |
| 15-minute stale run detection threshold | Runs older than 15 min with "running" status show error instead of restoring progress | 4 |
| Dedup returns existing run_id with resumed: true | Graceful handling; frontend can re-subscribe to existing pipeline progress | 4 |
| config.js loaded as first script, before Supabase module | Ensures window.ELUXR_CONFIG available to all scripts (module and non-module) | 5 |
| Hostname-based environment detection for config | localhost/127.0.0.1 = development, everything else = production | 5 |
| Directional tab slides in goToPhase() | Forward nav slides right, backward slides left -- tracks previousPhase for direction | 5 |
| mapContentItem() normalizes pending_review->pending | DB uses pending_review status; frontend expects pending; normalizer handles translation | 5 |
| Re-fetch from Supabase after mutations (not local state) | Approval/reject/batch re-fetch from Supabase instead of local state mutation; ensures consistency | 5 |
| Business profile saved to Supabase profiles (not localStorage) | Upsert on form submit; load on SIGNED_IN; replaces localStorage persistence | 5 |
| checkActivePipeline uses in-memory only (no localStorage) | Supabase query for running pipelines replaces localStorage pipeline run tracking | 5 |

### Known Issues

- ~~KIE API key hardcoded in 5 n8n nodes~~ FIXED in 01-02 -- migrated to credential store
- ~~All 13 webhooks accept unauthenticated requests~~ FIXED in 02-04 -- Auth Validator integrated on all endpoints
- ~~Image generation uses setTimeout(35000) hack~~ FIXED in 03-04 (TOOL-05) -- proper Wait+IF polling loop
- ~~Video Ready? IF node has inverted TRUE/FALSE wiring~~ FIXED in 03-04 (TOOL-06) -- TRUE -> Parse Video Result
- ~~Switch node routes to multiple branches per item~~ FIXED in 03-02 (PIPE-07) -- allMatchingOutputs=false + exact equality + content type normalization
- ~~Monolith is single point of failure~~ FIXED in 03-05 -- decomposed into 13 independent sub-workflows
- ~~Fake progress simulation with hardcoded timers~~ FIXED in 04-02 -- Supabase Realtime-driven progress
- Pipeline Orchestrator has no "Mark Failed" error path -- sub-workflow failures silently complete (non-blocking, noted for future gap work)
- "Fetch calendar error: Not authenticated" on initial page load -- race condition, not Phase 4 related
- Google Calendar multi-tenant may be infeasible (Phase 8 decision needed)
- n8n Cloud Starter: 2.5k executions/month, 5 concurrent -- may need monitoring in Phase 6 for batch generation
- KIE URL longevity unknown (test before launch)

### TODOs

- [ ] Verify n8n Cloud execution time limits for current plan
- [ ] Verify n8n Supabase native node capabilities (UPSERT support?)
- [x] Test CORS behavior of n8n Cloud webhooks with Authorization headers -- DONE in 02-01: CORS allows Authorization header
- [ ] Determine if n8n Cloud Code nodes have npm module access
- [ ] Check Supabase Realtime connection limits on chosen plan tier
- [ ] Test KIE image/video URL longevity (do they expire?)
- [ ] Evaluate Google Calendar per-user OAuth feasibility vs .ics export
- [ ] Add error handling path to Pipeline Orchestrator (Mark Failed on sub-workflow failure)

### Blockers

- n8n Cloud SELECT nodes need `alwaysOutputData: true` for graceful empty-result handling (frontend safeJson is a workaround)

## Session Continuity

### Last Session
- **Date:** 2026-03-03
- **Activity:** Completed 05-02-PLAN.md -- Supabase data layer migration: mapContentItem normalizer, direct Supabase queries for content_items/themes/profiles, removed all localStorage/saveSession/generateMockData
- **Outcome:** Plan 05-02 COMPLETE. 9/9 must-haves verified. Zero localStorage. Zero mock data. All data flows from Supabase through mapContentItem to rendering functions.

### Next Session
- **Expected:** Execute Plan 05-03 (next plan in Phase 5)
- **Prerequisites:** 05-02 complete. Data layer migrated. mapContentItem normalizer active. Profiles load/save via Supabase.
- **Entry point:** `/gsd:execute-phase 05-03`

---
*State initialized: 2026-02-27*
*Last updated: 2026-03-03*
