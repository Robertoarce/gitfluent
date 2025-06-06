-- Drop the trigger associated with the conversations table
DROP TRIGGER IF EXISTS update_conversations_updated_at ON conversations;

-- Drop the conversations table
DROP TABLE IF EXISTS conversations;

-- Drop the function that updates the 'updated_at' column.
-- This function was created specifically for the conversations table.
DROP FUNCTION IF EXISTS update_updated_at_column(); 