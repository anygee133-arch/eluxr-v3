# ELUXR v3 — User Experience Flow Map

> Every feature, action, and interaction a user can take — mapped with descriptions.

## Complete User Journey

```mermaid
flowchart TD
    Start([User visits ELUXR]) --> AuthCheck{Logged in?}
    AuthCheck -->|No| AuthFlow[Authentication]
    AuthCheck -->|Yes| Dashboard[Dashboard — 5 Steps]
    AuthFlow --> Dashboard

    Dashboard --> S1[Step 1: Business Profile]
    S1 -->|unlocks| S2[Step 2: Products]
    S2 -->|unlocks| S3[Step 3: Weekly Topics]
    S3 -->|unlocks| S4[Step 4: Content Review]
    S4 -->|unlocks| S5[Step 5: Calendar & Media]
```

## Authentication Flow

```mermaid
flowchart TD
    Auth([Auth Screen]) --> LoginCard

    subgraph LoginCard[Login]
        L1[Enter email]
        L2[Enter password]
        L3[Click Sign In]
        L1 --> L2 --> L3
    end

    subgraph SignupCard[Create Account]
        S1[Enter email]
        S2[Enter password — min 8 chars]
        S3[Confirm password]
        S4[Click Create Account]
        S1 --> S2 --> S3 --> S4
    end

    subgraph ResetCard[Password Reset]
        R1[Enter email]
        R2[Click Send Reset Link]
        R3[Check email for link]
        R4[Enter new password]
        R5[Click Set New Password]
        R1 --> R2 --> R3 --> R4 --> R5
    end

    LoginCard -->|Success| Dashboard([Dashboard])
    LoginCard -->|Forgot password?| ResetCard
    LoginCard -->|Sign up| SignupCard
    SignupCard -->|Already have account?| LoginCard
    ResetCard -->|Back to sign in| LoginCard
    SignupCard -->|Success| Dashboard

    LoginCard -->|Invalid credentials| LoginError[Show error message]
    LoginError --> LoginCard
    SignupCard -->|Passwords dont match| SignupError[Show error message]
    SignupError --> SignupCard
```

## Header — Always Visible

```mermaid
flowchart LR
    subgraph Header
        Logo[ELUXR Logo]
        Email[User email display]
        SignOut[Sign Out button]
    end

    subgraph StepDots[Step Progress — Vertical Sidebar]
        D1((1)) -->|Setup| D2((2))
        D2 -->|Products| D3((3))
        D3 -->|Topics| D4((4))
        D4 -->|Content| D5((5))
    end

    SignOut -->|Click| Logout[Clear session → Auth Screen]
    D1 -->|Click| ScrollS1[Scroll to Step 1]
    D2 -->|Click if unlocked| ScrollS2[Scroll to Step 2]
    D3 -->|Click if unlocked| ScrollS3[Scroll to Step 3]
    D4 -->|Click if unlocked| ScrollS4[Scroll to Step 4]
    D5 -->|Click if unlocked| ScrollS5[Scroll to Step 5]
```

## Step 1: Define Your Business Profile

```mermaid
flowchart TD
    S1([Step 1]) --> Form

    subgraph Form[Business Setup Form]
        URL[Website URL — text input<br/>e.g. https://tiffany.com]
        Industry[Industry — dropdown<br/>Manufacturing, Retail-Jewelry, etc.]
        Month[Content Month — month picker<br/>e.g. 2026-03]
        Language[Content Language — dropdown<br/>10 options: English, Spanish, etc.]
        Platforms[Target Platforms — checkboxes<br/>Instagram, Facebook, YouTube,<br/>TikTok, LinkedIn, X]
        Theme[Storytelling Theme — card selector<br/>4 options to click:]
        ThemeOpts[Luxury Intrigue & Discovery<br/>Emotional Journey<br/>Authority & Educator<br/>Cinematic Series]
        BrandVoice[Advanced: Brand Voice — expandable<br/>10 trait chips: Elegant, Bold, Playful...<br/>+ free-text notes]
    end

    Theme --> ThemeOpts

    Form --> Submit[Click: Analyze My Business]

    Submit --> Loading[Loading state:<br/>Skeleton cards + spinner]
    Loading --> Pipeline[n8n Orchestrator runs:<br/>Jina scrape → Perplexity research ×3<br/>→ Claude ICP synthesis]

    Pipeline --> Progress[Progress bar updates:<br/>Phase 1: Analyzing business<br/>Phase 2: Creating themes]

    Pipeline --> ICPCard

    subgraph ICPCard[ICP Results Card — appears after analysis]
        Summary[Summary — business description<br/>+ ideal customer profile]
        Audience[Target Audience — demographics,<br/>job titles, income, education]
        PainPoints[Pain Points — values,<br/>interests, lifestyle]
        Opportunities[Content Opportunities —<br/>10 content ideas]
        Hashtags[Recommended Hashtags —<br/>25-30 clickable tags]
        LastAnalyzed[Last analyzed timestamp]
    end

    ICPCard -->|Auto-scrolls to| Step2([Step 2 unlocked])
```

## Step 2: Your Products

```mermaid
flowchart TD
    S2([Step 2]) --> ProductsCard

    subgraph ProductsCard[Products Panel — collapsible]
        Header[Click header to expand/collapse<br/>Shows: Your Products 23/28]
        ProductGrid[Product Grid — draggable cards]
    end

    subgraph ProductItem[Each Product Card]
        Thumb[Product thumbnail image<br/>Click → opens gallery OR product URL]
        Name[Editable product name<br/>text input field]
        Meta[Description + Price + Category<br/>read-only display]
        Link[External link icon<br/>opens product page in new tab]
        Remove[× button — removes product]
    end

    ProductGrid --> ProductItem

    subgraph ProductActions[Product Actions]
        AddCustom[+ Add Custom Product<br/>Creates empty row, auto-focuses input]
        SaveChanges[Save Changes button<br/>Hidden until edits made]
        DragDrop[Drag & drop to reorder<br/>Grab handle on left side]
    end

    Remove -->|Click| MarkModified[Show Save Changes button]
    Name -->|Edit| MarkModified
    AddCustom -->|Click| NewRow[New product row appears] --> MarkModified
    SaveChanges -->|Click| SaveToSupabase[Save to Supabase<br/>Toast: Products saved!]

    SaveToSupabase --> GenButton[Generate Week 1 Topics<br/>button appears below products]
    GenButton -->|Click| Step3([Step 3 begins])
```

## Product Gallery Modal

```mermaid
flowchart TD
    ThumbClick[Click product thumbnail] --> Gallery

    subgraph Gallery[Gallery Modal — fullscreen overlay]
        MainImage[Large product image<br/>centered display]
        PrevBtn[← Prev button]
        NextBtn[Next → button]
        Counter[Image counter: 1 / 4]
        Thumbs[Thumbnail strip below<br/>Click any to jump]
        CloseBtn[× Close button]
    end

    PrevBtn -->|Click or ← key| PrevImage[Show previous image]
    NextBtn -->|Click or → key| NextImage[Show next image]
    Thumbs -->|Click thumb| JumpTo[Jump to that image]
    CloseBtn -->|Click or Escape key| CloseGallery[Close modal]
```

## Step 3: Weekly Topics

```mermaid
flowchart TD
    S3([Step 3]) --> WeekTabs

    subgraph WeekTabs[Week Navigation — 4 tabs]
        W1[Week 1 — active]
        W2[Week 2 — locked until Week 1 done]
        W3[Week 3 — locked]
        W4[Week 4 — locked]
    end

    W1 -->|Click| ShowWeek1[Show Week 1 topics]

    subgraph GenerateSection[Generate Topics]
        GenBtn[Generate Topics for Week N<br/>Sends products + theme + ICP to n8n]
        GenLoading[Spinner: Generating your topics...]
    end

    GenBtn -->|Click| GenLoading --> TopicsGrid

    subgraph TopicsGrid[7 Topic Cards — one per day]
        Topic1[Day 1 — Mon<br/>Topic title + description<br/>Assigned product + image]
        Topic2[Day 2 — Tue]
        Topic3[Day 3 — Wed]
        Topic4[Day 4 — Thu]
        Topic5[Day 5 — Fri]
        Topic6[Day 6 — Sat]
        Topic7[Day 7 — Sun]
    end

    subgraph TopicActions[Each Topic Card Actions]
        Approve[Approve ✓<br/>Locks in topic for content generation]
        Regenerate[Regenerate ↻<br/>Creates new topic for this day<br/>with different product]
    end

    TopicsGrid --> TopicActions

    subgraph ApprovalBar[Approval Progress]
        Counter[0/7 topics approved — live counter]
        ApproveAll[Approve All & Generate Content<br/>Approves all 7 + triggers content pipeline]
        LockIn[Lock In & Generate Content<br/>Uses only approved topics]
    end

    Approve -->|All 7 approved| ContentGen
    ApproveAll -->|Click| ContentGen
    LockIn -->|Click| ContentGen

    ContentGen[Content Generation Progress<br/>Progress bar + percentage] --> Complete

    Complete[Week Complete! ✓] --> ViewContent[View Generated Content<br/>→ scrolls to Step 4]
    Complete --> SkipCal[Skip to Calendar<br/>→ scrolls to Step 5]
    Complete --> NextWeek[Week 2 tab unlocks]
```

## Step 4: Content Review

```mermaid
flowchart TD
    S4([Step 4]) --> DayGrid

    subgraph DayGrid[Day Cards Grid — 7 cards per week]
        Day1[Mon — Curiosity Hook<br/>6 posts · 1 approved · #]
        Day2[Tue — Craftsmanship<br/>6 posts · 0 approved]
        Day3[Wed — Meaning & Symbolism]
        Day4[Thu — Transformation Moment]
        Day5[Fri — Hidden Detail / Surprise]
        Day6[Sat — Lifestyle Aspiration]
        Day7[Sun — Legacy & Timelessness]
    end

    Day1 -->|Click any day card| DayModal
```

## Day Modal — Content Detail View

```mermaid
flowchart TD
    DayModal([Day Modal Opens<br/>e.g. Mon — Curiosity Hook — 2026-03-02])

    DayModal --> TopicHeader
    DayModal --> ImageSection
    DayModal --> VideoSection
    DayModal --> PostsSection

    subgraph TopicHeader[Topic Header]
        ThemeLine[Theme: Curiosity Hook —<br/>Stop the scroll with intrigue]
        TopicTitle[The Secret Behind Hardware<br/>That's Not Hardware]
        TopicDesc[A mysterious close-up reveals<br/>unexpected luxury...]
        ProductName[Product: Tiffany HardWear<br/>Large Link Earrings in Rose Gold]
    end

    subgraph ImageSection[Day Image Section]
        GenImageBtn[Generate Image button<br/>or Regenerate if image exists]
        ImageDisplay[Generated image display<br/>with Generated badge]
    end

    GenImageBtn -->|Click| ImageGen[Fire-and-forget to n8n:<br/>GPT-4o analyzes product photo<br/>→ GPT-4.1-mini writes prompt<br/>→ KIE generates 2K image<br/>Polls Supabase every 5s<br/>60-90 second wait]
    ImageGen --> ImageDisplay

    subgraph VideoSection[Day Video Section]
        GenVideoBtn[Generate Video button]
        VideoPlayer[Video player with controls]
    end

    GenVideoBtn -->|Click| VideoGen[n8n generates video<br/>Polls Supabase every 5s<br/>Up to 3 min wait]
    VideoGen --> VideoPlayer

    subgraph PostsSection[Platform Posts — 6 cards]
        Post1[instagram — SCRIPT<br/>Full post text + hashtags]
        Post2[facebook — Post text + hashtags]
        Post3[youtube — SCRIPT with scenes,<br/>narration, camera directions]
        Post4[tiktok — Post text + hashtags]
        Post5[linkedin — Long-form thought<br/>leadership post + hashtags]
        Post6[x — Thread format<br/>1/6, 2/6... + hashtags]
    end

    subgraph PostActions[Each Post Actions]
        StatusBadge[Status: pending / approved]
        ApproveBtn[Approve — marks approved<br/>Sends to n8n for sync]
        EditBtn[Edit — opens edit modal<br/>with textarea]
        RejectBtn[Reject — marks rejected<br/>Red text styling]
    end

    PostsSection --> PostActions

    CloseModal[× Close or Escape key<br/>Returns to day grid]
```

## Content Edit Modal

```mermaid
flowchart TD
    EditClick[Click Edit on any post] --> EditModal

    subgraph EditModal[Content Preview & Edit Modal]
        PreviewDate[Date display]
        PlatformBadge[Platform badge — colored]
        ProductImages[Product images — if available]
        ContentImage[Generated image — if available<br/>+ Download button]
        ContentVideo[Video player — if available<br/>+ Download button]
        PostText[Full post text display]
    end

    subgraph EditActions[Modal Actions]
        ApproveBtn[Approve — marks content approved]
        EditBtn[Edit — reveals textarea<br/>with current post text]
        RegenBtn[Regenerate — creates new<br/>version via n8n]
        RejectBtn[Reject — marks rejected]
        GenVideoBtn[Generate Video — creates<br/>video for this specific post]
    end

    EditBtn -->|Click| EditMode[Textarea appears<br/>with current text]
    EditMode --> SaveEdit[Save Changes — updates<br/>content in Supabase]
    EditMode --> CancelEdit[Cancel — discards changes]
```

## Step 5: Calendar & Media

```mermaid
flowchart TD
    S5([Step 5]) --> Schedule
    S5 --> Stats
    S5 --> WeekStrip
    S5 --> Calendar

    subgraph Schedule[Weekly Content Schedule]
        SchedHeader[This Week's Content Schedule<br/>← Prev Week · date range · Next Week → · ↻ Refresh]
        SchedGrid[7 day cards for the week]
    end

    subgraph SchedCard[Each Schedule Day Card — clickable]
        DayLabel[Day name + date number]
        ThemeIndicator[Theme name or — if empty]
        ContentStatus[Content status summary<br/>or No content scheduled]
        ActionBtns[Action buttons:<br/>Generate / Approve / Reject / View]
    end

    SchedGrid --> SchedCard
    SchedCard -->|Click| SchedModal

    subgraph SchedModal[Schedule Detail Modal]
        ModalDate[Date + day of week]
        ModalTheme[Theme framework]
        ModalPosts[All posts for this day<br/>with editable text areas]
        ModalActions[Generate · Regenerate All<br/>Approve All · Reject All]
    end
```

## Statistics & Content List

```mermaid
flowchart TD
    subgraph Stats[Stats Cards Row — clickable]
        Total[Total Posts: 42<br/>Click to see all]
        Pending[Pending: 41<br/>Click to see pending]
        Approved[Approved: 1<br/>Click to see approved]
        Videos[Videos: 0<br/>Click to see video content]
    end

    Total -->|Click| ContentList
    Pending -->|Click| ContentList
    Approved -->|Click| ContentList
    Videos -->|Click| ContentList

    subgraph ContentList[Content List Panel — slides down]
        ListTitle[Filtered title: e.g. Pending Posts 41]
        CloseList[× Close button]
        ListItems[Scrollable list of content items<br/>Each shows: day number · title ·<br/>platform · type · status badge]
    end

    ListItems -->|Click any item| EditModal([Opens Content Edit Modal])
```

## Calendar View

```mermaid
flowchart TD
    subgraph CalNav[Calendar Navigation]
        PrevMonth[← Prev month]
        Title[March 2026 Content Calendar]
        NextMonth[Next → month]
    end

    subgraph CalActions[Calendar Action Buttons]
        Today[Today — jump to current month<br/>resets manual month selection]
        Refresh[↻ Refresh — reload all data]
        ExportCSV[Export CSV — downloads spreadsheet<br/>with all content items:<br/>date, platform, text, status, hashtags]
        SyncGoogle[Sync to Google — creates<br/>Google Calendar events with<br/>post text in description]
        ClearPending[Clear Pending — deletes all<br/>pending posts, keeps approved<br/>Confirmation dialog required]
        NewCalendar[New Calendar — full reset<br/>Clears everything, starts fresh<br/>Confirmation dialog required]
    end

    subgraph CalGrid[Monthly Calendar Grid]
        DayCell[Each day cell shows:<br/>Date number<br/>Platform dots — colored by platform<br/>Approved count badge<br/>Selection checkbox for batch ops]
    end

    DayCell -->|Click| SchedModal([Opens Schedule Detail Modal])

    subgraph CalLegend[Calendar Legend]
        L1[LinkedIn — blue dot]
        L2[Instagram — pink dot]
        L3[X/Twitter — dark dot]
        L4[YouTube — red dot]
        L5[Facebook — blue dot]
        L6[TikTok — cyan dot]
        L7[Has Video indicator]
        L8[Pending — yellow]
        L9[Approved — green]
    end
```

## Week View Strip

```mermaid
flowchart LR
    subgraph WeekStrip[Week View — horizontal strip]
        Prev[‹ Prev]
        Label[Mar 16 - Mar 22]
        Next[Next ›]
    end

    subgraph DayCells[7 Day Cells]
        Mon[Mon 16<br/>Click to open]
        Tue[Tue 17]
        Wed[Wed 18 — today highlight]
        Thu[Thu 19]
        Fri[Fri 20]
        Sat[Sat 21]
        Sun[Sun 22]
    end

    Prev -->|Click| PrevWeek[Show previous week]
    Next -->|Click| NextWeek[Show next week]
    DayCells -->|Click any| OpenModal([Opens Schedule Modal])
```

## Batch Operations

```mermaid
flowchart TD
    Select[Select content items<br/>via checkboxes on calendar cells] --> BatchBar

    subgraph BatchBar[Batch Action Bar — appears when items selected]
        Count[3 items selected]
        SelectAll[Select All Pending<br/>Selects every pending item]
        ApproveSelected[Approve Selected<br/>Bulk approve all checked items]
        BatchExport[Export CSV<br/>Export selected items]
        BatchSync[Sync to Google<br/>Sync selected to calendar]
    end
```

## Export & Sync Features

```mermaid
flowchart TD
    subgraph CSVExport[CSV Export]
        ExportBtn[Click Export CSV] --> GenerateCSV[Generates spreadsheet with:<br/>Date, Platform, Post Text,<br/>Status, Hashtags, Image URL,<br/>Video URL, Product Name]
        GenerateCSV --> Download[Browser downloads .csv file<br/>Null-safe — handles missing data]
    end

    subgraph GoogleSync[Google Calendar Sync]
        SyncBtn[Click Sync to Google] --> CheckGoogle{Google OAuth<br/>configured?}
        CheckGoogle -->|Yes| CreateEvents[Creates calendar events<br/>Title: platform + first 80 chars<br/>Description: full post text]
        CheckGoogle -->|No| ICSFallback[Downloads .ics file<br/>SUMMARY sanitized for special chars<br/>Compatible with any calendar app]
    end
```

## Toast Notifications

```mermaid
flowchart LR
    subgraph Toasts[Toast Types — auto-dismiss after 4s]
        Success[✓ Success — green<br/>Products saved, Content approved,<br/>Image generated, Calendar refreshed]
        Error[✗ Error — red<br/>Auth failed, Generation error,<br/>Network timeout, Save failed]
        Warning[⚠ Warning — yellow<br/>Only X products found,<br/>Max 28 products reached]
        Info[ℹ Info — blue<br/>Generating image 60-90s,<br/>Polling for result...]
    end
```

## Confirmation Dialogs

```mermaid
flowchart TD
    subgraph Confirmations[Actions That Require Confirmation]
        C1[Clear Pending Content<br/>Are you sure? Approved posts kept.]
        C2[New Calendar / Start Over<br/>Clears everything, starts fresh.]
        C3[Generate With Pending Posts<br/>Clear pending before generating?<br/>Approved posts will be kept.]
    end

    C1 -->|OK| ClearAction[Delete all pending content items]
    C1 -->|Cancel| NoAction1[Nothing happens]
    C2 -->|OK| ResetAction[Full session reset]
    C2 -->|Cancel| NoAction2[Nothing happens]
    C3 -->|OK| ClearThenGen[Clear pending + generate new]
    C3 -->|Cancel| NoAction3[Nothing happens]
```

## Keyboard Shortcuts

```mermaid
flowchart LR
    subgraph Keys[Keyboard Shortcuts]
        Escape[Escape key<br/>Closes any open modal:<br/>Day modal, Gallery,<br/>Content preview, Schedule modal]
        ArrowL[← Left Arrow<br/>Previous image in gallery]
        ArrowR[→ Right Arrow<br/>Next image in gallery]
    end
```

## Drag and Drop

```mermaid
flowchart TD
    subgraph DnD[Product Reordering — Step 2]
        Grab[Grab product by handle ☰] --> Drag[Drag to new position<br/>Visual: card lifts, target highlights]
        Drag --> Drop[Drop to reorder<br/>Saves new order]
        Drop --> Modified[Save Changes button appears]
    end
```

## Loading & Empty States

```mermaid
flowchart TD
    subgraph LoadingStates[Loading States]
        ICP[ICP Analysis — skeleton cards<br/>5 animated placeholder lines]
        Topics[Topic Generation — spinner<br/>Generating your topics...]
        Content[Content Generation — progress bar<br/>Percentage + phase indicator]
        Image[Image Generation — inline message<br/>Generating image... 60-90 seconds]
        Video[Video Generation — inline message<br/>Generating video... may take minutes]
        Calendar[Calendar — Loading weekly themes...]
    end

    subgraph EmptyStates[Empty States]
        NoICP[Step 2: Complete Step 1<br/>to discover your products]
        NoProducts[No products: empty state card]
        NoTopics[Generate 7 daily content topics<br/>for this week]
        NoContent[Generate content in Step 3<br/>to review it here]
        NoImage[No images yet. Click Generate Image<br/>to create an AI image for this day]
        NoVideo[No video yet. Click Generate Video<br/>to create a video for this day]
        NoCalContent[No content scheduled — Empty]
    end
```
