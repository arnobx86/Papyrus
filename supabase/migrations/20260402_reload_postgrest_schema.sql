-- 🚀 RELOAD POSTGREST SCHEMA CACHE
-- This migration forces PostgREST to reload its schema cache to recognize new columns
-- Run this after adding new columns to tables (like vat_percent)

-- Force PostgREST to reload the schema cache
-- This will make PostgREST aware of the vat_percent column in purchases and sales tables
NOTIFY pgrst, 'reload schema';

-- Also try alternative reload methods for different PostgREST versions
-- Some versions use different channel names
DO $$
BEGIN
    -- Try to notify on the pgrst channel (standard)
    PERFORM pg_notify('pgrst', 'reload schema');
    
    -- Log that the reload was attempted
    RAISE NOTICE 'PostgREST schema reload requested';
EXCEPTION WHEN OTHERS THEN
    -- If notify fails, it's okay - the schema will eventually reload
    RAISE NOTICE 'PostgREST reload notification failed (this is okay): %', SQLERRM;
END $$;
