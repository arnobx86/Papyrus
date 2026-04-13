-- Add RLS policies for the roles table
-- Allow all authenticated users to read roles (needed for names and permissions mapping)
-- Allow only admins/owners (if we ever allow it through UI) to modify them, or just leave it for now.

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'roles' AND schemaname = 'public') THEN
        DROP POLICY IF EXISTS "roles_select_policy" ON roles;
        CREATE POLICY "roles_select_policy" ON roles FOR SELECT TO authenticated USING (true);
    END IF;
END $$;

-- Also ensure categories are readable by members of shops or owners
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'categories' AND schemaname = 'public') THEN
        DROP POLICY IF EXISTS "categories_select_per_shop" ON categories;
        CREATE POLICY "categories_select_per_shop" ON categories FOR SELECT TO authenticated 
        USING (
            EXISTS (
                SELECT 1 FROM shops 
                WHERE shops.id = categories.shop_id 
                AND shops.owner_user_id = auth.uid()
            )
            OR
            EXISTS (
                SELECT 1 FROM shop_members
                WHERE shop_members.shop_id = categories.shop_id
                AND shop_members.user_id = auth.uid()
            )
        );
    END IF;
END $$;
