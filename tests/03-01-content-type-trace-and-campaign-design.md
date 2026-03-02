# content_type Value Trace and Campaign/Themes Insert Design

**Traced:** 2026-03-02
**Plan:** 03-01 Task 3
**Purpose:** Document exact content_type values flowing through the pipeline and design the two-step campaign/themes Supabase insert pattern for Plans 02-04.

---

## Part A: content_type Value Trace

### Data Flow

```
[Claude Netflix Theme Generator] (HTTP Request -> Anthropic API)
    |
    v
[Parse & Split Theme Days] (Code node: parses JSON, splits into 30 items)
    |
    v
[Save Themes to Google Sheets] (appends to ELUXR_Themes sheet)
    ...later...
[Read Today's Theme] (reads from ELUXR_Themes sheet)
    |
    v
[Filter Today's Content] (Code node: filters by today's date)
    |
    v
[Route: Text / Image / Video] (Switch node -- PIPE-07 BUG)
    |--- Output 0 (Text) ---> Claude Write Post Content
    |--- Output 1 (Image) --> KIE Generate Content Image
    |--- Output 2 (Video) --> Claude Video Script Generator
```

### Claude Prompt -- content_type Specification

The Claude Netflix Theme Generator prompt instructs Claude to generate 30 days of content with this cyclicity pattern:

| Day of Week | content_type Value |
|-------------|-------------------|
| Monday | Hook |
| Tuesday | Value |
| Wednesday | Proof |
| Thursday | Carousel |
| Friday | Video |
| Saturday | Engagement |
| Sunday | Cliffhanger |

The prompt specifies shorthand: `content_type (Hook/Value/Proof/Carousel/Video/Engagement/Cliffhanger)`

Claude may also return variations like:
- "Hook Post" / "Hook"
- "Value Post" / "Value"
- "Social Proof" / "Proof"
- "Carousel/Thread" / "Carousel"
- "Video/Reel" / "Video"
- "Engagement Post" / "Engagement"
- "Cliffhanger" / "Cliffhanger Post"

### Parse & Split Theme Days Output Shape

The "Parse & Split Theme Days" Code node receives the Claude response and outputs an array of 30 items, each with:

```json
{
  "json": {
    "month": "March 2026",
    "day_number": 1,
    "date": "2026-03-01",
    "day_of_week": "Sunday",
    "week_number": 1,
    "weekly_show_name": "The Origin Story",
    "theme": "How I Started My Business",
    "content_type": "Cliffhanger",
    "platform": "LinkedIn",
    "secondary_platform": "X",
    "hook": "3 years ago I almost quit...",
    "cta": "Follow for the full story this week",
    "hashtags": "#business, #startup, #founder, #entrepreneur, #hustle",
    "notes": "Personal photo recommended",
    "created_at": "2026-03-02T07:00:00.000Z"
  }
}
```

**Key observations:**
- `content_type` is a free-text string from Claude (not normalized)
- `month` is added from the webhook body
- `hashtags` are converted from array to comma-separated string
- `created_at` is added by the Code node

### Filter Today's Content Node

This Code node:
1. Filters the 30 items by `date === today`
2. If no matches, returns the first item or a fallback: `{ theme: 'General engagement post', content_type: 'Value Post', platform: 'LinkedIn' }`

**No normalization of content_type occurs here.** The raw Claude value passes through.

### PIPE-07 Bug: Switch Node Analysis

Current Switch node rules (Route: Text / Image / Video):

| Output | Rule | Operator | Value | Targets |
|--------|------|----------|-------|---------|
| 0 (Text) | `$json.content_type` | notContains | "Video" | Claude Write Post Content |
| 1 (Image) | `$json.content_type` | exists | (any) | KIE Generate Content Image |
| 2 (Video) | `$json.content_type` | contains | "Video" | Claude Video Script Generator |

**The Bug:** Switch v3.2 evaluates rules top-down with first-match semantics.
- Rule 0 (`notContains "Video"`) matches ALL values EXCEPT those containing "Video"
- Rule 1 (`exists`) would match everything, but is NEVER reached because Rule 0 catches non-Video items first
- Rule 2 (`contains "Video"`) catches Video items that Rule 0 didn't match

**Result:** Images NEVER reach Output 1. All non-Video content goes to Output 0 (Text), including Carousel and any content that should generate images.

### Database Schema content_type Constraints

**content_items table:** `content_type TEXT NOT NULL CHECK (content_type IN ('text', 'image', 'video', 'carousel'))`

**themes table:** `content_types JSONB` (plural, stores the full content type info as JSON, no CHECK constraint)

### Content Type Normalization Map

For PIPE-07 fix, normalize Claude's free-text content_type to database-compatible values BEFORE the Switch node:

```javascript
// Normalization Code node (before Switch)
const item = $input.item.json;
const ct = (item.content_type || '').toLowerCase().trim();

// Save original for reference
item.original_content_type = item.content_type;

// Normalize to DB-compatible values
if (ct.includes('video') || ct.includes('reel')) {
  item.content_type = 'video';
} else if (ct.includes('carousel') || ct.includes('thread')) {
  item.content_type = 'carousel';
} else if (ct.includes('image')) {
  item.content_type = 'image';
} else {
  // Hook, Value, Proof, Engagement, Cliffhanger -> all text-based
  item.content_type = 'text';
}

return { json: item };
```

| Claude Value | Normalized | Switch Route | Generation Node |
|-------------|-----------|-------------|-----------------|
| Hook / Hook Post | text | Output 0 (Text) | Claude Write Post Content |
| Value / Value Post | text | Output 0 (Text) | Claude Write Post Content |
| Proof / Social Proof | text | Output 0 (Text) | Claude Write Post Content |
| Carousel / Carousel/Thread | carousel | Output 0 (Text) | Claude Write Post Content |
| Video / Video/Reel | video | Output 2 (Video) | Claude Video Script Generator |
| Engagement / Engagement Post | text | Output 0 (Text) | Claude Write Post Content |
| Cliffhanger | text | Output 0 (Text) | Claude Write Post Content |

**Note:** `carousel` items route to the Text branch because the text content is generated by Claude Write Post Content. The carousel format (multi-slide layout) is a frontend presentation concern, not a generation concern.

### Fixed Switch Node Rules

```
Output 0 (Text+Carousel): content_type equals "text" OR content_type equals "carousel"
Output 1 (Image):         content_type equals "image"
Output 2 (Video):         content_type equals "video"
Fallback:                 Any unmatched value -> default to text branch
```

With normalization happening BEFORE the Switch, exact equality checks work reliably.

---

## Part B: Campaign/Themes Two-Step Insert Design

### Current V1 Flow (Google Sheets)

```
[Claude Netflix Theme Generator] -> [Parse & Split Theme Days] -> [Save Themes to Google Sheets]
```

The v1 flow appends 30 flat rows to the ELUXR_Themes sheet. No campaign concept, no FK relationships.

### V2 Flow (Supabase)

The v2 database has TWO tables with a FK relationship:

```
campaigns (id, user_id, month, status)
    |
    v (campaign_id FK)
themes (id, user_id, campaign_id, week_number, theme_name, theme_description, ...)
```

**UNIQUE constraint:** `campaigns(user_id, month)` -- one campaign per user per month.

**FK constraint:** `themes.campaign_id REFERENCES campaigns(id) ON DELETE CASCADE`

### Two-Step Insert Pattern

```
[Claude Netflix Theme Generator]
    |
    v
[Parse Claude Response] (Code node)
    |
    v
[UPSERT Campaign] (HTTP Request -> Supabase)
    |  Returns: campaign row with id
    v
[Prepare Theme Rows] (Code node)
    |  Maps each theme day to DB format with campaign_id FK
    v
[INSERT Themes Batch] (HTTP Request -> Supabase)
    |  Returns: created theme rows
    v
[Success Response] (Respond to Webhook)
```

### Node Designs

#### Node A: "Parse Claude Response" (Code node)

```javascript
const input = $input.item.json;
const webhookData = $('Auth OK? (eluxr-phase2-themes)').item.json;

// Extract Claude response text
let themeContent = '';
try {
  themeContent = input.content[0].text;
} catch(e) {
  themeContent = JSON.stringify(input);
}

// Parse JSON array of 30 theme days
let themes = [];
try {
  themes = JSON.parse(themeContent);
} catch(e) {
  const match = themeContent.match(/\[\s*\{[\s\S]*\}\s*\]/);
  if (match) {
    themes = JSON.parse(match[0]);
  } else {
    throw new Error('Could not parse themes from Claude response');
  }
}

return {
  json: {
    user_id: webhookData.user_id,
    month: webhookData.body.month || '',
    themes: themes,
    theme_count: themes.length
  }
};
```

#### Node B: "UPSERT Campaign" (HTTP Request)

```
Method: POST
URL: https://llpnwaoxisfwptxvdfed.supabase.co/rest/v1/campaigns?on_conflict=user_id,month
Headers:
  Authorization: Bearer {{ SERVICE_ROLE_KEY }}
  apikey: sb_publishable_9gnLO_J9HBxVta1f8Ecvxw_KO8huPYQ
  Content-Type: application/json
  Prefer: resolution=merge-duplicates,return=representation

Body:
{
  "user_id": "{{ $json.user_id }}",
  "month": "{{ $json.month }}",
  "status": "generating"
}
```

**Response:** Returns the campaign row with its `id` (UUID). On re-generation for the same month, the existing campaign is updated (status reset to "generating").

**CRITICAL: `on_conflict=user_id,month`** -- This is a composite unique key. PostgREST accepts comma-separated column names.

#### Node C: "Prepare Theme Rows" (Code node)

```javascript
const campaign = $input.item.json;
const campaignId = campaign.id;       // From UPSERT response
const userId = campaign.user_id;
const parsedData = $('Parse Claude Response').item.json;
const themes = parsedData.themes;

// Group themes by week_number to create theme records
// The DB themes table represents weekly "shows", not individual days
const weekMap = {};
for (const day of themes) {
  const wn = day.week_number || 1;
  if (!weekMap[wn]) {
    weekMap[wn] = {
      user_id: userId,
      campaign_id: campaignId,
      week_number: wn,
      theme_name: day.weekly_show_name || `Week ${wn}`,
      theme_description: day.theme || '',
      show_concept: day.weekly_show_name || '',
      hook: day.hook || '',
      content_types: []
    };
  }
  // Collect all content types for this week
  weekMap[wn].content_types.push({
    day_number: day.day_number,
    date: day.date,
    day_of_week: day.day_of_week,
    content_type: day.content_type,
    theme: day.theme,
    platform: day.platform,
    hook: day.hook,
    cta: day.cta,
    hashtags: day.hashtags,
    notes: day.notes
  });
}

// Convert to array for batch INSERT
const themeRows = Object.values(weekMap).map(w => ({
  ...w,
  content_types: JSON.stringify(w.content_types) // JSONB column
}));

return themeRows.map(t => ({ json: t }));
```

**Note:** This uses `runOnceForAllItems` mode (returns array of `{ json }` objects) because we need to transform one input into multiple outputs.

#### Node D: "INSERT Themes Batch" (HTTP Request)

```
Method: POST
URL: https://llpnwaoxisfwptxvdfed.supabase.co/rest/v1/themes
Headers:
  Authorization: Bearer {{ SERVICE_ROLE_KEY }}
  apikey: sb_publishable_9gnLO_J9HBxVta1f8Ecvxw_KO8huPYQ
  Content-Type: application/json
  Prefer: return=representation

Body: JSON array of theme rows (from Node C)
[
  { "user_id": "...", "campaign_id": "...", "week_number": 1, "theme_name": "The Origin Story", ... },
  { "user_id": "...", "campaign_id": "...", "week_number": 2, "theme_name": "The Proof", ... },
  { "user_id": "...", "campaign_id": "...", "week_number": 3, "theme_name": "The Method", ... },
  { "user_id": "...", "campaign_id": "...", "week_number": 4, "theme_name": "The Vision", ... }
]
```

**Important:** When re-generating themes for the same month:
1. The campaign UPSERT updates the existing campaign
2. Old themes still exist (FK to same campaign_id)
3. **Need to DELETE old themes first** before inserting new ones:

```
DELETE /rest/v1/themes?campaign_id=eq.{campaign_id}
```

Add this as Node C.5 between UPSERT Campaign and INSERT Themes.

### Complete Node Flow

```
[Parse Claude Response]     -- Extract user_id, month, themes array
        |
        v
[UPSERT Campaign]          -- POST /campaigns?on_conflict=user_id,month
        |                      Returns: { id: campaign_id, ... }
        v
[Delete Old Themes]         -- DELETE /themes?campaign_id=eq.{campaign_id}
        |                      Clears any existing themes for re-generation
        v
[Prepare Theme Rows]        -- Map 30 days -> 4 weekly themes with campaign_id FK
        |
        v
[INSERT Themes Batch]       -- POST /themes (array of 4 rows)
        |
        v
[Update Campaign Status]    -- PATCH /campaigns?id=eq.{campaign_id}
                               Body: { "status": "active" }
```

### Error Handling Considerations

1. **Campaign UPSERT fails:** Return 500 with error message
2. **Theme INSERT fails (FK violation):** Campaign was deleted between UPSERT and INSERT -- retry
3. **Partial theme INSERT:** Supabase bulk INSERT is atomic -- all succeed or all fail
4. **Re-generation:** DELETE old themes before INSERT prevents duplicates

### Supabase API Patterns Used

| Operation | Method | URL Pattern | Prefer Header |
|-----------|--------|-------------|---------------|
| Campaign UPSERT | POST | `/campaigns?on_conflict=user_id,month` | `resolution=merge-duplicates,return=representation` |
| Delete old themes | DELETE | `/themes?campaign_id=eq.{id}` | (none) |
| Theme batch INSERT | POST | `/themes` | `return=representation` |
| Campaign status update | PATCH | `/campaigns?id=eq.{id}` | `return=representation` |

---

## Summary of Critical Findings for Downstream Plans

### CONTENT_TYPE_VALUES (for Plan 03-02 Task 4: PIPE-07 fix)

Claude generates 7 content_type values: **Hook, Value, Proof, Carousel, Video, Engagement, Cliffhanger**

These must be normalized to 4 DB-compatible values: **text, image, video, carousel**

Normalization code must run BEFORE the Switch node.

### THEME_INSERT_PATTERN (for Plan 03-02 Task 2: Theme Generator)

1. UPSERT campaign: `POST /campaigns?on_conflict=user_id,month`
2. Delete old themes: `DELETE /themes?campaign_id=eq.{id}`
3. Prepare 4 weekly theme rows with campaign_id FK
4. Batch INSERT themes: `POST /themes` with JSON array body
5. Update campaign status to "active"

### CLAUDE_RESPONSE_FORMAT (for Plan 03-02 Task 2: Parse Claude Response)

Claude returns `content[0].text` containing a JSON array of 30 objects with: day_number, date, day_of_week, week_number, weekly_show_name, theme, content_type, platform, secondary_platform, hook, cta, hashtags, notes.

### THEMES_TABLE_MAPPING (for Plan 03-02 Tasks 2-3)

The 30 daily items from Claude map to 4 weekly theme rows in the themes table. Each theme row stores the daily content details in the `content_types` JSONB column.

---
*Traced: 2026-03-02*
*Ready for consumption by Plans 03-02, 03-03, 03-04*
