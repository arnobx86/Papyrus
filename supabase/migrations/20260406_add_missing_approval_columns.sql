-- 🚀 FIX: Add missing updated_at column to approval_requests table
-- The RPC function was trying to insert into updated_at but the column doesn't exist

DO $$
BEGIN
    -- Check if approval_requests table exists
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'approval_requests') THEN
        
        -- Add updated_at column if it doesn't exist
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'approval_requests' 
            AND column_name = 'updated_at'
        ) THEN
            ALTER TABLE approval_requests ADD COLUMN updated_at timestamptz DEFAULT now();
            RAISE NOTICE 'Added updated_at column to approval_requests table';
        ELSE
            RAISE NOTICE 'updated_at column already exists in approval_requests table';
        END IF;
        
        -- Add responder_id column if it doesn't exist (needed for update_approval_request_status)
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'approval_requests' 
            AND column_name = 'responder_id'
        ) THEN
            ALTER TABLE approval_requests ADD COLUMN responder_id uuid REFERENCES auth.users(id);
            RAISE NOTICE 'Added responder_id column to approval_requests table';
        END IF;
        
        -- Add response_notes column if it doesn't exist
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'approval_requests' 
            AND column_name = 'response_notes'
        ) THEN
            ALTER TABLE approval_requests ADD COLUMN response_notes text;
            RAISE NOTICE 'Added response_notes column to approval_requests table';
        END IF;
        
        -- Add responded_at column if it doesn't exist
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'approval_requests' 
            AND column_name = 'responded_at'
        ) THEN
            ALTER TABLE approval_requests ADD COLUMN responded_at timestamptz;
            RAISE NOTICE 'Added responded_at column to approval_requests table';
        END IF;
        
    ELSE
        RAISE NOTICE 'approval_requests table does not exist, skipping';
    END IF;
END;
$$;

-- Now recreate the RPC function with the correct columns
DROP FUNCTION IF EXISTS insert_approval_request(UUID, UUID, TEXT, UUID, JSONB, TEXT);

CREATE OR REPLACE FUNCTION insert_approval_request(
    p_shop_id UUID,
    p_requested_by UUID,
    p_action_type TEXT,
    p_reference_id UUID DEFAULT NULL,
    p_details JSONB DEFAULT NULL,
    p_status TEXT DEFAULT 'pending'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_approval_request_id UUID;
    v_result JSONB;
BEGIN
    -- Insert the approval request with correct column names
    INSERT INTO approval_requests (
        shop_id,
        requested_by,
        action_type,
        reference_id,
        details,
        status,
        created_at,
        updated_at
    ) VALUES (
        p_shop_id,
        p_requested_by,
        p_action_type,
        p_reference_id,
        COALESCE(p_details, '{}'::JSONB),
        p_status,
        NOW(),
        NOW()
    )
    RETURNING id INTO v_approval_request_id;
    
    -- Return the created approval request
    SELECT row_to_json(approval_requests)::JSONB
    INTO v_result
    FROM approval_requests
    WHERE id = v_approval_request_id;
    
    RETURN v_result;
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'error', SQLERRM,
        'detail', SQLSTATE
    );
END;
$$;

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION insert_approval_request TO authenticated;

COMMENT ON FUNCTION insert_approval_request IS 'Inserts a new approval request using correct column names.';