-- Dynamically find the enum type used for shop_members.status and add 'inactive' and 'terminated' to it
DO $$
DECLARE
    enum_type_name text;
BEGIN
    -- Query the pg_catalog to find the name of the ENUM type used by the status column
    SELECT pg_type.typname INTO enum_type_name
    FROM pg_attribute
    JOIN pg_class ON pg_class.oid = pg_attribute.attrelid
    JOIN pg_type ON pg_type.oid = pg_attribute.atttypid
    WHERE pg_class.relname = 'shop_members'
      AND pg_attribute.attname = 'status';

    -- If we found the enum type, add the new values to it
    IF enum_type_name IS NOT NULL THEN
        BEGIN
            EXECUTE format('ALTER TYPE %I ADD VALUE IF NOT EXISTS ''inactive''', enum_type_name);
        EXCEPTION WHEN duplicate_object THEN
            -- Ignore if value already exists
        END;
        
        BEGIN
            EXECUTE format('ALTER TYPE %I ADD VALUE IF NOT EXISTS ''terminated''', enum_type_name);
        EXCEPTION WHEN duplicate_object THEN
            -- Ignore if value already exists
        END;
    END IF;
END $$;
