# ELUXR v3 — Full System Architecture Flow

## High-Level App Flow

```mermaid
flowchart LR
    User([User]) --> Login
    Login -->|Supabase Auth JWT| Step1
    Step1[Step 1: Business Profile] --> Step2[Step 2: Products]
    Step2 --> Step3[Step 3: Weekly Topics]
    Step3 --> Step4[Step 4: Content Review]
    Step4 --> Step5[Step 5: Calendar & Media]
```

## Authentication Flow

```mermaid
flowchart LR
    Browser -->|email + password| SupaAuth[Supabase Auth]
    SupaAuth -->|JWT access_token| Browser
    Browser -->|authenticatedFetch| n8n[n8n Webhooks]
    n8n -->|Auth Validator Workflow| AuthCheck{Valid JWT?}
    AuthCheck -->|Yes: extract user_id| Workflow[Run Workflow]
    AuthCheck -->|No| 401[401 Unauthorized]
    Workflow -->|service_role_key| Supabase[(Supabase DB)]
```

## Step 1: Define Your Business Profile

```mermaid
flowchart TD
    Form[User fills form:<br/>URL, Industry, Platforms,<br/>Theme, Language, Brand Voice]
    Form -->|saveProfile| ProfilesTable[(profiles table)]
    Form -->|handleFormSubmit| Orchestrator

    subgraph n8n Orchestrator Pipeline
        Orchestrator[POST /eluxr-generate-content<br/>Returns pipeline_run_id]
        Orchestrator --> Phase1[01-icp-analyzer<br/>Jina Scrape → Perplexity ×3 → Claude Synthesis]
        Phase1 -->|writes| ICPTable[(icps table)]
        Phase1 -->|writes| ProductsTable[(products table)]
        Phase1 --> Phase2[02-theme-generator]
        Phase2 -->|writes| ThemesTable[(themes table)]
    end

    Browser[Frontend] -->|Supabase Realtime subscription| PipelineRuns[(pipeline_runs table)]
    PipelineRuns -->|status updates| ProgressUI[Progress bar + phase indicators]
```

## Step 2: Your Products

```mermaid
flowchart TD
    Load[loadProducts] -->|SELECT * FROM products<br/>WHERE user_id = X| ProductsTable[(products table)]
    ProductsTable --> Grid[Product grid UI<br/>23-28 products with images]

    Grid -->|Edit name| Save[saveProductChanges]
    Grid -->|Add custom| Add[addCustomProduct]
    Grid -->|Remove| Deactivate[UPDATE is_active = false]

    Save -->|UPDATE| ProductsTable
    Add -->|INSERT| ProductsTable
    Deactivate -->|UPDATE| ProductsTable
```

## Step 3: Weekly Topics Generation

```mermaid
flowchart TD
    Generate[User clicks<br/>Generate Topics for Week N]
    Generate -->|ensureCampaign| CampaignsTable[(campaigns table)]
    Generate -->|POST /eluxr-generate-topics| TopicsWF

    subgraph n8n Workflow 15
        TopicsWF[generate-topics<br/>Claude creates 7 daily topics]
        TopicsWF -->|excludes products<br/>used in prior weeks| ProductRotation[Product Rotation Logic]
    end

    TopicsWF -->|writes| WeeklyTopics[(weekly_topics table)]
    WeeklyTopics --> TopicCards[7 Topic Cards UI]

    TopicCards -->|Approve| ApproveT[UPDATE status = approved]
    TopicCards -->|Regenerate| RegenWF[POST /eluxr-regenerate-topic<br/>Workflow 16]
    RegenWF -->|writes| WeeklyTopics
```

## Step 4: Content Review

```mermaid
flowchart TD
    ContentLoad[renderContentReview] -->|SELECT FROM content_items<br/>WHERE user_id = X| ContentTable[(content_items table)]
    ContentTable --> DayGrid[Day Cards Grid<br/>7 days × 6 platforms = 42 posts]

    DayGrid -->|click day| DayModal[Day Modal:<br/>Topic Header → Image → Video → Posts]

    subgraph Day Modal Actions
        DayModal --> ApprovePost[Approve]
        DayModal --> RejectPost[Reject]
        DayModal --> EditPost[Edit]
        DayModal --> GenImage[Generate Image]
        DayModal --> GenVideo[Generate Video]
    end

    ApprovePost -->|UPDATE status = approved| ContentTable
    RejectPost -->|UPDATE status = rejected| ContentTable
    EditPost -->|UPDATE content| ContentTable

    ApprovePost -->|POST /eluxr-approval-action| ApprovalWF[n8n Workflow 07]
    RejectPost -->|POST /eluxr-approval-action| ApprovalWF

    subgraph Content Generation
        RegenContent[POST /eluxr-phase4-studio<br/>Workflow 04] -->|Claude generates<br/>platform-specific posts| ContentTable
    end
```

## Step 5: Calendar & Media Generation

```mermaid
flowchart TD
    Calendar[fetchAndDisplayCalendar] -->|SELECT FROM content_items<br/>WHERE month = X| ContentTable[(content_items table)]
    ContentTable --> CalendarUI[Monthly Calendar View<br/>+ Weekly Schedule + Stats]

    subgraph Calendar Actions
        CalendarUI --> ExportCSV[Export CSV]
        CalendarUI --> SyncGoogle[Sync to Google Calendar]
        CalendarUI --> ClearPending[Clear Pending<br/>POST /eluxr-clear-pending]
        CalendarUI --> NewCalendar[New Calendar / Start Over]
    end
```

## Image Generation Flow (New Workflow)

```mermaid
flowchart TD
    Button[User clicks<br/>Generate Image in Day Modal]
    Button -->|generateDayImages| FetchCall

    subgraph Frontend
        FetchCall[POST /eluxr-tools-image<br/>body: topic, productImageUrl, content_id]
        FetchCall -->|fire-and-forget| Response[200: Workflow was started]
        Response --> Poll[Poll Supabase every 5s<br/>Check content_items.image_url<br/>Max 24 attempts = 2 min]
    end

    subgraph n8n: Social Calendar - Image Generator
        Webhook[Webhook Trigger<br/>POST /eluxr-tools-image] --> Config[Config + Inputs<br/>KIE API key, ratio 9:16,<br/>Supabase credentials]
        Config --> Analyze[GPT-4o: Analyze Product Image<br/>Returns detailed JSON:<br/>subject, lighting, colors,<br/>materials, orientation]
        Analyze --> Store[Store Analysis]
        Store --> Prompt[GPT-4.1-mini: Image Scene Prompt<br/>Combines product analysis +<br/>content topic into<br/>photorealistic prompt]
        Prompt --> KIE[KIE Nano Banana Pro<br/>Generate 2K image<br/>with product reference]
        KIE --> ParseID[Parse Task ID]
        ParseID --> Wait[Wait 15s]
        Wait --> CheckStatus[GET KIE Status]
        CheckStatus --> Ready{Image Ready?}
        Ready -->|Yes| Extract[Extract Image URL]
        Ready -->|No| Wait
        Extract --> SaveDB[PATCH content_items<br/>SET image_url = URL]
    end

    SaveDB -->|image_url populated| Poll
    Poll -->|found| Display[Display image in Day Modal<br/>with Generated badge]
```

## Video Generation Flow

```mermaid
flowchart TD
    VidButton[User clicks<br/>Generate Video in Day Modal]
    VidButton -->|generateDayVideo| VidFetch

    subgraph Frontend
        VidFetch[POST /eluxr-generate-video<br/>Authenticated]
        VidFetch --> VidPoll[Poll Supabase every 5s<br/>Check content_items.video_url<br/>Max 36 attempts = 3 min]
    end

    subgraph n8n Workflow
        VidWebhook[Video Creator Workflow<br/>Claude script → Video generation] --> VidSave[Save video_url to Supabase]
    end

    VidSave --> VidPoll
    VidPoll -->|found| VidDisplay[Display video player in modal]
```

## Complete Data Model

```mermaid
erDiagram
    profiles ||--o{ icps : has
    profiles ||--o{ products : has
    profiles ||--o{ campaigns : has
    profiles ||--o{ pipeline_runs : has
    profiles ||--o{ content_items : has
    campaigns ||--o{ weekly_topics : contains
    campaigns ||--o{ themes : contains
    campaigns ||--o{ content_items : contains

    profiles {
        uuid id PK
        text business_url
        text industry
        timestamp updated_at
    }
    icps {
        uuid id PK
        uuid user_id FK
        jsonb icp_summary
        jsonb industry_analysis
    }
    products {
        uuid id PK
        uuid user_id FK
        text name
        text description
        text category
        text price
        text image_url
        boolean is_active
    }
    campaigns {
        uuid id PK
        uuid user_id FK
        text month
        timestamp created_at
    }
    weekly_topics {
        uuid id PK
        uuid campaign_id FK
        int week_number
        int day_number
        text topic
        text description
        text product_name
        uuid product_id
        text status
    }
    content_items {
        uuid id PK
        uuid user_id FK
        uuid campaign_id FK
        uuid theme_id FK
        text title
        text content
        text platform
        text content_type
        text status
        text scheduled_date
        text image_url
        text video_url
        text post_text
        jsonb hashtags
    }
    pipeline_runs {
        uuid id PK
        uuid user_id FK
        text status
        text error_message
        timestamp started_at
    }
    themes {
        uuid id PK
        uuid user_id FK
        uuid campaign_id FK
        int week_number
    }
```

## N8N Webhook Endpoints Summary

```mermaid
flowchart LR
    subgraph Authenticated Endpoints
        E1[/eluxr-generate-content/]
        E2[/eluxr-phase4-studio/]
        E3[/eluxr-approval-action/]
        E4[/eluxr-approval-list/]
        E5[/eluxr-clear-pending/]
        E6[/eluxr-generate-topics/]
        E7[/eluxr-regenerate-topic/]
        E8[/eluxr-tools-video/]
        E9[/eluxr-generate-video/]
    end

    subgraph Unauthenticated
        E10[/eluxr-tools-image/]
    end

    E1 --- WF1[Orchestrator Pipeline]
    E2 --- WF4[04-content-studio]
    E3 --- WF7[07-approval-action]
    E4 --- WF6[06-approval-list]
    E5 --- WF8[08-clear-pending]
    E6 --- WF15[15-generate-topics]
    E7 --- WF16[16-regenerate-topic]
    E8 --- WF13[13-video-creator]
    E9 --- WF12[12-video-script-builder]
    E10 --- WFIMG[Social Calendar - Image Generator]
```

## Tech Stack

```mermaid
flowchart TD
    subgraph Frontend
        HTML[index.html<br/>~7600 lines<br/>Vanilla HTML/CSS/JS]
        ConfigJS[config.js<br/>Environment detection]
    end

    subgraph Backend
        n8n[n8n Cloud<br/>flowbound.app.n8n.cloud<br/>16 workflows + orchestrator]
    end

    subgraph Database
        Supabase[Supabase<br/>PostgreSQL + Auth + RLS + Realtime]
    end

    subgraph AI Services
        Claude[Claude<br/>Content generation]
        Perplexity[Perplexity<br/>Research & trends]
        GPT4o[GPT-4o<br/>Image analysis]
        GPT41mini[GPT-4.1-mini<br/>Prompt engineering]
        KIE[KIE AI / Nano Banana Pro<br/>Image generation]
    end

    subgraph Hosting
        Vercel[Vercel<br/>Static deployment]
    end

    HTML --> n8n
    HTML --> Supabase
    n8n --> Supabase
    n8n --> Claude
    n8n --> Perplexity
    n8n --> GPT4o
    n8n --> GPT41mini
    n8n --> KIE
    Vercel --> HTML
```
