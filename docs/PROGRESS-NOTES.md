# ELUXR v3 — Progress Notes

**Last Updated:** 2026-03-18

---

## Redesign Checklist Audit (from claude-code-prompt.md)

### DONE
| # | Item | Evidence |
|---|------|----------|
| 3 | Remove "Magic Content Engine" from header/auth cards | Header only shows `<h1>ELUXR</h1>` |
| 4 | Remove Step 1 subtitle paragraph | Only h2 header remains |
| 5 | Rename "Your Business Profile" → "Ideal Customer Profile" | ICP card heading says "Ideal Customer Profile" |
| 8 | Remove all step description `<p>` paragraphs (Steps 1-5) | All 5 steps have h2 only |
| 10 | Step 3: Full topic text + product image on right | renderTopicCards() has productImgHtml on right via flex |
| 11 | Step 4: Full content in popup modal, topic title header, inline approve/edit/reject | openDayModal() renders full text, topic header, action buttons |

### PARTIALLY DONE
| # | Item | What's Done | What's Missing |
|---|------|-------------|----------------|
| 1 | B&W color scheme | CSS vars converted to black/gray | 5 leftover green/purple remnants (orbs, logo glow, form focus, calendar dot, toast) |
| 9 | Step 2: Product improvements | Image click opens product URL | "Add Custom Product" button NOT moved to top of list |
| 12 | CSS cleanup | Most glows removed | Orb gradients, logo drop-shadow, form focus shadow, calendar dot shadow, toast color |

### NOT DONE
| # | Item | Current State |
|---|------|---------------|
| 2 | Buttons use header border gradient | Buttons use solid #0f1729, NOT the green→purple gradient |
| 6 | Regroup platforms (3 groups) | Still 6 individual checkboxes (Instagram, Facebook, YouTube, TikTok, LinkedIn, X) |

### NOT NEEDED
| # | Item | Reason |
|---|------|--------|
| 7 | Comma-separated platform parsing | Using arrays, not comma-separated values |

---

## Specific CSS Remnants to Fix

1. **Lines ~92-100:** `.orb-1` and `.orb-2` still have green/purple radial gradients
2. **Line ~154:** Logo `filter: drop-shadow()` still has green glow `rgba(22,163,74,0.15)`
3. **Line ~306:** Form input `:focus` still has green shadow `rgba(22,163,74,0.08)`
4. **Line ~614:** Calendar `.video` dot still has purple shadow `rgba(124,58,237,0.3)`
5. **Line ~776:** `.toast.success` still uses green `rgba(22,163,74,0.9)`

---

## Recent Fixes (March 13-18, 2026)

### Bug Fixes (commit dd8feed)
- **Platform constraint:** Supabase `content_items.platform` CHECK constraint updated to allow `facebook` and `tiktok` — was blocking ALL content inserts
- **Non-blocking fetch:** `lockInAndGenerate()` no longer blocks on await for 5 min while workflow runs
- **viewGeneratedContent():** Made async, awaits renderContentReview() before scrolling
- **fetchAndDisplayCalendar():** Now called with `silent=true` to prevent auto-scroll to calendar
- **Navigation:** Removed `goToPhase(2)` calls that jumped to wrong step

### New Feature (commit dd8feed)
- **Image Generation:** `generateImageForItem()` function added
  - Fire-and-forget POST to `https://n8n-dev.eluxr.com/webhook/eluxr-tools-image`
  - Polls Supabase every 5s for up to 3 min for `image_url`
  - "Generate Image" / "Regenerate Image" buttons in day modal
  - Uses plain `fetch` (no auth) since external n8n instance

### n8n Webhook Fix
- Content Studio webhook (workflow 04) was returning 500 due to corrupted `responseMode` parameter
- Fixed by replacing entire webhook parameters object (removing responseMode entirely)

---

## What Still Needs Work

- [ ] Fix 5 CSS green/purple remnants (orbs, logo, form focus, calendar dot, toast)
- [ ] Buttons: switch from solid #0f1729 to header border gradient (if still desired)
- [ ] Move "Add Custom Product" button to top of products list
- [ ] Platform grouping: decide whether to keep 6 individual or group into 3
- [ ] Vercel production deployment
- [ ] Full E2E browser test of all 5 steps
