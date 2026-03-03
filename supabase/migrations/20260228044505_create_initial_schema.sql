-- ELUXR v2: Initial Database Schema
-- Phase 1: Security Hardening + Database Foundation
-- 10 tables, RLS policies, indexes, trigger, Realtime
-- ============================================================

-- ============================================================
-- A. TABLES (10 total)
-- ============================================================

-- 1. profiles (extends auth.users -- id IS the FK, not user_id)
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT,
  display_name TEXT,
  business_url TEXT,
  industry TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. icps (ICP analysis results -- one per user)
CREATE TABLE public.icps (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  business_url TEXT,
  industry TEXT,
  icp_summary TEXT,
  demographics JSONB,
  psychographics JSONB,
  content_preferences JSONB,
  competitors JSONB,
  content_opportunities JSONB,
  recommended_hashtags JSONB,
  raw_research TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id)
);

-- 3. campaigns (monthly content campaigns)
CREATE TABLE public.campaigns (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  month TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'generating', 'active', 'completed', 'archived')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, month)
);

-- 4. themes (weekly shows -- 4 per campaign)
CREATE TABLE public.themes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  campaign_id UUID NOT NULL REFERENCES public.campaigns(id) ON DELETE CASCADE,
  week_number INTEGER NOT NULL CHECK (week_number BETWEEN 1 AND 5),
  theme_name TEXT NOT NULL,
  theme_description TEXT,
  show_concept TEXT,
  hook TEXT,
  content_types JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. content_items (individual posts)
CREATE TABLE public.content_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  campaign_id UUID REFERENCES public.campaigns(id) ON DELETE CASCADE,
  theme_id UUID REFERENCES public.themes(id) ON DELETE SET NULL,
  title TEXT,
  content TEXT,
  content_type TEXT NOT NULL CHECK (content_type IN ('text', 'image', 'video', 'carousel')),
  platform TEXT NOT NULL CHECK (platform IN ('linkedin', 'instagram', 'x', 'youtube')),
  scheduled_date DATE,
  scheduled_time TIME,
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'pending_review', 'approved', 'rejected', 'published', 'archived')),
  image_url TEXT,
  video_url TEXT,
  image_prompt TEXT,
  feedback TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. pipeline_runs (real-time progress tracking)
CREATE TABLE public.pipeline_runs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  pipeline_type TEXT NOT NULL CHECK (pipeline_type IN ('icp_analysis', 'theme_generation', 'content_generation', 'image_generation', 'video_generation', 'calendar_sync', 'full_pipeline')),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'running', 'completed', 'failed', 'cancelled')),
  current_step INTEGER DEFAULT 0,
  total_steps INTEGER DEFAULT 0,
  step_label TEXT,
  step_progress NUMERIC(5,2) DEFAULT 0,
  error_message TEXT,
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. chat_conversations (conversation threads)
CREATE TABLE public.chat_conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. chat_messages (individual messages)
CREATE TABLE public.chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  conversation_id UUID NOT NULL REFERENCES public.chat_conversations(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
  content TEXT NOT NULL,
  actions_taken JSONB,
  phase_context TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 9. trend_alerts (weekly trend research results)
CREATE TABLE public.trend_alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  trend_topic TEXT NOT NULL,
  relevance_score NUMERIC(3,2),
  summary TEXT,
  suggested_content JSONB,
  source TEXT,
  status TEXT NOT NULL DEFAULT 'new' CHECK (status IN ('new', 'reviewed', 'actioned', 'dismissed')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 10. tool_outputs (standalone tool history)
CREATE TABLE public.tool_outputs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  tool_type TEXT NOT NULL CHECK (tool_type IN ('image_generator', 'video_creator', 'video_script_builder', 'content_generator')),
  input_params JSONB,
  output_data JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- B. ENABLE ROW LEVEL SECURITY ON ALL TABLES
-- ============================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.icps ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.themes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pipeline_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trend_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tool_outputs ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- C. RLS POLICIES
-- CRITICAL: Uses (select auth.uid()) for performance optimization
-- ============================================================

-- profiles: SELECT + UPDATE only (trigger handles INSERT, no DELETE)
CREATE POLICY "Users can view own profile" ON public.profiles
  FOR SELECT USING ((select auth.uid()) = id);
CREATE POLICY "Users can update own profile" ON public.profiles
  FOR UPDATE USING ((select auth.uid()) = id);

-- icps: full CRUD
CREATE POLICY "Users can view own icps" ON public.icps
  FOR SELECT USING ((select auth.uid()) = user_id);
CREATE POLICY "Users can insert own icps" ON public.icps
  FOR INSERT WITH CHECK ((select auth.uid()) = user_id);
CREATE POLICY "Users can update own icps" ON public.icps
  FOR UPDATE USING ((select auth.uid()) = user_id);
CREATE POLICY "Users can delete own icps" ON public.icps
  FOR DELETE USING ((select auth.uid()) = user_id);

-- campaigns: full CRUD
CREATE POLICY "Users can view own campaigns" ON public.campaigns
  FOR SELECT USING ((select auth.uid()) = user_id);
CREATE POLICY "Users can insert own campaigns" ON public.campaigns
  FOR INSERT WITH CHECK ((select auth.uid()) = user_id);
CREATE POLICY "Users can update own campaigns" ON public.campaigns
  FOR UPDATE USING ((select auth.uid()) = user_id);
CREATE POLICY "Users can delete own campaigns" ON public.campaigns
  FOR DELETE USING ((select auth.uid()) = user_id);

-- themes: full CRUD
CREATE POLICY "Users can view own themes" ON public.themes
  FOR SELECT USING ((select auth.uid()) = user_id);
CREATE POLICY "Users can insert own themes" ON public.themes
  FOR INSERT WITH CHECK ((select auth.uid()) = user_id);
CREATE POLICY "Users can update own themes" ON public.themes
  FOR UPDATE USING ((select auth.uid()) = user_id);
CREATE POLICY "Users can delete own themes" ON public.themes
  FOR DELETE USING ((select auth.uid()) = user_id);

-- content_items: full CRUD
CREATE POLICY "Users can view own content_items" ON public.content_items
  FOR SELECT USING ((select auth.uid()) = user_id);
CREATE POLICY "Users can insert own content_items" ON public.content_items
  FOR INSERT WITH CHECK ((select auth.uid()) = user_id);
CREATE POLICY "Users can update own content_items" ON public.content_items
  FOR UPDATE USING ((select auth.uid()) = user_id);
CREATE POLICY "Users can delete own content_items" ON public.content_items
  FOR DELETE USING ((select auth.uid()) = user_id);

-- pipeline_runs: full CRUD
CREATE POLICY "Users can view own pipeline_runs" ON public.pipeline_runs
  FOR SELECT USING ((select auth.uid()) = user_id);
CREATE POLICY "Users can insert own pipeline_runs" ON public.pipeline_runs
  FOR INSERT WITH CHECK ((select auth.uid()) = user_id);
CREATE POLICY "Users can update own pipeline_runs" ON public.pipeline_runs
  FOR UPDATE USING ((select auth.uid()) = user_id);
CREATE POLICY "Users can delete own pipeline_runs" ON public.pipeline_runs
  FOR DELETE USING ((select auth.uid()) = user_id);

-- chat_conversations: full CRUD
CREATE POLICY "Users can view own chat_conversations" ON public.chat_conversations
  FOR SELECT USING ((select auth.uid()) = user_id);
CREATE POLICY "Users can insert own chat_conversations" ON public.chat_conversations
  FOR INSERT WITH CHECK ((select auth.uid()) = user_id);
CREATE POLICY "Users can update own chat_conversations" ON public.chat_conversations
  FOR UPDATE USING ((select auth.uid()) = user_id);
CREATE POLICY "Users can delete own chat_conversations" ON public.chat_conversations
  FOR DELETE USING ((select auth.uid()) = user_id);

-- chat_messages: full CRUD
CREATE POLICY "Users can view own chat_messages" ON public.chat_messages
  FOR SELECT USING ((select auth.uid()) = user_id);
CREATE POLICY "Users can insert own chat_messages" ON public.chat_messages
  FOR INSERT WITH CHECK ((select auth.uid()) = user_id);
CREATE POLICY "Users can update own chat_messages" ON public.chat_messages
  FOR UPDATE USING ((select auth.uid()) = user_id);
CREATE POLICY "Users can delete own chat_messages" ON public.chat_messages
  FOR DELETE USING ((select auth.uid()) = user_id);

-- trend_alerts: full CRUD
CREATE POLICY "Users can view own trend_alerts" ON public.trend_alerts
  FOR SELECT USING ((select auth.uid()) = user_id);
CREATE POLICY "Users can insert own trend_alerts" ON public.trend_alerts
  FOR INSERT WITH CHECK ((select auth.uid()) = user_id);
CREATE POLICY "Users can update own trend_alerts" ON public.trend_alerts
  FOR UPDATE USING ((select auth.uid()) = user_id);
CREATE POLICY "Users can delete own trend_alerts" ON public.trend_alerts
  FOR DELETE USING ((select auth.uid()) = user_id);

-- tool_outputs: full CRUD
CREATE POLICY "Users can view own tool_outputs" ON public.tool_outputs
  FOR SELECT USING ((select auth.uid()) = user_id);
CREATE POLICY "Users can insert own tool_outputs" ON public.tool_outputs
  FOR INSERT WITH CHECK ((select auth.uid()) = user_id);
CREATE POLICY "Users can update own tool_outputs" ON public.tool_outputs
  FOR UPDATE USING ((select auth.uid()) = user_id);
CREATE POLICY "Users can delete own tool_outputs" ON public.tool_outputs
  FOR DELETE USING ((select auth.uid()) = user_id);

-- ============================================================
-- D. INDEXES
-- ============================================================

-- Single-column indexes for RLS performance
CREATE INDEX idx_icps_user_id ON public.icps(user_id);
CREATE INDEX idx_campaigns_user_id ON public.campaigns(user_id);
CREATE INDEX idx_themes_user_id ON public.themes(user_id);
CREATE INDEX idx_content_items_user_id ON public.content_items(user_id);
CREATE INDEX idx_pipeline_runs_user_id ON public.pipeline_runs(user_id);
CREATE INDEX idx_chat_conversations_user_id ON public.chat_conversations(user_id);
CREATE INDEX idx_chat_messages_user_id ON public.chat_messages(user_id);
CREATE INDEX idx_trend_alerts_user_id ON public.trend_alerts(user_id);
CREATE INDEX idx_tool_outputs_user_id ON public.tool_outputs(user_id);

-- Composite indexes for common query patterns
CREATE INDEX idx_content_items_user_status ON public.content_items(user_id, status);
CREATE INDEX idx_content_items_user_campaign ON public.content_items(user_id, campaign_id);
CREATE INDEX idx_content_items_user_date ON public.content_items(user_id, scheduled_date);
CREATE INDEX idx_pipeline_runs_user_status ON public.pipeline_runs(user_id, status);
CREATE INDEX idx_chat_messages_conversation ON public.chat_messages(conversation_id, created_at);
CREATE INDEX idx_trend_alerts_user_status ON public.trend_alerts(user_id, status);
CREATE INDEX idx_themes_campaign ON public.themes(campaign_id);

-- ============================================================
-- E. AUTO-CREATE PROFILE TRIGGER
-- ============================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.profiles (id, email)
  VALUES (new.id, new.email);
  RETURN new;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- ============================================================
-- F. ENABLE SUPABASE REALTIME ON pipeline_runs
-- ============================================================

ALTER PUBLICATION supabase_realtime ADD TABLE public.pipeline_runs;
