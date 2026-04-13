-- Create returns table for Papyrus Flutter app
-- This table stores return transactions for purchases and sales

-- Create the returns table if it doesn't exist
CREATE TABLE IF NOT EXISTS returns (
    id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    shop_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('sale', 'purchase')),
    reference_id TEXT,
    amount NUMERIC NOT NULL DEFAULT 0,
    note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Disable RLS (consistent with other business tables in this app)
ALTER TABLE returns DISABLE ROW LEVEL SECURITY;

-- Add note column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'returns' AND column_name = 'note'
    ) THEN
        ALTER TABLE returns ADD COLUMN note TEXT;
    END IF;
END
$$;

-- Create index for fast lookups
CREATE INDEX IF NOT EXISTS idx_returns_shop_id ON returns(shop_id);
CREATE INDEX IF NOT EXISTS idx_returns_type ON returns(shop_id, type);
CREATE INDEX IF NOT EXISTS idx_returns_created_at ON returns(created_at);

-- Add returns table to the supabase_realtime publication
-- (This is already in the 20260328_1818_enable_products_realtime.sql migration,
-- but we add it here for completeness)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND tablename = 'returns'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE returns;
    END IF;
END
$$;

-- Insert sample data for testing (optional)
-- INSERT INTO returns (shop_id, type, reference_id, amount) VALUES
-- ('00000000-0000-0000-0000-000000000000', 'purchase', 'PUR-001', 5000),
-- ('00000000-0000-0000-0000-000000000000', 'sale', 'SALE-001', 3000);