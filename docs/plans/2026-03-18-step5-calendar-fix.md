# Step 5 Calendar Fix Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix all 7 broken features in Step 5 (Calendar): date awareness, schedule grid buttons, stats cards, Google Calendar events, CSV export, Clear Pending/New Calendar, and content list panel.

**Architecture:** All changes are in `index.html` (single-file app, ~7553 lines). Fixes target the JavaScript section (lines 2800+). No HTML/CSS structural changes needed — only JS logic fixes, missing window exports, and null safety.

**Tech Stack:** Vanilla JS, Supabase client (CDN), n8n webhooks via `authenticatedFetch()`

---

## Task 1: Fix Date Awareness (Problem 1)

**Files:**
- Modify: `index.html:3327` (add `userManuallyChangedMonth` flag)
- Modify: `index.html:4465` (`fetchAndDisplayCalendar` — add auto month detection)
- Modify: `index.html:4679` (`changeMonth` — set manual flag)
- Modify: `index.html:4691` (`goToCurrentMonth` — full rewrite)
- Modify: `index.html:4715` (`loadScheduleThemes` — reset offset)

**Step 1:** Add `userManuallyChangedMonth` global flag at line 3327, after `currentMonth` declaration:
```javascript
let userManuallyChangedMonth = false;
```

**Step 2:** In `fetchAndDisplayCalendar()` (line 4465), after `contentData` is set (~line 4470), add smart month auto-detection:
```javascript
if (contentData.length > 0 && !userManuallyChangedMonth) {
  const dateCounts = {};
  contentData.forEach(c => {
    const d = c.date || c.scheduled_date || '';
    const m = d.substring(0, 7);
    if (m) dateCounts[m] = (dateCounts[m] || 0) + 1;
  });
  const topMonth = Object.entries(dateCounts).sort((a, b) => b[1] - a[1])[0];
  if (topMonth && topMonth[0]) {
    currentMonth = topMonth[0];
    const monthInput = document.getElementById('month');
    if (monthInput) monthInput.value = currentMonth;
  }
}
```

**Step 3:** In `changeMonth()` (line 4679), add `userManuallyChangedMonth = true;` at the top of the function body.

**Step 4:** Rewrite `goToCurrentMonth()` (line 4691):
```javascript
function goToCurrentMonth() {
  const now = new Date();
  currentMonth = now.getFullYear() + '-' + String(now.getMonth() + 1).padStart(2, '0');
  userManuallyChangedMonth = false;
  renderCalendar(currentMonth, contentData);
  updateStats();
  scheduleWeekOffset = 0;
  loadScheduleThemes();
}
```

**Step 5:** In `loadScheduleThemes()` (line 4715), add `scheduleWeekOffset = 0;` at the beginning of the function (after the opening brace), so it always starts on the current week.

---

## Task 2: Fix Schedule Grid Buttons (Problem 2)

**Files:**
- Modify: `index.html:4923` (`openScheduleCard` — verify modal toggle)
- Modify: `index.html:4913` (`changeScheduleWeek` — verify)
- Modify: `index.html:4918` (`refreshSchedule` — verify)
- Modify: `index.html:5222-5226` (verify window exports)

**Step 1:** Verify `openScheduleCard()` (line 4923) uses `modal.classList.add('visible')` and that the CSS for `.schedule-modal.visible` or `#schedule-modal.visible` actually shows the modal. If it uses a different mechanism (e.g., `style.display`), fix the mismatch.

**Step 2:** Verify `changeScheduleWeek()` (line 4913) increments `scheduleWeekOffset` and calls `loadScheduleThemes()`.

**Step 3:** Verify `refreshSchedule()` (line 4918) calls `loadScheduleThemes()`.

**Step 4:** Verify ALL these window exports exist at lines 5222-5226:
```
window.openScheduleCard
window.closeScheduleModal
window.changeScheduleWeek
window.refreshSchedule
window.loadScheduleThemes
```
Add any that are missing.

**Step 5:** Add missing window exports for schedule-related functions that are called from HTML onclick handlers:
```javascript
window.generateScheduleContent = generateScheduleContent;  // if exists
window.approveScheduleContent = approveScheduleContent;      // if exists
window.rejectScheduleContent = rejectScheduleContent;        // if exists
window.saveScheduleEdit = saveScheduleEdit;                  // if exists
```

---

## Task 3: Fix Stats Cards (Problem 3)

**Files:**
- Modify: `index.html:5927` (`updateStats` — add fallback)
- Verify: multiple functions for `updateStats()` calls

**Step 1:** Rewrite `updateStats()` (line 5927) to add fallback when month filter returns empty:
```javascript
function updateStats() {
  let monthData = getContentForMonth(currentMonth);
  if (monthData.length === 0 && contentData.length > 0) {
    monthData = contentData;
  }
  const totalEl = document.getElementById('stat-total');
  const pendingEl = document.getElementById('stat-pending');
  const approvedEl = document.getElementById('stat-approved');
  const videosEl = document.getElementById('stat-videos');
  if (totalEl) totalEl.textContent = monthData.length;
  if (pendingEl) pendingEl.textContent = monthData.filter(c => c.status === 'pending' || !c.status).length;
  if (approvedEl) approvedEl.textContent = monthData.filter(c => c.status === 'approved').length;
  if (videosEl) videosEl.textContent = monthData.filter(c => c.video_url).length;
}
```

**Step 2:** Verify `updateStats()` is called at the end of ALL these functions (add if missing):
- `fetchAndDisplayCalendar()` — after `renderCalendar()`
- `quickApprove()` — after Supabase update
- `quickReject()` — after Supabase update
- `approveContent()` — after success
- `rejectContent()` — after success
- `clearPendingContent()` — after clearing
- `renderContentReview()` — at the end

---

## Task 4: Fix Google Calendar Events (Problem 4)

**Files:**
- Modify: `index.html:5772` (`buildCalendarEvents` — summary line)
- Modify: `index.html:5904` (`downloadIcsFile` — SUMMARY line)

**Step 1:** In `buildCalendarEvents()` (line 5742), update the event summary construction at line 5772 to use actual post text:
```javascript
const firstPostText = (posts[0].post_text || posts[0].content || '').replace(/\n/g, ' ').substring(0, 80);
const eventTitle = theme
  ? theme + ': ' + firstPostText
  : firstPostText || 'ELUXR Content — ' + platforms;

// Then use eventTitle as the summary:
summary: eventTitle,
```

**Step 2:** In `downloadIcsFile()` (line 5886), update the SUMMARY line at ~line 5904 to sanitize for ICS format:
```javascript
'SUMMARY:' + (event.summary || 'ELUXR Content').replace(/[,;\\]/g, ' ') + '\r\n' +
```

---

## Task 5: Fix CSV Export (Problem 5)

**Files:**
- Modify: `index.html:5717` (`exportToCSV` — full rewrite with null safety)

**Step 1:** Rewrite `exportToCSV()` (line 5717) with complete null safety and empty data guard:
```javascript
function exportToCSV() {
  const monthData = getContentForMonth(currentMonth);
  if (monthData.length === 0) {
    showToast('No content to export for this month.', 'error');
    return;
  }
  const headers = ['Date', 'Platform', 'Theme', 'Content Type', 'Post Text', 'Hashtags', 'Image URL', 'Video URL', 'Status'];
  const rows = monthData.map(c => [
    c.date || c.scheduled_date || '',
    c.platform || '',
    c.theme || '',
    c.content_type || '',
    '"' + (c.post_text || c.content || '').replace(/"/g, '""').replace(/\n/g, ' ') + '"',
    Array.isArray(c.hashtags) ? c.hashtags.join(' ') : (c.hashtags || ''),
    c.image_url || '',
    c.video_url || '',
    c.status || 'pending'
  ]);
  const csv = [headers.join(','), ...rows.map(r => r.join(','))].join('\n');
  const blob = new Blob([csv], { type: 'text/csv' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = 'eluxr-content-' + currentMonth + '.csv';
  link.click();
  URL.revokeObjectURL(url);
  showToast(rows.length + ' posts exported to CSV!', 'success');
}
```

**Step 2:** Add `window.exportToCSV = exportToCSV;` (currently MISSING).

---

## Task 6: Fix Clear Pending and New Calendar (Problem 6)

**Files:**
- Modify: `index.html:6054` (`clearPendingContent` — verify)
- Modify: `index.html:6091` (`startOver` — verify and add window export)

**Step 1:** Verify `clearPendingContent()` (line 6054):
- Confirms with user
- Supabase delete uses `.neq('status', 'approved')`
- Calls `fetchAndDisplayCalendar()` after
- Calls `updateStats()` after
- `window.clearPendingContent` export exists (line 4705 — confirmed)

**Step 2:** Verify `startOver()` (line 6091):
- Confirms with user
- Clears all content from Supabase
- Resets frontend state
- Scrolls to Step 1

**Step 3:** Add `window.startOver = startOver;` (currently MISSING).

---

## Task 7: Fix Content List Panel (Problem 7)

**Files:**
- Modify: `index.html:5953` (`showContentList` — verify and add window export)
- Modify: `index.html:6046` (`closeContentList` — verify and add window export)

**Step 1:** Verify `showContentList()` (line 5953):
- Panel toggles visibility
- Items render as clickable entries
- Each entry opens content preview

**Step 2:** Add missing window exports:
```javascript
window.showContentList = showContentList;
window.closeContentList = closeContentList;
window.exportToCSV = exportToCSV;
window.downloadIcsFile = downloadIcsFile;
window.buildCalendarEvents = buildCalendarEvents;
window.getContentForMonth = getContentForMonth;
window.approveContent = approveContent;
window.rejectContent = rejectContent;
window.startOver = startOver;
```

All 9 missing window exports must be added to make onclick handlers work.

---

## Verification Checklist

After all tasks, test every interactive element in Step 5:
- Schedule grid: prev/next week, refresh, day cell click, modal open/close
- Stats cards: correct counts, clickable to open content list
- Calendar: prev/next month, Today button, day click, content modal
- Buttons: Refresh, Export CSV, Sync to Google, Clear Pending, New Calendar
- Batch: checkbox selection, batch bar, approve selected, export selected
