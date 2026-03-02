# Phase 3: Workflow Decomposition + Backend Bug Fixes - Research

**Researched:** 2026-03-02
**Domain:** n8n workflow architecture, Supabase integration, workflow bug fixes
**Confidence:** HIGH (verified via workflow JSON analysis, official docs, and community sources)

## Summary

This phase requires three major work streams: (1) decomposing a 132-node monolithic n8n workflow into 13 focused sub-workflows, (2) replacing all 16 Google Sheets nodes with Supabase queries, and (3) fixing 3 confirmed backend bugs (Switch routing, image polling, video branch wiring).

The monolithic workflow has been thoroughly analyzed. The 132 nodes group into 10+ distinct functional domains with clear boundaries around 13 webhook endpoints. The Google Sheets nodes map cleanly to the 10 Supabase tables created in Phase 1. All three bugs have been confirmed and root-caused through direct JSON analysis.

The primary risk is n8n Cloud execution limits -- the Starter plan has 5-minute execution timeout and 320MiB RAM per execution, which is tight for content generation pipelines making multiple AI API calls. Sub-workflows are the mitigation: they don't count toward execution quotas and isolate memory usage.

**Primary recommendation:** Use HTTP Request nodes for all Supabase operations (not the native Supabase node) because the native node lacks Update and Upsert operations. Follow the established Supabase REST API pattern from Phase 2's Auth Validator.

---

## Standard Stack

### Core (Already Established)

| Library/Tool | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| n8n Cloud | Current (flowbound.app.n8n.cloud) | Workflow automation platform | Existing infrastructure |
| Supabase REST API (PostgREST) | Current | Database CRUD via HTTP | Full CRUD + UPSERT support via headers |
| n8n Execute Sub-Workflow node | typeVersion 1 | Call sub-workflows | Already used for Auth Validator (13 instances) |
| n8n Switch node | typeVersion 3.2 | Content type routing | Already exists; needs reconfiguration |
| n8n Wait node | typeVersion 1 | Async polling delays | Already used for video; needed for image polling |
| n8n HTTP Request node | typeVersion 4.2 | External API calls + Supabase | Consistent pattern across all API integrations |

### NOT Using (Native Supabase Node)

| Library | Why NOT | Use Instead |
|---------|---------|-------------|
| n8n-nodes-base.supabase | Only supports Insert, Get, Delete. No Update. No Upsert. | HTTP Request + Supabase REST API |

**Rationale:** The n8n native Supabase node is missing critical operations this project needs (Update rows for approval status changes, Upsert for ICP data). Using HTTP Request nodes with the Supabase REST API provides full CRUD + UPSERT and is consistent with the Auth Validator pattern established in Phase 2.

### Supabase REST API Pattern (HTTP Request Node)

All Supabase operations use the same header pattern:

```
Headers:
  Authorization: Bearer <service_role_key>
  apikey: <service_role_key>
  Content-Type: application/json
  Prefer: return=representation  (for INSERT/UPDATE/UPSERT -- returns affected rows)
```

**Confidence: HIGH** -- Verified from Phase 1 research and Phase 2 Auth Validator implementation.

---

## Architecture Patterns

### Recommended Sub-Workflow Structure

Based on the monolith analysis (132 nodes, 13 webhooks, 10 functional domains), the recommended decomposition into 13 sub-workflows:

```
workflows/
  00-Auth-Validator/           # Already exists (Phase 2)
  01-ICP-Analyzer/             # Phase 1 pipeline: Perplexity + Claude -> icps table
  02-Theme-Generator/          # Phase 2 pipeline: Claude -> campaigns + themes tables
  03-Themes-List/              # Read endpoint: themes table -> frontend
  04-Content-Studio/           # Phase 4 pipeline: Switch routing + text/image/video generation
  05-Content-Submit/           # Submit content to approval queue
  06-Approval-List/            # Read approval queue
  07-Approval-Action/          # Approve/reject/edit content
  08-Clear-Pending/            # Delete pending content items
  09-Calendar-Sync/            # Read approved -> Google Calendar events
  10-Chat/                     # Chat endpoint: Claude conversation
  11-Image-Generator/          # Standalone tool: KIE image generation
  12-Video-Script-Builder/     # Standalone tool: Claude video scripts
  13-Video-Creator/            # Standalone tool: KIE video generation
```

Plus shared utility sub-workflows:
```
  Util-Supabase-Error-Handler/ # Shared error formatting for Supabase failures
```

### Node Counts Per Sub-Workflow (From Monolith Analysis)

| Sub-Workflow | Current Nodes | Key Operations |
|-------------|---------------|----------------|
| 01-ICP-Analyzer | ~7 | Webhook + Auth + Perplexity + Claude + Supabase UPSERT + Respond |
| 02-Theme-Generator | ~8 | Webhook + Auth + Claude + Parse + Supabase INSERT batch + Respond |
| 03-Themes-List | ~5 | Webhook + Auth + Supabase SELECT + Format + Respond |
| 04-Content-Studio | ~12 | Webhook/Cron + Auth + Supabase READ + Switch + Claude/KIE + Supabase WRITE |
| 05-Content-Submit | ~5 | Webhook + Auth + Format + Supabase INSERT + Respond |
| 06-Approval-List | ~5 | Webhook + Auth + Supabase SELECT + Organize + Respond |
| 07-Approval-Action | ~8 | Webhook + Auth + IF approve/reject/edit + Supabase UPDATE + Respond |
| 08-Clear-Pending | ~4 | Webhook + Auth + Supabase DELETE + Respond |
| 09-Calendar-Sync | ~6 | Webhook + Auth + Supabase SELECT + Format + Google Calendar + Respond |
| 10-Chat | ~5 | Webhook + Auth + Prepare Context + Claude + Respond |
| 11-Image-Generator | ~7 | Webhook + Auth + Prepare + KIE Create + Poll Loop + Parse + Respond |
| 12-Video-Script-Builder | ~5 | Webhook + Auth + Claude + Parse + Respond |
| 13-Video-Creator | ~7 | Webhook + Auth + Prepare + KIE Create + Wait + Poll + Parse + Respond |

### Pattern 1: Standard Webhook Sub-Workflow

Every sub-workflow follows the same entry pattern established in Phase 2:

```
Webhook (POST /endpoint)
  -> Execute Sub-Workflow (Auth Validator, workflowId: S4QtfIKpvhW4mQYG)
    -> IF (authenticated = true)
      -> [Business Logic]
      -> Respond to Webhook (200 + JSON)
    -> ELSE
      -> Respond to Webhook (401 Unauthorized)
```

**Confidence: HIGH** -- This pattern is already implemented in the monolith for all 13 endpoints.

### Pattern 2: Supabase CRUD via HTTP Request

**SELECT (Read rows):**
```
HTTP Request Node:
  Method: GET
  URL: https://llpnwaoxisfwptxvdfed.supabase.co/rest/v1/content_items?user_id=eq.{{ $json.user_id }}&status=eq.pending
  Headers:
    Authorization: Bearer {{ $credentials.supabaseServiceRole }}
    apikey: {{ $credentials.supabaseServiceRole }}
```

**INSERT (Create rows):**
```
HTTP Request Node:
  Method: POST
  URL: https://llpnwaoxisfwptxvdfed.supabase.co/rest/v1/content_items
  Headers:
    Prefer: return=representation
    Authorization: Bearer {{ $credentials.supabaseServiceRole }}
    apikey: {{ $credentials.supabaseServiceRole }}
  Body (JSON): { "user_id": "...", "title": "...", "content": "...", ... }
```

**UPDATE (Modify rows):**
```
HTTP Request Node:
  Method: PATCH
  URL: https://llpnwaoxisfwptxvdfed.supabase.co/rest/v1/content_items?id=eq.{{ $json.content_id }}
  Headers:
    Prefer: return=representation
    Authorization: Bearer {{ $credentials.supabaseServiceRole }}
    apikey: {{ $credentials.supabaseServiceRole }}
  Body (JSON): { "status": "approved", "updated_at": "{{ $now.toISO() }}" }
```

**UPSERT (Insert or update):**
```
HTTP Request Node:
  Method: POST
  URL: https://llpnwaoxisfwptxvdfed.supabase.co/rest/v1/icps
  Headers:
    Prefer: resolution=merge-duplicates,return=representation
    Authorization: Bearer {{ $credentials.supabaseServiceRole }}
    apikey: {{ $credentials.supabaseServiceRole }}
  Body (JSON): { "user_id": "...", "icp_summary": "...", ... }
```
Note: UPSERT requires a UNIQUE constraint on the conflict column (icps has `UNIQUE(user_id)`).

**DELETE (Remove rows):**
```
HTTP Request Node:
  Method: DELETE
  URL: https://llpnwaoxisfwptxvdfed.supabase.co/rest/v1/content_items?user_id=eq.{{ $json.user_id }}&status=eq.pending
  Headers:
    Authorization: Bearer {{ $credentials.supabaseServiceRole }}
    apikey: {{ $credentials.supabaseServiceRole }}
```

**Confidence: HIGH** -- PostgREST API is well-documented; Phase 1 research verified the two-header pattern.

### Pattern 3: Polling Loop (for Image Generation)

Replace the hacky `setTimeout(35000)` with a proper polling loop:

```
KIE -- Create Image Task
  -> Wait (10 seconds)
    -> KIE -- Get Image Result
      -> IF (data.state = "success")
        -> TRUE: Parse Image Result -> Respond
        -> FALSE: Wait (5 seconds) -> KIE -- Get Image Result (loop back)
```

The IF node's FALSE branch connects back to the Wait node, creating a retry loop. The loop exits when the KIE API returns `state: "success"`.

**Key details:**
- Initial wait: 10 seconds (KIE image generation typically takes 15-30 seconds)
- Retry interval: 5 seconds between polls
- Maximum iterations: Add a counter in a Code node to break after ~12 attempts (60 seconds total) to prevent infinite loops
- The Wait node handles delays properly -- for waits under 65 seconds, it keeps execution in memory (synchronous), which is appropriate here

**Confidence: HIGH** -- Verified from n8n community polling loop pattern (community.n8n.io/t/how-to-build-a-polling-loop/110997).

### Anti-Patterns to Avoid

- **setTimeout in Code nodes for delays:** The `await new Promise(resolve => setTimeout(resolve, 35000))` pattern blocks the Code node's execution thread and wastes the entire 35 seconds regardless of whether the task completed early. Use the Wait node instead.
- **Giant sub-workflows:** Keep each sub-workflow under 15 nodes. If it grows larger, extract shared logic into utility sub-workflows.
- **Passing large data between sub-workflows:** The Execute Sub-Workflow node passes all data by value. Strip unnecessary fields before calling sub-workflows to reduce memory usage.
- **"Send data to all matching outputs" on Switch:** The default mode sends data to ALL matching branches. For mutually exclusive routing, this must be explicitly disabled.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Database CRUD | Custom SQL queries in Code nodes | HTTP Request + Supabase REST API (PostgREST) | PostgREST handles filtering, pagination, JSON serialization, and respects RLS |
| UPSERT logic | IF exists -> UPDATE, ELSE -> INSERT | PostgREST `Prefer: resolution=merge-duplicates` header | Single atomic operation; no race conditions |
| Polling/retry loops | setTimeout in Code nodes | n8n Wait node + IF node loop | Wait node integrates with n8n's execution engine; setTimeout blocks the thread |
| JWT validation | Code node parsing JWT | Execute Sub-Workflow (Auth Validator) | Already built in Phase 2; reusable across all workflows |
| Error responses | Inline error handling in each node | Shared error formatting pattern | Consistent 4xx/5xx responses across all endpoints |
| Data filtering | Code node JavaScript filters | PostgREST query parameters (`?status=eq.pending&user_id=eq.X`) | Server-side filtering is faster and uses less memory |

---

## Bug Analysis (From Monolith JSON)

### Bug 1: Switch Node Routing (PIPE-07) -- CONFIRMED

**What's wrong:** The Switch node "Route: Text / Image / Video" has three rules that are NOT mutually exclusive:

| Rule | Output | Condition | Problem |
|------|--------|-----------|---------|
| 0 | Text (Claude -- Write Post Content) | `content_type` NOT contains "Video" | Matches everything except Video items |
| 1 | Image (KIE -- Generate Content Image) | `content_type` EXISTS | Matches EVERYTHING (content_type always exists) |
| 2 | Video (Claude -- Video Script Generator) | `content_type` CONTAINS "Video" | Matches only Video items |

**Result:** Text items trigger BOTH text (Rule 0) and image (Rule 1) branches. Video items trigger BOTH image (Rule 1) and video (Rule 2) branches. Only nothing routes correctly.

**Root cause:** Rule 1 uses "exists" operator instead of an equality check for the image content type. Also, the Switch `options` object is empty -- meaning it uses the default "all matching outputs" mode.

**Fix:** Two changes needed:
1. Set Switch to "first match" mode: set `options.sendDataToAllOutputs` to `false` (the Switch node's option "Send data to all matching outputs" must be turned OFF)
2. Rewrite rules with proper equality checks:
   - Rule 0: `content_type` equals "text" (or "Text Post" or whatever the actual value is)
   - Rule 1: `content_type` equals "image" (or "Image Post")
   - Rule 2: `content_type` contains "Video"
   - Add fallback output for unmatched items

**Confidence: HIGH** -- Direct JSON analysis of Switch node parameters and connections.

### Bug 2: Image Polling setTimeout (TOOL-05) -- CONFIRMED

**What's wrong:** The node "Code in JavaScript" between `KIE -- Create Image Task` and `KIE -- Get Image Result` contains:

```javascript
await new Promise(resolve => setTimeout(resolve, 35000));
return $input.all();
```

This blindly waits 35 seconds regardless of whether the image is ready earlier or needs more time.

**Problems:**
- Wastes time if image is ready in 15 seconds
- Fails silently if image takes longer than 35 seconds
- Blocks the execution thread (n8n Cloud has 5min/40min timeout depending on plan)
- No retry logic -- single attempt only

**Fix:** Replace with a Wait node + polling IF loop (see Pattern 3 above).

**Confidence: HIGH** -- Direct JSON analysis of Code node content.

### Bug 3: Video Branch Wiring (TOOL-06) -- CONFIRMED

**What's wrong:** The "Video Ready?" IF node checks `$json.data.successFlag` equals `"1"`. But the connections are inverted:

| Branch | Connection | Expected | Actual |
|--------|-----------|----------|--------|
| TRUE (output 0) -- successFlag=1 (video IS ready) | Video Processing -- Response | Parse Video Result | WRONG: sends "processing" response when video is DONE |
| FALSE (output 1) -- successFlag!=1 (video NOT ready) | Parse Video Result | Video Processing -- Response | WRONG: parses result when video is NOT done |

For comparison, the "Image Ready?" IF node is wired CORRECTLY:
- TRUE (state=success) -> Parse Image Result (correct)
- FALSE (state!=success) -> Image Processing -- Response (correct)

**Fix:** Swap the connections on the "Video Ready?" IF node:
- TRUE (output 0) -> Parse Video Result
- FALSE (output 1) -> Video Processing -- Response

**Confidence: HIGH** -- Direct JSON analysis confirmed by comparing with correctly-wired Image Ready? node.

---

## Google Sheets to Supabase Migration Map

All 16 Google Sheets nodes mapped to their Supabase replacements:

### Sheet Tab: ELUXR_ICP_Data -> Table: `icps`

| Google Sheets Node | Operation | Supabase Replacement | HTTP Method | PostgREST Pattern |
|-------------------|-----------|---------------------|-------------|-------------------|
| Save ICP to Google Sheets1 | appendOrUpdate | UPSERT into `icps` | POST | `Prefer: resolution=merge-duplicates` |

### Sheet Tab: ELUXR_Themes -> Tables: `campaigns` + `themes`

| Google Sheets Node | Operation | Supabase Replacement | HTTP Method | PostgREST Pattern |
|-------------------|-----------|---------------------|-------------|-------------------|
| Save Themes to Google Sheets | append | INSERT into `campaigns` then INSERT batch into `themes` | POST | Standard insert (needs campaign_id FK) |
| Read Today's Theme | read (filter) | SELECT from `themes` WHERE scheduled_date = today | GET | `?scheduled_date=eq.YYYY-MM-DD` |
| Read Themes Sheet | read (all) | SELECT from `themes` joined with `campaigns` | GET | `?user_id=eq.X&select=*,campaigns(month)` |

### Sheet Tab: ELUXR_Approval_Queue -> Table: `content_items`

| Google Sheets Node | Operation | Supabase Replacement | HTTP Method | PostgREST Pattern |
|-------------------|-----------|---------------------|-------------|-------------------|
| Save to Approval Queue Sheet | append | INSERT into `content_items` | POST | Standard insert |
| Save to Queue Sheet | append | INSERT into `content_items` | POST | Standard insert |
| Read Queue Sheet | read (all) | SELECT from `content_items` | GET | `?user_id=eq.X` |
| Get Pending Rows | read (filter) | SELECT from `content_items` WHERE status=pending | GET | `?status=eq.pending&user_id=eq.X` |
| Delete Pending Rows | delete | DELETE from `content_items` WHERE status=pending | DELETE | `?status=eq.pending&user_id=eq.X` |
| Find Content Row | read (filter by id) | SELECT from `content_items` WHERE id=X | GET | `?id=eq.X` |
| Update to Approved | update | UPDATE `content_items` SET status=approved | PATCH | `?id=eq.X` body: `{"status":"approved"}` |
| Find Row for Reject | read (filter by id) | SELECT from `content_items` WHERE id=X | GET | `?id=eq.X` |
| Update to Rejected | update | UPDATE `content_items` SET status=rejected | PATCH | `?id=eq.X` body: `{"status":"rejected"}` |
| Find Row for Edit | read (filter by id) | SELECT from `content_items` WHERE id=X | GET | `?id=eq.X` |
| Update Content | update | UPDATE `content_items` SET content=... | PATCH | `?id=eq.X` body: `{"content":"..."}` |
| Read Approval Queue for Calendar | read (filter) | SELECT from `content_items` WHERE status=approved | GET | `?status=eq.approved&user_id=eq.X` |

### Key Schema Mapping Notes

1. **ICP Save uses UPSERT:** The `icps` table has `UNIQUE(user_id)`, so the PostgREST `Prefer: resolution=merge-duplicates` header enables atomic upsert. No need for Find-then-Update logic.

2. **Theme Save is a two-step operation:** The Sheets tab stored flat rows. Supabase has normalized `campaigns` + `themes` tables. The save operation needs to: (a) UPSERT into `campaigns` to get/create campaign_id, then (b) INSERT batch into `themes` with that campaign_id.

3. **Approval Queue maps to content_items status field:** In v1, the approval queue was a separate sheet tab. In v2, approval is a status on `content_items` (pending_review, approved, rejected). The "Find + Update" pairs can be simplified to single PATCH calls with filter.

4. **user_id must be injected:** The Auth Validator returns `user_id`. Every Supabase operation must include this in the query filter (for reads) or request body (for writes).

5. **Find + Update can be collapsed:** The Google Sheets pattern required "Find Row" then "Update Row" as separate operations. Supabase REST API supports `PATCH /content_items?id=eq.X` directly -- the find step becomes part of the URL filter.

**Confidence: HIGH** -- Direct analysis of all 16 nodes + Supabase schema from Phase 1 migration file.

---

## n8n Cloud Execution Limits

### Confirmed Limits

| Metric | Starter Plan | Pro Plan |
|--------|-------------|----------|
| Execution timeout | 5 minutes | 40 minutes |
| RAM per execution | 320 MiB | 1 GB |
| Monthly executions | 2,500 | 10,000 |
| Active workflows | 5 | 15 |
| Concurrent executions | 5 | 20 |

**Confidence: MEDIUM** -- Sourced from community discussions and third-party pricing analyses; official n8n pricing page does not publish all limits publicly.

### Impact on This Phase

**Critical constraint -- Active Workflows:** The Starter plan allows only 5 active workflows. With 14 sub-workflows (Auth Validator + 13 domain workflows), the Pro plan (15 active workflows) is the minimum. If the user is on Starter, this decomposition requires an upgrade.

**Execution timeout:** Individual sub-workflows will be well under 5 minutes (most are simple CRUD operations). The Content Studio sub-workflow (04) is the longest due to AI API calls, but even that should complete in 1-2 minutes per content item.

**Sub-workflow executions don't count toward quotas:** This is confirmed from multiple sources. Sub-workflow executions called via Execute Sub-Workflow node do not count toward the monthly execution limit. This makes the decomposition cost-effective.

**Memory:** At 320 MiB (Starter) or 1 GB (Pro), individual sub-workflows processing single items are well within limits. The concern is batch operations processing 30+ content items simultaneously -- the Content Studio workflow should process items in batches, not all at once.

### Recommendation

The user MUST be on at least the Pro plan (15 active workflows) to deploy all 14 sub-workflows. Verify current plan before beginning Phase 3 implementation.

**Confidence: HIGH** for the architectural impact; **MEDIUM** for exact limit numbers.

---

## n8n Switch Node Configuration

### How to Configure Mutually Exclusive Routing

The Switch node has a "Send data to all matching outputs" setting:

- **ON (default):** Data goes to ALL outputs whose conditions match -- this is the current bug
- **OFF:** Data goes to ONLY the FIRST matching output -- this is what we need

Additionally, the Switch node supports a **Fallback output** for items that match no rules.

### Correct Configuration for Content Type Routing

```json
{
  "parameters": {
    "rules": {
      "values": [
        {
          "conditions": {
            "conditions": [{
              "leftValue": "={{ $json.content_type }}",
              "rightValue": "text",
              "operator": { "type": "string", "operation": "equals" }
            }],
            "options": { "caseSensitive": false }
          }
        },
        {
          "conditions": {
            "conditions": [{
              "leftValue": "={{ $json.content_type }}",
              "rightValue": "image",
              "operator": { "type": "string", "operation": "equals" }
            }],
            "options": { "caseSensitive": false }
          }
        },
        {
          "conditions": {
            "conditions": [{
              "leftValue": "={{ $json.content_type }}",
              "rightValue": "video",
              "operator": { "type": "string", "operation": "contains" }
            }],
            "options": { "caseSensitive": false }
          }
        }
      ]
    },
    "options": {
      "allMatchingOutputs": false,
      "fallbackOutput": "extra"
    }
  }
}
```

**Note:** The exact content_type values need to be determined from the v1 data. The current Code nodes generate values like "text", "image", "video" (lowercase in some places, mixed case in others). Normalize to lowercase in the Code nodes that set content_type.

**Confidence: HIGH** -- Switch node options verified from n8n documentation and community sources.

---

## n8n Code Node on Cloud

### Confirmed Capabilities

- **Available built-in modules:** `crypto` (Node.js built-in), `moment` (npm)
- **No external npm modules:** n8n Cloud blocks all external module imports
- **Execution modes:** "Run Once for Each Item" (default, returns `{ json: {...} }`) and "Run Once for All Items" (returns `[{ json: {...} }]`)
- **Built-in helpers:** `this.helpers.httpRequest()` for making HTTP calls from within Code nodes
- **Environment variables:** Accessible via `$env.get('NAME')`
- **Item access:** `$input.item.json` (per-item mode), `$input.all()` (all-items mode)
- **Cross-node references:** `$('Node Name').item.json` or `$('Node Name').first().json`

### Limitations

- No `require()` or `import` for external packages
- No file system access
- No `child_process` or `os` modules
- `setTimeout`/`setInterval` work but are anti-patterns (use Wait node instead)

**Confidence: HIGH** -- Verified from n8n official documentation.

---

## Common Pitfalls

### Pitfall 1: Active Workflow Limit Exceeded

**What goes wrong:** Deploying 14+ active sub-workflows on the Starter plan (limit: 5) causes workflows to be deactivated.
**Why it happens:** The plan limit is enforced on active workflows, not total workflows.
**How to avoid:** Confirm the user is on the Pro plan (15 active workflows) before beginning.
**Warning signs:** Workflows show as "inactive" after activation; n8n dashboard shows plan limit warning.

### Pitfall 2: Data Loss During Sub-Workflow Handoff

**What goes wrong:** Data available in the parent workflow is not accessible in the sub-workflow (or vice versa).
**Why it happens:** Execute Sub-Workflow passes data by value from the triggering node's output. Cross-node references (`$('Other Node')`) don't work across workflow boundaries.
**How to avoid:** Ensure all needed data is consolidated into a single item before calling Execute Sub-Workflow. In each sub-workflow, the trigger node output contains the passed data.
**Warning signs:** `undefined` values in sub-workflow nodes when referencing parent workflow data.

### Pitfall 3: Supabase REST API Requires Both Headers

**What goes wrong:** Supabase queries return 401 or 403 errors.
**Why it happens:** Supabase REST API requires BOTH `Authorization: Bearer <key>` AND `apikey: <key>` headers. Missing either one causes auth failures.
**How to avoid:** Use a consistent HTTP Request node template with both headers for every Supabase call. Consider creating an n8n credential with both headers.
**Warning signs:** 401 Unauthorized from Supabase REST API even with a valid key.

### Pitfall 4: PostgREST Filter Syntax Errors

**What goes wrong:** Supabase queries return all rows or wrong rows.
**Why it happens:** PostgREST filter syntax is `?column=eq.value` (not `?column=value`). The `eq.` prefix is required.
**How to avoid:** Always include the operator prefix: `eq.`, `neq.`, `gt.`, `lt.`, `in.()`, `is.null`, etc.
**Warning signs:** SELECT returns more rows than expected; UPDATE/DELETE affects more rows than intended.

### Pitfall 5: Theme Save Requires Two-Step Insert

**What goes wrong:** Themes are inserted without a campaign_id FK, causing orphan records or FK violations.
**Why it happens:** In Google Sheets, themes were flat rows. In Supabase, they require a parent `campaigns` record.
**How to avoid:** Always UPSERT the campaign first (`campaigns` table with `UNIQUE(user_id, month)`), capture the returned campaign_id, then INSERT themes with that FK.
**Warning signs:** FK constraint violation errors on `themes.campaign_id`.

### Pitfall 6: Switch Node Fallthrough

**What goes wrong:** Items with unexpected content_type values trigger wrong branches or no branch.
**Why it happens:** Switch rules use exact matching but content_type values may have unexpected casing, whitespace, or values.
**How to avoid:** Normalize content_type to lowercase before the Switch node. Add a fallback output to catch unmatched items and log them.
**Warning signs:** Items disappearing (no output from Switch) or appearing in wrong branches.

### Pitfall 7: Polling Loop Runs Forever

**What goes wrong:** Image/video generation polling never completes, consuming the entire execution timeout.
**Why it happens:** External API failure, changed response format, or unexpected error state.
**How to avoid:** Add a retry counter in a Code node. After N attempts, break the loop and return an error response. Also check for error states (not just success vs not-success).
**Warning signs:** Workflow execution times suddenly spike to 5+ minutes.

---

## Code Examples

### Example 1: Supabase SELECT with Filter (HTTP Request Node)

For "Read Queue Sheet" replacement -- get all pending content items for a user:

```
Node Type: HTTP Request
Method: GET
URL: https://llpnwaoxisfwptxvdfed.supabase.co/rest/v1/content_items?user_id=eq.{{ $json.user_id }}&status=eq.pending_review&order=created_at.desc
Headers:
  Authorization: Bearer [service_role_key from credential]
  apikey: [service_role_key from credential]
```

Returns: JSON array of matching rows.

### Example 2: Supabase UPSERT (HTTP Request Node)

For "Save ICP to Google Sheets1" replacement -- upsert ICP data:

```
Node Type: HTTP Request
Method: POST
URL: https://llpnwaoxisfwptxvdfed.supabase.co/rest/v1/icps
Headers:
  Authorization: Bearer [service_role_key]
  apikey: [service_role_key]
  Prefer: resolution=merge-duplicates,return=representation
  Content-Type: application/json
Body (JSON):
{
  "user_id": "{{ $json.user_id }}",
  "business_url": "{{ $json.business_url }}",
  "industry": "{{ $json.industry }}",
  "icp_summary": "{{ $json.icp_summary }}",
  "demographics": {{ $json.demographics }},
  "psychographics": {{ $json.psychographics }},
  "content_preferences": {{ $json.content_preferences }},
  "competitors": {{ $json.competitors }},
  "content_opportunities": {{ $json.content_opportunities }},
  "recommended_hashtags": {{ $json.recommended_hashtags }},
  "updated_at": "{{ $now.toISO() }}"
}
```

The UNIQUE(user_id) constraint on the icps table makes this an upsert on user_id.

### Example 3: Supabase PATCH (HTTP Request Node)

For "Update to Approved" replacement:

```
Node Type: HTTP Request
Method: PATCH
URL: https://llpnwaoxisfwptxvdfed.supabase.co/rest/v1/content_items?id=eq.{{ $json.content_id }}
Headers:
  Authorization: Bearer [service_role_key]
  apikey: [service_role_key]
  Prefer: return=representation
  Content-Type: application/json
Body (JSON):
{
  "status": "approved",
  "updated_at": "{{ $now.toISO() }}"
}
```

### Example 4: Polling Loop for Image Generation

```
Node flow:
  KIE -- Create Image Task (HTTP Request, POST)
    -> Init Poll Counter (Code: return { json: { ...input, pollCount: 0 } })
      -> Wait (10 seconds, first iteration)
        -> KIE -- Get Image Result (HTTP Request, GET)
          -> Check Result (Code: increment pollCount, check state)
            -> IF (state = "success" OR pollCount >= 12)
              -> TRUE: Parse Image Result (success or timeout)
              -> FALSE: Wait (5 seconds) -> loops back to KIE -- Get Image Result
```

Check Result Code node:
```javascript
const result = $input.item.json;
const pollCount = (result.pollCount || 0) + 1;

const state = result.data?.state || 'processing';
const isReady = state === 'success';
const isTimeout = pollCount >= 12;
const isError = state === 'failed' || state === 'error';

return {
  json: {
    ...result,
    pollCount,
    isComplete: isReady || isTimeout || isError,
    isSuccess: isReady,
    error: isTimeout ? 'Image generation timed out after 60 seconds' :
           isError ? `Image generation failed: ${state}` : null
  }
};
```

---

## State of the Art

| Old Approach (v1) | New Approach (v2) | Impact |
|-------------------|-------------------|--------|
| Google Sheets for all data | Supabase REST API (PostgREST) | Proper DB with filtering, indexes, RLS, multi-tenant |
| Single 132-node monolith | 13 focused sub-workflows | Independently testable, maintainable, debuggable |
| setTimeout(35000) for image polling | Wait node + IF polling loop | Detect completion, not guess; retry on failure |
| Switch with "all matching" + bad rules | Switch with "first match" + exact equality | Mutually exclusive routing guaranteed |
| Video IF wired backwards | Swap TRUE/FALSE connections | Video result parsed when ready, not when processing |
| Flat Google Sheets rows | Normalized Supabase tables with FKs | Campaign -> Themes -> Content Items relationship |
| Find Row + Update Row (2 operations) | Single PATCH with filter (1 operation) | Simpler, atomic, no race conditions |

---

## Open Questions

### 1. Which n8n Cloud Plan Is Active?

- **What we know:** The project uses flowbound.app.n8n.cloud. Starter allows 5 active workflows; Pro allows 15.
- **What's unclear:** Which plan the user is on.
- **Impact:** Starter plan CANNOT support 14 active sub-workflows. Pro plan can.
- **Recommendation:** Verify plan tier before beginning. If Starter, either upgrade to Pro or reduce sub-workflow count by combining small workflows.

### 2. Exact Content Type Values in Pipeline

- **What we know:** Code nodes generate content_type values, but different nodes use different conventions (some capitalize, some don't).
- **What's unclear:** The exact values that flow into the Switch node from the theme/content generation pipeline.
- **Impact:** Switch node rules must match the actual values.
- **Recommendation:** During implementation, trace the data flow from theme generation through to the Switch node. Normalize to lowercase before the Switch.

### 3. Supabase Service Role Key Credential Pattern

- **What we know:** Supabase REST API requires both `Authorization` and `apikey` headers with the service_role key.
- **What's unclear:** Whether an n8n credential was already created in Phase 1 for this, and its exact ID.
- **Impact:** Every HTTP Request node targeting Supabase needs this credential.
- **Recommendation:** Check if the credential exists; if not, create one. May need a "Custom Auth" credential type or just hardcode both headers referencing an environment variable.

### 4. Google Calendar Node Stays or Gets Replaced

- **What we know:** There is 1 Google Calendar node in the monolith (`Create Google Calendar Event`). The Google Calendar OAuth credential exists (ID: FJBcOjKITBIaEqRV).
- **What's unclear:** Whether Google Calendar integration stays as-is in Phase 3 or gets deferred to Phase 8.
- **Impact:** The Calendar Sync sub-workflow (09) needs this node if calendar integration is kept.
- **Recommendation:** Keep the Google Calendar node as-is in the Calendar Sync sub-workflow. It's a separate concern from the Sheets migration. Phase 8 will decide its future.

---

## Sources

### Primary (HIGH confidence)
- **Monolith workflow JSON** (`workflows/eluxr-social-media-action-v2-authenticated.json`) -- All 132 nodes, connections, Switch parameters, Code node contents, bug confirmations
- **Auth Validator JSON** (`workflows/eluxr-auth-validator.json`) -- Sub-workflow trigger pattern, Supabase API call pattern
- **Supabase migration SQL** (`supabase/migrations/20260228044505_create_initial_schema.sql`) -- All 10 tables, columns, constraints, indexes, RLS policies
- **Phase 1 Research** (`.planning/phases/01-security-hardening-database-foundation/01-RESEARCH.md`) -- Google Sheets to Supabase mapping, credential setup, REST API pattern
- **Phase 2 Research** (`.planning/phases/02-authentication/02-RESEARCH.md`) -- Auth Validator pattern, JWT validation approach

### Secondary (MEDIUM confidence)
- [n8n Switch Node Documentation](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.switch/) -- "Send data to all matching outputs" option
- [n8n Sub-Workflows Documentation](https://docs.n8n.io/flow-logic/subworkflows/) -- Data passing, execution counting
- [n8n Community: Polling Loop](https://community.n8n.io/t/how-to-build-a-polling-loop/110997) -- Wait + IF loop pattern
- [n8n Community: Cloud Memory Limits](https://community.n8n.io/t/subscription-plan-for-could-starter-and-pro-memory-difference/177448) -- Starter: 320MiB, Pro: 1GB
- [n8n Community: Cloud Execution Timeout](https://community.n8n.io/t/what-is-the-maximum-timeout-for-cloud-3-minutes-or-unlimited/25115) -- Starter: 5min, Pro: 40min
- [n8n Community: Sub-Workflow Tutorial](https://community.n8n.io/t/how-to-use-sub-workflows-in-n8-when-to-use-examples/257577) -- Don't count toward execution quota
- [n8n Code Node Documentation](https://docs.n8n.io/code/code-node/) -- Cloud sandbox limitations, available modules
- [PostgREST Upsert Documentation](https://docs.postgrest.org/en/latest/references/api/tables_views.html) -- `Prefer: resolution=merge-duplicates` header
- [ConnectSafely n8n Cloud Pricing](https://connectsafely.ai/articles/n8n-cloud-pricing-guide) -- Plan tier specifications

### Tertiary (LOW confidence)
- [n8n Community: Supabase Node Upsert Missing](https://community.n8n.io/t/supabase-node-upsert-operation-missing-only-insert-get-delete-visible/161689) -- Node only supports Insert, Get, Delete (no Update, no Upsert). Status may have changed.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- All tools are already in use; decision is HTTP Request over native Supabase node based on capability gaps
- Architecture (sub-workflow decomposition): HIGH -- Based on direct monolith analysis showing clear domain boundaries
- Bug analysis: HIGH -- All three bugs confirmed and root-caused via direct JSON analysis
- Sheets-to-Supabase migration map: HIGH -- All 16 nodes mapped with specific PostgREST patterns
- n8n Cloud limits: MEDIUM -- Exact numbers sourced from community, not official docs
- Polling pattern: HIGH -- Verified from n8n community with confirmed working examples

**Research date:** 2026-03-02
**Valid until:** 2026-04-01 (stable -- n8n Cloud limits and Supabase REST API are unlikely to change within 30 days)
