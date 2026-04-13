-- Add status column to sales and purchases to handle returns without deletion
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'sales' AND column_name = 'status'
    ) THEN
        ALTER TABLE sales ADD COLUMN status TEXT DEFAULT 'active';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'purchases' AND column_name = 'status'
    ) THEN
        ALTER TABLE purchases ADD COLUMN status TEXT DEFAULT 'active';
    END IF;
END
$$;
