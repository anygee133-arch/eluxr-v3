-- Add storytelling_theme column to weekly_topics
-- Maps day_number 1-7 to the 7-Day Storytelling Framework:
--   1=curiosity_hook, 2=craftsmanship, 3=meaning_symbolism,
--   4=transformation, 5=hidden_detail, 6=lifestyle_aspiration, 7=legacy_timelessness

ALTER TABLE public.weekly_topics
ADD COLUMN IF NOT EXISTS storytelling_theme TEXT
CHECK (storytelling_theme IN (
  'curiosity_hook',
  'craftsmanship',
  'meaning_symbolism',
  'transformation',
  'hidden_detail',
  'lifestyle_aspiration',
  'legacy_timelessness'
));
