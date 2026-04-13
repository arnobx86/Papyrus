-- 🚀 FIX: RPC Function Column Names
-- The RPC functions are using old column names (requester_id, type) 
-- but the database has renamed columns (requested_by, action_type)
-- This migration updates the RPC functions to use correct column names

-- First, drop the existing functions to avoid parameter name conflict
DROP FUNCTION IF EXISTS insert_approval_request(UUID, UUID, TEXT, UUID, JSONB, TEXT);
DROP FUNCTION IF EXISTS update_approval_request_status(UUID, TEXT, UUID, TEXT);

-- 1. Create insert_approval_request function with correct parameter name p_requested_by
CREATE OR REPLACE FUNCTION insert_approval_request(
    p_shop_id UUID,
    p_requested_by UUID,  -- Changed from p_requester_id
    p_action_type TEXT,   -- Already correct
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
        requested_by,      -- Changed from requester_id
        action_type,       -- Already correct
        reference_id,
        details,
        status,
        created_at,
        updated_at
    ) VALUES (
        p_shop_id,
        p_requested_by,    -- Changed from p_requester_id
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

-- 2. Create update_approval_request_status function (no parameter changes needed)
CREATE OR REPLACE FUNCTION update_approval_request_status(
    p_approval_request_id UUID,
    p_status TEXT,
    p_responder_id UUID,
    p_response_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB;
    v_shop_id UUID;
    v_is_owner BOOLEAN;
BEGIN
    -- Get the shop_id from the approval request
    SELECT shop_id INTO v_shop_id
    FROM approval_requests
    WHERE id = p_approval_request_id;
    
    -- Check if responder is the shop owner
    SELECT EXISTS (
        SELECT 1 FROM shops
        WHERE id = v_shop_id AND owner_user_id = p_responder_id
    ) INTO v_is_owner;
    
    IF NOT v_is_owner THEN
        RETURN jsonb_build_object(
            'error', 'Only shop owners can approve/reject approval requests',
            'detail', 'PERMISSION_DENIED'
        );
    END IF;
    
    -- Update the approval request with correct column names
    UPDATE approval_requests
    SET 
        status = p_status,
        responder_id = p_responder_id,
        response_notes = p_response_notes,
        responded_at = NOW(),
        updated_at = NOW()
    WHERE id = p_approval_request_id;
    
    -- Return the updated approval request
    SELECT row_to_json(approval_requests)::JSONB
    INTO v_result
    FROM approval_requests
    WHERE id = p_approval_request_id;
    
    RETURN v_result;
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'error', SQLERRM,
        'detail', SQLSTATE
    );
END;
$$;

-- 3. Keep get_shop_approval_requests function (no changes needed)
-- This function uses SELECT * so it automatically gets all columns

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION insert_approval_request TO authenticated;
GRANT EXECUTE ON FUNCTION update_approval_request_status TO authenticated;
GRANT EXECUTE ON FUNCTION get_shop_approval_requests TO authenticated;

-- Comment explaining the changes
COMMENT ON FUNCTION insert_approval_request IS 'Inserts a new approval request using correct column names (requested_by instead of requester_id).';
COMMENT ON FUNCTION update_approval_request_status IS 'Updates approval request status (approve/reject), only allowed for shop owners.';
COMMENT ON FUNCTION get_shop_approval_requests IS 'Gets approval requests for a shop, with optional status filter.';

-- Log the changes
DO $$
BEGIN
    RAISE NOTICE 'RPC functions updated to use correct column names: requested_by instead of requester_id';
END;
$$;