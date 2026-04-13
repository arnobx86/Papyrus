-- 🚀 🚀 🚀 FINAL SCHEMA RESOLUTION (2027)
-- This is a fresh version to overcome CLI state issues.

DO $$
BEGIN
    -- 1. Create/Alter Columns for Sales
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'sales' AND column_name = 'vat_percent') THEN
        ALTER TABLE sales ADD COLUMN vat_percent NUMERIC(5,2) DEFAULT 0;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'sales' AND column_name = 'status') THEN
        ALTER TABLE sales ADD COLUMN status TEXT DEFAULT 'active';
    END IF;

    -- 2. Create/Alter Columns for Purchases
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'purchases' AND column_name = 'vat_percent') THEN
        ALTER TABLE purchases ADD COLUMN vat_percent NUMERIC(5,2) DEFAULT 0;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'purchases' AND column_name = 'status') THEN
        ALTER TABLE purchases ADD COLUMN status TEXT DEFAULT 'active';
    END IF;
END $$;
