-- ELUXR v3 Revision Spec — Milestone 1 Database Changes
-- Adds: image_themes, brand_documents, platform_connections tables
-- Alters: campaigns, content_items, products, profiles
-- Date: 2026-03-29
-- ============================================================

-- ============================================================
-- A. New Table: image_themes (reference data for image generation styles)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.image_themes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  theme_name TEXT NOT NULL,
  theme_prompt TEXT NOT NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.image_themes ENABLE ROW LEVEL SECURITY;

-- Public read access (reference data), service-role write
CREATE POLICY "Anyone can read image_themes" ON public.image_themes
  FOR SELECT USING (true);

-- Seed launch themes from spec
INSERT INTO public.image_themes (theme_name, theme_prompt) VALUES
  ('Product on Model', 'Product worn or used by a model in a luxury editorial photography setting. The product is the focal point, naturally integrated into a real-world scenario. Shallow depth of field, 85mm f/1.4, natural lighting, fashion editorial style.'),
  ('Hero Shot', 'Clean, centered hero shot with dramatic studio lighting. Product isolated against a minimal background with cinematic light and shadow. Professional product photography, sharp focus, high contrast, dramatic mood.'),
  ('Nature', 'Product placed in a beautiful natural outdoor environment. Organic textures, natural light, environmental context that complements the product aesthetic. Golden hour lighting, shallow depth of field, editorial nature photography.')
ON CONFLICT DO NOTHING;

-- ============================================================
-- B. New Table: brand_documents (user-uploaded brand guidelines)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.brand_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  campaign_id UUID REFERENCES public.campaigns(id) ON DELETE CASCADE,
  file_url TEXT NOT NULL,
  file_name TEXT NOT NULL,
  file_type TEXT,
  file_size INTEGER,
  extracted_text TEXT,
  summary_text TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.brand_documents ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users own brand_documents" ON public.brand_documents
  FOR ALL USING (auth.uid() = user_id);

CREATE INDEX idx_brand_documents_user_campaign ON public.brand_documents(user_id, campaign_id);

-- ============================================================
-- C. New Table: platform_connections (Zernio M2 placeholder)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.platform_connections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  platform TEXT NOT NULL,
  zernio_account_id TEXT,
  connected_at TIMESTAMPTZ,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, platform)
);

ALTER TABLE public.platform_connections ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users own platform_connections" ON public.platform_connections
  FOR ALL USING (auth.uid() = user_id);

CREATE INDEX idx_platform_connections_user ON public.platform_connections(user_id);

-- ============================================================
-- D. Alter campaigns table
-- ============================================================

ALTER TABLE public.campaigns ADD COLUMN IF NOT EXISTS brand_voice_traits JSONB DEFAULT '[]'::jsonb;
ALTER TABLE public.campaigns ADD COLUMN IF NOT EXISTS brand_voice_notes TEXT;
ALTER TABLE public.campaigns ADD COLUMN IF NOT EXISTS campaign_theme TEXT;
ALTER TABLE public.campaigns ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;
ALTER TABLE public.campaigns ADD COLUMN IF NOT EXISTS start_date DATE;
ALTER TABLE public.campaigns ADD COLUMN IF NOT EXISTS platforms JSONB DEFAULT '[]'::jsonb;
ALTER TABLE public.campaigns ADD COLUMN IF NOT EXISTS content_language TEXT DEFAULT 'English';

-- ============================================================
-- E. Alter content_items table
-- ============================================================

ALTER TABLE public.content_items ADD COLUMN IF NOT EXISTS image_theme_id UUID REFERENCES public.image_themes(id) ON DELETE SET NULL;
ALTER TABLE public.content_items ADD COLUMN IF NOT EXISTS selected_visual TEXT;
ALTER TABLE public.content_items ADD COLUMN IF NOT EXISTS zernio_post_id TEXT;

-- Update status check constraint to include new statuses
-- First drop existing constraint, then add expanded one
ALTER TABLE public.content_items DROP CONSTRAINT IF EXISTS content_items_status_check;
ALTER TABLE public.content_items ADD CONSTRAINT content_items_status_check
  CHECK (status IN ('draft', 'pending_review', 'approved', 'rejected', 'published', 'archived', 'scheduled', 'posted', 'failed'));

-- ============================================================
-- F. Alter products table
-- ============================================================

ALTER TABLE public.products ADD COLUMN IF NOT EXISTS sort_order INTEGER DEFAULT 0;

-- ============================================================
-- G. Alter profiles table (Zernio M2 placeholder)
-- ============================================================

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS zernio_profile_id TEXT;

-- ============================================================
-- H. Supabase Storage bucket for brand documents
-- Note: Storage bucket creation must be done via Supabase Dashboard
-- or Supabase CLI. This comment documents the required config:
--
-- Bucket: brand-documents
-- Public: false (private, authenticated access)
-- File size limit: 10MB (10485760 bytes)
-- Allowed MIME types: application/pdf, application/msword,
--   application/vnd.openxmlformats-officedocument.wordprocessingml.document,
--   text/plain, image/png, image/jpeg
-- RLS: Users can upload/read/delete own files (path: {user_id}/*)
-- ============================================================

-- Storage RLS policies (if bucket exists)
-- These are applied via Supabase Dashboard or programmatically

-- ============================================================
-- I. Expand weekly_topics week_number constraint for more weeks
-- Some months need 5-6 weeks with partial weeks
-- ============================================================

ALTER TABLE public.weekly_topics DROP CONSTRAINT IF EXISTS weekly_topics_week_number_check;
ALTER TABLE public.weekly_topics ADD CONSTRAINT weekly_topics_week_number_check
  CHECK (week_number BETWEEN 1 AND 6);
