-- Create RPC function to create categories table if missing
-- This allows the Flutter app to create the table on-demand if migration hasn't been applied

CREATE OR REPLACE FUNCTION create_categories_table_if_not_exists()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
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

    -- Create index for fast lookups if they don't exist
    CREATE INDEX IF NOT EXISTS idx_categories_shop_id ON categories(shop_id);
    CREATE INDEX IF NOT EXISTS idx_categories_type ON categories(shop_id, type);
    CREATE INDEX IF NOT EXISTS idx_categories_name ON categories(shop_id, name);

    -- Add categories table to the supabase_realtime publication for real-time sync
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND tablename = 'categories'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE categories;
    END IF;

    RAISE NOTICE 'Categories table created or already exists';
END;
$$;