-- Fix the shop_members select policy so that shop owners can see all members in their shop.
-- Previously it was "using (user_id = auth.uid())" which meant owners couldn't see the members they invited!

do $$
begin
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'shop_members') then
    
    -- Drop all existing policies on shop_members just to be clean
    drop policy if exists "shop_members_select_policy" on shop_members;
    drop policy if exists "shop_members_insert_policy" on shop_members;
    drop policy if exists "shop_members_update_policy" on shop_members;
    drop policy if exists "shop_members_delete_policy" on shop_members;

    -- SELECT POLICY:
    -- A user can see a shop_member record if:
    -- 1. They are the user in the record (user_id = auth.uid())
    -- 2. They are the owner of the shop the record belongs to
    -- (We don't check if they are another member of the same shop to avoid infinite recursion)
    create policy "shop_members_select_policy" on shop_members
      for select
      using (
        user_id = auth.uid()
        OR
        exists (
          select 1 from shops
          where shops.id = shop_members.shop_id
          and shops.owner_user_id = auth.uid()
        )
      );

    -- INSERT POLICY:
    -- A user can insert a shop_member record if:
    -- 1. They are inserting for themselves (accepting an invitation)
    -- 2. They are the owner of the shop
    create policy "shop_members_insert_policy" on shop_members
      for insert
      with check (
        user_id = auth.uid()
        OR
        exists (
          select 1 from shops
          where shops.id = shop_members.shop_id
          and shops.owner_user_id = auth.uid()
        )
      );

    -- UPDATE POLICY:
    -- A user can update a shop_member record if:
    -- 1. They are updating their own record
    -- 2. They are the owner of the shop
    create policy "shop_members_update_policy" on shop_members
      for update
      using (
        user_id = auth.uid()
        OR
        exists (
          select 1 from shops
          where shops.id = shop_members.shop_id
          and shops.owner_user_id = auth.uid()
        )
      )
      with check (
        user_id = auth.uid()
        OR
        exists (
          select 1 from shops
          where shops.id = shop_members.shop_id
          and shops.owner_user_id = auth.uid()
        )
      );

    -- DELETE POLICY:
    -- A user can delete a shop_member record if:
    -- 1. They are deleting their own record (leaving shop)
    -- 2. They are the owner of the shop (removing member)
    create policy "shop_members_delete_policy" on shop_members
      for delete
      using (
        user_id = auth.uid()
        OR
        exists (
          select 1 from shops
          where shops.id = shop_members.shop_id
          and shops.owner_user_id = auth.uid()
        )
      );

  end if;
end $$;
