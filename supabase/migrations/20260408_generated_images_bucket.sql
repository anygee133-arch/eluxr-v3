-- Migration: Create generated-images bucket for AI-generated content
-- Date: 2026-04-08
-- Purpose: Move AI-generated images from tempfile.aiquickdraw.com (ephemeral KIE CDN)
--          to Supabase Storage for permanent, reliable hosting.
--
-- Public bucket: files served at /storage/v1/object/public/generated-images/{path}
-- Upload path convention: {content_item_id}.png
-- n8n workflow (Social Calendar - Image Generator) uses service_role key for uploads.

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'generated-images',
  'generated-images',
  true,
  10485760,
  ARRAY['image/png', 'image/jpeg', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;
