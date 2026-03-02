# Phase 3: Workflow Decomposition + Backend Bug Fixes - Context

**Gathered:** 2026-03-02
**Status:** Ready for planning

<domain>
## Phase Boundary

Split the monolithic 116KB n8n workflow into 13 focused, independently testable sub-workflows. Replace all 16 Google Sheets nodes with Supabase queries. Fix 3 known backend bugs (Switch routing, image polling, video wiring). No new features — this is backend reorganization and bug elimination before feature development begins.

</domain>

<decisions>
## Implementation Decisions

### Workflow organization
- Numbered naming convention: `01-[Name]`, `02-[Name]`, etc. — shows pipeline order in n8n workflow list
- Grouping logic is Claude's discretion — determine best sub-workflow boundaries based on data dependencies and logical domain separation
- Each sub-workflow gets its own webhook endpoint (one webhook per workflow, not a central router)
- Shared utility sub-workflows encouraged — extract common patterns (error handling, Supabase queries, response formatting) beyond just Auth Validator
- Remaining organization details (folder structure, tagging, etc.) at Claude's discretion

### Sheets-to-Supabase migration
- Fresh start — no data migration from Google Sheets (test/demo data only)
- Remove Google Sheets integration entirely — delete all Sheets nodes and credentials from n8n, clean break
- Map Sheets data flows to existing Supabase schema from Phase 1 — no schema redesign, minor tweaks only if needed
- Native Supabase node vs HTTP Request: Claude's discretion based on research into node capabilities (UPSERT support, etc.)

### Bug fix verification
- Test Switch routing fix with real content — run actual content items and verify only one branch (text/image/video) fires per item
- Image polling: Claude decides balance of speed vs reliability based on KIE API behavior
- Video branch wiring: Claude investigates monolith to determine correct true/false path behavior
- Verify each bug fix individually as completed (not all together at end)
- Improve behavior where possible — if fixing a bug reveals a better approach, use it rather than matching v1 exactly
- Verification requires both: execution logs proving correct behavior + user hands-on walkthrough
- Three listed bugs are comprehensive — no additional v1 bugs to address

### Claude's Discretion
- Sub-workflow grouping/boundary decisions (based on actual workflow analysis)
- Which common patterns to extract into shared sub-workflows
- Native Supabase node vs HTTP Request approach (based on capability research)
- Image polling interval and retry strategy (speed vs reliability balance)
- Video branch correct wiring (determined from code analysis)
- Whether bug fixes match v1 or improve — decided per bug

</decisions>

<specifics>
## Specific Ideas

- User wants numbered prefix naming (`01-Name`) so workflow list shows pipeline order at a glance
- Individual webhook per workflow preferred over central routing — keeps things simple and direct
- Bug fixes should be verified with real content, not just synthetic test data
- After all fixes: logs first for Claude to confirm, then user does manual end-to-end verification

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 03-workflow-decomposition-backend-bug-fixes*
*Context gathered: 2026-03-02*
