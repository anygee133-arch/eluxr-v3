-- ELUXR v2: Phase 6 Content Pipeline - Schema Additions
-- Products table + column additions to icps, campaigns, themes, content_items
-- Supports: product scraping storage, Netflix model, video scripts, ICP enrichment
-- ============================================================

-- ============================================================
-- A. NEW TABLE: products (scraped product data per tenant)
-- ============================================================

CREATE TABLE public.products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  price TEXT,
  features JSONB,
  image_url TEXT,
  category TEXT,
  source_url TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- B. RLS ON products
-- ============================================================

ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own products" ON public.products
  FOR SELECT USING ((select auth.uid()) = user_id);

CREATE POLICY "Users can insert own products" ON public.products
  FOR INSERT WITH CHECK ((select auth.uid()) = user_id);

CREATE POLICY "Users can update own products" ON public.products
  FOR UPDATE USING ((select auth.uid()) = user_id);

CREATE POLICY "Users can delete own products" ON public.products
  FOR DELETE USING ((select auth.uid()) = user_id);

-- ============================================================
-- C. INDEX ON products
-- ============================================================

CREATE INDEX idx_products_user_id ON public.products(user_id);

-- ============================================================
-- D. ADD COLUMNS TO content_items
-- ============================================================

ALTER TABLE public.content_items ADD COLUMN product_id UUID REFERENCES public.products(id) ON DELETE SET NULL;
ALTER TABLE public.content_items ADD COLUMN video_script JSONB;
ALTER TABLE public.content_items ADD COLUMN hashtags TEXT[];
ALTER TABLE public.content_items ADD COLUMN first_comment TEXT;

-- ============================================================
-- E. ADD COLUMN TO campaigns
-- ============================================================

ALTER TABLE public.campaigns ADD COLUMN show_name TEXT;

-- ============================================================
-- F. ADD COLUMNS TO themes
-- ============================================================

ALTER TABLE public.themes ADD COLUMN season_arc TEXT;
ALTER TABLE public.themes ADD COLUMN inspirational_theme TEXT;

-- ============================================================
-- G. ADD COLUMNS TO icps
-- ============================================================

ALTER TABLE public.icps ADD COLUMN content_pillars JSONB;
ALTER TABLE public.icps ADD COLUMN pain_points JSONB;
ALTER TABLE public.icps ADD COLUMN desires JSONB;
ALTER TABLE public.icps ADD COLUMN objections JSONB;
ALTER TABLE public.icps ADD COLUMN buying_triggers JSONB;
