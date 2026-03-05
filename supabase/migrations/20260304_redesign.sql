-- ELUXR v3 Redesign: Weekly Topics + Product Image Galleries
-- Adds: products.image_urls, products.product_url, weekly_topics table, campaigns.current_week
-- ============================================================

-- ============================================================
-- A. Products: add image_urls array + product_url
-- ============================================================

ALTER TABLE public.products ADD COLUMN IF NOT EXISTS image_urls JSONB DEFAULT '[]'::jsonb;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS product_url TEXT;

-- Migrate existing image_url data into image_urls array
UPDATE public.products
SET image_urls = CASE
  WHEN image_url IS NOT NULL AND image_url != ''
  THEN jsonb_build_array(image_url)
  ELSE '[]'::jsonb
END
WHERE image_urls = '[]'::jsonb OR image_urls IS NULL;

-- ============================================================
-- B. Weekly Topics table
-- ============================================================

CREATE TABLE public.weekly_topics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  campaign_id UUID NOT NULL REFERENCES public.campaigns(id) ON DELETE CASCADE,
  week_number INTEGER NOT NULL CHECK (week_number BETWEEN 1 AND 5),
  day_number INTEGER NOT NULL CHECK (day_number BETWEEN 1 AND 7),
  topic TEXT NOT NULL,
  description TEXT,
  content_angle TEXT,
  product_id UUID REFERENCES public.products(id) ON DELETE SET NULL,
  product_name TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'regenerating')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, campaign_id, week_number, day_number)
);

-- ============================================================
-- C. RLS on weekly_topics
-- ============================================================

ALTER TABLE public.weekly_topics ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users own weekly_topics" ON public.weekly_topics
  FOR ALL USING (auth.uid() = user_id);

-- ============================================================
-- D. Indexes
-- ============================================================

CREATE INDEX idx_weekly_topics_lookup ON public.weekly_topics(user_id, campaign_id, week_number);

-- ============================================================
-- E. Track current week on campaigns
-- ============================================================

ALTER TABLE public.campaigns ADD COLUMN IF NOT EXISTS current_week INTEGER DEFAULT 0;
