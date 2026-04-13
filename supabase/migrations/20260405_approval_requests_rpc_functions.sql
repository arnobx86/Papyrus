-- 🚀 APPROVAL REQUESTS RPC FUNCTIONS
-- These functions bypass PostgREST's schema cache to work around the "Could not find column" error
-- Use these functions instead of direct insert/update operations for approval requests

-- Function to insert a new approval request
CREATE OR REPLACE FUNCTION insert_approval_request(
    p_shop_id UUID,
    p_requester_id UUID,
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
    -- Insert the approval request with all columns
    INSERT INTO approval_requests (
        shop_id,
        requester_id,
        action_type,
        reference_id,
        details,
        status,
        created_at,
        updated_at
    ) VALUES (
        p_shop_id,
        p_requester_id,
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

-- Function to update approval request status (approve/reject)
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
    
    -- Update the approval request
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

-- Function to get approval requests for a shop
CREATE OR REPLACE FUNCTION get_shop_approval_requests(
    p_shop_id UUID,
    p_status TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB;
BEGIN
    -- Get approval requests for the shop
    IF p_status IS NULL THEN
        SELECT jsonb_agg(row_to_json(approval_requests))
        INTO v_result
        FROM approval_requests
        WHERE shop_id = p_shop_id
        ORDER BY created_at DESC;
    ELSE
        SELECT jsonb_agg(row_to_json(approval_requests))
        INTO v_result
        FROM approval_requests
        WHERE shop_id = p_shop_id AND status = p_status
        ORDER BY created_at DESC;
    END IF;
    
    RETURN COALESCE(v_result, '[]'::JSONB);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'error', SQLERRM,
        'detail', SQLSTATE
    );
END;
$$;

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION insert_approval_request TO authenticated;
GRANT EXECUTE ON FUNCTION update_approval_request_status TO authenticated;
GRANT EXECUTE ON FUNCTION get_shop_approval_requests TO authenticated;

-- Comment explaining the functions
COMMENT ON FUNCTION insert_approval_request IS 'Inserts a new approval request, bypassing PostgREST schema cache issues.';
COMMENT ON FUNCTION update_approval_request_status IS 'Updates approval request status (approve/reject), only allowed for shop owners.';
COMMENT ON FUNCTION get_shop_approval_requests IS 'Gets approval requests for a shop, with optional status filter.';