-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email VARCHAR UNIQUE NOT NULL,
  password_hash VARCHAR,
  first_name VARCHAR NOT NULL,
  last_name VARCHAR NOT NULL,
  is_premium BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  last_login_at TIMESTAMP WITH TIME ZONE,
  profile_image_url VARCHAR,
  auth_provider VARCHAR DEFAULT 'email',
  provider_id VARCHAR,
  preferences JSONB DEFAULT '{}',
  statistics JSONB DEFAULT '{}'
);

-- User vocabulary table
CREATE TABLE user_vocabulary (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  word VARCHAR NOT NULL,
  base_form VARCHAR NOT NULL,
  word_type VARCHAR NOT NULL,
  language VARCHAR NOT NULL,
  translations TEXT[],
  forms TEXT[],
  difficulty_level INTEGER DEFAULT 1,
  mastery_level INTEGER DEFAULT 0,
  times_seen INTEGER DEFAULT 1,
  times_correct INTEGER DEFAULT 0,
  last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  first_learned TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  next_review TIMESTAMP WITH TIME ZONE,
  is_favorite BOOLEAN DEFAULT FALSE,
  tags TEXT[],
  example_sentences TEXT[],
  source_message_id VARCHAR
);

-- Vocabulary stats table
CREATE TABLE vocabulary_stats (
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  language VARCHAR NOT NULL,
  total_words INTEGER DEFAULT 0,
  mastered_words INTEGER DEFAULT 0,
  learning_words INTEGER DEFAULT 0,
  new_words INTEGER DEFAULT 0,
  words_due_review INTEGER DEFAULT 0,
  average_mastery DECIMAL DEFAULT 0.0,
  last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  words_by_type JSONB DEFAULT '{}',
  PRIMARY KEY (user_id, language)
);

-- Chat history table
CREATE TABLE chat_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  message_data JSONB NOT NULL
);

-- Indexes
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_vocabulary_user_language ON user_vocabulary(user_id, language);
CREATE INDEX idx_vocabulary_review ON user_vocabulary(user_id, next_review);
CREATE INDEX idx_chat_history_user_time ON chat_history(user_id, timestamp);

-- Enable Row Level Security
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_vocabulary ENABLE ROW LEVEL SECURITY;
ALTER TABLE vocabulary_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_history ENABLE ROW LEVEL SECURITY;

-- RLS Policies

-- Users table policies
CREATE POLICY "Users can view own profile"
  ON users FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON users FOR UPDATE
  USING (auth.uid() = id);

-- Vocabulary table policies
CREATE POLICY "Users can view own vocabulary"
  ON user_vocabulary FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own vocabulary"
  ON user_vocabulary FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own vocabulary"
  ON user_vocabulary FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own vocabulary"
  ON user_vocabulary FOR DELETE
  USING (auth.uid() = user_id);

-- Stats table policies
CREATE POLICY "Users can view own stats"
  ON vocabulary_stats FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can upsert own stats"
  ON vocabulary_stats FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own stats"
  ON vocabulary_stats FOR UPDATE
  USING (auth.uid() = user_id);

-- Chat history policies (only for premium users)
CREATE POLICY "Premium users can view own chat history"
  ON chat_history FOR SELECT
  USING (
    auth.uid() = user_id AND
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid() AND is_premium = true
    )
  );

CREATE POLICY "Premium users can insert own chat history"
  ON chat_history FOR INSERT
  WITH CHECK (
    auth.uid() = user_id AND
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid() AND is_premium = true
    )
  );

-- Functions

-- Function to update vocabulary stats
CREATE OR REPLACE FUNCTION update_vocabulary_stats()
RETURNS TRIGGER AS $$
BEGIN
  -- Update stats when vocabulary item is modified
  INSERT INTO vocabulary_stats (
    user_id,
    language,
    total_words,
    mastered_words,
    learning_words,
    new_words,
    words_due_review,
    average_mastery,
    last_updated,
    words_by_type
  )
  SELECT
    user_id,
    language,
    COUNT(*) as total_words,
    COUNT(*) FILTER (WHERE mastery_level >= 4) as mastered_words,
    COUNT(*) FILTER (WHERE mastery_level BETWEEN 1 AND 3) as learning_words,
    COUNT(*) FILTER (WHERE times_seen = 1) as new_words,
    COUNT(*) FILTER (WHERE next_review <= NOW()) as words_due_review,
    AVG(mastery_level) as average_mastery,
    NOW() as last_updated,
    jsonb_object_agg(
      word_type,
      COUNT(*)
    ) as words_by_type
  FROM user_vocabulary
  WHERE user_id = NEW.user_id AND language = NEW.language
  GROUP BY user_id, language
  ON CONFLICT (user_id, language) DO UPDATE
  SET
    total_words = EXCLUDED.total_words,
    mastered_words = EXCLUDED.mastered_words,
    learning_words = EXCLUDED.learning_words,
    new_words = EXCLUDED.new_words,
    words_due_review = EXCLUDED.words_due_review,
    average_mastery = EXCLUDED.average_mastery,
    last_updated = EXCLUDED.last_updated,
    words_by_type = EXCLUDED.words_by_type;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update stats on vocabulary changes
CREATE TRIGGER update_vocabulary_stats_trigger
  AFTER INSERT OR UPDATE OR DELETE ON user_vocabulary
  FOR EACH ROW
  EXECUTE FUNCTION update_vocabulary_stats(); 