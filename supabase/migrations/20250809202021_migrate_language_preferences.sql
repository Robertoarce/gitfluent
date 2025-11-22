-- Add new language preference columns to the users table
ALTER TABLE public.users
ADD COLUMN target_language VARCHAR DEFAULT 'it',
ADD COLUMN native_language VARCHAR DEFAULT 'en',
ADD COLUMN support_language_1 VARCHAR,
ADD COLUMN support_language_2 VARCHAR;

-- Migrate existing language preferences from the preferences JSONB column
UPDATE public.users
SET
  target_language = COALESCE(preferences->>'target_language', 'it'),
  native_language = COALESCE(preferences->>'native_language', 'en'),
  support_language_1 = preferences->>'support_language_1',
  support_language_2 = preferences->>'support_language_2';

-- Update the default value of the preferences column to remove language settings
ALTER TABLE public.users
ALTER COLUMN preferences SET DEFAULT '{
  "notifications_enabled": true,
  "sound_enabled": true,
  "theme": "system",
  "ai_provider": "gemini",
  "max_verbs": 5,
  "max_nouns": 10
}'::jsonb;

-- Remove language-related fields from existing preferences JSONB for all users
UPDATE public.users
SET preferences = jsonb_strip_nulls(jsonb_build_object(
    'notifications_enabled', preferences->'notifications_enabled',
    'sound_enabled', preferences->'sound_enabled',
    'theme', preferences->'theme',
    'ai_provider', preferences->'ai_provider',
    'max_verbs', preferences->'max_verbs',
    'max_nouns', preferences->'max_nouns'
));
