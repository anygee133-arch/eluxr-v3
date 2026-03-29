# ELUXR v3 Revision Spec — Implementation Progress

**Source Document**: `ELUXR-v3-Revision-Spec-FINAL (1).docx` (March 28, 2026)
**Branch**: `feature/v3-revision-spec-m1`
**Last Updated**: March 29, 2026
**Status**: Sections 1-7 implemented and tested end-to-end

---

## What Was Done

### Frontend (index.html ~9,300 lines)

**Restructured from 5 steps to 7 sections:**
- Section 1: Business Profile (simplified — URL, Industry, Language, Notes only)
- Section 2: ICP Output (extracted from old Step 1 into own section)
- Section 3: Products (enhanced — Add Product auto-save, Continue button)
- Section 4: Campaign Setup (NEW — Month, Platforms, Campaign Theme, Brand Voice, Doc Upload)
- Section 5: Weekly Topics (WeekNav, partial weeks, per-week generation for weeks 2+)
- Section 6: Content Review (image themes, image gate, inline editing, regeneration popup)
- Section 7: Posting Calendar (only approved posts, Scheduled/Posted/Failed labels)

**Key frontend changes:**
- `step-*` IDs renamed to `section-*` throughout (~72 renames)
- `STEP_ORDER` → `SECTION_ORDER`, `unlockStep` → `unlockSection`, etc.
- 7 progress dots (was 5), reduced size to fit
- Stats bar moved to fixed bottom with clickable navigation
- `.platform-chip` CSS added for Section 4
- `WeekNav` reusable component shared across Sections 5/6/7
- `showConfirmDialog()` glassmorphic promise-based dialog
- `progressiveUnlockFromState()` checks DB state step-by-step on page load
- `autoSaveNewProduct()` saves on blur (no Save button)
- `generateTopicsForWeek()` for per-week topic generation
- `getTopicDayName()` maps actual calendar days (not always Mon-Sun)
- Pipeline progress polling fallback (5s interval) since Supabase Realtime unreliable
- `ensureCampaign()` no longer auto-creates campaigns
- `_contentGeneratingWeek` state preserves loading UI across tab switches
- `_campaignWeeks` cache cleared on new campaign creation
- Content generation reads platforms/month from campaign record (not DOM)
- Re-analyze dialog only on real DB data (not stale JS vars)
- Old running pipelines marked as failed before starting new analysis

### Backend (n8n workflows — v1 active)

**WF14 Pipeline Orchestrator (Tjtmepkq6WnxQFtU):**
- Changed to 1-step pipeline (was 2). Stops after WF01, does NOT trigger WF02
- `jsCode` updated in: Route Next Stage, Create Pipeline Run, Prepare Fire Payload
- Fire 01-ICP-Analyzer node now sends `notes` and `content_language`
- Metadata stores notes + content_language (not brand_voice)

**WF01 ICP Analyzer (Bin0AjccOtr2etgH):**
- 9 nodes updated to propagate `notes` and `content_language` through entire pipeline
- Prepare Synthesize ICP injects notes as "ADDITIONAL CONTEXT FROM THE BUSINESS OWNER"
- Output language instruction added from content_language

**WF02 Theme Generator (hQeqQ0r6Ahop3YOI):**
- Extract Params accepts: campaign_theme, brand_voice_traits, brand_voice_notes, brand_doc_summary
- Prepare Theme Prompt injects brand context before Netflix framework rules
- Auth OK? node fixed (singleValue: true)

**WF15 Generate Topics (qTDGBLtfBqyb1Vm1):**
- Supports variable day counts (not hardcoded 7)
- Extract Params accepts: day_count, start_date, end_date, brand_voice_traits, brand_voice_notes, campaign_theme
- Prepare Claude Prompt dynamically builds N-day framework
- Parse Topics slices to dayCount
- Target audience stringified (was [object Object])

**WF04 Content Studio (TreszUaJqlykCrMi):**
- Prepare Daily Content Loop iterates over actual topics (not hardcoded 7 days)
- Dynamic day count from weekly_topics rows

**Image Generator (Yh5DEtB1lR9lkbzo):**
- Config + Inputs extracts image_theme_prompt and direction_hint
- Image Scene Prompt1 injects both conditionally

### Database (Supabase)

**Migration file**: `supabase/migrations/20260329_revision_spec_m1.sql`

**New tables:**
- `image_themes` (3 seed rows: Product on Model, Hero Shot, Nature)
- `brand_documents` (user uploads with extracted_text + summary_text)
- `platform_connections` (Zernio M2 placeholder)

**Altered tables:**
- `campaigns`: +brand_voice_traits, brand_voice_notes, campaign_theme, is_active, start_date, platforms, content_language
- `content_items`: +image_theme_id, selected_visual, zernio_post_id, expanded status CHECK
- `products`: +sort_order
- `profiles`: +zernio_profile_id
- `weekly_topics`: week_number constraint expanded to 1-6

**RLS policies added:**
- SELECT policies on: icps, products, campaigns, weekly_topics, content_items, pipeline_runs

### CLAUDE.md
- Updated to require Obsidian brain check before any changes
- Brain vault path: configurable per machine

---

## Test Results (Playwright automated — March 29, 2026)

| Feature | Status |
|---------|--------|
| Section 1: Business Profile | PASS |
| Section 2: ICP (notes → 65+ age range) | PASS |
| Section 3: Products (21 scraped) | PASS |
| Section 4: Campaign Setup | PASS |
| Section 5: Topics (5 for partial week Wed-Sun) | PASS |
| Section 5: Correct day names | PASS |
| Section 6: Image generation + theme selector | PASS |
| Section 6: Image-before-approval gate | PASS |
| Section 6: Post approval | PASS |
| Section 6: Regeneration popup | PASS |
| Section 6: Inline text editing (5 contenteditable) | PASS |
| Section 6: Visual content checkboxes | PASS |
| Section 7: Calendar with approved posts | PASS |
| Section 7: WeekNav (5 weeks for April) | PASS |
| Stats bar: Counters + clickable | PASS |
| Sequential section locking | PASS |
| Re-analyze dialog (only on real data) | PASS |
| Week labels (MM/DD format) | PASS |

---

## Known Issues (non-blocking)

1. Calendar fetch error: "Cannot set properties of null (innerHTML)" — cosmetic
2. Supabase Realtime not delivering pipeline_runs events — polling fallback works
3. `profiles` table 406 on page load — cosmetic

---

## What's NOT Done (Remaining for M1)

- [ ] Merge `feature/v3-revision-spec-m1` to `main`
- [ ] Deploy to Vercel
- [ ] Fix calendar innerHTML null error

## What's Deferred to Milestone 2

- Zernio API integration (OAuth, post scheduling, status polling)
- Platform-specific image sizing
- Analytics dashboard
- Multi-month campaign planning

---

## How to Continue Development

```bash
git clone https://github.com/anygee133-arch/eluxr-v3.git
git clone https://github.com/anygee133-arch/eluxr-brain.git
cd eluxr-v3
git checkout feature/v3-revision-spec-m1

# Update CLAUDE.md brain path to your machine's path
# Then:
python3 -m http.server 8888
```

**Obsidian Brain**: `github.com/anygee133-arch/eluxr-brain` (private)
- Clone next to eluxr-v3
- Update path in CLAUDE.md to match your machine
- Open in Obsidian for visual navigation

**n8n workflows**: All changes are live on flowbound.app.n8n.cloud (v1 workflows, tagged "v1-original")

**Supabase**: Migration must be run + RLS policies added (see migration file)
