# ELUXR Dashboard Redesign Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement 6 frontend+backend changes: ICP hashtags on posts, 28-product ordering, rename "Scraped Products", smooth transitions, drag-to-reorder products, and Step 4 flow fix.

**Architecture:** Single-file HTML/CSS/JS frontend (`index.html`) + n8n Cloud workflows (04-Content-Studio, 15-Generate-Topics) + Supabase PostgreSQL. Changes span all three layers.

**Tech Stack:** Vanilla JS/CSS, n8n MCP for workflow updates, Supabase REST API, HTML5 Drag and Drop API.

**Key Files:**
- Frontend: `/Users/andrewgershan/Desktop/eluxr v3 dev/index.html` (~6600 lines)
- n8n Workflow 15 (Generate Topics): ID `qTDGBLtfBqyb1Vm1`
- n8n Workflow 04 (Content Studio): ID `TreszUaJqlykCrMi`

**n8n Node IDs (for partial updates):**
- WF15 "Extract Params": `f566647d-448f-40bb-873b-ccc03ec3026c`
- WF15 "Prepare Claude Prompt": `3dd86418-2485-4e6b-9a88-ecc1f6e9b4dd`
- WF04 "Prepare Daily Content Loop": `81601ac0-77a2-49d1-87b7-b874f55f8796`
- WF04 "Parse All Days": `8717a5bc-b516-47fe-952c-ea87a8c1acfd`
- WF04 "Prepare Batch Insert": `ab5fab0b-e475-4497-af85-5f094fcd2e91`

---

## Task 1: Rename "Scraped Products" → "Your Products" (Change 3)

**Files:** Modify: `index.html`

**Step 1:** Search and replace all user-facing "scrape"/"Scraped" text.

Find `Scraped Products` (~line 2429) → replace with `Your Products`
Find `No products scraped yet. Run the pipeline to analyze your website.` → replace with `No products found yet. Run the analysis to discover your products.`
Find `Complete Step 1 to scrape products from your website.` → replace with `Complete Step 1 to discover your products.`
Search entire file for remaining "scrape"/"scraped" in user-facing strings and replace.

**Step 2:** Verify — grep the file for "scrape" case-insensitive, confirm only code references remain (not UI text).

**Step 3:** Commit: `feat: rename Scraped Products to Your Products`

---

## Task 2: Smooth Step Transitions (Change 4)

**Files:** Modify: `index.html` (CSS ~line 150-160 and JS ~line 3601+, 3692+)

**Step 1:** Add CSS transitions for step sections. Find `.step-section` styles and add:

```css
.step-section {
  transition: opacity 0.6s cubic-bezier(0.22, 1, 0.36, 1),
              transform 0.6s cubic-bezier(0.22, 1, 0.36, 1);
}
.step-section.locked {
  opacity: 0.4;
  transform: translateY(8px);
}
```

**Step 2:** Add smooth transition helpers in the JS section (after `scrollToStep()` ~line 3606):

```javascript
let userHasScrolled = false;
let autoScrollTimeout = null;

function smoothTransitionToStep(stepId, delay = 1000) {
  userHasScrolled = false;
  const scrollHandler = () => {
    userHasScrolled = true;
    clearTimeout(autoScrollTimeout);
    window.removeEventListener('scroll', scrollHandler);
  };
  window.addEventListener('scroll', scrollHandler, { once: true });
  autoScrollTimeout = setTimeout(() => {
    if (!userHasScrolled) {
      scrollToStep(stepId);
    }
    window.removeEventListener('scroll', scrollHandler);
  }, delay);
}
window.smoothTransitionToStep = smoothTransitionToStep;
```

**Step 3:** In `handleFormSubmit()` (~line 3754), replace direct `scrollToStep('step-products')` with `smoothTransitionToStep('step-products', 1500)`.

**Step 4:** Find `goToPhase(2)` calls in the content generation flow and replace with `smoothTransitionToStep('step-topics', 1000)`.

**Step 5:** After products load (in the pipeline success callback), add `smoothTransitionToStep('step-topics', 1500)`.

**Step 6:** Commit: `feat: smooth step-to-step transitions with scroll tracking`

---

## Task 3: Products Panel Restructure — Expandable Card + Drag-to-Reorder (Change 5a, 5b)

**Files:** Modify: `index.html` (HTML ~line 2425-2442, CSS ~line 1125-1142, JS ~line 3383-3433)

**Step 1:** Replace the collapsible dropdown HTML with an expandable panel. Modify `#products-card-container`:
- Remove `onclick="toggleProductsCard()"` from header
- Add click handler to toggle expanded state: `onclick="toggleProductsPanel()"`
- Add `style="max-height:400px; overflow-y:auto;"` to `#products-list`
- Change header icon from chevron to expand/collapse indicator

**Step 2:** Add drag-and-drop CSS:

```css
.product-item[draggable="true"] { cursor: grab; }
.product-item.dragging { opacity: 0.5; transform: scale(0.98); }
.product-item.drag-over { border-top: 2px solid #000; }
.product-order-badge {
  width: 28px; height: 28px; border-radius: 50%;
  background: #0f172a; color: #fff;
  display: flex; align-items: center; justify-content: center;
  font-size: 12px; font-weight: 700; flex-shrink: 0;
}
.drag-handle {
  cursor: grab; color: var(--text-muted); padding: 4px;
  display: flex; align-items: center; font-size: 16px;
}
```

**Step 3:** Add `productOrder` array and drag-and-drop JS:

```javascript
let productOrder = []; // Array of product IDs in user-defined order

function initProductOrder() {
  if (productsData && productsData.length > 0) {
    productOrder = productsData.map(p => p.id);
  }
}

function getOrderedProducts() {
  if (productOrder.length === 0) return productsData || [];
  return productOrder.map(id => (productsData || []).find(p => p.id === id)).filter(Boolean);
}

function initDragAndDrop() {
  const items = document.querySelectorAll('#products-items .product-item');
  items.forEach((item, idx) => {
    item.setAttribute('draggable', 'true');
    item.dataset.orderIndex = idx;

    item.addEventListener('dragstart', (e) => {
      item.classList.add('dragging');
      e.dataTransfer.setData('text/plain', idx);
      e.dataTransfer.effectAllowed = 'move';
    });

    item.addEventListener('dragend', () => {
      item.classList.remove('dragging');
      document.querySelectorAll('.product-item.drag-over').forEach(el => el.classList.remove('drag-over'));
    });

    item.addEventListener('dragover', (e) => {
      e.preventDefault();
      e.dataTransfer.dropEffect = 'move';
      item.classList.add('drag-over');
    });

    item.addEventListener('dragleave', () => {
      item.classList.remove('drag-over');
    });

    item.addEventListener('drop', (e) => {
      e.preventDefault();
      item.classList.remove('drag-over');
      const fromIndex = parseInt(e.dataTransfer.getData('text/plain'));
      const toIndex = idx;
      if (fromIndex !== toIndex) {
        reorderProducts(fromIndex, toIndex);
      }
    });
  });
}

function reorderProducts(fromIndex, toIndex) {
  const [moved] = productOrder.splice(fromIndex, 1);
  productOrder.splice(toIndex, 0, moved);
  renderProductsCard(getOrderedProducts());
  initDragAndDrop();
  markProductsModified();
}
```

**Step 4:** Modify `renderProductsCard()` to add order badges and drag handles to each product item. Prepend to each `.product-item`:

```html
<div class="drag-handle">&#9776;</div>
<div class="product-order-badge">{idx + 1}</div>
```

**Step 5:** Call `initProductOrder()` after products are loaded, and `initDragAndDrop()` after each render.

**Step 6:** Add warning if fewer than 28 products:

```javascript
if (productsData.length < 28) {
  showToast('Only ' + productsData.length + ' products found. Some days may share products.', 'warning');
}
```

**Step 7:** Commit: `feat: expandable products panel with drag-to-reorder and numbering`

---

## Task 4: Move "Generate Topics" Button to Step 2 + "Approve All" in Step 3 (Change 5c, 5d)

**Files:** Modify: `index.html` (HTML ~line 2442, 2467-2492, JS ~line 5971+, 6098+)

**Step 1:** Add "Generate Topics" button below products panel in Step 2 HTML (after `#products-card-container`):

```html
<div id="generate-topics-btn-container" style="text-align:center; margin-top:24px; display:none;">
  <button class="btn btn-primary btn-lg" id="btn-generate-week-topics" onclick="generateTopicsFromProducts()">
    Generate Week 1 Topics
  </button>
</div>
```

**Step 2:** Remove `#topics-generate-section` from Step 3 HTML (~line 2467-2475) — or hide it and replace with the new button in Step 2.

**Step 3:** Add `generateTopicsFromProducts()` function:

```javascript
async function generateTopicsFromProducts() {
  if (!productOrder || productOrder.length === 0) {
    showToast('No products ordered yet', 'error');
    return;
  }
  const weekStart = (currentWeek - 1) * 7;
  const weekEnd = weekStart + 7;
  const weekProducts = getOrderedProducts().slice(weekStart, weekEnd);
  if (weekProducts.length === 0) {
    showToast('No products available for Week ' + currentWeek, 'error');
    return;
  }
  await generateTopics(weekProducts);
  smoothTransitionToStep('step-topics', 500);
}
window.generateTopicsFromProducts = generateTopicsFromProducts;
```

**Step 4:** Modify `generateTopics()` (~line 5971) to accept optional `assignedProducts` parameter and include them in the request body:

```javascript
async function generateTopics(assignedProducts) {
  // ... existing code ...
  const body = {
    campaign_id: campaignId,
    week_number: currentWeek,
    storytelling_framework: frameworkContext
  };
  if (assignedProducts && assignedProducts.length > 0) {
    body.assigned_products = assignedProducts.map(p => ({
      id: p.id, name: p.name, description: p.description, category: p.category
    }));
  }
  // ... call authenticatedFetch with body ...
}
```

**Step 5:** Show `#generate-topics-btn-container` after products load. Update button text per week:

```javascript
function updateGenerateTopicsButton() {
  const container = document.getElementById('generate-topics-btn-container');
  const btn = document.getElementById('btn-generate-week-topics');
  if (container && productsData && productsData.length > 0) {
    container.style.display = 'block';
    if (btn) btn.textContent = 'Generate Week ' + currentWeek + ' Topics';
  }
}
```

**Step 6:** In Step 3 `#topics-approval` section, replace "Lock In & Generate Content" button with "Approve All & Generate Content":

```html
<button class="btn btn-primary" id="btn-approve-generate" onclick="approveAllAndGenerate()">
  Approve All &amp; Generate Content
</button>
```

**Step 7:** Add `approveAllAndGenerate()` function:

```javascript
async function approveAllAndGenerate() {
  const topics = weekTopics[currentWeek];
  if (!topics || topics.length === 0) {
    showToast('No topics to approve', 'error');
    return;
  }
  for (const topic of topics) {
    if (topic.status !== 'approved') {
      topic.status = 'approved';
      await window.supabase
        .from('weekly_topics')
        .update({ status: 'approved', updated_at: new Date().toISOString() })
        .eq('id', topic.id);
    }
  }
  renderTopicCards(topics);
  updateApprovalCount(topics);
  showToast('All topics approved! Starting content generation...', 'success');
  await lockInAndGenerate();
}
window.approveAllAndGenerate = approveAllAndGenerate;
```

**Step 8:** Commit: `feat: Generate Topics in Step 2, Approve All & Generate in Step 3`

---

## Task 5: n8n Workflow 15 — Accept Assigned Products (Change 2 backend)

**Files:** n8n workflow `qTDGBLtfBqyb1Vm1`, nodes: Extract Params, Prepare Claude Prompt

**Step 1:** Update "Extract Params" node (id: `f566647d`) to pass through `assigned_products`:

```javascript
const authData = $input.item.json;
const body = authData.body || {};

return {
  json: {
    campaign_id: body.campaign_id || '',
    week_number: parseInt(body.week_number) || 1,
    user_id: authData.user_id || '',
    assigned_products: body.assigned_products || null
  }
};
```

**Step 2:** Update "Prepare Claude Prompt" node (id: `3dd86418`) to use assigned products when provided:

In the existing code, after the product filtering/rotation logic, add:

```javascript
// If frontend sent assigned_products, use those instead of server-side rotation
const assignedFromFrontend = params.assigned_products;
if (assignedFromFrontend && assignedFromFrontend.length > 0) {
  // Match assigned products to full product objects for IDs
  available = assignedFromFrontend.map(ap => {
    const fullProduct = products.find(p => p.id === ap.id || p.name.toLowerCase() === (ap.name || '').toLowerCase());
    return fullProduct || ap;
  }).filter(Boolean);
}
```

**Step 3:** Use `mcp__n8n-mcp__n8n_update_partial_workflow` to apply both node updates.

**Step 4:** Commit: `feat(n8n): workflow 15 accepts assigned products from frontend`

---

## Task 6: n8n Workflow 04 — Add ICP Hashtags to Content Generation (Change 1 backend)

**Files:** n8n workflow `TreszUaJqlykCrMi`, nodes: Prepare Daily Content Loop, Parse All Days, Prepare Batch Insert

**Step 1:** The "Read ICP" node already fetches `recommended_hashtags`. Verify field is included in select: `icp_summary,content_pillars,recommended_hashtags` ✓

**Step 2:** Update "Prepare Daily Content Loop" node (id: `81601ac0`) to include ICP hashtags in the Claude prompt context. In the prompt body, add:

```
ICP RECOMMENDED HASHTAGS (pick exactly 3 most relevant per post):
{hashtags list}
```

And in the JSON output format instruction, add: `hashtags: [array of exactly 3 hashtags from the recommended list]`

**Step 3:** Update "Parse All Days" node (id: `8717a5bc`) to extract hashtags from Claude response and include them in content items:

```javascript
hashtags: post.hashtags || [],
```

**Step 4:** The "Prepare Batch Insert" node already handles hashtags field — confirm it formats correctly for Supabase array type. Current code: `hashtags: item.hashtags && item.hashtags.length > 0 ? \`{${...}}\` : null` ✓

**Step 5:** Use `mcp__n8n-mcp__n8n_update_partial_workflow` to apply node updates.

**Step 6:** Commit: `feat(n8n): workflow 04 assigns 3 ICP hashtags per generated post`

---

## Task 7: Frontend — ICP Hashtag Display + Client-Side Fallback (Change 1 frontend)

**Files:** Modify: `index.html`

**Step 1:** Add `assignRelevantHashtags()` helper function:

```javascript
function assignRelevantHashtags(postTheme, postProductName, allHashtags, count = 3) {
  if (!allHashtags || allHashtags.length === 0) return [];
  const keywords = ((postTheme || '') + ' ' + (postProductName || '')).toLowerCase().split(/\s+/).filter(w => w.length > 2);
  const scored = allHashtags.map(tag => {
    const tagLower = tag.toLowerCase().replace('#', '');
    let score = 0;
    keywords.forEach(kw => {
      if (tagLower.includes(kw) || kw.includes(tagLower)) score += 2;
    });
    return { tag, score };
  });
  scored.sort((a, b) => b.score - a.score);
  const result = scored.slice(0, count).map(s => s.tag);
  // Fill with random if not enough matches
  if (result.length < count) {
    const remaining = allHashtags.filter(t => !result.includes(t));
    while (result.length < count && remaining.length > 0) {
      const idx = Math.floor(Math.random() * remaining.length);
      result.push(remaining.splice(idx, 1)[0]);
    }
  }
  return result.map(t => t.startsWith('#') ? t : '#' + t);
}
window.assignRelevantHashtags = assignRelevantHashtags;
```

**Step 2:** After fetching content in `renderContentReview()`, run fallback hashtag assignment on items missing hashtags:

```javascript
// After deduplication, check for missing hashtags
const icpHashtags = window._icpHashtags || []; // cached from Step 1
for (const item of deduped) {
  if (!item.hashtags || item.hashtags.length === 0) {
    const assigned = assignRelevantHashtags(
      item.theme || '', item.product_name || '', icpHashtags, 3
    );
    if (assigned.length > 0) {
      item.hashtags = assigned;
      // Update Supabase in background
      window.supabase.from('content_items')
        .update({ hashtags: assigned })
        .eq('id', item.id)
        .then(() => {});
    }
  }
}
```

**Step 3:** Cache ICP hashtags when ICP loads. In the ICP rendering function (~line 3258), add:

```javascript
window._icpHashtags = tags; // cache for hashtag assignment
```

**Step 4:** In `openDayModal()`, display hashtag pills below each platform card's content. After the `.post-preview` div, add:

```javascript
const hashtagsHtml = (item.hashtags && item.hashtags.length > 0)
  ? '<div class="post-hashtags" style="display:flex; flex-wrap:wrap; gap:6px; margin-top:8px;">' +
      item.hashtags.map(h => '<span class="hashtag">' + escapeHTML(h) + '</span>').join('') +
    '</div>'
  : '';
```

**Step 5:** Ensure `mapContentItem()` (~line 3156) maps the `hashtags` field:

```javascript
hashtags: dbRow.hashtags || [],
```

**Step 6:** Commit: `feat: display ICP hashtags on content cards with client-side fallback`

---

## Task 8: Step 4 Flow — "View Generated Content" Instead of Jump to Calendar (Change 6)

**Files:** Modify: `index.html` (HTML ~line 2503-2508, JS ~line 6191-6210)

**Step 1:** Update `#week-complete` section HTML:

```html
<div id="week-complete" style="display:none; text-align:center; padding:40px 20px;">
  <div style="font-size:48px; margin-bottom:12px;">&#10003;</div>
  <h3 style="color:var(--text-primary); margin-bottom:8px;">Week <span id="completed-week-num">1</span> Complete!</h3>
  <p style="color:var(--text-secondary); margin-bottom:20px;">Content has been generated. Review your posts below.</p>
  <div style="display:flex; gap:12px; justify-content:center;">
    <button class="btn btn-primary" onclick="viewGeneratedContent()">View Generated Content</button>
    <button class="btn btn-outline" onclick="scrollToStep('step-calendar')">Skip to Calendar</button>
  </div>
</div>
```

**Step 2:** Add `viewGeneratedContent()` function:

```javascript
function viewGeneratedContent() {
  renderContentReview();
  scrollToStep('step-content');
}
window.viewGeneratedContent = viewGeneratedContent;
```

**Step 3:** In `lockInAndGenerate()` completion handler (~line 6191-6210), remove any `scrollToStep('step-calendar')` or `goToPhase(3)` calls. The flow should stop at the "Week X Complete!" screen.

**Step 4:** Center all primary action buttons. Verify `.nav-buttons` has `justify-content: center`. Check other button containers:
- `#generate-topics-btn-container` — already has `text-align:center`
- `#topics-approval` — add `justify-content: center` if not present

**Step 5:** Commit: `feat: show View Generated Content after week completion, center all buttons`

---

## Task 9: Integration Testing

**Step 1:** Wipe test data (use Supabase REST API as before).

**Step 2:** Run through full pipeline via Playwright:
1. Login → Step 1 → enter business URL → "Analyze My Business"
2. Verify smooth scroll to Step 2
3. Verify products show as "Your Products", numbered, draggable
4. Reorder a product via drag-and-drop
5. Click "Generate Week 1 Topics" → verify smooth scroll to Step 3
6. Verify topics show assigned products from ordering
7. Click "Approve All & Generate Content"
8. Verify "Week 1 Complete!" shows "View Generated Content" button
9. Click "View Generated Content" → verify Step 4 shows posts with hashtags
10. Verify hashtag pills appear on each content card

**Step 3:** Check console for errors.

**Step 4:** Commit: `test: verify full pipeline with all 6 redesign changes`

---

## Execution Order & Dependencies

```
Task 1 (rename) ─────────────────────────────────── independent
Task 2 (transitions) ────────────────────────────── independent
Task 3 (drag-reorder) ──┐
                         ├── Task 4 depends on Task 3 (products panel must exist)
Task 4 (move buttons) ──┘
Task 5 (n8n WF15) ──────── Task 4 sends assigned_products
Task 6 (n8n WF04) ──────── independent
Task 7 (hashtag UI) ─────── Task 6 provides hashtag data
Task 8 (Step 4 flow) ────── independent
Task 9 (testing) ─────────── depends on ALL above
```

**Parallelizable groups:**
- Group A: Tasks 1, 2, 8 (independent frontend)
- Group B: Tasks 3 → 4 → 5 (products flow, sequential)
- Group C: Task 6 → 7 (hashtags, sequential)
- Final: Task 9 (integration test)
