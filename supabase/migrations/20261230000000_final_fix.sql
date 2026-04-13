-- 🚀 FINAL EMERGENCY SCHEMA FIX (202612)
-- High timestamp to ensure it's forced after any conflicting migrations.

DO $$
BEGIN
    -- 1. VAT Columns
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'purchases' AND column_name = 'vat_percent') THEN
        ALTER TABLE purchases ADD COLUMN vat_percent NUMERIC(5,2) DEFAULT 0;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'sales' AND column_name = 'vat_percent') THEN
        ALTER TABLE sales ADD COLUMN vat_percent NUMERIC(5,2) DEFAULT 0;
    END IF;

    -- 2. Status Columns
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'purchases' AND column_name = 'status') THEN
        ALTER TABLE purchases ADD COLUMN status TEXT DEFAULT 'active';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'sales' AND column_name = 'status') THEN
        ALTER TABLE sales ADD COLUMN status TEXT DEFAULT 'active';
    END IF;
END $$;

-- 3. Reload PostgREST Cache (If possible)
-- NOTIFY pgrst, 'reload schema';
