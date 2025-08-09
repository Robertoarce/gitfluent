-- Add flashcard session tracking tables for spaced repetition learning

-- Flashcard sessions table for tracking study sessions
CREATE TABLE public.flashcard_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  session_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  duration_minutes INTEGER NOT NULL,
  words_studied INTEGER DEFAULT 0,
  total_cards INTEGER DEFAULT 0,
  accuracy_percentage DECIMAL(5,2) DEFAULT 0.0,
  session_type VARCHAR(50) DEFAULT 'timed', -- 'timed', 'count-based', etc.
  is_completed BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Session details for individual card performance
CREATE TABLE public.flashcard_session_cards (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID REFERENCES public.flashcard_sessions(id) ON DELETE CASCADE,
  vocabulary_item_id UUID REFERENCES public.user_vocabulary(id) ON DELETE CASCADE,
  question_type VARCHAR(50) NOT NULL, -- 'traditional', 'multiple_choice', 'fill_blank', 'reverse'
  response_time_ms INTEGER DEFAULT 0,
  was_correct BOOLEAN NOT NULL,
  difficulty_rating VARCHAR(20), -- 'again', 'hard', 'good', 'easy'
  shown_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  answered_at TIMESTAMP WITH TIME ZONE
);

-- Create indexes for better query performance
CREATE INDEX idx_flashcard_sessions_user_id ON public.flashcard_sessions(user_id);
CREATE INDEX idx_flashcard_sessions_date ON public.flashcard_sessions(session_date);
CREATE INDEX idx_flashcard_session_cards_session_id ON public.flashcard_session_cards(session_id);
CREATE INDEX idx_flashcard_session_cards_vocabulary_id ON public.flashcard_session_cards(vocabulary_item_id);
CREATE INDEX idx_flashcard_session_cards_question_type ON public.flashcard_session_cards(question_type);

-- Add trigger to update updated_at timestamp on flashcard_sessions
CREATE OR REPLACE FUNCTION update_flashcard_sessions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_flashcard_sessions_updated_at
  BEFORE UPDATE ON public.flashcard_sessions
  FOR EACH ROW
  EXECUTE FUNCTION update_flashcard_sessions_updated_at();

-- Enable Row Level Security
ALTER TABLE public.flashcard_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.flashcard_session_cards ENABLE ROW LEVEL SECURITY;

-- RLS Policies for flashcard_sessions table
CREATE POLICY "Users can view own flashcard sessions"
  ON public.flashcard_sessions FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own flashcard sessions"
  ON public.flashcard_sessions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own flashcard sessions"
  ON public.flashcard_sessions FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own flashcard sessions"
  ON public.flashcard_sessions FOR DELETE
  USING (auth.uid() = user_id);

-- RLS Policies for flashcard_session_cards table
CREATE POLICY "Users can view own flashcard session cards"
  ON public.flashcard_session_cards FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.flashcard_sessions 
      WHERE id = session_id AND user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert own flashcard session cards"
  ON public.flashcard_session_cards FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.flashcard_sessions 
      WHERE id = session_id AND user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update own flashcard session cards"
  ON public.flashcard_session_cards FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.flashcard_sessions 
      WHERE id = session_id AND user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete own flashcard session cards"
  ON public.flashcard_session_cards FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.flashcard_sessions 
      WHERE id = session_id AND user_id = auth.uid()
    )
  );

-- Add comments for documentation
COMMENT ON TABLE public.flashcard_sessions IS 'Tracks flashcard study sessions with performance metrics';
COMMENT ON TABLE public.flashcard_session_cards IS 'Individual flashcard responses within sessions';
COMMENT ON COLUMN public.flashcard_sessions.session_type IS 'Type of session: timed, count-based, etc.';
COMMENT ON COLUMN public.flashcard_session_cards.question_type IS 'Type of question: traditional, multiple_choice, fill_blank, reverse';
COMMENT ON COLUMN public.flashcard_session_cards.difficulty_rating IS 'User self-assessment: again, hard, good, easy'; 