# State: ELUXR Magic Content Engine v2

## Project Reference

**Core Value:** A business can go from entering their URL to having a full month of platform-specific, trend-aware social media content generated, reviewed, and ready to post -- with zero manual content creation.

**Current Focus:** Phase 2 in progress (Authentication). Plan 02-01 complete.

## Current Position

**Milestone:** v2 Multi-Tenant SaaS
**Phase:** 2 of 11 (Authentication)
**Plan:** 1 of 5 in phase (02-01 complete)
**Status:** In progress
**Last activity:** 2026-03-02 - Completed 02-01-PLAN.md (CORS Test + JWT Credential Setup)

**Progress:**
```
Phase  1: Security + DB Foundation    [### COMPLETE ######## ] 3/3 plans
Phase  2: Authentication              [##                    ] 1/5 plans
Phase  3: Workflow Decomposition      [ . . . . . . . . . . ] 0%
Phase  4: Progress Tracking           [ . . . . . . . . . . ] 0%
Phase  5: Frontend Migration + UI     [ . . . . . . . . . . ] 0%
Phase  6: Content Pipeline            [ . . . . . . . . . . ] 0%
Phase  7: Approval Queue              [ . . . . . . . . . . ] 0%
Phase  8: Calendar + Scheduling       [ . . . . . . . . . . ] 0%
Phase  9: AI Chat                     [ . . . . . . . . . . ] 0%
Phase 10: Standalone Tools            [ . . . . . . . . . . ] 0%
Phase 11: Trend Intelligence          [ . . . . . . . . . . ] 0%

Overall: 4/50 requirements complete (8%)
```

## Performance Metrics

| Metric | Value |
|--------|-------|
| Requirements total | 50 |
| Requirements complete | 4 |
| Phases total | 11 |
| Phases complete | 1 |
| Current streak | 4 plans |

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

### Known Issues

- ~~KIE API key hardcoded in 5 n8n nodes~~ FIXED in 01-02 -- migrated to credential store
- All 13 webhooks accept unauthenticated requests (CRIT -- Phase 2 fix)
- Google Calendar multi-tenant may be infeasible (Phase 8 decision needed)
- n8n Cloud execution limits unverified (Phase 3 research needed)
- KIE URL longevity unknown (test before launch)

### TODOs

- [ ] Verify n8n Cloud execution time limits for current plan
- [ ] Verify n8n Supabase native node capabilities (UPSERT support?)
- [x] Test CORS behavior of n8n Cloud webhooks with Authorization headers -- DONE in 02-01: CORS allows Authorization header
- [ ] Determine if n8n Cloud Code nodes have npm module access
- [ ] Check Supabase Realtime connection limits on chosen plan tier
- [ ] Test KIE image/video URL longevity (do they expire?)
- [ ] Evaluate Google Calendar per-user OAuth feasibility vs .ics export

### Blockers

None currently. Phase 1 complete, Phase 2 ready to begin.

## Session Continuity

### Last Session
- **Date:** 2026-03-02
- **Activity:** Completed 02-01-PLAN.md (CORS Test + JWT Credential Setup)
- **Outcome:** CORS allows Authorization header, JWT is ES256, n8n JWT Auth credential created (GjLV4iwAj88m95yP). All auth architecture decisions resolved.

### Next Session
- **Expected:** Execute 02-02-PLAN.md (Auth Middleware Workflow)
- **Prerequisites:** 02-01 complete (JWT credential exists, CORS confirmed)
- **Entry point:** `/gsd:execute-phase` with 02-02-PLAN.md

---
*State initialized: 2026-02-27*
*Last updated: 2026-03-02*
