# Phase 6: Content Pipeline - Research

**Researched:** 2026-03-03
**Domain:** AI content generation pipeline -- Jina AI scraping, Perplexity research, Claude synthesis, KIE image generation, n8n workflow orchestration
**Confidence:** MEDIUM-HIGH

## Summary

Phase 6 transforms the existing stub workflows (01-ICP-Analyzer, 02-Theme-Generator, 04-Content-Studio, 11-Image-Generator, 12-Video-Script-Builder) into a production-grade content pipeline. The current workflows have basic scaffolding but lack the three-service ICP pipeline (Jina + Perplexity + Claude), product extraction/management, the refined Netflix model (1 show/4 seasons/product-per-day), weekly batch generation, platform-selective posting, shared daily hero images, and detailed video scripts with trending audio.

The biggest technical constraint is the **n8n Cloud Starter plan's 5-minute execution timeout**. The orchestrator (workflow 14) currently chains all sub-workflows sequentially in a single execution. With Jina scraping + 2-3 Perplexity calls + Claude synthesis + theme generation + batch content generation (7 days x N platforms) + 7 image generations + 3-4 video scripts per week, a single execution will far exceed 5 minutes. The orchestrator must be restructured to use **webhook callbacks** between stages rather than synchronous HTTP calls, allowing each sub-workflow to complete independently within the timeout window.

Secondary concerns include n8n Cloud's 2,500 monthly execution limit (each sub-workflow call and each image poll counts as an execution), KIE API async polling (10s initial wait + 5s retries already implemented in workflow 11), and Claude JSON response parsing robustness.

**Primary recommendation:** Restructure the pipeline into isolated webhook-callback stages that each complete within 5 minutes. Generate content in weekly batches (7 days at a time). Use Jina Reader API via HTTP Request node for product scraping. Add a `products` table to Supabase. Modify orchestrator to fire-and-forget sub-workflows with callback URLs rather than awaiting responses.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **ICP analysis stack:** Three-service pipeline -- Jina AI (site scraping) -> Perplexity (market research, 2-3 calls) -> Claude (synthesis into ICP with demographics, pain points, content pillars, hashtags)
- **Product management:** Scraped products stored in new `products` table; products dropdown card on Setup tab; user can edit product list; products rotate across the month; new month = fresh scrape
- **ICP lifecycle:** 1 ICP per month with 1 optional re-run; new month = fresh ICP + fresh product scrape
- **Netflix model:** 1 show/month (AI-generated name), 4 seasons/weeks (inspirational themes), progressive arc (intro/deepen/challenge/celebrate), 1 product + 1 inspirational topic per day, weekly hooks only
- **Content generation:** Weekly batches (7 days at a time); user selects platforms (LinkedIn, Instagram, X, YouTube); heavily platform-adapted tone; product-linked CTA on every post
- **Image generation:** 1 hero image per day shared across platforms (~30/month); product + lifestyle blend style; via KIE Nano Banana Pro with Claude-generated prompts
- **Video scripts:** 3-4 per week (not every day); same video for Instagram + YouTube; max 30 seconds; very detailed and professional; include actual product image/URL; include 2 trending audio recommendations via Perplexity

### Claude's Discretion
- Which days of the week get video scripts (3 or 4 per week)
- Exact progressive arc narrative for each month's 4 seasons
- How to cluster/order products across the month for maximum theme coherence
- Image prompt style and composition details
- Video script structure and shot-by-shot breakdown format
- How to handle products with missing data (no price, no image, etc.)

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| PIPE-01 | ICP analysis via Perplexity market research + Claude synthesis, stored in Supabase per-tenant | Jina Reader API for scraping -> Perplexity sonar-pro for research -> Claude for synthesis. Existing workflow 01 needs Jina prepended and Perplexity expanded to 2-3 calls. Products table migration needed. |
| PIPE-02 | 30-day Netflix-model theme generation with 4 weekly themed "shows" per month | Existing workflow 02 has basic Netflix model. Needs product injection, show naming, progressive arc, and product-per-day assignment. Theme structure remains 4 rows in `themes` table with JSONB `content_types`. |
| PIPE-03 | Daily content generation producing platform-specific posts for LinkedIn, Instagram, X, YouTube | Workflow 04 needs refactoring for weekly batch mode (7 days x N platforms). Each post needs product context, platform-adapted tone, and CTA. Must stay within 5-min timeout per batch call. |
| PIPE-04 | AI image prompt generation for each post via Claude | Claude generates 1 hero image prompt per day (product + lifestyle blend). Prompt stored in `content_items.image_prompt`. KIE Nano Banana Pro generates the image; URL stored in `content_items.image_url`. |
| PIPE-05 | Video script generation (hook/setup/value/CTA structure) via Claude | Workflow 12 has basic scaffolding. Needs detailed professional format, product context, and Perplexity trending audio lookup. 3-4 scripts per week, stored in `content_items.content` as JSONB. |
| PIPE-06 | One post per platform per day (4 platforms = 4 posts/day max) | Content generation loop: for each day in week, for each selected platform, generate 1 post. Max 4 posts/day x 7 days = 28 content_items per week batch. |
</phase_requirements>

## Standard Stack

### Core (Already in Project)
| Library/Service | Version | Purpose | Status |
|----------------|---------|---------|--------|
| n8n Cloud | Starter plan | Workflow orchestration | Active -- 5-min timeout, 2.5k executions/month, 5 concurrent |
| Supabase | PostgreSQL + Realtime | Database, auth, RLS, progress tracking | Active -- 10 tables, RLS enabled |
| Claude API | claude-sonnet-4-20250514 | ICP synthesis, content writing, image prompts, video scripts | Active -- credential `cZwkXj4ZfHTkpBtT` |
| Perplexity API | sonar-pro | Market research, trending audio | Active -- credential `3rYRY1C2K9o0DDXI` |
| KIE AI | Nano Banana Pro | Image generation | Active -- credential `KIE_AI_API_CREDENTIAL` |

### New for Phase 6
| Service | Integration | Purpose | How to Use |
|---------|------------|---------|------------|
| Jina AI Reader | HTTP Request node (`https://r.jina.ai/{url}`) | Website scraping + product extraction | GET request, returns markdown. No native n8n node needed -- simpler via HTTP Request. Free tier: 20 RPM without key. |

### Not Adding
| Instead of | Why Not | What Instead |
|------------|---------|--------------|
| n8n Jina AI native node | Jina Reader is simpler as a plain HTTP GET to `r.jina.ai/` -- no credential setup, no node configuration complexity | HTTP Request node with URL `https://r.jina.ai/{business_url}` |
| Firecrawl / Apify | Additional service dependency; Jina Reader handles the scraping need with zero cost | Jina Reader API |
| n8n Execute Sub-Workflow (sync) | Already in use for Auth Validator but sync pattern blocks orchestrator | HTTP Request with webhook callback pattern for pipeline stages |

## Architecture Patterns

### Orchestrator Restructure: Webhook Callback Pattern

**CRITICAL: The current orchestrator (workflow 14) chains 6 sub-workflows synchronously. Each HTTP call waits for the sub-workflow to complete before proceeding. This WILL exceed the 5-minute Starter plan timeout.**

**Current pattern (BROKEN for real workloads):**
```
Orchestrator: Webhook -> Auth -> INSERT run -> Respond 202
  -> Update Step 1 -> Call 01 (WAIT 60-120s) -> Update Step 2 -> Call 02 (WAIT 120-180s)
  -> Update Step 3 -> Call 04 (WAIT 300s) -> ... -> Mark Complete
  TOTAL: 10-20+ minutes = TIMEOUT
```

**New pattern (each stage independent, within 5 min):**
```
Orchestrator: Webhook -> Auth -> INSERT run -> Respond 202
  -> Update Step 1 -> Fire 01-ICP (fire-and-forget via HTTP, neverError)
  EXECUTION ENDS (< 30 seconds)

01-ICP-Analyzer: completes scraping + research + synthesis (< 5 min)
  -> UPSERT ICP -> UPSERT products
  -> HTTP POST to orchestrator callback webhook with {pipeline_run_id, step: 1, status: 'complete'}

Orchestrator Callback: receives step 1 complete
  -> Update Step 2 -> Fire 02-Theme-Generator
  EXECUTION ENDS (< 30 seconds)

02-Theme-Generator: completes (< 5 min)
  -> INSERT themes
  -> HTTP POST callback with {pipeline_run_id, step: 2, status: 'complete'}

...and so on for each stage
```

**Implementation: Orchestrator gets a NEW "callback" webhook** (e.g., `eluxr-pipeline-callback`) that receives step completions and fires the next stage. Each sub-workflow receives `pipeline_run_id` and `callback_url` in its payload.

### Weekly Batch Content Generation

Content generation processes 1 week (7 days) at a time rather than 30 days at once:

```
Week 1 batch:
  For each day (1-7):
    For each selected platform:
      -> Claude: generate platform-specific post with product + theme context
      -> Claude: generate hero image prompt (1 per day, shared across platforms)
    If video day (3-4 per week):
      -> Perplexity: research trending audio for Instagram/YouTube
      -> Claude: generate detailed video script with audio recommendations
  -> Batch INSERT all content_items for week 1
  -> KIE: generate 7 hero images (sequential, ~10-15s each with polling)
  -> Update image_urls on content_items

Total per week: ~20-30 Claude calls + 7 KIE calls + 1 Perplexity call
```

**Each weekly batch should be its own sub-workflow execution** to stay within the 5-minute timeout. Within each batch, Claude calls can be done in a Loop Over Items pattern.

### Execution Budget Analysis

With 2,500 executions/month on Starter plan:

| Operation | Executions per Campaign |
|-----------|------------------------|
| Orchestrator trigger | 1 |
| Orchestrator callbacks (6 stages) | 6 |
| 01-ICP-Analyzer | 1 |
| 02-Theme-Generator | 1 |
| 04-Content-Studio (4 weekly batches) | 4 |
| 11-Image-Generator (30 images, but each poll loop is 1 execution) | 30 |
| 12-Video-Script-Builder (12-16 scripts) | 1 per week = 4 |
| **Subtotal per campaign** | **~47** |

Image generation polling is the biggest concern. Each KIE image poll loop (create + poll retries) happens within a single workflow execution using Wait nodes (already implemented), so it counts as 1 execution per image. 30 images = 30 executions for images alone.

**However**, if images are generated in batch within the content studio weekly execution (7 images per week batch = 7 KIE calls within 1 execution using Loop Over Items + Wait), the count drops dramatically. This is the recommended approach.

### Supabase Schema Changes

**New table: `products`**
```sql
CREATE TABLE public.products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  price TEXT,
  features JSONB,
  image_url TEXT,
  category TEXT,
  source_url TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own products" ON public.products
  FOR SELECT USING ((select auth.uid()) = user_id);
CREATE POLICY "Users can insert own products" ON public.products
  FOR INSERT WITH CHECK ((select auth.uid()) = user_id);
CREATE POLICY "Users can update own products" ON public.products
  FOR UPDATE USING ((select auth.uid()) = user_id);
CREATE POLICY "Users can delete own products" ON public.products
  FOR DELETE USING ((select auth.uid()) = user_id);

-- Indexes
CREATE INDEX idx_products_user_id ON public.products(user_id);
```

**Modifications to existing tables:**

`content_items` -- add new columns:
```sql
ALTER TABLE public.content_items ADD COLUMN product_id UUID REFERENCES public.products(id) ON DELETE SET NULL;
ALTER TABLE public.content_items ADD COLUMN video_script JSONB;
ALTER TABLE public.content_items ADD COLUMN hashtags TEXT[];
ALTER TABLE public.content_items ADD COLUMN first_comment TEXT;
```

`campaigns` -- add show name:
```sql
ALTER TABLE public.campaigns ADD COLUMN show_name TEXT;
```

`themes` -- add season arc info:
```sql
ALTER TABLE public.themes ADD COLUMN season_arc TEXT;
ALTER TABLE public.themes ADD COLUMN inspirational_theme TEXT;
```

`icps` -- add content pillars and detailed fields:
```sql
ALTER TABLE public.icps ADD COLUMN content_pillars JSONB;
ALTER TABLE public.icps ADD COLUMN pain_points JSONB;
ALTER TABLE public.icps ADD COLUMN desires JSONB;
ALTER TABLE public.icps ADD COLUMN objections JSONB;
ALTER TABLE public.icps ADD COLUMN buying_triggers JSONB;
```

### Recommended Project Structure (Workflow Files)

```
workflows/
  01-icp-analyzer.json        # MAJOR UPDATE: Add Jina scraping, expand Perplexity to 2-3 calls, product extraction
  02-theme-generator.json     # MAJOR UPDATE: Netflix model with show naming, product assignment, progressive arc
  04-content-studio.json      # MAJOR UPDATE: Weekly batch mode, multi-platform, product context, image prompts
  11-image-generator.json     # MINOR UPDATE: Accept product+lifestyle prompts, keep existing poll loop
  12-video-script-builder.json # MAJOR UPDATE: Detailed scripts, product context, Perplexity trending audio
  14-pipeline-orchestrator.json # RESTRUCTURE: Webhook callback pattern instead of synchronous chain
supabase/
  migrations/
    20260228044505_create_initial_schema.sql  # Existing
    20260303_add_products_and_pipeline_columns.sql  # NEW: products table + column additions
```

### Data Flow Architecture

```
User submits form (business_url, industry, month, platforms)
  |
  v
14-Orchestrator: INSERT pipeline_run -> Respond 202 -> Fire 01-ICP
  |
  v
01-ICP-Analyzer:
  Jina Reader: GET r.jina.ai/{url} -> markdown of site
  |-> Claude: Extract products from markdown -> INSERT products table
  |-> Perplexity #1: Industry landscape + competitors
  |-> Perplexity #2: Audience pain points + desires
  |-> (Optional) Perplexity #3: Content gaps + opportunities
  |-> Claude: Synthesize ICP from all research
  |-> UPSERT icps table
  |-> Callback to orchestrator (step 1 complete)
  |
  v
02-Theme-Generator:
  Read ICP + products from Supabase
  |-> Claude: Generate show name, 4 season themes, progressive arc
  |-> Claude: Assign products to days, generate daily topics
  |-> UPSERT campaign (with show_name) + INSERT 4 theme rows
  |-> Callback (step 2 complete)
  |
  v
04-Content-Studio (called 4x, once per week):
  Read themes week N + products + ICP from Supabase
  |-> Loop 7 days:
  |    |-> For each selected platform:
  |    |    |-> Claude: Write platform-specific post with product CTA
  |    |-> Claude: Generate hero image prompt for the day
  |    |-> If video day:
  |    |    |-> Perplexity: Research trending audio
  |    |    |-> Claude: Generate detailed video script
  |-> Batch INSERT content_items
  |-> Loop 7 images:
  |    |-> KIE: createTask -> poll -> get URL
  |    |-> PATCH content_items with image_url
  |-> Callback (step 3/4/5/6 complete per week)
```

### Anti-Patterns to Avoid

- **Single-execution full pipeline:** NEVER run all 6 stages in one n8n execution. Each stage must be isolated to stay within 5-minute timeout.
- **Synchronous HTTP Request waits in orchestrator:** NEVER use `await` pattern (current implementation) where orchestrator waits for sub-workflow response. Use fire-and-forget + callback.
- **Generating all 30 days at once:** Creates massive Claude prompts and risks token limits. Generate in weekly batches of 7 days.
- **Individual content_item INSERTs:** Batch all content_items for a week into a single POST request (PostgREST accepts JSON arrays).
- **Polling KIE from orchestrator:** Image polling (Wait + retry loop) must happen inside the sub-workflow (11-Image-Generator or within 04-Content-Studio), not in orchestrator.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Website scraping | Custom puppeteer/cheerio scraper | Jina Reader API (`r.jina.ai/`) | Handles JS rendering, anti-bot, outputs clean markdown. Free tier sufficient. |
| Product extraction from HTML | Regex/DOM parsing | Claude with structured JSON instructions | Claude can identify products from any site format -- e-commerce, SaaS, services. More flexible than rule-based extraction. |
| Market research | Manual competitor analysis | Perplexity sonar-pro | Real-time web search with citations. Handles industry-specific research automatically. |
| Image generation | Stable Diffusion / DALL-E integration | KIE Nano Banana Pro (already integrated) | Already has credential, polling loop, and working n8n workflow. Just update prompts. |
| JSON response parsing | Simple JSON.parse | Robust parser with markdown stripping + regex JSON extraction | Claude sometimes wraps JSON in markdown code fences. Existing `Parse ICP Response` pattern in workflow 01 handles this -- reuse everywhere. |
| Async pipeline orchestration | Custom queue system | n8n webhook callback pattern | n8n's Wait node + webhook resume is designed for this. No external queue needed. |

**Key insight:** The existing workflows already have the skeleton of every service integration (Claude, Perplexity, KIE). Phase 6 is about enriching prompts, restructuring the orchestrator for timeout safety, and adding the Jina + products layer.

## Common Pitfalls

### Pitfall 1: n8n Cloud 5-Minute Execution Timeout (CRIT-5)
**What goes wrong:** Pipeline orchestrator times out mid-execution, leaving pipeline_run in "running" state forever.
**Why it happens:** Starter plan enforces 5-minute max execution time. ICP analysis alone (Jina + 2-3 Perplexity + Claude) can take 2-3 minutes. Adding themes + content + images = 15+ minutes total.
**How to avoid:** Restructure orchestrator to use webhook callback pattern. Each stage fires the next via a callback webhook. Each individual execution completes in under 5 minutes.
**Warning signs:** Pipeline progress sticks at a step and never advances. `pipeline_runs.status` stays "running" past 15-minute threshold.

### Pitfall 2: Claude JSON Response Parsing Failures (HIGH-4)
**What goes wrong:** Claude returns JSON wrapped in ```json...``` code fences, or with trailing text, or with invalid characters. JSON.parse fails silently and downstream data is empty.
**Why it happens:** Claude's instruction following for "return ONLY valid JSON" is imperfect, especially with large responses (8K+ tokens).
**How to avoid:** Use robust parsing in every Code node:
```javascript
let parsed;
try {
  parsed = JSON.parse(raw);
} catch(e) {
  // Strip markdown fences
  const stripped = raw.replace(/```(?:json)?\s*/g, '').replace(/```\s*$/g, '').trim();
  try {
    parsed = JSON.parse(stripped);
  } catch(e2) {
    // Extract first JSON object/array
    const match = stripped.match(/[\[{][\s\S]*[\]}]/);
    if (match) parsed = JSON.parse(match[0]);
    else throw new Error('Could not parse Claude response as JSON');
  }
}
```
**Warning signs:** Empty ICP fields, themes with null content_types, content_items with raw Claude text instead of structured data.

### Pitfall 3: Perplexity Hallucinated Research (MOD-3)
**What goes wrong:** Perplexity returns plausible-sounding but fabricated competitor names, statistics, or market data.
**Why it happens:** Perplexity's sonar-pro model can hallucinate when information is scarce for niche industries.
**How to avoid:** Use Perplexity's citation feature -- check that response includes `citations` array. Structure prompts to ask for "research with sources" rather than open-ended analysis. Accept that some creative interpolation is acceptable for content marketing (not medical/financial advice).
**Warning signs:** Competitors that don't exist, statistics with no source, industry trends that seem implausible.

### Pitfall 4: Rate Limit Exhaustion (MOD-6)
**What goes wrong:** Claude API rate limits hit during batch content generation (28 posts per week = 28 Claude calls).
**Why it happens:** Tier 1 Claude API has low RPM limits. Rapid-fire Loop Over Items can exceed them.
**How to avoid:** Add 2-3 second Wait nodes between Claude calls in loops. Consider batching multiple posts into a single Claude call (e.g., "generate 4 platform posts for Day 1" in one call vs. 4 separate calls).
**Warning signs:** HTTP 429 responses from Claude API. Content generation stuck mid-batch.

### Pitfall 5: Execution Budget Exhaustion
**What goes wrong:** 2,500 monthly executions consumed by a few pipeline runs, leaving no budget for other workflows.
**Why it happens:** Each webhook call, each KIE poll retry, each sub-workflow invocation counts as an execution.
**How to avoid:** Consolidate operations into fewer, larger executions. Generate images in batch within content studio (7 per execution) rather than 7 separate image generator calls. Track execution count in pipeline_runs metadata.
**Warning signs:** n8n dashboard showing execution count approaching 2,500 early in the month.

### Pitfall 6: Jina Reader Returns Incomplete Product Data
**What goes wrong:** Jina returns clean markdown but doesn't capture all products, especially on JS-heavy e-commerce sites with lazy-loaded content.
**Why it happens:** Jina Reader has limited JS rendering. Single-page app product grids may not fully render.
**How to avoid:** Use Claude to extract products from whatever Jina returns. Accept partial results -- the user can manually add/edit products on the Setup tab. Prompt Claude: "Extract all products/services/offerings you can identify. If information is incomplete, note what's missing."
**Warning signs:** Product list is empty or has only 1-2 items for sites with known larger catalogs.

## Code Examples

### Jina Reader API Call (n8n HTTP Request node)

```javascript
// In n8n Code node: prepare Jina URL
const businessUrl = $json.business_url;
// Jina Reader: prepend r.jina.ai/ to any URL
const jinaUrl = `https://r.jina.ai/${businessUrl}`;

return {
  json: {
    url: jinaUrl,
    business_url: businessUrl,
    user_id: $json.user_id
  }
};

// HTTP Request node config:
// Method: GET
// URL: {{ $json.url }}
// Headers: Accept: application/json (optional, for JSON output instead of markdown)
// Timeout: 30000
```

### Product Extraction via Claude

```javascript
// Code node: prepare Claude prompt for product extraction
const siteContent = $json.body; // Jina Reader output (markdown)
const prompt = `You are a product/service extractor. Analyze this website content and extract ALL products, services, or offerings mentioned.

WEBSITE CONTENT:
${siteContent.substring(0, 12000)}

Return a JSON array of products. Each product should have:
- name: string (product/service name)
- description: string (brief description, max 100 chars)
- price: string or null (if price is visible)
- features: string[] (key features, max 5)
- image_url: string or null (product image URL if found)
- category: string (product category)

If the site is not e-commerce, treat service packages, consulting tiers, software plans, or menu items as "products."

Return ONLY a valid JSON array. No markdown, no explanation.`;

return {
  json: {
    apiBody: JSON.stringify({
      model: 'claude-sonnet-4-20250514',
      max_tokens: 4096,
      messages: [{ role: 'user', content: prompt }]
    }),
    user_id: $json.user_id
  }
};
```

### Batch Content Generation (Single Claude Call for Multiple Platforms)

```javascript
// Generate all platform posts for 1 day in a single Claude call
const prompt = `Generate social media posts for ALL of these platforms for the same content piece.

CONTEXT:
- Show Name: "${showName}"
- Season ${weekNum} Theme: "${seasonTheme}"
- Today's Product: ${productName} - ${productDesc}
- Today's Topic: "${dailyTopic}"
- ICP Summary: "${icpSummary}"
- Day ${dayNum} of 30

PLATFORMS TO GENERATE FOR: ${platforms.join(', ')}

For each platform, follow these rules:
- LinkedIn: 1300-1800 chars, thought leadership tone, line breaks, 3-5 hashtags, product CTA
- Instagram: 150-300 char caption, 20-30 hashtags in first_comment field, emoji, product CTA
- X: 5-7 tweet thread, each under 280 chars, numbered, punchy and conversational, product CTA
- YouTube: Community post format, story-driven, 200-400 chars, product CTA

Return JSON object with platform keys:
{
  "linkedin": { "post_text": "...", "hashtags": [...], "cta": "..." },
  "instagram": { "post_text": "...", "hashtags": [...], "first_comment": "...", "cta": "..." },
  "x": { "thread": ["1/...", "2/...", ...], "cta": "..." },
  "youtube": { "post_text": "...", "hashtags": [...], "cta": "..." }
}

Only include platforms listed above. Product CTA for every post: "Check out ${productName}" or similar.`;
```

### Hero Image Prompt Generation

```javascript
// Claude generates product + lifestyle image prompt
const prompt = `Generate an image prompt for AI image generation (KIE Nano Banana Pro).

Product: ${productName}
Product Description: ${productDesc}
${productImageUrl ? `Product Image Reference: ${productImageUrl}` : ''}
Season Theme: ${seasonTheme}
ICP Target: ${icpSummary.substring(0, 200)}

Create a single image prompt that:
1. Features the product as the HERO in an aspirational lifestyle scene
2. Matches the ${seasonTheme} theme
3. Appeals to the target audience described above
4. Is photorealistic, high quality, no text overlays
5. Works as a social media image across all platforms (1:1 aspect ratio)

Return ONLY the image prompt text, nothing else. Max 500 characters.`;
```

### Video Script Format (Detailed Professional)

```javascript
// Claude generates detailed video script
const scriptPrompt = `Create a professional, production-ready 30-second video script.

Product: ${productName} - ${productDesc}
Product Image/URL: ${productImageUrl || 'N/A'}
Theme: ${dailyTopic}
Target Audience: ${icpSummary.substring(0, 300)}
Trending Audio Options: ${trendingAudio}

Return a JSON object with this EXACT structure:
{
  "title": "Video title",
  "duration": "30 seconds",
  "platforms": ["Instagram Reels", "YouTube Shorts"],
  "trending_audio": [
    { "name": "Song/Sound Name", "artist": "Artist", "platform": "Instagram/YouTube" },
    { "name": "Song/Sound Name", "artist": "Artist", "platform": "Instagram/YouTube" }
  ],
  "sections": {
    "hook": {
      "timing": "0:00-0:03",
      "script": "Exact words to say",
      "camera": "Close-up face, direct eye contact",
      "b_roll": "Product hero shot with lifestyle background",
      "on_screen_text": "Bold text overlay"
    },
    "setup": {
      "timing": "0:03-0:10",
      "script": "...",
      "camera": "...",
      "b_roll": "...",
      "on_screen_text": "..."
    },
    "value": {
      "timing": "0:10-0:25",
      "script": "...",
      "camera": "...",
      "b_roll": "...",
      "on_screen_text": "...",
      "key_points": ["Point 1", "Point 2", "Point 3"]
    },
    "cta": {
      "timing": "0:25-0:30",
      "script": "...",
      "camera": "...",
      "on_screen_text": "...",
      "action": "Link in bio / Follow for more"
    }
  },
  "music_mood": "Upbeat, energetic",
  "thumbnail_idea": "Description of thumbnail",
  "production_notes": "Any special filming instructions"
}`;
```

### Webhook Callback Pattern (Orchestrator Side)

```javascript
// New callback webhook handler in orchestrator
// Receives: { pipeline_run_id, step, status, data }
const callback = $input.item.json;
const runId = callback.body.pipeline_run_id;
const completedStep = callback.body.step;
const nextStep = completedStep + 1;

// Define pipeline stages
const stages = {
  1: { label: 'Creating content themes...', webhook: 'eluxr-phase2-themes' },
  2: { label: 'Generating Week 1 content...', webhook: 'eluxr-phase4-studio' },
  3: { label: 'Generating Week 2 content...', webhook: 'eluxr-phase4-studio' },
  4: { label: 'Generating Week 3 content...', webhook: 'eluxr-phase4-studio' },
  5: { label: 'Generating Week 4 content...', webhook: 'eluxr-phase4-studio' },
  6: { label: 'Complete!', webhook: null }
};

if (nextStep > 6) {
  // Pipeline complete
  return { json: { action: 'mark_complete', pipeline_run_id: runId } };
} else {
  const stage = stages[nextStep];
  return {
    json: {
      action: 'fire_next',
      pipeline_run_id: runId,
      next_step: nextStep,
      step_label: stage.label,
      webhook_url: stage.webhook,
      week_number: nextStep >= 2 && nextStep <= 5 ? nextStep - 1 : null
    }
  };
}
```

### KIE Callback URL Pattern (Alternative to Polling)

```javascript
// Instead of polling, KIE supports callBackUrl
// Create task with callback:
{
  "model": "nano-banana-pro",
  "callBackUrl": "https://flowbound.app.n8n.cloud/webhook/eluxr-image-callback",
  "input": {
    "prompt": "Product lifestyle image...",
    "aspect_ratio": "1:1",
    "resolution": "1K",
    "output_format": "png"
  }
}

// BUT: this requires another webhook endpoint and execution, so polling within
// the content studio execution is more execution-efficient. Keep existing poll pattern.
```

## State of the Art

| Old Approach (Current) | New Approach (Phase 6) | Impact |
|------------------------|------------------------|--------|
| Orchestrator chains all stages synchronously | Webhook callback pattern, each stage isolated | Eliminates 5-min timeout risk |
| Single Perplexity call for ICP | Jina scraping + 2-3 Perplexity calls + Claude synthesis | Much richer ICP with real product data |
| Generic theme structure | Netflix model with show names, seasons, product-per-day | Engaging, cohesive content strategy |
| One post per day (any platform) | Multi-platform daily posts (user-selected) | 4x content volume, platform-optimized |
| Basic video script (topic + platform) | Detailed production-ready script with trending audio | Professional quality, actionable scripts |
| Image prompt = theme description | Product + lifestyle blend prompts via Claude | Higher quality, brand-relevant images |
| No product awareness | Products extracted, stored, rotated across month | Product-linked CTAs, business-relevant content |

## Open Questions

1. **n8n Cloud Starter timeout exact enforcement**
   - What we know: Community reports 5-minute timeout for Starter plan. n8n docs confirm plan-specific timeout limits exist.
   - What's unclear: Whether the 5-minute limit is hard or if there's any grace period. Whether Wait nodes count against execution time (they should not -- Wait pauses execution and resumes as a new execution).
   - Recommendation: Design for strict 5-minute limit. Each individual stage must complete within 5 minutes. Wait nodes in polling loops are safe (they pause and resume as separate executions).

2. **Execution count with Wait node polling**
   - What we know: Each Wait node resume counts as a continuation of the same execution (not a new one) in n8n Cloud.
   - What's unclear: Whether this changed in recent n8n versions. The existing 11-Image-Generator uses Wait nodes for KIE polling.
   - Recommendation: Test with a single image generation to verify execution count behavior before scaling to 30 images.

3. **Jina Reader effectiveness on dynamic sites**
   - What we know: Jina Reader handles basic JS rendering. Works well on static/SSR sites. May miss lazy-loaded content on SPAs.
   - What's unclear: How well it handles modern e-commerce sites (Shopify, WooCommerce, etc.) specifically for product extraction.
   - Recommendation: Test with a few known sites during implementation. Fall back to manual product entry via the products card if Jina output is insufficient.

4. **Claude token limits for batch content generation**
   - What we know: Claude Sonnet has 200K context window and 8K output limit per request.
   - What's unclear: Whether generating 4 platform posts in a single call stays within output limits reliably.
   - Recommendation: Cap at 4 platforms per call. If output is truncated, fall back to 1 call per platform.

5. **Pipeline step count update for weekly batches**
   - What we know: Current orchestrator has 6 steps. Context specifies weekly batches with user review between weeks.
   - What's unclear: Whether the user wants automatic Week 2/3/4 generation or manual trigger per week.
   - Recommendation: Per CONTEXT.md, "User can review each week before next generates." Implement Week 1 as automatic (part of pipeline). Weeks 2-4 require user trigger from frontend. Pipeline completes after Week 1; subsequent weeks are separate pipeline runs.

## Sources

### Primary (HIGH confidence)
- Existing workflow JSON files (01, 02, 04, 11, 12, 14) -- read directly from project
- Supabase migration SQL -- read directly from project
- Frontend `index.html` -- read directly from project
- [KIE API docs](https://docs.kie.ai/market/google/pro-image-to-image) -- createTask endpoint parameters
- [KIE Get Task Details](https://docs.kie.ai/market/common/get-task-detail) -- recordInfo response format and states

### Secondary (MEDIUM confidence)
- [n8n community: Timeout 5 minutes](https://community.n8n.io/t/timeout-after-5-minutes/203547) -- Starter plan 5-min, Pro plan 40-min
- [n8n community: Execution limits](https://community.n8n.io/t/clarification-on-execution-time-limits-for-starter-plan-after-trial/146159) -- Starter plan docs say 5-min max
- [Jina AI Reader API](https://jina.ai/reader/) -- Free 20 RPM, prepend r.jina.ai/ to URLs
- [n8n async processing pattern](https://n8n.io/workflows/2536-pattern-for-parallel-sub-workflow-execution-followed-by-wait-for-all-loop/) -- Webhook callback pattern for long workflows
- [Perplexity API pricing](https://docs.perplexity.ai/docs/getting-started/pricing) -- sonar-pro: $3/1M input, $15/1M output

### Tertiary (LOW confidence)
- n8n Wait node execution counting behavior -- unverified for Cloud Starter; needs testing
- Jina Reader JS rendering capability for specific e-commerce platforms -- limited data

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All services already integrated in project, just need enrichment
- Architecture (orchestrator restructure): MEDIUM-HIGH - Webhook callback pattern is well-documented in n8n community, but Starter plan timeout behavior needs live testing
- Pitfalls: HIGH - Timeout and parsing issues are well-documented and experienced in prior phases
- Jina integration: MEDIUM - Simple API but product extraction quality depends on site structure
- Video scripts with trending audio: MEDIUM - Perplexity trending audio research quality is unknown until tested

**Research date:** 2026-03-03
**Valid until:** 2026-04-03 (30 days -- stable services, no expected breaking changes)
