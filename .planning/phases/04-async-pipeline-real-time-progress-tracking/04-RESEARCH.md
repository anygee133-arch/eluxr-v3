# Phase 4: Async Pipeline + Real-Time Progress Tracking - Research

**Researched:** 2026-03-02
**Domain:** n8n async webhook patterns, Supabase Realtime (postgres_changes), pipeline orchestration
**Confidence:** HIGH (verified via official docs, existing codebase analysis, and community sources)

## Summary

This phase transforms the current synchronous, sequential pipeline (where the frontend makes 3 blocking HTTP calls to n8n and runs a fake progress timer) into an async pattern where a single webhook returns immediately with a pipeline_run ID, and real progress updates flow via Supabase Realtime WebSocket subscriptions on the `pipeline_runs` table.

The architecture has three parts: (1) an n8n orchestrator workflow that accepts the initial request, creates a `pipeline_runs` row, responds immediately with HTTP 202, then sequentially calls each pipeline sub-workflow while updating progress in Supabase after each step; (2) the frontend subscribes to Supabase Realtime `postgres_changes` on the `pipeline_runs` table filtered by the returned row ID, updating the progress UI on each UPDATE event; (3) the existing `pipeline_runs` table (already created in Phase 1 with Realtime enabled) stores the persistent state so page refresh restores progress.

The key technical challenge is the n8n "respond immediately then continue processing" pattern. Two approaches exist: (A) set the Webhook node's `responseMode` to `onReceived` (Immediately), which sends a default "Workflow got started" response and continues execution; or (B) use the `Respond to Webhook` node with `responseMode: responseNode`, which allows a custom JSON response (with the pipeline_run ID) and then continues executing downstream nodes. Approach B is verified to work -- the Respond to Webhook node has an output that flows to subsequent nodes, and the workflow continues after the response is sent.

**Primary recommendation:** Create a new "Pipeline Orchestrator" workflow that uses `responseMode: responseNode` with a `Respond to Webhook` node to return the pipeline_run ID immediately, then continues executing downstream steps (ICP analysis, theme generation, content writing, image generation, video creation, calendar sync), updating `pipeline_runs` via Supabase REST API after each step. The frontend subscribes to `postgres_changes` on the `pipeline_runs` table using the existing supabase-js client.

## Standard Stack

### Core (Already Established)

| Library/Tool | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| supabase-js | @2 (CDN via esm.sh) | Realtime subscriptions + auth | Already loaded in frontend; provides `.channel().on('postgres_changes')` |
| n8n Webhook node | typeVersion 2 | Accept pipeline trigger request | Already used across all 13 workflows |
| n8n Respond to Webhook node | typeVersion 1.1 | Send HTTP 202 with pipeline_run ID immediately | Already used for 401 and success responses |
| n8n HTTP Request node | typeVersion 4.2 | Update pipeline_runs in Supabase + call pipeline steps | Consistent pattern from Phases 1-3 |
| n8n Execute Sub-Workflow node | typeVersion 1 | Call existing sub-workflows (01-ICP, 02-Themes, etc.) | Already used for Auth Validator |
| Supabase REST API (PostgREST) | Current | CRUD on pipeline_runs table | Established header pattern from Phases 1-3 |

### Not Using

| Library | Why NOT | Use Instead |
|---------|---------|-------------|
| Supabase Broadcast channel | Requires custom server-side logic | `postgres_changes` -- automatically broadcasts on table updates |
| n8n native Supabase node | Missing Update operation (needed for progress updates) | HTTP Request + Supabase REST API |
| Socket.io / custom WebSocket | Over-engineering; Supabase Realtime already provides this | supabase-js `.channel().on('postgres_changes')` |
| Execute Sub-Workflow "Wait=false" (fire-and-forget) | Known bug: sub-workflow aborts prematurely | Execute Sub-Workflow with default Wait=true, called sequentially in orchestrator |

### Supabase REST API Pattern (Pipeline Progress Updates)

All pipeline_runs operations use the same header pattern established in Phases 1-3:

```
Headers:
  Authorization: Bearer <service_role_key>
  apikey: <service_role_key>
  Content-Type: application/json
  Prefer: return=representation
```

**INSERT** (create pipeline run):
```
POST /rest/v1/pipeline_runs
Body: { user_id, pipeline_type: 'full_pipeline', status: 'running', current_step: 0, total_steps: 6, step_label: 'Starting...' }
```

**UPDATE** (advance step):
```
PATCH /rest/v1/pipeline_runs?id=eq.<run_id>
Body: { current_step: N, step_label: 'Step name', step_progress: 100, status: 'running' }
```

**Confidence: HIGH** -- Verified from Phase 1-3 established patterns and existing workflow JSON.

## Architecture Patterns

### Pattern 1: Orchestrator Workflow (Respond-Then-Continue)

**What:** A new n8n workflow that acts as the pipeline entry point. It receives the trigger, creates a pipeline_runs row, responds with HTTP 202, then sequentially calls each sub-workflow while updating progress.

**When to use:** For the full content generation pipeline (6 steps).

**Critical n8n behavior:**
- Webhook node `responseMode` must be set to `responseNode`
- The `Respond to Webhook` node sends the HTTP response AND has an output connection
- Nodes connected AFTER the Respond to Webhook node continue executing
- Only the FIRST Respond to Webhook node encountered sends the response
- The workflow continues until all downstream nodes complete or the execution timeout is reached

**Workflow structure:**
```
Webhook (POST /eluxr-generate-content)
  -> Auth Validator (Execute Sub-Workflow)
  -> Auth OK? (IF)
    -> FALSE: 401 Unauthorized (Respond to Webhook)
    -> TRUE: Create Pipeline Run (Code node: prepare INSERT)
      -> Supabase -- INSERT pipeline_runs (HTTP Request)
      -> Respond 202 (Respond to Webhook: { status: 202, pipeline_run_id })
      -> Update Step 1 (HTTP Request: PATCH pipeline_runs step=1)
      -> Execute 01-ICP-Analyzer (Execute Sub-Workflow)
      -> Update Step 2 (HTTP Request: PATCH pipeline_runs step=2)
      -> Execute 02-Theme-Generator (Execute Sub-Workflow)
      -> Update Step 3 (HTTP Request: PATCH pipeline_runs step=3)
      -> Execute 04-Content-Studio (Execute Sub-Workflow)
      -> Update Step 4 (HTTP Request: PATCH pipeline_runs step=4)
      -> Execute 11-Image-Generator (Execute Sub-Workflow)
      -> Update Step 5 (HTTP Request: PATCH pipeline_runs step=5)
      -> Execute 13-Video-Creator (Execute Sub-Workflow)
      -> Update Step 6 (HTTP Request: PATCH pipeline_runs step=6)
      -> Execute 09-Calendar-Sync (Execute Sub-Workflow)
      -> Mark Complete (HTTP Request: PATCH pipeline_runs status=completed)
```

**Confidence: HIGH** -- Respond to Webhook output continuation verified via official n8n docs ("By default, the Respond to Webhook node has a single output branch that contains the node's input data. You can optionally enable a second output branch.") and multiple community confirmations.

### Pattern 2: Frontend Realtime Subscription

**What:** The frontend subscribes to `postgres_changes` on the `pipeline_runs` table, filtered by the specific pipeline_run ID, to receive real-time progress updates.

**When to use:** Immediately after triggering the pipeline and receiving the pipeline_run_id from the HTTP 202 response.

**Example:**
```javascript
// Source: Supabase official docs - Postgres Changes
// After receiving pipeline_run_id from webhook response:

const channel = window.supabase
  .channel(`pipeline-${pipelineRunId}`)
  .on(
    'postgres_changes',
    {
      event: 'UPDATE',
      schema: 'public',
      table: 'pipeline_runs',
      filter: `id=eq.${pipelineRunId}`,
    },
    (payload) => {
      const run = payload.new;
      updateProgressUI(run.current_step, run.total_steps, run.step_label, run.status);
    }
  )
  .subscribe();
```

**Cleanup:**
```javascript
// When pipeline completes or user navigates away:
await window.supabase.removeChannel(channel);
```

**Confidence: HIGH** -- Verified from Supabase official Postgres Changes documentation. Filter by `id=eq.{value}` is a supported operator. The `payload.new` object contains the complete updated row.

### Pattern 3: Page Refresh Recovery

**What:** On page load, check Supabase for any active pipeline_runs for the current user. If one exists with status 'running', re-subscribe to Realtime and restore the progress UI.

**Example:**
```javascript
// On page load / auth state change:
async function checkActivePipeline() {
  const { data: runs } = await window.supabase
    .from('pipeline_runs')
    .select('*')
    .eq('status', 'running')
    .order('created_at', { ascending: false })
    .limit(1);

  if (runs && runs.length > 0) {
    const activeRun = runs[0];
    // Restore UI state
    showProgressUI(activeRun);
    // Re-subscribe to Realtime
    subscribeToProgress(activeRun.id);
  }
}
```

**Note:** This reads from Supabase using the anon key with RLS -- the `pipeline_runs` table has RLS policies that filter by `auth.uid() = user_id`, so this automatically returns only the current user's runs.

**Confidence: HIGH** -- Standard Supabase query pattern; RLS verified from Phase 1 schema.

### Recommended Workflow Structure

```
n8n Workflows:
  existing/
    00-Auth-Validator           # Unchanged
    01-ICP-Analyzer             # Unchanged (called by orchestrator)
    02-Theme-Generator          # Unchanged (called by orchestrator)
    04-Content-Studio           # Unchanged (called by orchestrator)
    09-Calendar-Sync            # Unchanged (called by orchestrator)
    11-Image-Generator          # Unchanged (called by orchestrator)
    13-Video-Creator            # Unchanged (called by orchestrator)

  new/
    14-Pipeline-Orchestrator    # NEW: Entry point, responds 202, orchestrates all steps
```

### Anti-Patterns to Avoid

- **Anti-pattern: Frontend calling pipeline steps sequentially.** The current frontend calls `eluxr-phase1-analyzer`, then `eluxr-phase2-themes`, then `eluxr-phase4-studio` in sequence. This blocks the browser, causes timeouts, and means progress is fake. Instead, a single call to the orchestrator starts everything.

- **Anti-pattern: Fire-and-forget sub-workflows via Execute Sub-Workflow Wait=false.** This has a known bug where sub-workflows abort prematurely. Use sequential execution within the orchestrator instead.

- **Anti-pattern: Polling for status.** Instead of the frontend polling an endpoint for status, use Supabase Realtime push. This is more efficient and lower latency.

- **Anti-pattern: Simulated progress timers.** The current `simulateProgress()` function uses hardcoded durations. Replace entirely with real progress from `pipeline_runs` updates.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Real-time push to browser | Custom WebSocket server | Supabase Realtime `postgres_changes` | Already enabled on `pipeline_runs` table; supabase-js already loaded |
| Progress state persistence | localStorage with manual sync | `pipeline_runs` table in Supabase | Survives refresh; multi-device; RLS-isolated per user |
| Async webhook response | Custom queueing system | n8n Respond to Webhook + downstream nodes | Built-in n8n capability; no external dependencies |
| Pipeline orchestration | Custom job queue (Redis, BullMQ) | n8n Execute Sub-Workflow (sequential) | n8n is the orchestration engine; sub-workflows already exist |
| Progress event filtering | Custom event filtering logic | Supabase Realtime `filter: 'id=eq.{id}'` | Server-side filtering; only relevant updates reach the client |

**Key insight:** The entire real-time progress system can be built using only existing infrastructure (Supabase Realtime already enabled, supabase-js already loaded, n8n sub-workflows already built). No new services, libraries, or infrastructure needed.

## Common Pitfalls

### Pitfall 1: n8n Cloud Execution Timeout (5 minutes on Starter plan)

**What goes wrong:** The full pipeline (ICP analysis + themes + content + images + videos + calendar) may take longer than 5 minutes total, causing the orchestrator workflow to be killed mid-execution.
**Why it happens:** n8n Cloud Starter plan enforces a ~5-minute maximum execution timeout.
**How to avoid:**
- Measure actual pipeline execution time during testing
- If it exceeds 5 minutes, split the orchestrator into two chained workflows: (1) orchestrator triggers ICP + themes + content, (2) a second orchestrator handles images + videos + calendar, triggered by the first via HTTP webhook
- Each sub-workflow runs as a separate execution, so individual steps won't timeout unless they individually take >5 minutes
- Consider that sub-workflows called via Execute Sub-Workflow run WITHIN the parent execution (same timeout)
**Warning signs:** Workflow execution shows "timed out" in n8n execution log; pipeline_runs stuck in 'running' status.

### Pitfall 2: Execute Sub-Workflow Shares Parent Execution

**What goes wrong:** When using Execute Sub-Workflow with Wait=true, the sub-workflow runs within the parent's execution context, sharing its timeout budget.
**Why it happens:** Execute Sub-Workflow is synchronous by default -- the parent pauses while the sub-workflow runs.
**How to avoid:**
- If timeout is a concern, consider using HTTP Request to trigger sub-workflows via their own webhook endpoints instead of Execute Sub-Workflow. Each webhook-triggered execution gets its own timeout budget.
- Trade-off: HTTP trigger creates separate executions (counts toward 2,500/month limit) vs Execute Sub-Workflow which shares the parent execution.
**Warning signs:** Pipeline consistently fails at the same step (the one that pushes cumulative time over 5 minutes).

### Pitfall 3: Supabase Realtime RLS Requires Authenticated Client

**What goes wrong:** Realtime subscription receives no events despite table changes occurring.
**Why it happens:** The supabase-js client must be authenticated (user signed in) for RLS-filtered Realtime to work. If the client's JWT expires mid-pipeline, the WebSocket connection drops.
**How to avoid:**
- Ensure `supabase.auth.getSession()` returns a valid session before subscribing
- supabase-js auto-refreshes tokens, but verify the `onAuthStateChange` listener handles reconnection
- The n8n side writes with `service_role` key (bypasses RLS), but the frontend reads through RLS
**Warning signs:** Console shows WebSocket errors; subscription callback never fires; works for first few minutes then stops.

### Pitfall 4: Pipeline Run Stuck in "Running" State

**What goes wrong:** If the orchestrator workflow fails (timeout, error, n8n outage), the pipeline_run stays in 'running' status forever. The frontend shows a perpetual progress bar.
**Why it happens:** No cleanup mechanism for orphaned runs.
**How to avoid:**
- Add error handling in the orchestrator: on any step failure, PATCH pipeline_runs with `status: 'failed'` and `error_message`
- Frontend should detect stale runs (e.g., `started_at` > 15 minutes ago with status still 'running') and show an error state
- Consider adding a `timeout_at` field or using `started_at` comparison
**Warning signs:** User sees "running" progress that never completes.

### Pitfall 5: Respond to Webhook Returns Before Pipeline Run ID is Created

**What goes wrong:** Race condition where the HTTP 202 response is sent before the Supabase INSERT completes, so the client gets no pipeline_run_id.
**Why it happens:** Node execution order in n8n is deterministic (sequential), so this should not happen if the Respond to Webhook node is placed AFTER the INSERT node in the flow.
**How to avoid:** Ensure the workflow graph is: INSERT pipeline_run -> Respond to Webhook -> Continue pipeline. Never place Respond to Webhook before the INSERT.
**Warning signs:** Client receives `null` or `undefined` for pipeline_run_id.

### Pitfall 6: Multiple Concurrent Pipeline Runs

**What goes wrong:** User clicks "Generate" multiple times, creating multiple running pipelines that compete for resources.
**Why it happens:** No deduplication guard on the frontend or backend.
**How to avoid:**
- Frontend: disable the generate button while a pipeline is running; check for active runs on page load
- Backend (orchestrator): check for existing 'running' pipeline_runs for this user before starting a new one; return the existing run_id if found
**Warning signs:** Multiple pipeline_runs rows with status 'running' for the same user.

## Code Examples

### Example 1: Orchestrator Webhook Configuration

```json
// Webhook node configuration
{
  "parameters": {
    "httpMethod": "POST",
    "path": "eluxr-generate-content",
    "responseMode": "responseNode",
    "options": {
      "allowedOrigins": "*"
    }
  },
  "type": "n8n-nodes-base.webhook",
  "typeVersion": 2
}
```

### Example 2: Respond to Webhook (HTTP 202)

```json
// Respond to Webhook node - sends 202 immediately, continues downstream
{
  "parameters": {
    "respondWith": "json",
    "responseBody": "={{ JSON.stringify({ success: true, status: 'accepted', pipeline_run_id: $json.pipeline_run_id }) }}",
    "options": {
      "responseCode": 202
    }
  },
  "type": "n8n-nodes-base.respondToWebhook",
  "typeVersion": 1.1
}
```

### Example 3: Pipeline Progress Update (Code Node)

```javascript
// Code node: Prepare progress update for step N
// Source: Established Supabase REST pattern from Phase 1-3

const stepMap = {
  1: 'Analyzing your business...',
  2: 'Creating content themes...',
  3: 'Writing posts...',
  4: 'Generating images...',
  5: 'Creating videos...',
  6: 'Syncing calendar...'
};

const step = 1; // Replace with actual step number
return {
  json: {
    current_step: step,
    total_steps: 6,
    step_label: stepMap[step],
    step_progress: 0,
    status: 'running',
    updated_at: new Date().toISOString()
  }
};
```

### Example 4: Frontend Realtime Subscription (Vanilla JS)

```javascript
// Source: Supabase Postgres Changes official docs
// Place in non-module script (accesses window.supabase)

let progressChannel = null;

async function startPipeline(formData) {
  // 1. Trigger orchestrator
  const response = await authenticatedFetch(`${API_BASE}/eluxr-generate-content`, {
    method: 'POST',
    body: JSON.stringify(formData)
  });

  if (response.status === 202) {
    const data = await response.json();
    const runId = data.pipeline_run_id;

    // 2. Show progress UI
    showProgressSection();

    // 3. Subscribe to Realtime updates
    subscribeToProgress(runId);
  }
}

function subscribeToProgress(runId) {
  // Clean up any existing subscription
  if (progressChannel) {
    window.supabase.removeChannel(progressChannel);
  }

  progressChannel = window.supabase
    .channel(`pipeline-${runId}`)
    .on(
      'postgres_changes',
      {
        event: 'UPDATE',
        schema: 'public',
        table: 'pipeline_runs',
        filter: `id=eq.${runId}`,
      },
      (payload) => {
        const run = payload.new;
        renderProgress(run);
      }
    )
    .subscribe();
}

function renderProgress(run) {
  const percentage = Math.round((run.current_step / run.total_steps) * 100);

  // Update progress bar
  document.getElementById('progress-bar').style.width = `${percentage}%`;
  document.getElementById('progress-text').textContent = `${percentage}%`;
  document.getElementById('phase-text').textContent = run.step_label;

  // Update step list checkmarks
  document.querySelectorAll('#phase-2 .phase-item').forEach((item, index) => {
    item.classList.remove('active', 'completed');
    if (index < run.current_step) {
      item.classList.add('completed');
      item.querySelector('.phase-icon').textContent = '\u2713';
    } else if (index === run.current_step) {
      item.classList.add('active');
    }
  });

  // Handle completion
  if (run.status === 'completed') {
    cleanup();
    // Transition to content view
    fetchAndDisplayCalendar();
  } else if (run.status === 'failed') {
    cleanup();
    showToast(`Pipeline failed: ${run.error_message || 'Unknown error'}`, 'error');
  }
}

function cleanup() {
  if (progressChannel) {
    window.supabase.removeChannel(progressChannel);
    progressChannel = null;
  }
}
```

### Example 5: Page Refresh Recovery

```javascript
// On auth state change (user logged in), check for active pipeline
async function checkActivePipeline() {
  const { data: runs, error } = await window.supabase
    .from('pipeline_runs')
    .select('*')
    .eq('status', 'running')
    .order('created_at', { ascending: false })
    .limit(1);

  if (!error && runs && runs.length > 0) {
    const activeRun = runs[0];

    // Check if run is stale (> 15 minutes)
    const startedAt = new Date(activeRun.started_at || activeRun.created_at);
    const minutesElapsed = (Date.now() - startedAt.getTime()) / 60000;

    if (minutesElapsed > 15) {
      // Stale run -- show error, don't subscribe
      showToast('Previous generation may have failed. Please try again.', 'error');
      return;
    }

    // Active run found -- restore progress UI
    showProgressSection();
    renderProgress(activeRun);
    subscribeToProgress(activeRun.id);
  }
}
```

### Example 6: Error Handler in Orchestrator (Code Node)

```javascript
// Code node: Handle pipeline step failure
// Placed in error branch of each Execute Sub-Workflow

const pipelineRunId = $input.first().json.pipeline_run_id;
const failedStep = $input.first().json.current_step;
const errorMsg = $input.first().json.error || 'Unknown error in pipeline step';

return {
  json: {
    id: pipelineRunId,
    status: 'failed',
    error_message: `Step ${failedStep} failed: ${errorMsg}`,
    completed_at: new Date().toISOString(),
    updated_at: new Date().toISOString()
  }
};
```

## State of the Art

| Old Approach (Current) | New Approach (Phase 4) | Impact |
|------------------------|----------------------|--------|
| Frontend calls 3 webhooks sequentially, blocking browser | Single webhook returns 202 immediately | Browser never blocks; no timeout risk on client side |
| `simulateProgress()` with hardcoded durations | Supabase Realtime push from actual step completion | Progress is real, not fake |
| "Estimated time remaining" text | Step-by-step checkmarks, no time estimate | Honest UX, no misleading information |
| Progress lost on page refresh | `pipeline_runs` persisted in Supabase | Survives refresh, multi-device |
| `currentSessionId` stored in localStorage | `pipeline_run_id` from Supabase UUID | Server-authoritative, no client-side ID generation |
| No error recovery | `pipeline_runs.status = 'failed'` with error_message | User sees what went wrong |

**Deprecated/outdated (to remove):**
- `simulateProgress()` function -- replace entirely
- `updateProgressUI()` function -- replace with Realtime-driven `renderProgress()`
- `#time-remaining` element and `.time-remaining` CSS -- remove per UI-05
- `currentSessionId` local generation -- replace with server-generated pipeline_run_id
- Sequential `authenticatedFetch` calls to phase1/phase2/phase4 in `generateContent()` -- replace with single orchestrator call

## Execution Budget Analysis

**n8n Cloud Starter: 2,500 executions/month, 5 concurrent**

With Execute Sub-Workflow (Wait=true), sub-workflows run within the parent execution and do NOT count as separate executions. This is execution-budget-friendly.

If we use HTTP Request to trigger sub-workflows (to get separate timeout budgets), each sub-workflow trigger counts as a separate execution:
- 1 orchestrator + 6 sub-workflow triggers = 7 executions per pipeline run
- At 2,500/month: ~357 pipeline runs per month
- With Execute Sub-Workflow: 1 execution per pipeline run = 2,500 pipeline runs per month

**Recommendation:** Use Execute Sub-Workflow (Wait=true) by default. Only switch to HTTP-triggered if the 5-minute timeout is actually hit during testing. This preserves the execution budget.

**Timeout concern:** Individual pipeline steps (ICP analysis: ~30s, themes: ~45s, content: ~2-3min, images: ~1-2min, videos: ~2-3min, calendar: ~30s) could total 7-10 minutes. This EXCEEDS the 5-minute Starter plan timeout.

**Mitigation strategy (if timeout hit):**
1. Split orchestrator into 2 chained orchestrators:
   - Orchestrator A: ICP + Themes + Content (~3-4 min) -> triggers Orchestrator B via webhook
   - Orchestrator B: Images + Videos + Calendar (~3-5 min)
2. Each gets its own 5-minute budget
3. Both update the same pipeline_runs row
4. Costs 2 executions per pipeline run instead of 1

## Supabase Realtime Limits Assessment

**Current plan: Free tier**

| Metric | Free Tier Limit | Phase 4 Usage | Status |
|--------|----------------|---------------|--------|
| Concurrent connections | 200 | 1 per active user viewing progress | Well within limits |
| Messages/month | 2 million | ~12 messages per pipeline run (6 step starts + 6 completions) | Well within limits |
| Channels per connection | 100 | 1 per pipeline run | Well within limits |
| Postgres change payload | 1,024 KB | pipeline_runs row is ~500 bytes | Well within limits |

**Conclusion:** Supabase Free tier is more than adequate for this use case. No upgrade needed for Phase 4.

## Open Questions

1. **Exact n8n Cloud Starter execution timeout**
   - What we know: Community reports indicate 5 minutes; older docs said 3 minutes; values have changed over time
   - What's unclear: Whether the current exact limit is 5 minutes or has been updated
   - Recommendation: Test empirically with the orchestrator workflow. If it times out, implement the split-orchestrator pattern described above. Flag as HIGH priority to verify during implementation.

2. **Execute Sub-Workflow execution counting**
   - What we know: Multiple sources state sub-workflows called via Execute Sub-Workflow run within the parent execution and do not count as separate executions
   - What's unclear: Whether this is still true on the current n8n Cloud version
   - Recommendation: Verify by checking execution logs after a test run. If they DO count separately, budget accordingly.

3. **Respond to Webhook downstream continuation on n8n Cloud**
   - What we know: Official docs confirm the Respond to Webhook node has an output branch, and downstream nodes execute after the response is sent. One community report contradicts this (nodes not executing), but that appears to be a configuration issue, not a fundamental limitation.
   - What's unclear: Whether n8n Cloud has any different behavior from self-hosted for this pattern
   - Recommendation: Test with a minimal workflow: Webhook -> Code (log "before") -> Respond to Webhook -> Code (log "after"). If "after" is logged, the pattern works. If not, fall back to the "Respond Immediately" mode on the Webhook node itself.

4. **Supabase Realtime with RLS and anon key**
   - What we know: RLS policies are enforced for Realtime postgres_changes. The frontend uses the anon/publishable key. The user must be authenticated.
   - What's unclear: Whether the existing RLS policy `(select auth.uid()) = user_id` works correctly with Realtime subscriptions (SELECT policy is what matters for Realtime)
   - Recommendation: Test by subscribing before triggering a pipeline. The existing SELECT policy should work since Realtime checks SELECT access.

## Sources

### Primary (HIGH confidence)
- Supabase Postgres Changes docs: https://supabase.com/docs/guides/realtime/postgres-changes
- Supabase Realtime Limits: https://supabase.com/docs/guides/realtime/limits
- Supabase Realtime Pricing: https://supabase.com/docs/guides/realtime/pricing
- n8n Respond to Webhook docs: https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.respondtowebhook/
- n8n Webhook node docs: https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.webhook/
- n8n Execute Sub-workflow docs: https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.executeworkflow/
- Existing codebase analysis: workflow JSON, schema SQL, index.html

### Secondary (MEDIUM confidence)
- n8n Cloud Starter timeout (~5 min): https://community.n8n.io/t/clarification-on-execution-time-limits-for-starter-plan-after-trial/146159
- n8n Cloud timeout history: https://community.n8n.io/t/what-is-the-maximum-timeout-for-cloud-3-minutes-or-unlimited/25115
- n8n async parallel processing pattern: https://n8nplaybook.com/post/2025/09/asynchronous-n8n-workflows-parallel-processing-poc/
- Execute Sub-Workflow Wait=false bug: https://community.n8n.io/t/execute-workflow-wait-for-sub-workflow-false-sub-workflow-aborts/53771

### Tertiary (LOW confidence)
- Exact current Starter plan timeout value (conflicting sources; needs empirical verification)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all tools already in use, just combining in a new pattern
- Architecture (orchestrator pattern): HIGH -- Respond to Webhook continuation verified via official docs
- Architecture (Supabase Realtime): HIGH -- official docs + already enabled in schema
- Pitfalls (timeout): MEDIUM -- exact timeout value uncertain, but mitigation strategy clear
- Pitfalls (execution counting): MEDIUM -- well-documented but needs verification on current Cloud version
- Frontend pattern: HIGH -- standard supabase-js Postgres Changes API

**Research date:** 2026-03-02
**Valid until:** 2026-04-02 (30 days -- stable domain, no fast-moving changes expected)
