-- Add image and video approval tracking columns to content_items
-- Bug #5: image_approved persists approval state across re-renders
-- Bug #8: video_approved tracks final/irreversible video approval

-- DEFAULT NULL so pre-migration rows are distinguishable from explicitly un-approved rows
ALTER TABLE content_items ADD COLUMN IF NOT EXISTS image_approved BOOLEAN DEFAULT NULL;
ALTER TABLE content_items ADD COLUMN IF NOT EXISTS video_approved BOOLEAN DEFAULT NULL;
