ALTER TABLE public.chat_history
ADD COLUMN IF NOT EXISTS translation TEXT,
ADD COLUMN IF NOT EXISTS new_vocabulary JSONB,
ADD COLUMN IF NOT EXISTS corrections JSONB,
ADD COLUMN IF NOT EXISTS follow_up_question TEXT; 