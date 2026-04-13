-- 🚀 ONE-TIME EMERGENCY FIX (v2)
-- This migration ensures all missing columns and CORRECT RPC signatures are active.
-- Resolved: log_activity and get_recent_activity mismatch.

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

    -- 3. Add approved_by to approval_requests
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'approval_requests' AND column_name = 'approved_by') THEN
        ALTER TABLE approval_requests ADD COLUMN approved_by UUID REFERENCES auth.users(id);
    END IF;
    
    -- 4. Add user_email column to activity_logs
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'activity_logs' AND column_name = 'user_email') THEN
        ALTER TABLE activity_logs ADD COLUMN user_email TEXT;
    END IF;
END $$;

-- 5. Drop and Recreate Log Activity with the signature expected by Dart code
DROP FUNCTION IF EXISTS log_activity(text, uuid, text, text, jsonb) CASCADE;
DROP FUNCTION IF EXISTS log_activity(text, uuid, uuid, text, text, text, jsonb) CASCADE;

CREATE OR REPLACE FUNCTION log_activity(
    p_action text,
    p_shop_id uuid,
    p_user_id uuid DEFAULT NULL,
    p_user_email text DEFAULT NULL,
    p_entity_type text DEFAULT NULL,
    p_entity_id text DEFAULT NULL,
    p_details jsonb DEFAULT '{}'
)
RETURNS void AS $$
BEGIN
    INSERT INTO activity_logs (
        shop_id, user_id, user_email, action, entity_type, entity_id, details
    )
    VALUES (
        p_shop_id, 
        COALESCE(p_user_id, auth.uid()), 
        COALESCE(p_user_email, (SELECT email FROM auth.users WHERE id = auth.uid())),
        p_action, 
        p_entity_type, 
        p_entity_id, 
        p_details
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Drop and Recreate Get Recent Activity with the expected signature
DROP FUNCTION IF EXISTS get_recent_activity(uuid, integer) CASCADE;

CREATE OR REPLACE FUNCTION get_recent_activity(
    p_shop_id uuid,
    p_limit int DEFAULT 20
)
RETURNS TABLE (
    id uuid,
    shop_id uuid,
    user_id uuid,
    user_email text,
    action text,
    entity_type text,
    entity_id text,
    details jsonb,
    created_at timestamptz
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        al.id, al.shop_id, al.user_id, al.user_email, al.action, 
        al.entity_type, al.entity_id, al.details, al.created_at
    FROM activity_logs al
    WHERE al.shop_id = p_shop_id
    ORDER BY al.created_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
