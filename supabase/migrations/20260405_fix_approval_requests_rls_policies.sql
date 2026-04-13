-- 🚀 FIX: Approval Requests RLS Policies
-- The approval_requests table has RLS enabled but no proper policies,
-- causing "new row violates row-level security policy" error when employees
-- try to create deletion approval requests.

-- Instead of disabling RLS, we'll add comprehensive policies that:
-- 1. Allow employees to INSERT approval requests for their shop
-- 2. Allow shop members to SELECT approval requests for their shop  
-- 3. Allow shop owners to UPDATE/DELETE approval requests

DO $$
BEGIN
    -- Check if approval_requests table exists
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'approval_requests') THEN
        
        -- Ensure RLS is enabled
        ALTER TABLE approval_requests ENABLE ROW LEVEL SECURITY;
        
        -- Drop any existing policies to avoid conflicts
        DROP POLICY IF EXISTS "approval_requests_insert_policy" ON approval_requests;
        DROP POLICY IF EXISTS "approval_requests_select_policy" ON approval_requests;
        DROP POLICY IF EXISTS "approval_requests_update_policy" ON approval_requests;
        DROP POLICY IF EXISTS "approval_requests_delete_policy" ON approval_requests;
        DROP POLICY IF EXISTS "approval_requests_all_policy" ON approval_requests;
        
        -- Policy 1: INSERT - Employees can create approval requests for their shop
        -- Employees (shop members) should be able to request approvals
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
            -- The requester_id should match the authenticated user
            (approval_requests.requester_id = auth.uid())
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
        RAISE NOTICE 'RLS policies added to approval_requests table';
        
    ELSE
        RAISE NOTICE 'approval_requests table does not exist, skipping RLS policy creation';
    END IF;
END $$;

-- Also fix any column name mismatches that might exist
-- The app code uses 'type' but migrations renamed it to 'action_type'
-- Let's ensure both columns exist for compatibility
DO $$
BEGIN
    -- Check if 'type' column exists but 'action_type' doesn't
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'approval_requests' AND column_name = 'type'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'approval_requests' AND column_name = 'action_type'
    ) THEN
        -- Rename type to action_type for consistency
        ALTER TABLE approval_requests RENAME COLUMN type TO action_type;
        RAISE NOTICE 'Renamed column "type" to "action_type" in approval_requests';
    END IF;
    
    -- Check if 'requester_id' column exists but 'requested_by' doesn't
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'approval_requests' AND column_name = 'requester_id'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'approval_requests' AND column_name = 'requested_by'
    ) THEN
        -- Rename requester_id to requested_by for consistency
        ALTER TABLE approval_requests RENAME COLUMN requester_id TO requested_by;
        RAISE NOTICE 'Renamed column "requester_id" to "requested_by" in approval_requests';
    END IF;
    
    -- Ensure reference_id column exists (used for linking to sales/purchases/products)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'approval_requests' AND column_name = 'reference_id'
    ) THEN
        ALTER TABLE approval_requests ADD COLUMN reference_id UUID;
        RAISE NOTICE 'Added reference_id column to approval_requests';
    END IF;
END $$;

-- Comment explaining the security model
COMMENT ON TABLE approval_requests IS 'RLS enabled with policies: Employees can create/view requests for their shop, owners can approve/reject/delete.';
COMMENT ON POLICY "approval_requests_insert_policy" ON approval_requests IS 'Allows shop members to create approval requests for their shop.';
COMMENT ON POLICY "approval_requests_select_policy" ON approval_requests IS 'Allows shop members to view approval requests for their shop.';
COMMENT ON POLICY "approval_requests_update_policy" ON approval_requests IS 'Allows only shop owners to update (approve/reject) approval requests.';
COMMENT ON POLICY "approval_requests_delete_policy" ON approval_requests IS 'Allows only shop owners to delete approval requests.';