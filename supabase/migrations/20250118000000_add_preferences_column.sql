-- Add preferences column to users table
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS preferences jsonb DEFAULT '{
  "notifications_enabled": true,
  "sound_enabled": true,
  "theme": "system",
  "ai_provider": "gemini",
  "max_verbs": 5,
  "max_nouns": 10
}'::jsonb;

-- Update existing users to have the default preferences if they don't have any
UPDATE public.users 
SET preferences = '{
  "notifications_enabled": true,
  "sound_enabled": true,
  "theme": "system",
  "ai_provider": "gemini",
  "max_verbs": 5,
  "max_nouns": 10
}'::jsonb
WHERE preferences IS NULL OR preferences = '{}'::jsonb; 