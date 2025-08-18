-- Remove language fields from existing preferences JSONB data
-- This migration cleans up preferences column to only contain non-language settings

UPDATE public.users 
SET preferences = (
  preferences 
  - 'target_language' 
  - 'native_language' 
  - 'support_language_1' 
  - 'support_language_2'
)
WHERE preferences IS NOT NULL 
AND preferences != '{}'::jsonb
AND (
  preferences ? 'target_language' OR 
  preferences ? 'native_language' OR 
  preferences ? 'support_language_1' OR 
  preferences ? 'support_language_2'
);

-- Add comment for clarity
COMMENT ON COLUMN public.users.preferences IS 'JSONB column for non-language user preferences only. Language settings are stored in individual columns: target_language, native_language, support_language_1, support_language_2'; 