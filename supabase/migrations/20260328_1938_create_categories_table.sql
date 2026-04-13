-- Create categories table for Papyrus Flutter app
-- This table stores income/expense categories for transactions

-- Create the categories table if it doesn't exist
CREATE TABLE IF NOT EXISTS categories (
    id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    shop_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Disable RLS (consistent with other business tables in this app)
ALTER TABLE categories DISABLE ROW LEVEL SECURITY;

-- Create index for fast lookups
CREATE INDEX IF NOT EXISTS idx_categories_shop_id ON categories(shop_id);
CREATE INDEX IF NOT EXISTS idx_categories_type ON categories(shop_id, type);
CREATE INDEX IF NOT EXISTS idx_categories_name ON categories(shop_id, name);

-- Add categories table to the supabase_realtime publication for real-time sync
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND tablename = 'categories'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE categories;
    END IF;
END
$$;

-- Insert default categories for testing (optional)
-- INSERT INTO categories (shop_id, name, type) VALUES
-- ('00000000-0000-0000-0000-000000000000', 'Rent', 'expense'),
-- ('00000000-0000-0000-0000-000000000000', 'Salary', 'income'),
-- ('00000000-0000-0000-0000-000000000000', 'Utility', 'expense'),
-- ('00000000-0000-0000-0000-000000000000', 'Food', 'expense'),
-- ('00000000-0000-0000-0000-000000000000', 'Investment', 'income'),
-- ('00000000-0000-0000-0000-000000000000', 'Loan', 'expense');