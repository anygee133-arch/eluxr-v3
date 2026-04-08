-- Migration: Add business_notes column to profiles table
-- Date: 2026-04-08
-- Purpose: Persist "Additional Notes" from Section 1 so it survives page reload
--          and flows through to WF15 (topic generation) and WF04 (content generation).

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS business_notes TEXT;
