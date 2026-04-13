-- 1. Drop global unique constraint on role name so shops can have custom roles with identical names
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'roles_name_key') THEN
        ALTER TABLE roles DROP CONSTRAINT roles_name_key;
    END IF;
    
    -- Drop old index if it exists
    DROP INDEX IF EXISTS roles_name_shop_id_idx;
    
    -- Add composite unique index for name and shop_id (treating nulls as distinct)
    CREATE UNIQUE INDEX roles_name_shop_id_idx ON roles (name, COALESCE(shop_id, '00000000-0000-0000-0000-000000000000'::uuid));
END $$;

-- 2. Fix Roles Select Policy to prevent cross-tenant data leakage
DO $$
BEGIN
    DROP POLICY IF EXISTS "roles_select_policy" ON roles;
    
    CREATE POLICY "roles_select_policy" ON roles 
    FOR SELECT TO authenticated 
    USING (
        -- Can read global roles (system defaults)
        shop_id IS NULL
        OR 
        -- Can read roles for shops the user belongs to
        EXISTS (
            SELECT 1 FROM shop_members
            WHERE shop_members.shop_id = roles.shop_id
            AND shop_members.user_id = auth.uid()
        )
        OR
        -- Can read roles for shops the user owns
        EXISTS (
            SELECT 1 FROM shops
            WHERE shops.id = roles.shop_id
            AND shops.owner_user_id = auth.uid()
        )
    );
END $$;
