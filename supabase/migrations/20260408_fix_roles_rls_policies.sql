-- Fix RLS policies for the roles table to prevent unauthorized modifications
-- Currently, the roles table only has a SELECT policy (USING (true)), which means
-- any authenticated user can UPDATE, INSERT, or DELETE roles - a critical security vulnerability!

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'roles' AND schemaname = 'public') THEN
        -- First, ensure RLS is enabled on the roles table
        ALTER TABLE roles ENABLE ROW LEVEL SECURITY;
        
        -- Drop existing policies to recreate them properly
        DROP POLICY IF EXISTS "roles_select_policy" ON roles;
        DROP POLICY IF EXISTS "roles_insert_policy" ON roles;
        DROP POLICY IF EXISTS "roles_update_policy" ON roles;
        DROP POLICY IF EXISTS "roles_delete_policy" ON roles;
        
        -- SELECT POLICY: Allow all authenticated users to read roles
        -- This is needed for UI to display role names and permissions
        CREATE POLICY "roles_select_policy" ON roles 
        FOR SELECT TO authenticated 
        USING (true);
        
        -- INSERT POLICY: Only allow shop owners to insert roles for their shops
        -- Users cannot create global/system roles (shop_id IS NULL) via API
        CREATE POLICY "roles_insert_policy" ON roles
        FOR INSERT TO authenticated
        WITH CHECK (
            -- Allow insertion if:
            -- 1. Role has a shop_id (not a global role)
            -- 2. User is the owner of that shop
            shop_id IS NOT NULL
            AND EXISTS (
                SELECT 1 FROM shops
                WHERE shops.id = shop_id
                AND shops.owner_user_id = auth.uid()
            )
        );
        
        -- UPDATE POLICY: Only allow shop owners to update roles in their shop
                -- This prevents unauthorized permission modifications
                CREATE POLICY "roles_update_policy" ON roles
                FOR UPDATE TO authenticated
                USING (
                    -- Allow update if:
                    -- 1. Role is a global/system role (shop_id IS NULL) - only via migrations
                    --    For safety, we'll disallow updates to global roles via API
                    -- 2. Role belongs to a shop (shop_id IS NOT NULL) AND user is owner of that shop
                    (
                        roles.shop_id IS NOT NULL
                        AND EXISTS (
                            SELECT 1 FROM shops
                            WHERE shops.id = roles.shop_id
                            AND shops.owner_user_id = auth.uid()
                        )
                    )
                    -- Note: We don't allow updates to global roles (shop_id IS NULL) via API
                    -- These should only be modified via database migrations
                )
                WITH CHECK (
                    -- Same condition for the new row
                    (
                        shop_id IS NOT NULL
                        AND EXISTS (
                            SELECT 1 FROM shops
                            WHERE shops.id = shop_id
                            AND shops.owner_user_id = auth.uid()
                        )
                    )
                );
        
        -- DELETE POLICY: Prevent deletion of roles (safer to deactivate)
        -- Roles should not be deleted as they might be referenced by shop_members
        CREATE POLICY "roles_delete_policy" ON roles 
        FOR DELETE TO authenticated 
        USING (false); -- No one can delete roles
        
        -- Add a comment explaining the security model
        COMMENT ON TABLE roles IS 'Role-based access control. System roles (Owner, Manager, etc.) are seeded via migrations. Shop owners can create custom roles for their shops.';
        
        RAISE NOTICE 'Fixed RLS policies for roles table - now only shop owners can modify roles';
    ELSE
        RAISE NOTICE 'Roles table does not exist, skipping RLS policy fixes';
    END IF;
END $$;