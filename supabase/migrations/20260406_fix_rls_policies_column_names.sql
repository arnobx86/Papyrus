-- 🚀 FIX: RLS Policies Column Names
-- The RLS policies are using old column name (requester_id) 
-- but the database has renamed columns (requested_by)
-- This migration updates the RLS policies to use correct column names

DO $$
BEGIN
    -- Check if approval_requests table exists
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'approval_requests') THEN

        -- Drop any existing policies to avoid conflicts
        DROP POLICY IF EXISTS "approval_requests_insert_policy" ON approval_requests;
        DROP POLICY IF EXISTS "approval_requests_select_policy" ON approval_requests;
        DROP POLICY IF EXISTS "approval_requests_update_policy" ON approval_requests;
        DROP POLICY IF EXISTS "approval_requests_delete_policy" ON approval_requests;

        -- Policy 1: INSERT - Employees can create approval requests for their shop
        -- Using requested_by instead of requester_id
        CREATE POLICY "approval_requests_insert_policy" ON approval_requests
        FOR INSERT TO authenticated
        WITH CHECK (
            -- User must be a member of the shop they're requesting approval for
            EXISTS (
                SELECT 1 FROM shops s 
                WHERE s.id = approval_requests.shop_id 
                AND (
                    -- User is the shop owner
                    s.owner_user_id = auth.uid() 
                    OR 
                    -- User is an active member of the shop
                    EXISTS (
                        SELECT 1 FROM shop_members sm 
                        WHERE sm.shop_id = s.id 
                        AND sm.user_id = auth.uid()
                        AND sm.status = 'active'
                    )
                )
            )
            AND
            -- The requested_by should match the authenticated user
            (approval_requests.requested_by = auth.uid())
        );
        
        -- Policy 2: SELECT - Shop members can view approval requests for their shop
        CREATE POLICY "approval_requests_select_policy" ON approval_requests
        FOR SELECT TO authenticated
        USING (
            EXISTS (
                SELECT 1 FROM shops s 
                WHERE s.id = approval_requests.shop_id 
                AND (
                    -- User is the shop owner
                    s.owner_user_id = auth.uid() 
                    OR 
                    -- User is an active member of the shop
                    EXISTS (
                        SELECT 1 FROM shop_members sm 
                        WHERE sm.shop_id = s.id 
                        AND sm.user_id = auth.uid()
                        AND sm.status = 'active'
                    )
                )
            )
        );
        
        -- Policy 3: UPDATE - Only shop owners can update approval requests (approve/reject)
        CREATE POLICY "approval_requests_update_policy" ON approval_requests
        FOR UPDATE TO authenticated
        USING (
            EXISTS (
                SELECT 1 FROM shops s 
                WHERE s.id = approval_requests.shop_id 
                AND s.owner_user_id = auth.uid()
            )
        )
        WITH CHECK (
            EXISTS (
                SELECT 1 FROM shops s 
                WHERE s.id = approval_requests.shop_id 
                AND s.owner_user_id = auth.uid()
            )
        );

        -- Policy 4: DELETE - Only shop owners can delete approval requests
        CREATE POLICY "approval_requests_delete_policy" ON approval_requests
        FOR DELETE TO authenticated
        USING (
            EXISTS (
                SELECT 1 FROM shops s 
                WHERE s.id = approval_requests.shop_id 
                AND s.owner_user_id = auth.uid()
            )
        );

        -- Log the changes
        RAISE NOTICE 'RLS policies updated to use correct column names: requested_by instead of requester_id';

    ELSE
        RAISE NOTICE 'approval_requests table does not exist, skipping RLS policy update';
    END IF;
END;
$$;

-- Comment explaining the changes
COMMENT ON POLICY "approval_requests_insert_policy" ON approval_requests IS 'Allows shop members to create approval requests for their shop using requested_by column.';
COMMENT ON POLICY "approval_requests_select_policy" ON approval_requests IS 'Allows shop members to view approval requests for their shop.';
COMMENT ON POLICY "approval_requests_update_policy" ON approval_requests IS 'Allows only shop owners to update (approve/reject) approval requests.';
COMMENT ON POLICY "approval_requests_delete_policy" ON approval_requests IS 'Allows only shop owners to delete approval requests.';