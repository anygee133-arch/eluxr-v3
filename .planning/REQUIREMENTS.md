# Requirements: ELUXR Magic Content Engine v2

**Defined:** 2026-02-27
**Core Value:** A business can go from entering their URL to having a full month of platform-specific, trend-aware social media content generated, reviewed, and ready to post -- with zero manual content creation.

## v2 Requirements

Requirements for this release. Each maps to roadmap phases.

### Authentication

- [x] **AUTH-01**: User can sign up with email and password
- [x] **AUTH-02**: User can log in and access their dashboard
- [x] **AUTH-03**: User can reset password via email link
- [x] **AUTH-04**: Unauthenticated users are redirected to login page (protected routes)
- [x] **AUTH-05**: Each user's data is isolated -- users cannot see other tenants' content

### Infrastructure

- [x] **INFRA-01**: Supabase database with tables for users, ICP data, themes, content queue, and chat history
- [x] **INFRA-02**: Row-Level Security (RLS) policies on all tables enforcing tenant isolation via user_id
- [x] **INFRA-03**: All 16 Google Sheets nodes in n8n replaced with Supabase queries
- [x] **INFRA-04**: Every n8n webhook validates Supabase JWT before processing requests
- [x] **INFRA-05**: All API keys stored in n8n credential store -- zero hardcoded secrets (fix KIE key in 5 nodes)
- [x] **INFRA-06**: n8n monolithic workflow split into separate per-phase sub-workflows

### Progress Tracking

- [x] **PROG-01**: Real-time progress bar that advances when each pipeline step actually completes (not simulated)
- [x] **PROG-02**: Each of 6 steps (analyze business, create themes, write posts, generate images, create videos, sync calendar) reports completion individually
- [x] **PROG-03**: Checkmark appears next to each completed step
- [x] **PROG-04**: Progress state persisted in Supabase via Realtime -- survives page refresh

### Content Pipeline

- [ ] **PIPE-01**: ICP analysis via Perplexity market research + Claude synthesis, stored in Supabase per-tenant
- [ ] **PIPE-02**: 30-day Netflix-model theme generation with 4 weekly themed "shows" per month
- [ ] **PIPE-03**: Daily content generation producing platform-specific posts for LinkedIn, Instagram, X, YouTube
- [ ] **PIPE-04**: AI image prompt generation for each post via Claude
- [ ] **PIPE-05**: Video script generation (hook/setup/value/CTA structure) via Claude
- [ ] **PIPE-06**: One post per platform per day (4 platforms = 4 posts/day max)
- [x] **PIPE-07**: Fix Switch node routing bug -- ensure text/image/video branches are mutually exclusive

### Approval Queue

- [ ] **APPR-01**: User can view all content organized by status (pending/approved/rejected)
- [ ] **APPR-02**: User can approve individual content items
- [ ] **APPR-03**: User can reject individual content items
- [ ] **APPR-04**: User can edit content text before approving
- [ ] **APPR-05**: User can batch approve/reject multiple items
- [ ] **APPR-06**: Fix schedule edit ID mismatch bug (schedule-edit-content vs schedule-edit-content-{idx})

### Calendar

- [ ] **CAL-01**: Monthly calendar view showing content per day with platform-colored dots and status indicators
- [ ] **CAL-02**: Weekly content schedule grid with day cards showing theme, platform, and status
- [ ] **CAL-03**: Google Calendar sync for approved content (post scheduled events)
- [ ] **CAL-04**: CSV export of all content data

### AI Chat

- [ ] **CHAT-01**: Unified chatbot accessible from all tabs (single conversation thread)
- [ ] **CHAT-02**: Chat is context-aware -- loads user's ICP, themes, and content data before responding
- [ ] **CHAT-03**: Chat adjusts behavior based on which tab the user is on (setup/generate/calendar)

### Standalone Tools

- [ ] **TOOL-01**: Video Script Builder -- generate structured video scripts from topic, platform, style
- [ ] **TOOL-02**: Image Generator -- generate images via KIE Nano Banana Pro with aspect ratio and style options
- [ ] **TOOL-03**: Video Creator -- generate videos via KIE Veo with prompt and reference image support
- [ ] **TOOL-04**: Content Generator -- generate individual posts for any platform with tone/length options
- [x] **TOOL-05**: Fix image polling (replace hacky setTimeout with proper polling/wait pattern)
- [x] **TOOL-06**: Fix video branch wiring (true/false paths appear inverted in v1)

### Trend Intelligence

- [ ] **TREND-01**: Weekly trend research via Perplexity scanning for trending topics in user's industry
- [ ] **TREND-02**: Dynamic mid-month content pivots -- suggest swapping upcoming posts when major trends detected
- [ ] **TREND-03**: Dashboard notification banner when trending topics are detected

### UI/UX

- [ ] **UI-01**: Premium animations -- staggered reveals, glassmorphism touches, smooth transitions
- [ ] **UI-02**: Keep existing color scheme (#16a34a green, #0f172a dark) and 3-tab layout
- [ ] **UI-03**: Fix CSS stagger animation classes 5-6 (only 1-4 defined in v1)
- [ ] **UI-04**: Store ICP summary from Phase 1 response in frontend state (currently lost)
- [x] **UI-05**: Remove fake "estimated time remaining" from progress bar
- [ ] **UI-06**: Deploy frontend to Vercel or Netlify as static site

## Future Requirements (Post-v2)

### Chat Enhancements

- **CHAT-F01**: Action-capable chat (approve, reject, regenerate, edit content via chat commands)
- **CHAT-F02**: Persistent chat memory stored in Supabase (remembers across sessions)

### Publishing

- **PUB-F01**: Auto-publish approved content to LinkedIn via API
- **PUB-F02**: Auto-publish approved content to Instagram via API
- **PUB-F03**: Scheduled auto-publish at optimal posting times

### Billing

- **BILL-F01**: Stripe integration with subscription tiers
- **BILL-F02**: Feature gating based on plan level
- **BILL-F03**: Usage tracking and billing dashboard

### Platform Expansion

- **PLAT-F01**: TikTok platform support
- **PLAT-F02**: Facebook platform support

### Intelligence

- **INTEL-F01**: AI memory -- learns brand voice over time from approved/rejected content
- **INTEL-F02**: Netflix model enhancements -- season arcs, episode numbering, show analytics

## Out of Scope

| Feature | Reason |
|---------|--------|
| Auto-publishing to social platforms | Requires complex OAuth integrations with Meta/LinkedIn/X APIs -- defer to post-v2 |
| Telegram/push notifications | Dashboard-only approval flow keeps architecture simpler |
| TikTok and Facebook platforms | Focusing on 4 core platforms first (LinkedIn, Instagram, X, YouTube) |
| Stripe billing / subscriptions | Get product working first, add monetization later |
| Supabase Storage for media | KIE-hosted URLs are simpler; revisit if URLs expire |
| Mobile native app | Responsive web only for v2 |
| Google OAuth login | Email/password sufficient; Calendar sync is server-side via n8n |
| Multi-language support | English only for v2 |
| Analytics dashboard | No post-performance tracking in v2 -- manual posting means no metrics pipeline |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| AUTH-01 | Phase 2: Authentication | Complete |
| AUTH-02 | Phase 2: Authentication | Complete |
| AUTH-03 | Phase 2: Authentication | Complete |
| AUTH-04 | Phase 2: Authentication | Complete |
| AUTH-05 | Phase 2: Authentication | Complete |
| INFRA-01 | Phase 1: Security + DB Foundation | Complete |
| INFRA-02 | Phase 1: Security + DB Foundation | Complete |
| INFRA-03 | Phase 3: Workflow Decomposition | Complete |
| INFRA-04 | Phase 2: Authentication | Complete |
| INFRA-05 | Phase 1: Security + DB Foundation | Complete |
| INFRA-06 | Phase 3: Workflow Decomposition | Complete |
| PROG-01 | Phase 4: Progress Tracking | Complete |
| PROG-02 | Phase 4: Progress Tracking | Complete |
| PROG-03 | Phase 4: Progress Tracking | Complete |
| PROG-04 | Phase 4: Progress Tracking | Complete |
| PIPE-01 | Phase 6: Content Pipeline | Pending |
| PIPE-02 | Phase 6: Content Pipeline | Pending |
| PIPE-03 | Phase 6: Content Pipeline | Pending |
| PIPE-04 | Phase 6: Content Pipeline | Pending |
| PIPE-05 | Phase 6: Content Pipeline | Pending |
| PIPE-06 | Phase 6: Content Pipeline | Pending |
| PIPE-07 | Phase 3: Workflow Decomposition | Complete |
| APPR-01 | Phase 7: Approval Queue | Pending |
| APPR-02 | Phase 7: Approval Queue | Pending |
| APPR-03 | Phase 7: Approval Queue | Pending |
| APPR-04 | Phase 7: Approval Queue | Pending |
| APPR-05 | Phase 7: Approval Queue | Pending |
| APPR-06 | Phase 7: Approval Queue | Pending |
| CAL-01 | Phase 8: Calendar + Scheduling | Pending |
| CAL-02 | Phase 8: Calendar + Scheduling | Pending |
| CAL-03 | Phase 8: Calendar + Scheduling | Pending |
| CAL-04 | Phase 8: Calendar + Scheduling | Pending |
| CHAT-01 | Phase 9: AI Chat | Pending |
| CHAT-02 | Phase 9: AI Chat | Pending |
| CHAT-03 | Phase 9: AI Chat | Pending |
| TOOL-01 | Phase 10: Standalone Tools | Pending |
| TOOL-02 | Phase 10: Standalone Tools | Pending |
| TOOL-03 | Phase 10: Standalone Tools | Pending |
| TOOL-04 | Phase 10: Standalone Tools | Pending |
| TOOL-05 | Phase 3: Workflow Decomposition | Complete |
| TOOL-06 | Phase 3: Workflow Decomposition | Complete |
| TREND-01 | Phase 11: Trend Intelligence | Pending |
| TREND-02 | Phase 11: Trend Intelligence | Pending |
| TREND-03 | Phase 11: Trend Intelligence | Pending |
| UI-01 | Phase 5: Frontend Migration + UI | Pending |
| UI-02 | Phase 5: Frontend Migration + UI | Pending |
| UI-03 | Phase 5: Frontend Migration + UI | Pending |
| UI-04 | Phase 5: Frontend Migration + UI | Pending |
| UI-05 | Phase 4: Progress Tracking | Complete |
| UI-06 | Phase 5: Frontend Migration + UI | Pending |

**Coverage:**
- v2 requirements: 50 total
- Mapped to phases: 50
- Unmapped: 0

---
*Requirements defined: 2026-02-27*
*Last updated: 2026-03-03 after Phase 4 completion*
