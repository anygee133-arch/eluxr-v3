# Phase 6: Content Pipeline - Context

**Gathered:** 2026-03-03
**Status:** Ready for planning

<domain>
## Phase Boundary

Wire up the full content generation pipeline: scrape the user's website for products, analyze their ICP using Jina AI + Perplexity + Claude, generate a 30-day Netflix-model campaign (1 show/month, 4 seasons/weeks, 1 product+topic per day), produce platform-specific posts for user-selected platforms, generate shared daily images, create detailed video scripts 3-4 times per week, and store everything per-tenant in Supabase.

</domain>

<decisions>
## Implementation Decisions

### ICP analysis stack
- **Three-service pipeline:** Jina AI (site scraping) → Perplexity (market research) → Claude (synthesis)
- Jina AI has a native n8n node — use it to scrape the business URL and extract products, services, pricing, features, categories, images
- Perplexity does deep research: 2-3 calls covering industry landscape + competitor analysis + audience pain points/desires
- Claude synthesizes both into a professional ICP with: target demographics, pain points, desires, objections, buying triggers, 4-5 content pillars, 15-20 platform-specific hashtags
- Jina should adapt automatically for non-e-commerce sites (services, SaaS, agencies) — treat "products" broadly as offerings/services/packages
- Full product details extracted: name, description, price, images, key features, category

### Product management
- Scraped products stored in a **new `products` table** in Supabase (name, description, price, features, image_url, category, user_id)
- Separate dropdown card on Setup tab for scraped products (distinct from ICP card)
- User can **edit the product list** before generation: rename, remove, add custom products
- All products rotate across the month — if fewer than 30, products repeat; if more than 30, Claude picks top 30 based on ICP relevance
- Same products used for the entire month; new month = fresh scrape + fresh product lineup

### ICP lifecycle
- 1 ICP per month, with 1 optional re-run that goes deeper/more detailed
- Re-run keeps the same products but refreshes topics if necessary
- New month = fresh ICP + fresh product scrape from site
- Clean slate on new month — old content stays in history, new generation starts fresh

### Netflix content model
- **1 show per month** with an AI-generated catchy name (e.g., "The Glow-Up Series", "Build Different")
- **4 seasons per month** (1 per week), each with an overarching inspirational theme
- Theme wraps the products — each week's 7 products are presented through the lens of that week's theme
- **Progressive arc**: Season 1 introduces, Season 2 deepens, Season 3 challenges, Season 4 resolves/celebrates
- **Weekly hooks only** — last post of each week teases the next season. Daily posts stand alone within their week.
- **1 product + 1 inspirational topic per day** — topics appeal to the ICP customer on that day, tied to the actual product

### Content generation
- Generate in **weekly batches** (7 days at a time) — matches the season/week structure. User can review each week before next generates.
- **User selects which platforms** they're active on (LinkedIn, Instagram, X, YouTube) — only generate posts for selected platforms
- **Heavily platform-adapted tone**: LinkedIn = thought leadership + industry insight, Instagram = visual-first + emotional hook, X = punchy + conversational, YouTube = story-driven
- **Product-linked CTA** on every post — ties back to the featured product ("Check out [product]", "Link in bio", "Learn more at [URL]")

### Image generation
- **1 hero image per day, shared across all platforms** — ~30 images/month
- **Product + lifestyle blend** style — image prompts combine the actual product with an aspirational lifestyle scene (product is the hero in context)
- Image generated via KIE Nano Banana Pro using Claude-generated prompts

### Video scripts
- **3-4 video scripts per week** (not every day)
- Same video published for **Instagram and YouTube** — max 30 seconds
- Designed to **draw attention quickly** so potential customer gains interest
- Scripts are **very detailed and professional** — designed so user can hand to a videographer
- Scripts include **actual product image/URL** so a proper video can be made
- Include **2 trending audio recommendations** per script — Perplexity researches currently trending audio on Instagram Reels and YouTube Shorts each week

### Claude's Discretion
- Which days of the week get video scripts (3 or 4 per week)
- Exact progressive arc narrative for each month's 4 seasons
- How to cluster/order products across the month for maximum theme coherence
- Image prompt style and composition details
- Video script structure and shot-by-shot breakdown format
- How to handle products with missing data (no price, no image, etc.)

</decisions>

<specifics>
## Specific Ideas

- "One product per day, one topic per day" — the core content model. Every day pairs a real product from the site with an inspirational topic designed for the ICP
- Products are scraped from the actual site, not manually entered — Jina AI handles extraction
- Netflix model: show (month) → seasons (weeks) → episodes (days). Progressive arc builds anticipation
- Video scripts need to look like "a professional shot them" — production-ready detail level
- Audio recommendations should be currently trending on Instagram/YouTube, not generic genre suggestions
- The whole point is that the AI does the creative work using real products — zero manual content creation

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `authenticatedFetch()`: Wrapper for all n8n webhook calls with JWT auth — use for all pipeline API calls
- `loadICP()` / `renderICPCard()`: ICP display on Setup tab — extend pattern for products dropdown card
- `mapContentItem()`: Normalizes DB rows to frontend format — extend for new content fields
- `showICPSkeleton()`: Skeleton loading pattern — reuse for products card loading
- `escapeHTML()`: DOM-based HTML escaping — use for rendering scraped product data safely

### Established Patterns
- Pipeline Orchestrator (workflow 14): Async execution with Supabase Realtime progress — content generation plugs into this
- Auth Validator sub-workflow: All n8n webhooks protected — new endpoints (Jina scrape, etc.) must follow same pattern
- Content type normalization (text/image/video/carousel): Already in place in workflows 04 and 05
- Config-driven endpoints via `config.js` / `window.ELUXR_CONFIG`
- Weekly batch generation fits the existing `pipeline_runs` progress tracking (add steps for each week)

### Integration Points
- n8n sub-workflows 01 (ICP Analyzer) and 02 (Theme Generator) need major updates for Jina + product-based flow
- Sub-workflow 04 (Content Studio) generates posts — needs product context injection
- Sub-workflow 11 (Image Generator) handles KIE calls — needs product image/lifestyle prompt pattern
- Sub-workflow 12 (Video Script Builder) — needs detailed script format + audio recommendations
- Frontend Setup tab: Add products dropdown card below ICP card
- Supabase schema: New `products` table needed

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 06-content-pipeline*
*Context gathered: 2026-03-03*
