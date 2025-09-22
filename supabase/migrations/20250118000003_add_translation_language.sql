-- Add translation language column to user_vocabulary table
-- This tracks what language the translations are in

ALTER TABLE user_vocabulary 
ADD COLUMN translation_language VARCHAR;

-- Set default translation language to 'en' for existing records
UPDATE user_vocabulary 
SET translation_language = 'en' 
WHERE translation_language IS NULL;

-- Create index for better query performance when filtering by translation language
CREATE INDEX idx_vocabulary_translation_language ON user_vocabulary(translation_language);

-- Update the existing index to include translation language for better performance
DROP INDEX IF EXISTS idx_vocabulary_user_language;
CREATE INDEX idx_vocabulary_user_language_translation ON user_vocabulary(user_id, language, translation_language); 