-- 🚀 ONE-TIME EMERGENCY FIX
-- This migration ensures all missing columns and schema requirements are met
-- It uses IF NOT EXISTS to prevent errors if already manually applied.

DO $$
BEGIN
    -- 1. Add status column to sales and purchases
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'sales' AND column_name = 'status') THEN
        ALTER TABLE sales ADD COLUMN status TEXT DEFAULT 'active';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'purchases' AND column_name = 'status') THEN
        ALTER TABLE purchases ADD COLUMN status TEXT DEFAULT 'active';
    END IF;

    -- 2. Add vat_percent column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'sales' AND column_name = 'vat_percent') THEN
        ALTER TABLE sales ADD COLUMN vat_percent NUMERIC(5,2) DEFAULT 0;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'purchases' AND column_name = 'vat_percent') THEN
        ALTER TABLE purchases ADD COLUMN vat_percent NUMERIC(5,2) DEFAULT 0;
    END IF;

    -- 3. Add any other missing columns (e.g. from failed migrations)
    -- Add approved_by to approval_requests
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'approval_requests' AND column_name = 'approved_by') THEN
        ALTER TABLE approval_requests ADD COLUMN approved_by UUID REFERENCES auth.users(id);
    END IF;
END $$;
