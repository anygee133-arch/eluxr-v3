# ELUXR v3 -- All AI Prompts Extracted from n8n Workflows

> Generated: 2026-03-25
> Source: n8n Cloud (flowbound.app.n8n.cloud)

This document contains every AI prompt and instruction used across the ELUXR v3 n8n workflow pipeline. Each section identifies the workflow, node, AI model, and the full prompt text.

---

## Table of Contents

1. [04-Content-Studio (TreszUaJqlykCrMi)](#1-04-content-studio)
   - 1.1 [Prepare Daily Content Loop -- megaPrompt Construction](#11-prepare-daily-content-loop)
   - 1.2 [Generate Day Content -- Claude API Call](#12-generate-day-content)
2. [15-Generate-Topics (qTDGBLtfBqyb1Vm1)](#2-15-generate-topics)
   - 2.1 [Prepare Claude Prompt -- Topic Generation](#21-prepare-claude-prompt)
3. [Image Generator (Yh5DEtB1lR9lkbzo)](#3-image-generator)
   - 3.1 [Analyze Product Image1 -- GPT-4o Vision Analysis](#31-analyze-product-image1)
   - 3.2 [Image Scene Prompt1 -- GPT-4.1-mini Prompt Engineer](#32-image-scene-prompt1)
4. [01-ICP-Analyzer (Bin0AjccOtr2etgH)](#4-01-icp-analyzer)
   - 4.1 [Prepare Extract Products -- Claude Product Extraction](#41-prepare-extract-products)
   - 4.2 [Prepare Research 1 -- Perplexity Industry Research](#42-prepare-research-1)
   - 4.3 [Prepare Research 2 -- Perplexity Audience Research](#43-prepare-research-2)
   - 4.4 [Prepare Research 3 -- Perplexity Content Gaps](#44-prepare-research-3)
   - 4.5 [Prepare Synthesize ICP -- Claude ICP Synthesis](#45-prepare-synthesize-icp)
   - 4.6 [Prepare Image Extraction -- Claude Image URL Extraction](#46-prepare-image-extraction)
   - 4.7 [Build Products from Research -- Claude Product Builder](#47-build-products-from-research)
   - 4.8 [Research Products -- Perplexity Product Lookup](#48-research-products)
   - 4.9 [Research Product Images -- Perplexity Image Search](#49-research-product-images)

---

## 1. 04-Content-Studio

**Workflow ID:** `TreszUaJqlykCrMi`
**Workflow Name:** 04-Content-Studio
**Purpose:** Generates 7 days of multi-platform social media content for a given week, following the Viral Storytelling Framework.

### 1.1 Prepare Daily Content Loop

**Node Name:** `Prepare Daily Content Loop`
**Node Type:** `n8n-nodes-base.code` (Code node)
**AI Model:** Claude Sonnet 4 (`claude-sonnet-4-20250514`) -- called downstream in "Generate Day Content" node
**What it does:** Builds a massive prompt (megaPrompt) that instructs Claude to generate 7 days of content across all selected platforms, following a storytelling framework.

#### Full Code (jsCode):

```javascript
const params = $('Extract Params').first().json;
const themeRaw = $('Read Theme').first().json;
const icpRaw = $('Read ICP').first().json;

// Read Products and Read Weekly Topics may return multiple items (one per row)
// Use .all() and deduplicate
const productsAll = $('Read Products').all().map(i => i.json);
const weeklyTopicsAll = $('Read Weekly Topics').all().map(i => i.json);

const themes = Array.isArray(themeRaw) ? themeRaw : [themeRaw];
const theme = themes[0] || {};
const campaign = theme.campaigns || {};
// Prefer campaign_id from Extract Params (sent by frontend) over theme join
const campaign_id = params.campaign_id || campaign.id || theme.campaign_id || null;
const show_name = campaign.show_name || 'Content Series';
const theme_id = theme.id || null;
const theme_name = theme.theme_name || 'Weekly Theme';
const inspirational_theme = theme.inspirational_theme || '';

// Deduplicate weekly topics by id
const seenTopicIds = new Set();
let weeklyTopics = [];
for (const wt of weeklyTopicsAll) {
  // Handle both split items (single object) and array responses
  if (Array.isArray(wt)) {
    for (const t of wt) {
      if (t.id && !seenTopicIds.has(t.id)) { seenTopicIds.add(t.id); weeklyTopics.push(t); }
    }
  } else if (wt && wt.id && !seenTopicIds.has(wt.id)) {
    seenTopicIds.add(wt.id);
    weeklyTopics.push(wt);
  }
}
// Sort by day_number
weeklyTopics.sort((a, b) => (a.day_number || 0) - (b.day_number || 0));

let dailyAssignments = [];
if (weeklyTopics.length > 0) {
  dailyAssignments = weeklyTopics.map(wt => ({ day_number: wt.day_number, topic: wt.topic || 'Engagement', content_angle: wt.content_angle || '', product_id: wt.product_id || null, product_name: wt.product_name || null }));
} else if (theme.content_types && Array.isArray(theme.content_types)) {
  dailyAssignments = theme.content_types;
} else if (typeof theme.content_types === 'string') {
  try { dailyAssignments = JSON.parse(theme.content_types); } catch(e) { dailyAssignments = []; }
}

const icps = Array.isArray(icpRaw) ? icpRaw : [icpRaw];
const icp = icps[0] || {};
const icp_summary = (icp.icp_summary || '').substring(0, 500);

// Deduplicate products by id
const seenProductIds = new Set();
const products = [];
for (const p of productsAll) {
  if (Array.isArray(p)) {
    for (const pp of p) {
      if (pp.id && !seenProductIds.has(pp.id)) { seenProductIds.add(pp.id); products.push(pp); }
    }
  } else if (p && p.id && !seenProductIds.has(p.id)) {
    seenProductIds.add(p.id);
    products.push(p);
  }
}
const productMap = {};
for (const p of products) {
  if (p.id) productMap[p.id] = p;
}

const weekNum = params.week_number;
const platforms = params.platforms;
const month = params.month;

const storyFramework = [
  { day: 1, label: 'Monday', theme: 'Curiosity Hook', goal: 'Stop the scroll with intrigue and visual mystery', concept: 'Introduce the piece through partial reveal, light reflection, or extreme macro details that spark curiosity', angle: 'Focus on mystery rather than immediate explanation', hooks: ['The detail most people never notice...', 'A piece that changes everything.', 'Look closer.'], driver: 'Curiosity increases watch time and replays' },
  { day: 2, label: 'Tuesday', theme: 'Craftsmanship', goal: 'Establish luxury credibility and authority', concept: 'Highlight craftsmanship behind the piece', angle: 'Show the making process or implied craftsmanship story', hooks: ['From raw material to wearable art.', 'Precision in every millimeter.', 'Crafted, not manufactured.'], driver: 'Craftsmanship content triggers fascination and trust' },
  { day: 3, label: 'Wednesday', theme: 'Meaning & Symbolism', goal: 'Build emotional connection', concept: 'Position jewelry as a symbol of moments, relationships, or personal identity', angle: 'Storytelling around meaning rather than product specs', hooks: ['Some pieces mark a moment forever.', 'Jewelry is never just jewelry.', 'Every piece tells a story.'], driver: 'Emotion increases saves and comments' },
  { day: 4, label: 'Thursday', theme: 'Transformation Moment', goal: 'Show the impact when the jewelry is worn', concept: 'The transformation from object to presence', angle: 'Reveal the moment the piece becomes part of identity or style', hooks: ['The moment everything changes.', 'From detail to statement.', 'Presence begins here.'], driver: 'Transformation visuals drive shares and engagement' },
  { day: 5, label: 'Friday', theme: 'Hidden Detail / Surprise', goal: 'Encourage shares through discovery', concept: 'Reveal something unexpected about the piece, gemstone, or design', angle: 'Educational but visually captivating facts', hooks: ['Most people never notice this.', 'The secret behind the sparkle.', 'Why this cut catches light differently.'], driver: 'Surprise drives sharing behavior' },
  { day: 6, label: 'Saturday', theme: 'Lifestyle Aspiration', goal: 'Inspire desire and aspiration', concept: 'Place jewelry in aspirational environments', angle: 'Luxury lifestyle storytelling', hooks: ['Luxury is a feeling.', 'Some moments deserve more.', 'Where elegance begins.'], driver: 'Aspirational content fuels desire' },
  { day: 7, label: 'Sunday', theme: 'Legacy & Timelessness', goal: 'Build brand prestige and long-term emotional value', concept: 'Jewelry as heirloom, tradition, and timeless symbol', angle: 'Focus on longevity, legacy, and generational value', hooks: ['Some pieces outlive trends.', 'Designed to last generations.', 'What will your story be?'], driver: 'Legacy messaging strengthens brand authority' }
];

const platformRules = [];
for (const plat of platforms) {
  const p = plat.toLowerCase();
  if (p === 'linkedin') platformRules.push('- LinkedIn: 1300-1800 chars, thought leadership tone, line breaks between paragraphs, 3-5 professional hashtags, product CTA');
  if (p === 'instagram') platformRules.push('- Instagram: 150-300 char caption, 20-30 hashtags in separate first_comment field, emoji allowed, product CTA. Video will be generated from product image.');
  if (p === 'x') platformRules.push('- X: 5-7 tweet thread (each under 280 chars, numbered), punchy and conversational, product CTA in last tweet');
  if (p === 'youtube') platformRules.push('- YouTube: Detailed 30-60 second video script for YouTube Short. Include: title, hook (first 3 sec), 4 scene breakdowns with timing/visual/on_screen_text/narration, music_mood, thumbnail_concept, cta. Video generated from actual product image.');
  if (p === 'facebook') platformRules.push('- Facebook: 300-600 chars, conversational and engaging tone, emoji allowed, 3-5 hashtags, product CTA');
  if (p === 'tiktok') platformRules.push('- TikTok: 30-60 second video script with hook in first 2 sec, trending format, casual tone, 3-5 hashtags, product CTA');
}

const dayDescriptions = [];
const dayMeta = [];
for (let dayIdx = 0; dayIdx < 7; dayIdx++) {
  const dayNumber = dayIdx + 1;
  const framework = storyFramework[dayIdx];
  const assignment = dailyAssignments.find(a => a.day_number === dayNumber) || dailyAssignments[dayIdx] || {};
  const product_id = assignment.product_id || null;
  const product = product_id ? (productMap[product_id] || {}) : {};
  const product_name = assignment.product_name || product.name || 'Featured Product';
  const product_description = product.description || '';
  const product_image_url = product.image_url || null;
  const topic = assignment.topic || framework.theme;
  const content_angle = assignment.content_angle || framework.angle;

  let scheduledDate = '';
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const dayOffset = (weekNum - 1) * 7 + (dayNumber - 1);
  const targetDate = new Date(today);
  targetDate.setDate(today.getDate() + dayOffset);
  const sy = targetDate.getFullYear();
  const sm = String(targetDate.getMonth() + 1).padStart(2, '0');
  const sd = String(targetDate.getDate()).padStart(2, '0');
  scheduledDate = sy + '-' + sm + '-' + sd;

  dayDescriptions.push(
    'Day ' + dayNumber + ' (' + framework.label + ' - ' + framework.theme + '):\n' +
    '  Goal: ' + framework.goal + '\n' +
    '  Concept: ' + framework.concept + '\n' +
    '  Angle: ' + framework.angle + '\n' +
    '  Hooks: "' + framework.hooks.join('", "') + '"\n' +
    '  Driver: ' + framework.driver + '\n' +
    '  Product: ' + product_name + ' -- ' + product_description + '\n' +
    '  Topic: "' + topic + '"\n' +
    '  Angle: "' + content_angle + '"'
  );
  dayMeta.push({ day_number: dayNumber, product_id, product_name, product_description, product_image_url, topic, content_angle, scheduled_date: scheduledDate });
}

const platSchemas = [];
for (const plat of platforms) {
  const p = plat.toLowerCase();
  if (p === 'linkedin') platSchemas.push('"linkedin": { "text": "...", "hashtags": [...], "cta": "..." }');
  if (p === 'instagram') platSchemas.push('"instagram": { "text": "...", "hashtags": [...], "first_comment": "...", "cta": "..." }');
  if (p === 'x') platSchemas.push('"x": { "text": "...", "hashtags": [...], "cta": "..." }');
  if (p === 'youtube') platSchemas.push('"youtube": { "title": "...", "hook": "...", "scenes": [{"timing":"0:00-0:03","visual":"...","on_screen_text":"...","narration":"..."},{"timing":"0:03-0:10","visual":"...","on_screen_text":"...","narration":"..."},{"timing":"0:10-0:25","visual":"...","on_screen_text":"...","narration":"..."},{"timing":"0:25-0:30","visual":"CTA","on_screen_text":"...","narration":"..."}], "music_mood": "...", "thumbnail_concept": "...", "cta": "...", "hashtags": [...] }');
  if (p === 'facebook') platSchemas.push('"facebook": { "text": "...", "hashtags": [...], "cta": "..." }');
  if (p === 'tiktok') platSchemas.push('"tiktok": { "title": "...", "hook": "...", "scenes": [{"timing":"0:00-0:02","visual":"...","on_screen_text":"...","narration":"..."},{"timing":"0:02-0:10","visual":"...","on_screen_text":"...","narration":"..."},{"timing":"0:10-0:25","visual":"...","on_screen_text":"...","narration":"..."},{"timing":"0:25-0:30","visual":"CTA","on_screen_text":"...","narration":"..."}], "music_mood": "...", "cta": "...", "hashtags": [...] }');
}

const megaPrompt = 'You are a luxury brand content strategist. Generate social media content for ALL 7 days following the Viral Storytelling Framework.\n\n' +
'=== STORYTELLING FRAMEWORK ===\n' +
'Weekly rhythm: Curiosity > Craftsmanship > Emotion > Transformation > Surprise > Aspiration > Legacy\n\n' +
'=== CONTEXT ===\n' +
'Show: "' + show_name + '"\n' +
'Season ' + weekNum + ': "' + theme_name + '" -- ' + inspirational_theme + '\n' +
'ICP: ' + icp_summary + '\n' +
'Platforms: ' + platforms.join(', ') + '\n\n' +
'=== VIDEO NOTE ===\n' +
'For Instagram and YouTube, videos will use the ACTUAL PRODUCT IMAGE. Scripts should describe content anchored to real product photos.\n\n' +
'=== 7-DAY PLAN ===\n\n' +
dayDescriptions.join('\n\n') + '\n\n' +
'=== PLATFORM RULES ===\n' +
platformRules.join('\n') + '\n\n' +
'=== OUTPUT FORMAT ===\n' +
'Return JSON: { "days": [ { "day_number": 1, "storytelling_theme": "Curiosity Hook", "posts": { ' + platSchemas.join(', ') + ' }, "image_prompt": "Detailed AI image prompt for this day (max 500 chars)" }, ... (all 7 days) ] }\n' +
'Include ALL platforms for EVERY day. Do not skip any.';

return {
  json: {
    prompt: megaPrompt,
    day_meta: dayMeta,
    user_id: params.user_id,
    campaign_id,
    theme_id,
    show_name,
    theme_name,
    week_number: weekNum,
    platforms,
    pipeline_run_id: params.pipeline_run_id,
    callback_url: params.callback_url,
    step: params.step,
    icp_summary,
    inspirational_theme
  }
};
```

#### Reconstructed megaPrompt (what Claude actually receives):

```
You are a luxury brand content strategist. Generate social media content for ALL 7 days following the Viral Storytelling Framework.

=== STORYTELLING FRAMEWORK ===
Weekly rhythm: Curiosity > Craftsmanship > Emotion > Transformation > Surprise > Aspiration > Legacy

=== CONTEXT ===
Show: "{show_name}"
Season {weekNum}: "{theme_name}" -- {inspirational_theme}
ICP: {icp_summary (max 500 chars)}
Platforms: {platforms joined by comma}

=== VIDEO NOTE ===
For Instagram and YouTube, videos will use the ACTUAL PRODUCT IMAGE. Scripts should describe content anchored to real product photos.

=== 7-DAY PLAN ===

Day 1 (Monday - Curiosity Hook):
  Goal: Stop the scroll with intrigue and visual mystery
  Concept: Introduce the piece through partial reveal, light reflection, or extreme macro details that spark curiosity
  Angle: Focus on mystery rather than immediate explanation
  Hooks: "The detail most people never notice...", "A piece that changes everything.", "Look closer."
  Driver: Curiosity increases watch time and replays
  Product: {product_name} -- {product_description}
  Topic: "{topic}"
  Angle: "{content_angle}"

Day 2 (Tuesday - Craftsmanship):
  Goal: Establish luxury credibility and authority
  Concept: Highlight craftsmanship behind the piece
  Angle: Show the making process or implied craftsmanship story
  Hooks: "From raw material to wearable art.", "Precision in every millimeter.", "Crafted, not manufactured."
  Driver: Craftsmanship content triggers fascination and trust
  Product: {product_name} -- {product_description}
  Topic: "{topic}"
  Angle: "{content_angle}"

Day 3 (Wednesday - Meaning & Symbolism):
  Goal: Build emotional connection
  Concept: Position jewelry as a symbol of moments, relationships, or personal identity
  Angle: Storytelling around meaning rather than product specs
  Hooks: "Some pieces mark a moment forever.", "Jewelry is never just jewelry.", "Every piece tells a story."
  Driver: Emotion increases saves and comments
  Product: {product_name} -- {product_description}
  Topic: "{topic}"
  Angle: "{content_angle}"

Day 4 (Thursday - Transformation Moment):
  Goal: Show the impact when the jewelry is worn
  Concept: The transformation from object to presence
  Angle: Reveal the moment the piece becomes part of identity or style
  Hooks: "The moment everything changes.", "From detail to statement.", "Presence begins here."
  Driver: Transformation visuals drive shares and engagement
  Product: {product_name} -- {product_description}
  Topic: "{topic}"
  Angle: "{content_angle}"

Day 5 (Friday - Hidden Detail / Surprise):
  Goal: Encourage shares through discovery
  Concept: Reveal something unexpected about the piece, gemstone, or design
  Angle: Educational but visually captivating facts
  Hooks: "Most people never notice this.", "The secret behind the sparkle.", "Why this cut catches light differently."
  Driver: Surprise drives sharing behavior
  Product: {product_name} -- {product_description}
  Topic: "{topic}"
  Angle: "{content_angle}"

Day 6 (Saturday - Lifestyle Aspiration):
  Goal: Inspire desire and aspiration
  Concept: Place jewelry in aspirational environments
  Angle: Luxury lifestyle storytelling
  Hooks: "Luxury is a feeling.", "Some moments deserve more.", "Where elegance begins."
  Driver: Aspirational content fuels desire
  Product: {product_name} -- {product_description}
  Topic: "{topic}"
  Angle: "{content_angle}"

Day 7 (Sunday - Legacy & Timelessness):
  Goal: Build brand prestige and long-term emotional value
  Concept: Jewelry as heirloom, tradition, and timeless symbol
  Angle: Focus on longevity, legacy, and generational value
  Hooks: "Some pieces outlive trends.", "Designed to last generations.", "What will your story be?"
  Driver: Legacy messaging strengthens brand authority
  Product: {product_name} -- {product_description}
  Topic: "{topic}"
  Angle: "{content_angle}"

=== PLATFORM RULES ===
- LinkedIn: 1300-1800 chars, thought leadership tone, line breaks between paragraphs, 3-5 professional hashtags, product CTA
- Instagram: 150-300 char caption, 20-30 hashtags in separate first_comment field, emoji allowed, product CTA. Video will be generated from product image.
- X: 5-7 tweet thread (each under 280 chars, numbered), punchy and conversational, product CTA in last tweet
- YouTube: Detailed 30-60 second video script for YouTube Short. Include: title, hook (first 3 sec), 4 scene breakdowns with timing/visual/on_screen_text/narration, music_mood, thumbnail_concept, cta. Video generated from actual product image.
- Facebook: 300-600 chars, conversational and engaging tone, emoji allowed, 3-5 hashtags, product CTA
- TikTok: 30-60 second video script with hook in first 2 sec, trending format, casual tone, 3-5 hashtags, product CTA

=== OUTPUT FORMAT ===
Return JSON: { "days": [ { "day_number": 1, "storytelling_theme": "Curiosity Hook", "posts": { "linkedin": { "text": "...", "hashtags": [...], "cta": "..." }, "instagram": { "text": "...", "hashtags": [...], "first_comment": "...", "cta": "..." }, ... }, "image_prompt": "Detailed AI image prompt for this day (max 500 chars)" }, ... (all 7 days) ] }
Include ALL platforms for EVERY day. Do not skip any.
```

### 1.2 Generate Day Content

**Node Name:** `Generate Day Content`
**Node Type:** `n8n-nodes-base.httpRequest`
**AI Model:** Claude Sonnet 4 (`claude-sonnet-4-20250514`)
**API Endpoint:** `https://api.anthropic.com/v1/messages`
**Authentication:** Predefined Anthropic API credential
**Timeout:** 600,000ms (10 minutes)

The request body is constructed as an n8n expression:

```javascript
={{ JSON.stringify({
  model: 'claude-sonnet-4-20250514',
  max_tokens: 32768,
  messages: [{ role: 'user', content: $json.prompt }]
}) }}
```

Note: `$json.prompt` is the megaPrompt from the "Prepare Daily Content Loop" node above. There is no separate system message -- the entire instruction is in the user message.

---

## 2. 15-Generate-Topics

**Workflow ID:** `qTDGBLtfBqyb1Vm1`
**Workflow Name:** 15-Generate-Topics
**Purpose:** Generates 7 daily social media content topics for a given week, assigning products and storytelling themes.

### 2.1 Prepare Claude Prompt

**Node Name:** `Prepare Claude Prompt`
**Node Type:** `n8n-nodes-base.code` (Code node)
**AI Model:** Claude Sonnet 4 (`claude-sonnet-4-20250514`) -- called downstream in "Claude Generate Topics" node
**API Endpoint:** `https://api.anthropic.com/v1/messages` (via predefined Anthropic credential)
**Max Tokens:** 4096

#### Full Code (jsCode):

```javascript
const params = $('Extract Params').first().json;
const icpRaw = $('Read ICP').first().json;
const productsRaw = $('Read Products').first().json;

// Parse ICP
let icp = {};
try {
  icp = Array.isArray(icpRaw) ? icpRaw[0] || {} : icpRaw || {};
} catch(e) { icp = {}; }

// Use assigned_products from frontend (preserves user's order) or fall back to Supabase
let products = [];
if (params.assigned_products && params.assigned_products.length > 0) {
  products = params.assigned_products;
} else {
  try {
    products = Array.isArray(productsRaw) ? productsRaw : [];
  } catch(e) { products = []; }
}

// Build product list with explicit day assignment
const productsList = products.map((p, i) => 'Day ' + (i + 1) + ': ' + p.name + ' (' + (p.category || 'General') + ')' + (p.description ? ' -- ' + p.description : '')).join('\n');

const weekNum = params.week_number;
const dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

const body = JSON.stringify({
  model: 'claude-sonnet-4-20250514',
  max_tokens: 4096,
  system: 'You are a luxury brand social media content strategist specializing in the 7-Day Storytelling Framework. Generate daily topics that follow the weekly narrative arc.',
  messages: [{
    role: 'user',
    content: 'Generate 7 daily social media content topics for WEEK ' + weekNum + ' of a monthly campaign.\n\nBUSINESS CONTEXT:\n- Industry: ' + (icp.industry || 'General') + '\n- Target Audience: ' + (icp.target_audience || icp.demographics || 'General audience') + '\n- Brand Voice: ' + (icp.brand_voice || icp.tone || 'Professional and engaging') + '\n- Content Pillars: ' + JSON.stringify(icp.content_pillars || []) + '\n- Pain Points: ' + JSON.stringify(icp.pain_points || []) + '\n\nPRODUCT ASSIGNMENTS (MANDATORY - each day MUST use its assigned product):\n' + productsList + '\n\n7-DAY STORYTELLING FRAMEWORK (MANDATORY - each day MUST follow its assigned theme):\nDay 1 (Monday): CURIOSITY HOOK -- Stop the scroll with intrigue and visual mystery.\nDay 2 (Tuesday): CRAFTSMANSHIP -- Establish luxury credibility and authority.\nDay 3 (Wednesday): MEANING & SYMBOLISM -- Build emotional connection.\nDay 4 (Thursday): TRANSFORMATION MOMENT -- Show the impact when the product is worn/used.\nDay 5 (Friday): HIDDEN DETAIL / SURPRISE -- Encourage shares through discovery.\nDay 6 (Saturday): LIFESTYLE ASPIRATION -- Inspire desire and aspiration.\nDay 7 (Sunday): LEGACY & TIMELESSNESS -- Build brand prestige.\n\nIMPORTANT RULES:\n- Each day MUST use the EXACT product assigned above (Day 1 product for day 1, Day 2 product for day 2, etc.)\n- Do NOT reassign or swap products between days\n- The product_name in your response MUST exactly match the assigned product name\n\n' + (params.storytelling_framework ? 'ADDITIONAL CONTEXT FROM FRONTEND:\n' + params.storytelling_framework + '\n\n' : '') + 'For each of the 7 days provide:\n1. topic: A compelling topic title that reflects the day\'s storytelling theme (max 60 chars)\n2. description: Brief description of the post angle tied to the theme (max 150 chars)\n3. content_angle: Specific approach for this theme\n4. product_name: The EXACT product name assigned to this day (from the list above)\n5. storytelling_theme: The theme name\n\nReturn ONLY a valid JSON array of 7 objects with keys: day_number (1-7), topic, description, content_angle, product_name, storytelling_theme. No markdown.'
  }]
});

return {
  json: {
    apiBody: body,
    user_id: params.user_id,
    campaign_id: params.campaign_id,
    week_number: weekNum,
    products: products
  }
};
```

#### Reconstructed Prompt (what Claude receives):

**System Message:**
```
You are a luxury brand social media content strategist specializing in the 7-Day Storytelling Framework. Generate daily topics that follow the weekly narrative arc.
```

**User Message:**
```
Generate 7 daily social media content topics for WEEK {weekNum} of a monthly campaign.

BUSINESS CONTEXT:
- Industry: {icp.industry}
- Target Audience: {icp.target_audience}
- Brand Voice: {icp.brand_voice}
- Content Pillars: {JSON array of content pillars}
- Pain Points: {JSON array of pain points}

PRODUCT ASSIGNMENTS (MANDATORY - each day MUST use its assigned product):
Day 1: {product_name} ({category}) -- {description}
Day 2: {product_name} ({category}) -- {description}
Day 3: {product_name} ({category}) -- {description}
Day 4: {product_name} ({category}) -- {description}
Day 5: {product_name} ({category}) -- {description}
Day 6: {product_name} ({category}) -- {description}
Day 7: {product_name} ({category}) -- {description}

7-DAY STORYTELLING FRAMEWORK (MANDATORY - each day MUST follow its assigned theme):
Day 1 (Monday): CURIOSITY HOOK -- Stop the scroll with intrigue and visual mystery.
Day 2 (Tuesday): CRAFTSMANSHIP -- Establish luxury credibility and authority.
Day 3 (Wednesday): MEANING & SYMBOLISM -- Build emotional connection.
Day 4 (Thursday): TRANSFORMATION MOMENT -- Show the impact when the product is worn/used.
Day 5 (Friday): HIDDEN DETAIL / SURPRISE -- Encourage shares through discovery.
Day 6 (Saturday): LIFESTYLE ASPIRATION -- Inspire desire and aspiration.
Day 7 (Sunday): LEGACY & TIMELESSNESS -- Build brand prestige.

IMPORTANT RULES:
- Each day MUST use the EXACT product assigned above (Day 1 product for day 1, Day 2 product for day 2, etc.)
- Do NOT reassign or swap products between days
- The product_name in your response MUST exactly match the assigned product name

{optional: ADDITIONAL CONTEXT FROM FRONTEND: ...}

For each of the 7 days provide:
1. topic: A compelling topic title that reflects the day's storytelling theme (max 60 chars)
2. description: Brief description of the post angle tied to the theme (max 150 chars)
3. content_angle: Specific approach for this theme
4. product_name: The EXACT product name assigned to this day (from the list above)
5. storytelling_theme: The theme name

Return ONLY a valid JSON array of 7 objects with keys: day_number (1-7), topic, description, content_angle, product_name, storytelling_theme. No markdown.
```

---

## 3. Image Generator

**Workflow ID:** `Yh5DEtB1lR9lkbzo`
**Workflow Name:** Social Calendar - Image Generator
**Purpose:** Takes a product image URL and content topic, analyzes the product with GPT-4o vision, generates a photorealistic scene prompt with GPT-4.1-mini, then sends it to Kie.ai (Nano Banana Pro) for image generation.

### 3.1 Analyze Product Image1

**Node Name:** `Analyze Product Image1`
**Node Type:** `@n8n/n8n-nodes-langchain.openAi` (OpenAI node with image analysis)
**AI Model:** GPT-4o (`gpt-4o`)
**Operation:** Image Analysis
**Input:** Product image URL from `Config + Inputs` node

#### Full Prompt (text parameter):

```
Analyze the uploaded image and describe it in cinematic, production-ready terms.

Return JSON with these fields:

{
  "main_subject": "primary focus (e.g., man running, perfume bottle, luxury car, smiling woman)",
  "subject_position": "center / left / right / close-up / wide / top-down / etc.",
  "environment": "describe background or setting (e.g., beach at sunset, modern office, urban street, green forest)",
  "lighting": "type and quality of light (e.g., warm golden hour, moody shadows, bright studio light)",
  "color_palette": "dominant tones (e.g., beige and gold, blue and white, neon pink and cyan)",
  "style": "visual or artistic style (e.g., cinematic realism, minimalistic fashion, tech aesthetic, natural documentary)",
  "emotion_tone": "overall mood (e.g., calm, excitement, luxury, mystery, inspiration)",
  "action_or_motion": "visible or implied movement (e.g., walking, wind, pouring, camera pan)",
  "camera_perspective": "type of shot (macro, medium, wide, tracking, overhead, dolly)",
  "potential_genre": "product_commercial / fashion / lifestyle / travel / tech / cinematic / nature / art",
  "potential_vibe": "short creative tone summary (e.g., modern elegance, energetic motion, serene minimalism)",
  "contextual_elements": "secondary visual hints (props, reflections, accessories, surrounding textures, lighting accents)",
  "product_exact_colors": "e.g., matte black with rose gold trim",
  "product_shape_silhouette": "e.g., rectangular box, curved bottle, circular face",
  "product_text_or_logo": "any visible brand name, text, or logo on product",
  "product_material_finish": "e.g., glossy glass, matte leather, brushed metal",
  "product_unique_identifiers": "any distinctive marks, patterns, or design details",
  "stone_orientation_precise": "describe exact cardinal orientation of stone on band -- e.g., heart point facing toward finger base (downward), lobes facing away from finger (upward), heart cleavage centered at 12 o'clock",
  "stone_rotation_lock": "single sentence locking orientation -- e.g., the heart diamond sits with both lobes at the top and the point at the bottom, centered upright at 12 o'clock on the band, NOT rotated sideways"
}

Guidelines:
Keep phrasing professional and descriptive, not poetic.
Always fill all fields (infer if needed).
Return JSON only, no comments or text outside braces.
```

### 3.2 Image Scene Prompt1

**Node Name:** `Image Scene Prompt1`
**Node Type:** `@n8n/n8n-nodes-langchain.agent` (LangChain Agent node)
**AI Model:** GPT-4.1-mini (`gpt-4.1-mini`) -- via connected "OpenAI Chat Model1" sub-node
**Purpose:** Takes the image analysis JSON and content topic, produces a photorealistic editorial image prompt for Kie.ai

#### User Message (text parameter):

```
Product name: {{ $('Config + Inputs').item.json.productName }}
Product category: {{ $('Config + Inputs').item.json.productCategory }}
Product description: {{ $json.imageAnalysis }}

Content topic / creative direction: {{ $('Config + Inputs').item.json.topic }}
```

#### System Message (full):

```
You are a **photorealistic image prompt engineer** for AI image generation.

You receive:
1. A product name and category (e.g., "Rolling Diamonds Bracelet", category: "Bracelets")
2. A detailed product description (from image analysis)
3. A content topic or creative direction from a social media calendar

Your job is to write a SINGLE prompt that will generate a photorealistic editorial photograph showing the product being worn correctly on the appropriate body part.

CRITICAL -- PRODUCT TYPE RULES:
- If the product is a BRACELET or BANGLE: it MUST be shown on a WRIST. Never on ears, neck, or fingers.
- If the product is a NECKLACE, COLLIER, or PENDANT: it MUST be shown on a NECK/CHEST. Never on wrists or ears.
- If the product is an EARRING or OHRSCHMUCK: it MUST be shown on an EAR. Never on wrists or neck.
- If the product is a RING or DAMENRING: it MUST be shown on a FINGER. Never on wrists or ears.
- If the product is a RIVIERE: it MUST be shown as a necklace on the NECK.
- Use the product name and category to determine the correct body placement. The image analysis may misidentify the product type -- ALWAYS trust the product name/category over the image analysis for placement.

CRITICAL -- PHYSICAL FORM & RIGIDITY RULES:
Jewelry has real physical properties. You MUST describe how the piece sits, drapes, or holds its shape based on its construction:

**RIGID / SOLID pieces** (bangles, solid cuffs, tennis bracelets with rigid settings, eternity bands, solid link bracelets):
- Describe as holding a fixed circular or oval shape around the body part
- They do NOT drape, sag, or bend -- they maintain their form
- Use language like: "rigid circular form", "holds its shape firmly", "sits as a solid band"
- Tennis bracelets and eternity pieces with continuous stone settings are SEMI-RIGID -- they curve smoothly around the wrist/neck but do not flop or dangle

**FLEXIBLE / CHAIN pieces** (chain necklaces, pendant necklaces, rope chains, cable chains, link bracelets with loose links, drop earrings):
- Describe as draping naturally with gravity
- They follow the contour of the body and hang where gravity pulls them
- Use language like: "drapes softly", "hangs naturally", "follows the curve of the neck/wrist", "gentle sway"
- Pendant necklaces: the chain drapes, the pendant hangs at the lowest point

**ARTICULATED pieces** (pieces with individually set stones that can move, Rolling Diamonds (R) technology, pave bands):
- Describe stones as catching light from multiple angles due to micro-movement
- The piece itself may be semi-rigid but individual elements shift and sparkle
- Use language like: "each stone independently catches light", "subtle movement within the setting creates dynamic sparkle"

Determine rigidity from:
1. The product name (e.g., "claw bracelet" = semi-rigid, "chain necklace" = flexible, "bangle" = rigid)
2. The product description / image analysis (look for: links, chains, hinges = flexible; solid band, continuous setting = rigid)
3. If uncertain, default to SEMI-RIGID for bracelets and FLEXIBLE for necklaces

RULES:
- Output ONLY the image prompt text. No explanations, no JSON, no formatting -- just the prompt.
- Start with the scene/person description inspired by the content topic.
- EXPLICITLY STATE where on the body the product is worn (e.g., "wearing a diamond bracelet on her left wrist").
- EXPLICITLY DESCRIBE how the piece physically sits -- rigid, draping, or articulated.
- Then describe the product with EXTREME specificity -- every stone, every material, every detail from the product analysis.
- Describe the product as having real material properties: metal reflections, gemstone translucency, light refraction.
- Specify photographic qualities: shallow depth of field, natural lighting, shot on 85mm lens, editorial photography style.
- The image must look like a real photograph -- NOT a 3D render, NOT an illustration.
- Keep the prompt under 500 words.
- Do NOT describe any motion or camera movement -- this is a STILL photograph.
- The product should be the visual focal point but shown naturally on the person.

EXAMPLE OUTPUT (rigid bracelet):
Photorealistic editorial photograph of an elegant woman in a Parisian cafe, warm afternoon light. She wears a diamond tennis bracelet on her left wrist -- a continuous line of round brilliant-cut diamonds set in 18k white gold channel settings, the bracelet holding its smooth semi-rigid circular form snugly around her wrist, each stone approximately 3mm catching warm cafe light with prismatic fire. The bracelet maintains its shape as a solid band with hidden clasp. She rests her hand on a marble table, cream silk blouse sleeve pushed up to reveal the bracelet. Shallow depth of field, background softly blurred. Shot on 85mm f/1.4 lens, natural editorial photography style.

EXAMPLE OUTPUT (flexible necklace):
Photorealistic editorial photograph of a woman at a rooftop dinner, twilight sky behind her. She wears a graduated diamond necklace that drapes softly along her collarbone, the delicate chain following the natural curve of her neck. The pendant hangs at the lowest point of the neckline, swaying slightly with her posture. Each diamond catches the warm ambient candlelight. Shot on 85mm f/1.4 lens, natural editorial photography style.
```

#### Image Generation API Call (downstream):

The output from this node is sent to Kie.ai's Nano Banana Pro model:
- **Model:** `nano-banana-pro`
- **Resolution:** 2K
- **Aspect Ratio:** 4:5
- **Format:** PNG
- **Input:** The generated prompt text + original product image URL as `image_input`

---

## 4. 01-ICP-Analyzer

**Workflow ID:** `Bin0AjccOtr2etgH`
**Workflow Name:** 01-ICP-Analyzer
**Purpose:** Scrapes a business website, extracts products, researches the industry/audience/content landscape, and synthesizes a comprehensive Ideal Customer Profile (ICP).

### 4.1 Prepare Extract Products

**Node Name:** `Prepare Extract Products`
**Node Type:** `n8n-nodes-base.code` (Code node)
**AI Model:** Claude Sonnet 4 (`claude-sonnet-4-20250514`) -- called downstream in "Claude -- Extract Products" node
**Max Tokens:** 16384

#### Full Code (jsCode):

```javascript
const homepageResponse = $('Scrape Website').first().json;
const shopResponse = $('Scrape Shop Page').first().json;
const shopResponse2 = $('Scrape Shop Page 2').first().json;
const shopResponse3 = $('Scrape Shop Page 3').first().json;
const params = $('Prepare Jina URL').first().json;

const homepageContent = homepageResponse.data?.content || '';
const shopContent = shopResponse.data?.content || '';
const shopContent2 = shopResponse2?.data?.content || '';
const shopContent3 = shopResponse3?.data?.content || '';

const combinedContent = 'HOMEPAGE:\n' + homepageContent.substring(0, 10000) +
  '\n\nPRODUCTS PAGE 1:\n' + shopContent.substring(0, 20000) +
  '\n\nPRODUCTS PAGE 2:\n' + shopContent2.substring(0, 20000) +
  '\n\nPRODUCTS PAGE 3:\n' + shopContent3.substring(0, 20000);

const apiBody = JSON.stringify({
  model: 'claude-sonnet-4-20250514',
  max_tokens: 16384,
  system: 'You are a product extractor for luxury brand websites. Extract as many real products as possible from the page content. Products can be found in navigation menus, category links, collection listings, product grids, or any other part of the page.',
  messages: [{
    role: 'user',
    content: 'Extract ALL individual products from this website content. Look everywhere: navigation menus, category links, collection pages, product listings, image alt text, breadcrumbs, and any product references. We need UP TO 30 unique products.\n\n' + combinedContent + '\n\nReturn a JSON array. Each product needs:\n- name: string (specific product name like "Tiffany T Wire Bracelet" or "Rolling Diamonds Eternity Ring", NOT generic categories like "Bracelets")\n- description: string (brief, max 100 chars -- infer from context if needed)\n- price: string or null\n- features: string[] (max 5 -- infer from product name/category)\n- image_url: string or null (only if an actual image URL appears in the content)\n- image_urls: string[] (only real URLs from the content)\n- product_url: string or null (must be a URL that actually appears in the page content, absolute URL starting with https://)\n- category: string (e.g. Rings, Necklaces, Bracelets, Earrings, Watches)\n\nRULES:\n1. Extract specific NAMED products, not generic categories. "Tiffany T Wire Bracelet" is good. "Bracelets" is not.\n2. Look in navigation menus -- collection names like "Tiffany T", "HardWear", "Elsa Peretti" are product lines. Extract individual products from them.\n3. If you see a collection name but no individual products, create entries for the collection\'s likely products (e.g. "Tiffany T Smile Pendant", "Tiffany T Wire Ring").\n4. product_url must be from the actual page content. Do not guess URLs.\n5. Try to reach at least 20 products. Use product names, collection references, and category links to identify as many as possible.\n6. Base domain: {business_url}\n\nReturn ONLY a valid JSON array. No markdown.'
  }]
});

return {
  json: {
    apiBody,
    site_content: combinedContent.substring(0, 3000),
    user_id: params.user_id,
    business_url: params.business_url,
    industry: params.industry,
    month: params.month,
    platforms: params.platforms,
    pipeline_run_id: params.pipeline_run_id,
    callback_url: params.callback_url
  }
};
```

#### Reconstructed Prompt:

**System Message:**
```
You are a product extractor for luxury brand websites. Extract as many real products as possible from the page content. Products can be found in navigation menus, category links, collection listings, product grids, or any other part of the page.
```

**User Message:**
```
Extract ALL individual products from this website content. Look everywhere: navigation menus, category links, collection pages, product listings, image alt text, breadcrumbs, and any product references. We need UP TO 30 unique products.

HOMEPAGE:
{homepageContent up to 10,000 chars}

PRODUCTS PAGE 1:
{shopContent up to 20,000 chars}

PRODUCTS PAGE 2:
{shopContent2 up to 20,000 chars}

PRODUCTS PAGE 3:
{shopContent3 up to 20,000 chars}

Return a JSON array. Each product needs:
- name: string (specific product name like "Tiffany T Wire Bracelet" or "Rolling Diamonds Eternity Ring", NOT generic categories like "Bracelets")
- description: string (brief, max 100 chars -- infer from context if needed)
- price: string or null
- features: string[] (max 5 -- infer from product name/category)
- image_url: string or null (only if an actual image URL appears in the content)
- image_urls: string[] (only real URLs from the content)
- product_url: string or null (must be a URL that actually appears in the page content, absolute URL starting with https://)
- category: string (e.g. Rings, Necklaces, Bracelets, Earrings, Watches)

RULES:
1. Extract specific NAMED products, not generic categories. "Tiffany T Wire Bracelet" is good. "Bracelets" is not.
2. Look in navigation menus -- collection names like "Tiffany T", "HardWear", "Elsa Peretti" are product lines. Extract individual products from them.
3. If you see a collection name but no individual products, create entries for the collection's likely products (e.g. "Tiffany T Smile Pendant", "Tiffany T Wire Ring").
4. product_url must be from the actual page content. Do not guess URLs.
5. Try to reach at least 20 products. Use product names, collection references, and category links to identify as many as possible.
6. Base domain: {business_url}

Return ONLY a valid JSON array. No markdown.
```

### 4.2 Prepare Research 1

**Node Name:** `Prepare Research 1`
**Node Type:** `n8n-nodes-base.code` (Code node)
**AI Model:** Perplexity Sonar Pro (`sonar-pro`)
**Purpose:** Industry landscape and competitor analysis

#### Full Code (jsCode):

```javascript
const data = $('Prepare Save Products').first().json;

const prompt = 'Research the ' + data.industry + ' industry. Provide: 1) Key market trends and growth areas, 2) Top 5-10 competitors for a business like ' + data.business_url + ', 3) Industry-specific content strategies that perform well on social media. Include citations.';

const body = JSON.stringify({
  model: 'sonar-pro',
  messages: [
    {
      role: 'system',
      content: 'You are a market research analyst specializing in social media content strategy. Provide detailed, actionable research with citations.'
    },
    {
      role: 'user',
      content: prompt
    }
  ],
  temperature: 0.3,
  max_tokens: 4000
});

return {
  json: {
    perplexity_body_1: body,
    user_id: data.user_id,
    business_url: data.business_url,
    industry: data.industry,
    month: data.month,
    platforms: data.platforms,
    pipeline_run_id: data.pipeline_run_id,
    callback_url: data.callback_url,
    site_content: data.site_content,
    products: data.products,
    products_count: data.products_count
  }
};
```

#### Reconstructed Prompt:

**System:** `You are a market research analyst specializing in social media content strategy. Provide detailed, actionable research with citations.`

**User:** `Research the {industry} industry. Provide: 1) Key market trends and growth areas, 2) Top 5-10 competitors for a business like {business_url}, 3) Industry-specific content strategies that perform well on social media. Include citations.`

### 4.3 Prepare Research 2

**Node Name:** `Prepare Research 2`
**Node Type:** `n8n-nodes-base.code` (Code node)
**AI Model:** Perplexity Sonar Pro (`sonar-pro`)
**Purpose:** Audience pain points and desires

#### Full Code (jsCode):

```javascript
const research1 = $input.item.json;
const prepData = $('Prepare Research 1').item.json;

let research1Content = '';
try {
  research1Content = research1.choices[0].message.content;
} catch(e) {
  research1Content = JSON.stringify(research1);
}

const prompt = 'Research the target audience for ' + prepData.industry + ' businesses like ' + prepData.business_url + '. Provide: 1) Top pain points and frustrations, 2) Desires and aspirations, 3) Common objections to purchasing, 4) Buying triggers, 5) Where this audience spends time online. Include citations.';

const body = JSON.stringify({
  model: 'sonar-pro',
  messages: [
    {
      role: 'system',
      content: 'You are a consumer psychology researcher specializing in audience analysis for marketing. Provide detailed, actionable insights with citations.'
    },
    {
      role: 'user',
      content: prompt
    }
  ],
  temperature: 0.3,
  max_tokens: 4000
});

return {
  json: {
    perplexity_body_2: body,
    research_1: research1Content,
    user_id: prepData.user_id,
    business_url: prepData.business_url,
    industry: prepData.industry,
    month: prepData.month,
    platforms: prepData.platforms,
    pipeline_run_id: prepData.pipeline_run_id,
    callback_url: prepData.callback_url,
    site_content: prepData.site_content,
    products: prepData.products,
    products_count: prepData.products_count
  }
};
```

#### Reconstructed Prompt:

**System:** `You are a consumer psychology researcher specializing in audience analysis for marketing. Provide detailed, actionable insights with citations.`

**User:** `Research the target audience for {industry} businesses like {business_url}. Provide: 1) Top pain points and frustrations, 2) Desires and aspirations, 3) Common objections to purchasing, 4) Buying triggers, 5) Where this audience spends time online. Include citations.`

### 4.4 Prepare Research 3

**Node Name:** `Prepare Research 3`
**Node Type:** `n8n-nodes-base.code` (Code node)
**AI Model:** Perplexity Sonar Pro (`sonar-pro`)
**Purpose:** Content gaps and opportunities

#### Full Code (jsCode):

```javascript
const research2 = $input.item.json;
const prepData = $('Prepare Research 2').item.json;

let research2Content = '';
try {
  research2Content = research2.choices[0].message.content;
} catch(e) {
  research2Content = JSON.stringify(research2);
}

const prompt = 'Research content marketing opportunities in the ' + prepData.industry + ' space for ' + prepData.business_url + '. Provide: 1) Underserved content topics, 2) High-engagement content formats, 3) 15-20 trending and niche hashtags for LinkedIn, Instagram, X, and YouTube, 4) Content pillars that resonate with the target audience. Include citations.';

const body = JSON.stringify({
  model: 'sonar-pro',
  messages: [
    {
      role: 'system',
      content: 'You are a content marketing strategist specializing in social media trends and content gap analysis. Provide detailed, actionable research with citations.'
    },
    {
      role: 'user',
      content: prompt
    }
  ],
  temperature: 0.3,
  max_tokens: 4000
});

return {
  json: {
    perplexity_body_3: body,
    research_1: prepData.research_1,
    research_2: research2Content,
    user_id: prepData.user_id,
    business_url: prepData.business_url,
    industry: prepData.industry,
    month: prepData.month,
    platforms: prepData.platforms,
    pipeline_run_id: prepData.pipeline_run_id,
    callback_url: prepData.callback_url,
    site_content: prepData.site_content,
    products: prepData.products,
    products_count: prepData.products_count
  }
};
```

#### Reconstructed Prompt:

**System:** `You are a content marketing strategist specializing in social media trends and content gap analysis. Provide detailed, actionable research with citations.`

**User:** `Research content marketing opportunities in the {industry} space for {business_url}. Provide: 1) Underserved content topics, 2) High-engagement content formats, 3) 15-20 trending and niche hashtags for LinkedIn, Instagram, X, and YouTube, 4) Content pillars that resonate with the target audience. Include citations.`

### 4.5 Prepare Synthesize ICP

**Node Name:** `Prepare Synthesize ICP`
**Node Type:** `n8n-nodes-base.code` (Code node)
**AI Model:** Claude Sonnet 4 (`claude-sonnet-4-20250514`) -- called downstream in "Claude -- Synthesize ICP" node
**Max Tokens:** 8192
**Purpose:** Combines all 3 Perplexity research outputs + website content + product list into a comprehensive ICP

#### Full Code (jsCode):

```javascript
const research3 = $input.item.json;
const prepData = $('Prepare Research 3').item.json;

let research3Content = '';
try {
  research3Content = research3.choices[0].message.content;
} catch(e) {
  research3Content = JSON.stringify(research3);
}

const productsList = (prepData.products || []).map(p => {
  return '- ' + p.name + (p.price ? ' ($' + p.price + ')' : '') + ': ' + (p.description || 'No description');
}).join('\n');

const prompt = 'You are a world-class marketing strategist. Based on the following research, create a comprehensive Ideal Customer Profile (ICP) for this business.\n\n' +
  'BUSINESS: ' + prepData.business_url + '\n' +
  'INDUSTRY: ' + prepData.industry + '\n\n' +
  'WEBSITE CONTENT SUMMARY:\n' + (prepData.site_content || 'Not available') + '\n\n' +
  'PRODUCTS/SERVICES OFFERED:\n' + (productsList || 'None extracted') + '\n\n' +
  'RESEARCH 1 - INDUSTRY LANDSCAPE & COMPETITORS:\n' + prepData.research_1 + '\n\n' +
  'RESEARCH 2 - AUDIENCE PAIN POINTS & DESIRES:\n' + prepData.research_2 + '\n\n' +
  'RESEARCH 3 - CONTENT GAPS & OPPORTUNITIES:\n' + research3Content + '\n\n' +
  'Synthesize ALL of the above into a professional ICP. Return a JSON object with EXACTLY these keys:\n' +
  JSON.stringify({
    icp_summary: '2-3 paragraph executive summary of the ideal customer',
    demographics: { age_range: '', gender: '', income_level: '', education: '', location: '', job_titles: [] },
    psychographics: { values: [], interests: [], lifestyle: '' },
    pain_points: ['array of specific pain points'],
    desires: ['array of specific desires and aspirations'],
    objections: ['array of common objections to purchasing'],
    buying_triggers: ['array of triggers that prompt purchasing'],
    content_pillars: [{ name: '', description: '', example_topics: [] }],
    content_preferences: { platforms: {}, content_types: [], best_posting_times: {} },
    competitors: [{ name: '', url: '', strengths: [], weaknesses: [] }],
    content_opportunities: ['array of underserved content topics'],
    recommended_hashtags: { linkedin: [], instagram: [], x: [], youtube: [] }
  }, null, 2) + '\n\nFill in ALL fields with real, researched data. Return ONLY valid JSON. No markdown, no explanation.';

const body = JSON.stringify({
  model: 'claude-sonnet-4-20250514',
  max_tokens: 8192,
  messages: [{ role: 'user', content: prompt }]
});

return {
  json: {
    apiBody: body,
    raw_research: prepData.research_1 + '\n---\n' + prepData.research_2 + '\n---\n' + research3Content,
    user_id: prepData.user_id,
    business_url: prepData.business_url,
    industry: prepData.industry,
    month: prepData.month,
    platforms: prepData.platforms,
    pipeline_run_id: prepData.pipeline_run_id,
    callback_url: prepData.callback_url,
    products: prepData.products,
    products_count: prepData.products_count
  }
};
```

#### Reconstructed Prompt:

```
You are a world-class marketing strategist. Based on the following research, create a comprehensive Ideal Customer Profile (ICP) for this business.

BUSINESS: {business_url}
INDUSTRY: {industry}

WEBSITE CONTENT SUMMARY:
{site_content}

PRODUCTS/SERVICES OFFERED:
- {product_name} (${price}): {description}
- ...

RESEARCH 1 - INDUSTRY LANDSCAPE & COMPETITORS:
{research_1 output from Perplexity}

RESEARCH 2 - AUDIENCE PAIN POINTS & DESIRES:
{research_2 output from Perplexity}

RESEARCH 3 - CONTENT GAPS & OPPORTUNITIES:
{research_3 output from Perplexity}

Synthesize ALL of the above into a professional ICP. Return a JSON object with EXACTLY these keys:
{
  "icp_summary": "2-3 paragraph executive summary of the ideal customer",
  "demographics": {
    "age_range": "",
    "gender": "",
    "income_level": "",
    "education": "",
    "location": "",
    "job_titles": []
  },
  "psychographics": {
    "values": [],
    "interests": [],
    "lifestyle": ""
  },
  "pain_points": ["array of specific pain points"],
  "desires": ["array of specific desires and aspirations"],
  "objections": ["array of common objections to purchasing"],
  "buying_triggers": ["array of triggers that prompt purchasing"],
  "content_pillars": [{ "name": "", "description": "", "example_topics": [] }],
  "content_preferences": { "platforms": {}, "content_types": [], "best_posting_times": {} },
  "competitors": [{ "name": "", "url": "", "strengths": [], "weaknesses": [] }],
  "content_opportunities": ["array of underserved content topics"],
  "recommended_hashtags": { "linkedin": [], "instagram": [], "x": [], "youtube": [] }
}

Fill in ALL fields with real, researched data. Return ONLY valid JSON. No markdown, no explanation.
```

### 4.6 Prepare Image Extraction

**Node Name:** `Prepare Image Extraction`
**Node Type:** `n8n-nodes-base.code` (Code node)
**AI Model:** Claude Sonnet 4 (`claude-sonnet-4-20250514`) -- called downstream in "Claude Extract Images" node
**Max Tokens:** 2048
**Purpose:** Extracts product image URLs from individual product page content (runs in a loop per product)

#### Full Code (jsCode):

```javascript
const jinaOutput = $input.item.json;
const batchItem = $('Loop Products').first().json;

let pageContent = '';
try {
  if (jinaOutput.data && jinaOutput.data.content) {
    pageContent = jinaOutput.data.content;
  } else if (jinaOutput.content) {
    pageContent = jinaOutput.content;
  } else {
    pageContent = JSON.stringify(jinaOutput);
  }
} catch(e) {
  pageContent = '';
}

// Also extract image URLs directly from Jina response
let jinaImages = [];
try {
  if (jinaOutput.data && jinaOutput.data.images) {
    jinaImages = Object.values(jinaOutput.data.images).filter(u => typeof u === 'string' && u.startsWith('http'));
  }
  if (jinaOutput.data && jinaOutput.data.links) {
    const imgLinks = jinaOutput.data.links.filter(l => l && typeof l === 'string' && /\.(jpg|jpeg|png|webp)/i.test(l));
    jinaImages = jinaImages.concat(imgLinks);
  }
} catch(e) {}

const truncated = pageContent.substring(0, 8000);

const body = JSON.stringify({
  model: 'claude-sonnet-4-20250514',
  max_tokens: 2048,
  system: 'You extract product image URLs from webpage content. Return ONLY a JSON array of image URL strings.',
  messages: [{
    role: 'user',
    content: 'Extract ALL product image URLs from this page content for the product: ' + (batchItem.name || 'unknown') + '\n\nPAGE CONTENT:\n' + truncated + '\n\nReturn a JSON array of image URL strings. Include product photos, gallery images, variant images, and lifestyle shots. Exclude icons, logos, and UI elements. Return ONLY the JSON array, no markdown or explanation.'
  }]
});

return {
  json: {
    apiBody: body,
    product_name: batchItem.name,
    product_user_id: batchItem._passthrough_user_id || batchItem.user_id,
    existing_image_urls: batchItem.image_urls || [],
    jina_images: jinaImages
  }
};
```

#### Reconstructed Prompt:

**System:** `You extract product image URLs from webpage content. Return ONLY a JSON array of image URL strings.`

**User:**
```
Extract ALL product image URLs from this page content for the product: {product_name}

PAGE CONTENT:
{truncated page content, up to 8000 chars}

Return a JSON array of image URL strings. Include product photos, gallery images, variant images, and lifestyle shots. Exclude icons, logos, and UI elements. Return ONLY the JSON array, no markdown or explanation.
```

### 4.7 Build Products from Research

**Node Name:** `Build Products from Research`
**Node Type:** `n8n-nodes-base.code` (Code node)
**AI Model:** Claude Sonnet 4 (`claude-sonnet-4-20250514`) -- called downstream in "Claude Build Products" node
**Purpose:** Fallback: converts Perplexity product research text into structured product JSON (used when direct scraping yields too few products)

#### Full Code (jsCode):

```javascript
const researchResponse = $input.item.json;
const parseData = $('Parse Products').item.json;

let researchText = '';
try {
  researchText = researchResponse.choices[0].message.content;
} catch(e) {
  researchText = JSON.stringify(researchResponse);
}

const body = JSON.stringify({
  model: 'claude-sonnet-4-20250514',
  max_tokens: 8192,
  messages: [{
    role: 'user',
    content: 'Convert this product research into a JSON array of products. The brand is ' + parseData.business_url + '.\n\nRESEARCH:\n' + researchText + '\n\nReturn a JSON array where each product has:\n- name: string (specific product name)\n- description: string (brief, max 100 chars)\n- price: string or null\n- features: string[] (max 3)\n- image_url: null\n- image_urls: []\n- product_url: string or null (only if a real URL was mentioned in the research)\n- category: string (e.g. Rings, Necklaces, Bracelets, Earrings, Watches)\n\nReturn ONLY valid JSON array. No markdown.'
  }]
});

return { json: { apiBody: body, ...parseData } };
```

#### Reconstructed Prompt:

```
Convert this product research into a JSON array of products. The brand is {business_url}.

RESEARCH:
{researchText from Perplexity}

Return a JSON array where each product has:
- name: string (specific product name)
- description: string (brief, max 100 chars)
- price: string or null
- features: string[] (max 3)
- image_url: null
- image_urls: []
- product_url: string or null (only if a real URL was mentioned in the research)
- category: string (e.g. Rings, Necklaces, Bracelets, Earrings, Watches)

Return ONLY valid JSON array. No markdown.
```

### 4.8 Research Products

**Node Name:** `Research Products`
**Node Type:** `n8n-nodes-base.httpRequest` (inline body expression)
**AI Model:** Perplexity Sonar (`sonar`)
**Purpose:** Fallback product discovery when scraping yields insufficient products

#### Prompt (inline in jsonBody expression):

**User:**
```
List 28 specific individual products sold by {business_url} (industry: {industry}). I need REAL product names -- not categories. For example, for a jewelry brand list specific ring names, necklace names, bracelet names etc. For each product provide: product name, category (e.g. Rings, Necklaces, Bracelets, Earrings), brief description, and the exact product page URL if known. Return as a numbered list.
```

### 4.9 Research Product Images

**Node Name:** `Research Product Images`
**Node Type:** `n8n-nodes-base.httpRequest` (inline body expression)
**AI Model:** Perplexity Sonar (`sonar`) with `web_search_options: { search_context_size: 'high' }`
**Purpose:** Searches the web for product images when scraping fails (e.g., JS-heavy SPAs)

#### Prompt (inline in jsonBody expression):

**System:**
```
You are a product image researcher. When asked to find product images, search for them on press sites, fashion magazines, Pinterest, retail aggregators, and review sites. Always provide direct image file URLs. Format each result as: ProductName | ImageURL
```

**User:**
```
Find product images for these {business_url} products. Search press.tiffany.com, vogue.com, harpersbazaar.com, pinterest.com, nordstrom.com, bloomingdales.com, saks.com and any other site that has photos of these products.

Products:
1. {product_name} ({category})
2. {product_name} ({category})
...up to 15 products...

For EACH product, search the web and provide a direct image URL. The URL must point to an actual image file. Look at image search results and retail product listings. Format exactly as:
ProductName | https://image-url-here.jpg

Provide ALL products with image URLs. Do not skip any.
```

---

## Summary Table

| Workflow | Node | AI Model | Purpose |
|---|---|---|---|
| 04-Content-Studio | Prepare Daily Content Loop + Generate Day Content | Claude Sonnet 4 | 7-day multi-platform content generation (megaPrompt) |
| 15-Generate-Topics | Prepare Claude Prompt + Claude Generate Topics | Claude Sonnet 4 | 7 daily topic titles with product/theme assignments |
| Image Generator | Analyze Product Image1 | GPT-4o | Vision-based product image analysis (JSON) |
| Image Generator | Image Scene Prompt1 + OpenAI Chat Model1 | GPT-4.1-mini | Photorealistic editorial image prompt engineering |
| Image Generator | Nano Banana Pro | Kie.ai nano-banana-pro | Actual image generation (not AI prompt, but uses the prompt output) |
| 01-ICP-Analyzer | Prepare Extract Products + Claude -- Extract Products | Claude Sonnet 4 | Product extraction from scraped website content |
| 01-ICP-Analyzer | Prepare Research 1 + Perplexity Research 1 | Perplexity Sonar Pro | Industry landscape & competitor analysis |
| 01-ICP-Analyzer | Prepare Research 2 + Perplexity Research 2 | Perplexity Sonar Pro | Audience pain points & desires |
| 01-ICP-Analyzer | Prepare Research 3 + Perplexity Research 3 | Perplexity Sonar Pro | Content gaps & opportunities |
| 01-ICP-Analyzer | Prepare Synthesize ICP + Claude -- Synthesize ICP | Claude Sonnet 4 | Full ICP synthesis from all research |
| 01-ICP-Analyzer | Prepare Image Extraction + Claude Extract Images | Claude Sonnet 4 | Product image URL extraction from page content |
| 01-ICP-Analyzer | Build Products from Research + Claude Build Products | Claude Sonnet 4 | Convert Perplexity research into structured product JSON |
| 01-ICP-Analyzer | Research Products | Perplexity Sonar | Fallback product discovery via web search |
| 01-ICP-Analyzer | Research Product Images | Perplexity Sonar | Fallback image search for JS-heavy sites |
