# Feature Landscape: Social Media Content Automation SaaS

**Domain:** AI-powered social media content generation and management platform (multi-tenant SaaS)
**Researched:** 2026-02-27
**Confidence:** MEDIUM (based on training knowledge through May 2025; WebSearch/WebFetch unavailable for real-time verification)

---

## Competitor Landscape

Before categorizing features, here is what the key competitors offer so ELUXR v2 can position itself correctly.

### Buffer (Scheduling + Light AI)
- **Core:** Post scheduling, publishing queue, content calendar
- **AI:** "AI Assistant" for caption generation and repurposing (basic prompt-based)
- **Calendar:** Visual calendar with drag-and-drop
- **Approval:** Available on Team/Agency plans (multi-step approval workflow)
- **Analytics:** Per-post and cross-channel analytics
- **Multi-tenant:** Workspaces with role-based access on Business/Agency plans
- **Pricing:** Free (3 channels) -> Essentials ($6/mo/channel) -> Team ($12/mo/channel) -> Agency (custom)
- **No:** Image/video generation, ICP analysis, trend research, content themes

### Hootsuite (Enterprise Social Management)
- **Core:** Scheduling, social inbox, content calendar, social listening
- **AI:** OwlyWriter AI for caption generation, hashtag suggestions, post ideas
- **Calendar:** Full calendar with approval workflows baked in
- **Approval:** Multi-tier approval chains, compliance review
- **Analytics:** Deep analytics, custom reports, competitive benchmarking
- **Multi-tenant:** Organizations with teams, custom roles, permission sets
- **Pricing:** Professional ($99/mo) -> Team ($249/mo) -> Enterprise (custom)
- **No:** Image/video generation, full content pipeline, ICP analysis

### Later (Visual-First + Creator Focus)
- **Core:** Visual content planning, link-in-bio, scheduling
- **AI:** AI caption writer, best-time-to-post recommendations
- **Calendar:** Visual calendar with media library
- **Approval:** Team workflows on higher tiers
- **Analytics:** Instagram/TikTok analytics focus, influencer analytics
- **Multi-tenant:** Limited - workspace-based on Scale plan
- **Pricing:** Starter ($25/mo) -> Growth ($45/mo) -> Advanced ($80/mo) -> Agency ($200/mo)
- **No:** Full content generation pipeline, video generation, ICP analysis

### Jasper (AI Content Platform)
- **Core:** AI copywriting for all formats (not social-specific)
- **AI:** Full AI content engine, brand voice training, templates
- **Calendar:** No native content calendar
- **Approval:** Workflows through integrations
- **Multi-tenant:** Team workspaces with brand voice isolation
- **Pricing:** Creator ($49/mo) -> Pro ($69/mo) -> Business (custom)
- **No:** Scheduling, publishing, calendar, image gen (basic), video gen, analytics

### Lately.ai (AI Content Repurposing)
- **Core:** Repurpose long-form into social posts using AI
- **AI:** Learns brand voice from existing content, auto-generates posts from blogs/videos
- **Calendar:** Basic content calendar
- **Approval:** Queue-based approval
- **Multi-tenant:** Enterprise multi-brand support
- **Pricing:** Enterprise-focused (custom pricing, $49+ range historically)
- **No:** Image/video generation, ICP analysis, trend research

### ContentStudio (All-in-One Content Marketing)
- **Core:** Discovery, planning, publishing, analytics
- **AI:** AI content generation, repurposing
- **Calendar:** Visual content calendar with team collaboration
- **Approval:** Approval workflows on Team plans
- **Analytics:** Cross-platform analytics
- **Multi-tenant:** Workspaces with client management
- **Pricing:** Starter ($25/mo) -> Pro ($49/mo) -> Agency ($99/mo)
- **Discovery:** Content discovery/curation from trending sources

**Confidence:** MEDIUM -- Feature sets based on training data through May 2025. Pricing and specific feature names may have changed.

---

## Table Stakes

Features users expect from any social media content management SaaS. Missing any of these means users leave for competitors that have them.

| # | Feature | Why Expected | Complexity | ELUXR v1 Status | Notes |
|---|---------|-------------|------------|-----------------|-------|
| T1 | **Multi-platform scheduling & publishing** | Every competitor does this. Users won't manually copy/paste to each platform. | High | Partial (generates content per platform but no auto-publishing) | Requires OAuth integration with each platform API. Table stakes for v2 SaaS. |
| T2 | **Content calendar view** | Visual overview is the #1 interaction pattern for content managers | Medium | YES (calendar with day view, platform dots, status indicators) | Already strong. Needs polish for multi-tenant. |
| T3 | **Approval workflow** (approve/reject/edit) | Teams need gatekeeping before publishing. Single biggest reason teams choose paid tools over spreadsheets. | Medium | YES (approve, reject, edit, regenerate per post + batch approve) | Already solid. Needs multi-role support for v2. |
| T4 | **Multi-platform content adaptation** | Users expect content tailored to LinkedIn vs. Instagram vs. X. Copy-pasting the same post everywhere is amateur hour. | Medium | YES (platform-specific content generation via Claude) | Strong differentiator becoming table stakes. |
| T5 | **AI caption/post generation** | Since 2023, every tool has "AI assist." Users expect at minimum AI-suggested captions. | Low | YES (full AI generation pipeline with Claude) | ELUXR goes far beyond table stakes here. |
| T6 | **User authentication & access control** | SaaS means login, sessions, role-based access. | High | NO (single-user, no auth) | Critical gap for multi-tenant v2. Must add. |
| T7 | **Persistent data storage** (not just Google Sheets) | Users expect their content to persist, be searchable, and survive browser refreshes without localStorage hacks. | High | Partial (Google Sheets as backend + localStorage) | Needs real database for v2 multi-tenant. |
| T8 | **Content preview** (see how post will look on each platform) | Users want WYSIWYG preview before approving. All major competitors offer this. | Medium | Partial (text preview + image preview in modal, but not platform-native mockup) | Should add platform-native preview frames. |
| T9 | **Export capabilities** (CSV, PDF) | Even if they use your tool, users want data portability. | Low | YES (CSV export, Google Calendar sync) | Already covered. |
| T10 | **Mobile-responsive UI** | Content managers review/approve on mobile constantly. | Medium | Partial (responsive CSS exists but not mobile-optimized UX) | Needs dedicated mobile experience for approval workflows. |
| T11 | **Hashtag management** | Expected for Instagram/X content. Users want suggested, saved, and organized hashtags. | Low | YES (hashtags generated and displayed in preview) | Could enhance with hashtag performance tracking. |
| T12 | **Media library** | Users need to upload, organize, and reuse brand assets (logos, photos, templates). | Medium | NO (images generated per-post, no library) | Important gap for SaaS users who have existing brand assets. |
| T13 | **Analytics / performance tracking** | Users need to see what content performs. "Did my strategy work?" | High | NO | Must integrate platform analytics APIs. Can defer to post-MVP but users expect it. |
| T14 | **Billing & subscription management** | SaaS means payment processing, plan tiers, usage metering. | High | NO | Required infrastructure for multi-tenant SaaS. Stripe integration. |

---

## Differentiators

Features that set ELUXR apart from competitors. These are not expected but create competitive advantage. Sorted by strategic value.

| # | Feature | Value Proposition | Complexity | ELUXR v1 Status | Competitor Coverage | Notes |
|---|---------|-------------------|------------|-----------------|--------------------|----|
| D1 | **Netflix-model content calendar** (4 weekly themed "shows") | No competitor does this. Creates narrative coherence across a month instead of random isolated posts. Dramatically improves audience retention. | Medium | YES (theme engine creates 4 weekly shows with hooks, variety, retention psychology) | NONE | **Primary differentiator.** Keep and strengthen. |
| D2 | **Full content generation pipeline** (ICP analysis -> themes -> posts -> images -> videos in one flow) | Competitors do individual pieces. Nobody takes you from "here's my URL" to "here's 30 days of content with images and videos." | Very High | YES (end-to-end pipeline: business URL -> Perplexity ICP -> Claude themes -> Claude posts -> KIE images -> KIE Veo videos -> Google Calendar) | NONE at this level | **Core differentiator.** This is the product. |
| D3 | **AI image generation per post** | Competitors: "upload your own images." ELUXR: "we generate images for every post automatically." | Medium | YES (KIE Nano Banana Pro, ~$0.02/image) | Jasper has basic image gen, no competitor auto-generates per calendar post | Keep. Cost-effective at scale. |
| D4 | **AI video generation** | Competitors: "upload your own videos." ELUXR: "we generate videos from text." | High | YES (KIE Veo3, ~$0.60/video) | NONE offer integrated video generation | Strong differentiator but cost-sensitive. Offer as premium tier feature. |
| D5 | **ICP-driven content strategy** | Content is generated based on actual market research, not generic templates. Perplexity + Claude pipeline analyzes the business first. | Medium | YES (Perplexity market research -> Claude ICP analysis) | Lately.ai learns from existing content, but nobody does upfront ICP research | Unique value prop. |
| D6 | **Weekly trend research with mid-month pivots** | Adapt content calendar based on trending topics. Content stays relevant, not stale. | Medium | Planned for v2 | ContentStudio has content discovery; nobody auto-adjusts calendars based on trends | Strong differentiator if executed well. |
| D7 | **Standalone creative tools** (video script builder, image gen, video gen, content gen) | Users can use individual tools outside the main pipeline. Creates stickiness and daily usage beyond monthly calendar generation. | Low (already built) | YES (4 standalone tools in Phase 2 UI) | Competitors have individual tools but not bundled with full pipeline | Good for engagement metrics and upselling. |
| D8 | **Context-aware AI chatbot per phase** | Each phase has its own AI assistant with phase-specific system prompt. Not generic chat -- it knows the user's content and can take action. | Medium | YES (7 phase-specific system prompts, Claude-powered) | Hootsuite has chatbot for customer support; nobody has phase-aware content assistant | Unique UX pattern. Strengthen for v2. |
| D9 | **Real-time progress tracking during generation** | Users see exactly what the AI is doing: analyzing business (30s) -> creating themes (45s) -> writing posts (2-3min) -> generating images -> videos -> calendar sync | Low | YES (6-step progress UI with animated progress bar and time estimates) | NONE | Great UX. Builds trust during long generation process. |
| D10 | **Brand voice analysis and application** | AI learns the brand voice from the business URL and applies it consistently across all generated content. | Medium | Partial (brand_voice field in form, used in generation prompts) | Jasper has brand voice training; Lately.ai learns from existing content | Enhance: auto-detect voice from website, allow fine-tuning. |
| D11 | **Persistent AI memory across sessions** | Chatbot remembers previous conversations and content decisions. Gets smarter over time. | High | Planned for v2 | NONE in social media tools | Significant differentiator for returning users. |
| D12 | **Content series / episodic content** | The Netflix model naturally supports multi-part series, recurring segments, callbacks. | Medium | Partial (weekly themes create natural series) | NONE | Lean into this. "Episode 3 of your Monday show." |
| D13 | **One-click regeneration with context** | Reject a post and regenerate keeping the same theme, slot, and brand voice. | Low | YES (regenerate button in content preview modal) | Basic regen exists in Jasper; nobody maintains full context during regen | Already good. Preserve this in v2. |

---

## Anti-Features

Features to deliberately NOT build. Common mistakes in this domain that waste time, add complexity, or harm the product.

| # | Anti-Feature | Why Avoid | What to Do Instead |
|---|-------------|-----------|-------------------|
| A1 | **Built-in social media posting / native API publishing** (for MVP) | OAuth integration with Meta/LinkedIn/X/YouTube/TikTok is a massive engineering effort. Each API has different rules, rate limits, review processes. Meta requires app review. X/LinkedIn have shifting API policies. This alone could take months. | Export to CSV + Google Calendar sync (already working). Add Zapier/Make integration for users who want auto-publish. Add native publishing in a later phase after core SaaS is proven. |
| A2 | **Social inbox / unified messaging** | This is Hootsuite's moat. Requires maintaining persistent API connections, webhook handling for every platform, real-time message sync. Completely different product domain. | Stay focused on content creation and planning. Let users manage their inbox in the native platform apps. |
| A3 | **Competitor analytics / social listening** | Requires scraping or expensive third-party APIs. Complex data pipeline. Not aligned with the content generation value prop. | Partner or integrate with existing analytics tools (Sprout Social, Brandwatch) if needed. |
| A4 | **Built-in CRM / contact management** | Feature creep. Hootsuite and Sprout Social do this. It's a different product. | Integrate with existing CRMs via Zapier/Make or direct integrations (HubSpot, Salesforce). |
| A5 | **Stock photo library / Unsplash integration** | ELUXR generates custom AI images. Adding stock photos undermines the value proposition and adds licensing complexity. | Keep AI image generation as the primary visual strategy. Allow users to upload their own images to the media library. |
| A6 | **Complex team hierarchy / enterprise RBAC** (for MVP) | Over-engineering permissions before you have enterprise customers. | Start with simple roles: Owner, Manager (can approve), Creator (can generate, cannot approve), Viewer. Add complex RBAC when enterprise demand materializes. |
| A7 | **White-label / agency branding** (for MVP) | Tempting for "agency plan" but adds massive complexity: custom domains, email templates, branded UI per client, SSO. | Offer multi-brand workspaces first. White-label is a Phase 3+ feature after product-market fit. |
| A8 | **Real-time collaborative editing** (Google Docs-style) | Massively complex (CRDT/OT algorithms, WebSocket infrastructure). Social media posts are short; collaborative editing adds little value vs. the approval workflow. | Keep the approve/reject/edit cycle. One person edits at a time. Show who's currently viewing. |
| A9 | **Automated A/B testing of posts** | Requires publishing the same post in variants, measuring performance, and statistical analysis. Way too complex for MVP and requires native publishing (see A1). | Provide content variant suggestions ("Here are 3 hook options for this post"). Let users pick. Actual A/B testing is post-product-market-fit. |
| A10 | **In-app design editor** (Canva competitor) | Building a design tool is a product in itself. ELUXR's value is AI generation, not manual design. | AI-generated images + option to upload custom images. Link out to Canva/Figma for users who want to design manually. |

---

## Feature Dependencies

Understanding what depends on what is critical for phasing.

```
Authentication (T6)
  |
  +--> Multi-tenant data isolation
  |      |
  |      +--> Per-tenant content storage (T7)
  |      |      |
  |      |      +--> Content calendar (T2) [already exists, needs tenant scoping]
  |      |      +--> Approval workflow (T3) [already exists, needs role-based]
  |      |      +--> Media library (T12)
  |      |
  |      +--> Per-tenant AI configuration
  |             |
  |             +--> Brand voice per tenant (D10)
  |             +--> ICP per tenant (D5)
  |             +--> Content themes per tenant (D1)
  |
  +--> Role-based access control
  |      |
  |      +--> Approval workflow roles (manager vs creator)
  |      +--> Workspace management
  |
  +--> Billing & subscriptions (T14)
         |
         +--> Usage metering (API calls, images, videos)
         +--> Plan-based feature gating

Content Generation Pipeline (D2) [already exists]
  |
  +--> ICP analysis (D5) [depends on Perplexity API]
  +--> Theme engine (D1) [depends on Claude API]
  +--> Post generation (T4, T5) [depends on Claude API]
  +--> Image generation (D3) [depends on KIE API]
  +--> Video generation (D4) [depends on KIE Veo API, most expensive]
  |
  +--> Trend research (D6) [new capability, depends on trend data source]
  |      |
  |      +--> Mid-month calendar pivot (adjusts existing calendar)
  |
  +--> AI memory (D11) [depends on persistent storage]

Export & Integration
  |
  +--> CSV export (T9) [already exists]
  +--> Google Calendar sync (T9) [already exists]
  +--> Zapier/Make integration [future, replaces native publishing]
```

### Critical Path for Multi-Tenant SaaS

The minimum viable upgrade path from v1 single-user to v2 multi-tenant:

```
1. Authentication (T6) -- MUST be first. Everything else depends on it.
2. Database migration (T7) -- Google Sheets -> real DB with tenant isolation.
3. Tenant-scoped content pipeline -- Existing pipeline per tenant.
4. Billing (T14) -- Needed before launch, but can be built in parallel.
5. Role-based approval (T3 upgrade) -- Enhances existing feature.
```

---

## MVP Recommendation

### Must Have for Multi-Tenant SaaS Launch

**Priority 1 -- Infrastructure (no user value alone, but everything depends on it):**
1. User authentication (email/password + OAuth login) -- T6
2. Real database with tenant isolation (PostgreSQL/Supabase) -- T7
3. Billing and subscription management (Stripe) -- T14

**Priority 2 -- Core Differentiators (what users pay for):**
4. Netflix-model content calendar per tenant -- D1 (upgrade from v1)
5. Full content generation pipeline per tenant -- D2 (upgrade from v1)
6. AI image generation per post -- D3 (preserve from v1)
7. Approval workflow with roles -- T3 (upgrade from v1)

**Priority 3 -- Expected Features (table stakes gaps to fill):**
8. Media library (upload and organize brand assets) -- T12
9. Content preview with platform mockups -- T8

### Defer to Post-MVP

- Native social media publishing (A1) -- use CSV export + Zapier
- Analytics / performance tracking (T13) -- integrate later
- AI video generation (D4) -- offer as premium add-on, too expensive for base tier
- Trend research with mid-month pivots (D6) -- build after core is stable
- Persistent AI memory (D11) -- requires significant architecture
- White-label agency features (A7) -- after PMF
- Complex RBAC (A6) -- start with simple roles

---

## Multi-Tenant Content Isolation -- Deep Dive

This is the most architecturally significant upgrade from v1 to v2.

### What Must Be Isolated Per Tenant

| Data Type | Current v1 Storage | v2 Requirement |
|-----------|-------------------|----------------|
| Business profile (URL, industry, ICP) | Form input, not persisted beyond session | Tenant-scoped row in `tenants` table |
| Content themes | Generated per session, in memory/Google Sheets | Tenant-scoped `content_themes` table |
| Generated posts | Google Sheets (single sheet) | Tenant-scoped `posts` table with tenant_id FK |
| Generated images | KIE URLs (no storage) | Stored URLs or blob storage with tenant-scoped paths |
| Generated videos | KIE Veo URLs (no storage) | Same as images -- URL references with tenant scoping |
| Approval status | Google Sheets column | `posts.status` column (pending/approved/rejected) |
| Brand voice | Form field, localStorage | Tenant-scoped `tenant_settings` table |
| Chat history | Not persisted | Tenant-scoped `chat_messages` table (for AI memory) |

### Isolation Strategy

**Row-Level Security (RLS)** is the recommended approach:
- Every content table has a `tenant_id` column
- All queries filter by `tenant_id` from the authenticated session
- Supabase provides built-in RLS policies
- No risk of cross-tenant data leakage if RLS is enforced at the database level

### Key Decision: n8n Workflow Stays or Goes?

The current v1 runs the entire pipeline as an n8n workflow with webhooks. For multi-tenant v2:

| Approach | Pros | Cons |
|----------|------|------|
| **Keep n8n as backend** | Already working, rapid iteration, visual debugging, no code rewrite | n8n is not designed for multi-tenant isolation, harder to scale, webhook-per-tenant gets messy |
| **Move to custom API backend** | Full control over tenant isolation, proper auth middleware, scalable | Complete rewrite of working pipeline, slower iteration |
| **Hybrid: n8n for AI orchestration, custom API for auth/data** | Best of both worlds. Custom API handles auth, tenant isolation, CRUD. n8n handles the AI pipeline (Perplexity -> Claude -> KIE). | Architectural complexity of two systems communicating |

**Recommendation:** Hybrid approach. Build a lightweight API layer (Next.js API routes or Express) for auth, tenant management, and data persistence. Keep n8n for the AI content generation orchestration, triggered by the API layer with tenant context.

---

## AI Content Generation Pipeline -- Feature Comparison

| Capability | ELUXR v1 | Buffer AI | Hootsuite OwlyWriter | Jasper | Lately.ai |
|-----------|---------|-----------|---------------------|--------|-----------|
| Generate captions from prompt | YES | YES | YES | YES | YES |
| Generate from business URL | YES | NO | NO | NO | YES (from existing content) |
| ICP-based content strategy | YES | NO | NO | NO | NO |
| 30-day themed calendar | YES | NO | NO | NO | NO |
| Netflix-model content series | YES | NO | NO | NO | NO |
| Platform-specific adaptation | YES | Limited | Limited | YES | YES |
| Auto image generation | YES | NO | NO | Basic | NO |
| Auto video generation | YES | NO | NO | NO | NO |
| Brand voice learning | Basic | NO | NO | YES (trained) | YES (learned) |
| Real-time progress tracking | YES | N/A | N/A | NO | NO |
| One-click regeneration | YES | NO | NO | YES | NO |
| Phase-aware AI chat | YES | NO | NO | NO | NO |

**ELUXR is significantly ahead on AI content generation.** The gap to maintain is the end-to-end pipeline and the Netflix content model. No competitor comes close.

---

## Approval Workflow -- Best Practices from Competitors

### What the Best Tools Do

1. **Multi-step approval chains** (Hootsuite Enterprise): Creator -> Reviewer -> Approver -> Publisher. Each role sees only their queue.
2. **Deadline-based auto-escalation** (Sprout Social): If not approved within X hours, escalate to next person or auto-approve.
3. **Inline commenting** (Hootsuite, Sprout): Reviewers can comment on specific posts without rejecting. "Change this hashtag" vs. full rejection.
4. **Bulk operations** (all tools): Select multiple posts, approve/reject all at once.
5. **Approval analytics** (enterprise tools): Average approval time, bottleneck identification, posts per reviewer.

### ELUXR v1 Status

Already has: approve, reject, edit, regenerate, batch approve, batch actions bar. This is solid for a v1.

### Recommended v2 Enhancements

| Enhancement | Complexity | Priority |
|-------------|-----------|----------|
| Role-based approval (Creator vs. Manager vs. Owner) | Medium | P1 (needed for multi-tenant) |
| Inline comments on posts | Low | P2 |
| Approval notification (email + in-app) | Medium | P2 |
| Deadline-based reminders | Low | P3 |
| Approval analytics | Medium | P3 |

---

## Content Calendar -- Best Practices

### What Users Expect

1. **Monthly view** with daily content slots (ELUXR v1 has this)
2. **Weekly view** with more detail per day (ELUXR v1 has the weekly schedule component)
3. **Drag-and-drop rescheduling** (competitors all have this; ELUXR v1 does not)
4. **Platform color-coding** (ELUXR v1 has platform dots)
5. **Status indicators** (pending/approved/rejected) (ELUXR v1 has this)
6. **Click to preview** (ELUXR v1 has this via modal)

### Missing from ELUXR v1

| Feature | Complexity | Impact |
|---------|-----------|--------|
| Drag-and-drop rescheduling | Medium | High -- users expect this interaction pattern |
| Day/Week/Month view toggle | Low | Medium -- power users want different views |
| Best-time-to-post indicators | Low | Medium -- leverage AI to suggest optimal posting times |
| Content type filters (show only LinkedIn, only videos, etc.) | Low | Medium -- helpful as calendar fills up |

---

## Trend-Aware Content -- Feasibility

### What ELUXR v2 Plans

Weekly trend research with dynamic mid-month pivots: the system researches trending topics and can adjust the content calendar mid-month to capitalize on trends.

### How Competitors Handle Trends

- **ContentStudio:** Content discovery from trending sources, curated feeds
- **BuzzSumo (now part of Brandwatch):** Trending content analysis, not social-specific
- **Nobody** auto-adjusts an existing content calendar based on trends

### Implementation Approach

| Component | How | Complexity |
|-----------|-----|-----------|
| Trend data source | Perplexity API (already used for ICP research) or Google Trends API | Low |
| Trend analysis | Claude analyzes trends against tenant's ICP and content themes | Medium |
| Calendar adjustment | AI suggests swapping 2-3 posts to trend-aligned topics; user approves | Medium |
| Notification | "Trending in your industry: [topic]. We suggest updating Day 18 and Day 22." | Low |

**Recommendation:** Build as a weekly automated check. Present trend-based suggestions in the approval queue -- never auto-modify the calendar without approval.

---

## Netflix / Series Content Model -- Deep Dive

This is ELUXR's most unique differentiator. Worth protecting and enhancing.

### Current v1 Implementation

- 4 weekly themed "shows" (e.g., "Monday Motivation," "Tuesday Tips," "Wednesday Behind-the-Scenes," "Thursday Thought Leadership")
- Each show has hooks, variety, audience retention psychology
- Content cyclicity -- audiences learn to expect specific content on specific days

### Enhancement Opportunities for v2

| Enhancement | Description | Complexity |
|-------------|-------------|-----------|
| **Season model** | A month is a "season." Allow multi-month narrative arcs. Users subscribe to 3-month content strategies. | Medium |
| **Episode numbering** | "Episode 3 of your Tuesday Tips show" -- creates FOMO and completionism in audiences. | Low |
| **Show analytics** | Which "show" performs best? Data-driven decisions about which shows to keep/retire. | High (requires analytics) |
| **Spin-offs** | When a single post performs exceptionally, AI suggests creating a "spin-off series" around that topic. | Medium |
| **Cross-show callbacks** | Monday's post references something from Tuesday's show. Creates narrative web. | Medium |
| **Audience "previously on"** | Weekly recap posts that reference the week's content. Increases engagement with older posts. | Low |
| **Show templates** | Pre-built show archetypes: "The Founder's Journal," "Client Spotlight," "Industry Hot Take," "How-To Series" | Low |

### Why Nobody Else Does This

- Requires sophisticated AI that understands narrative structure, not just individual posts
- Requires maintaining context across 30 posts simultaneously
- Most competitors focus on individual post optimization, not calendar-level strategy
- The mental model is content marketing, not social media management

**This is ELUXR's moat. Build it deeper.**

---

## Feature Phasing Recommendation for Roadmap

Based on dependencies, competitive positioning, and complexity:

### Phase 1: Multi-Tenant Foundation
- Authentication (T6)
- Database with tenant isolation (T7)
- Tenant-scoped content pipeline (D2 upgrade)
- Basic billing (T14)

### Phase 2: Core Product Enhancement
- Role-based approval workflows (T3 upgrade)
- Netflix model enhancements (D1, D12)
- Media library (T12)
- Drag-and-drop calendar (T2 upgrade)
- Standalone tools per tenant (D7)

### Phase 3: Intelligence Layer
- Trend research and mid-month pivots (D6)
- Persistent AI memory (D11)
- Enhanced brand voice (D10)
- Best-time-to-post recommendations

### Phase 4: Growth & Scale
- Analytics dashboard (T13)
- Zapier/Make integration (replaces A1)
- Agency multi-workspace (partial A7)
- Video generation as premium tier (D4)

---

## Pricing Model Recommendation

Based on competitor analysis:

| Tier | Name | Price Range | Features | Target |
|------|------|-------------|----------|--------|
| Free | Starter | $0/mo | 1 brand, 5 posts/mo AI generation, no images/video, no approval workflow | Trial/hobbyist |
| Basic | Creator | $29-39/mo | 1 brand, 30 posts/mo, AI images included, basic approval, 1 user | Solo creator / small business |
| Pro | Business | $79-99/mo | 3 brands, unlimited posts, AI images + limited video, full approval workflow, 3 users | Growing business / freelance marketer |
| Agency | Agency | $199-299/mo | 10 brands, unlimited everything, priority generation, 10 users, white-label (future) | Marketing agencies |

### Key Pricing Decisions

- **Metered vs. flat:** AI generation has real costs (~$0.02/image, ~$0.60/video, ~$0.01-0.05/post via Claude). Use credit-based metering for videos; flat rate for posts and images within plan limits.
- **Per-brand vs. per-seat:** Charge per brand (tenant), not per seat. This is how Buffer, Later, and ContentStudio price. Users care about how many clients/brands they can manage.
- **Free tier:** Essential for acquisition. Limit to 5 generated posts/month. Enough to see value, not enough to run a business.

---

## Sources and Confidence

| Area | Confidence | Source | Notes |
|------|-----------|--------|-------|
| Competitor features (Buffer, Hootsuite, Later) | MEDIUM | Training data (May 2025) | Core features stable; pricing and minor features may have changed |
| Competitor features (Jasper, Lately.ai, ContentStudio) | MEDIUM | Training data (May 2025) | Same caveat as above |
| ELUXR v1 capabilities | HIGH | Direct code review of `index.html` and n8n workflow JSON | Verified from source code |
| AI generation costs | MEDIUM | ELUXR v1 code comments (~$0.02/image, ~$0.60/video) | Based on KIE API pricing in workflow sticky notes |
| Multi-tenant architecture patterns | HIGH | Well-established patterns (RLS, tenant_id FK) | Domain-stable knowledge |
| Feature categorization (table stakes vs. differentiator) | HIGH | Cross-referenced against 6 competitors | Categorization logic is sound even if individual features shift |
| Pricing recommendations | LOW | Based on competitor pricing as of training data | Pricing changes frequently. Verify before launch. |

### Gaps That Need Verification

- [ ] Current pricing of all 6 competitors (likely changed since May 2025)
- [ ] Buffer/Hootsuite latest AI feature additions (both investing heavily in AI)
- [ ] KIE API current pricing and rate limits
- [ ] Whether any competitor has launched a Netflix-model feature since May 2025
- [ ] Platform API requirements for future native publishing (Meta Business, LinkedIn Marketing API, X API v2)
