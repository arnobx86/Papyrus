-- 🚀 PAPYRUS SCHEMA UPDATE
-- Adding vat_percent to sales and purchases tables to support accurate tax tracking and editing.

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'purchases' AND column_name = 'vat_percent') THEN
        ALTER TABLE purchases ADD COLUMN vat_percent NUMERIC(5,2) DEFAULT 0;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'sales' AND column_name = 'vat_percent') THEN
        ALTER TABLE sales ADD COLUMN vat_percent NUMERIC(5,2) DEFAULT 0;
    END IF;
END $$;
