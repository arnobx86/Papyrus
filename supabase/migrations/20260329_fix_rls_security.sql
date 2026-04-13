-- CRITICAL SECURITY FIX: Re-enable RLS and implement proper shop access control
-- This migration fixes the security breach where users could access any shop

-- 1. RE-ENABLE ROW LEVEL SECURITY (only for existing tables)
do $$
begin
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'shops') then
    alter table shops enable row level security;
  end if;
  
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'shop_members') then
    alter table shop_members enable row level security;
  end if;
  
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'shop_invitations') then
    alter table shop_invitations enable row level security;
  end if;
  
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'products') then
    alter table products enable row level security;
  end if;
  
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'sales') then
    alter table sales enable row level security;
  end if;
  
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'purchases') then
    alter table purchases enable row level security;
  end if;
  
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'parties') then
    alter table parties enable row level security;
  end if;
  
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'categories') then
    alter table categories enable row level security;
  end if;
  
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'returns') then
    alter table returns enable row level security;
  end if;
  
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'wallets') then
    alter table wallets enable row level security;
  end if;
  
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'transactions') then
    alter table transactions enable row level security;
  end if;
  
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'activity_logs') then
    alter table activity_logs enable row level security;
  end if;
  
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'notifications') then
    alter table notifications enable row level security;
  end if;
end $$;

-- 2. SHOPS TABLE RLS POLICIES - SIMPLIFIED TO AVOID RECURSION
do $$
begin
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'shops') then
    -- Users can only see shops they own
    drop policy if exists "shops_select_policy" on shops;
    create policy "shops_select_policy" on shops
      for select
      using (owner_user_id = auth.uid());

    -- Only owners can insert shops
    drop policy if exists "shops_insert_policy" on shops;
    create policy "shops_insert_policy" on shops
      for insert
      with check (owner_user_id = auth.uid());

    -- Only owners can update their shops
    drop policy if exists "shops_update_policy" on shops;
    create policy "shops_update_policy" on shops
      for update
      using (owner_user_id = auth.uid())
      with check (owner_user_id = auth.uid());

    -- Only owners can delete their shops
    drop policy if exists "shops_delete_policy" on shops;
    create policy "shops_delete_policy" on shops
      for delete
      using (owner_user_id = auth.uid());
  end if;
end $$;

-- 2b. CREATE A VIEW FOR SHOP MEMBERS TO SEE SHOPS THEY'RE MEMBERS OF
do $$
begin
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'shops')
     and exists (select from pg_tables where schemaname = 'public' and tablename = 'shop_members') then
    -- Create a secure view that shop members can use
    create or replace view member_shops as
    select s.*
    from shops s
    inner join shop_members sm on s.id = sm.shop_id
    where sm.user_id = auth.uid() and sm.status = 'active';
    
    -- Grant access to the view
    grant select on member_shops to authenticated;
  end if;
end $$;

-- 3. SHOP_MEMBERS TABLE RLS POLICIES
do $$
begin
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'shop_members') then
    -- Users can see their own membership records
    drop policy if exists "shop_members_select_policy" on shop_members;
    create policy "shop_members_select_policy" on shop_members
      for select
      using (user_id = auth.uid());

    -- Users can insert their own membership records (when accepting invites)
    drop policy if exists "shop_members_insert_policy" on shop_members;
    create policy "shop_members_insert_policy" on shop_members
      for insert
      with check (user_id = auth.uid());

    -- Users can update their own membership status
    drop policy if exists "shop_members_update_policy" on shop_members;
    create policy "shop_members_update_policy" on shop_members
      for update
      using (user_id = auth.uid())
      with check (user_id = auth.uid());

    -- Users can delete their own membership records
    drop policy if exists "shop_members_delete_policy" on shop_members;
    create policy "shop_members_delete_policy" on shop_members
      for delete
      using (user_id = auth.uid());
  end if;
end $$;

-- 4. SHOP_INVITATIONS TABLE RLS POLICIES
do $$
begin
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'shop_invitations') then
    -- Users can see invitations sent to them
    drop policy if exists "shop_invitations_select_policy" on shop_invitations;
    create policy "shop_invitations_select_policy" on shop_invitations
      for select
      using (
        -- Invited user can see invitations
        invited_email_or_phone = (
          select email from auth.users where id = auth.uid()
        )
        OR
        -- Shop owner can see invitations they sent
        exists (
          select 1 from shops
          where shops.id = shop_invitations.shop_id
          and shops.owner_user_id = auth.uid()
        )
      );

    -- Shop owners can insert invitations
    drop policy if exists "shop_invitations_insert_policy" on shop_invitations;
    create policy "shop_invitations_insert_policy" on shop_invitations
      for insert
      with check (
        shop_id in (
          select id from shops where owner_user_id = auth.uid()
        )
      );

    -- Shop owners can update invitations
    drop policy if exists "shop_invitations_update_policy" on shop_invitations;
    create policy "shop_invitations_update_policy" on shop_invitations
      for update
      using (
        shop_id in (
          select id from shops where owner_user_id = auth.uid()
        )
      )
      with check (
        shop_id in (
          select id from shops where owner_user_id = auth.uid()
        )
      );

    -- Shop owners can delete invitations
    drop policy if exists "shop_invitations_delete_policy" on shop_invitations;
    create policy "shop_invitations_delete_policy" on shop_invitations
      for delete
      using (
        shop_id in (
          select id from shops where owner_user_id = auth.uid()
        )
      );
  end if;
end $$;

-- 5. PRODUCTS TABLE RLS POLICIES
do $$
begin
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'products') then
    -- Users can only see products from shops they own or are members of
    drop policy if exists "products_select_policy" on products;
    create policy "products_select_policy" on products
      for select
      using (
        -- Check if user is owner of the shop
        exists (select 1 from shops where shops.id = products.shop_id and shops.owner_user_id = auth.uid())
        OR
        -- Check if user is an active member of the shop
        exists (select 1 from shop_members where shop_members.shop_id = products.shop_id and shop_members.user_id = auth.uid() and shop_members.status = 'active')
      );

    -- Users can insert products into their shops
    drop policy if exists "products_insert_policy" on products;
    create policy "products_insert_policy" on products
      for insert
      with check (
        shop_id in (
          select id from shops where owner_user_id = auth.uid()
        )
      );

    -- Users can update products in their shops
    drop policy if exists "products_update_policy" on products;
    create policy "products_update_policy" on products
      for update
      using (
        shop_id in (
          select id from shops where owner_user_id = auth.uid()
        )
      )
      with check (
        shop_id in (
          select id from shops where owner_user_id = auth.uid()
        )
      );

    -- Users can delete products from their shops
    drop policy if exists "products_delete_policy" on products;
    create policy "products_delete_policy" on products
      for delete
      using (
        shop_id in (
          select id from shops where owner_user_id = auth.uid()
        )
      );
  end if;
end $$;

-- 6. SALES TABLE RLS POLICIES
do $$
begin
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'sales') then
    -- Users can only see sales from shops they own or are members of
    drop policy if exists "sales_select_policy" on sales;
    create policy "sales_select_policy" on sales
      for select
      using (
        shop_id in (
          select id from shops
          where owner_user_id = auth.uid()
          OR id in (
            select shop_id from shop_members
            where user_id = auth.uid() and status = 'active'
          )
        )
      );

    -- Users can insert sales into their shops
    drop policy if exists "sales_insert_policy" on sales;
    create policy "sales_insert_policy" on sales
      for insert
      with check (
        shop_id in (
          select id from shops where owner_user_id = auth.uid()
          OR id in (
            select shop_id from shop_members
            where user_id = auth.uid() and status = 'active'
          )
        )
      );

    -- Users can update sales in their shops
    drop policy if exists "sales_update_policy" on sales;
    create policy "sales_update_policy" on sales
      for update
      using (
        shop_id in (
          select id from shops where owner_user_id = auth.uid()
        )
      )
      with check (
        shop_id in (
          select id from shops where owner_user_id = auth.uid()
        )
      );

    -- Users can delete sales from their shops
    drop policy if exists "sales_delete_policy" on sales;
    create policy "sales_delete_policy" on sales
      for delete
      using (
        shop_id in (
          select id from shops where owner_user_id = auth.uid()
        )
      );
  end if;
end $$;

-- 7. PURCHASES TABLE RLS POLICIES
do $$
begin
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'purchases') then
    -- Users can only see purchases from shops they own or are members of
    drop policy if exists "purchases_select_policy" on purchases;
    create policy "purchases_select_policy" on purchases
      for select
      using (
        shop_id in (
          select id from shops
          where owner_user_id = auth.uid()
          OR id in (
            select shop_id from shop_members
            where user_id = auth.uid() and status = 'active'
          )
        )
      );

    -- Users can insert purchases into their shops
    drop policy if exists "purchases_insert_policy" on purchases;
    create policy "purchases_insert_policy" on purchases
      for insert
      with check (
        shop_id in (
          select id from shops where owner_user_id = auth.uid()
          OR id in (
            select shop_id from shop_members
            where user_id = auth.uid() and status = 'active'
          )
        )
      );

    -- Users can update purchases in their shops
    drop policy if exists "purchases_update_policy" on purchases;
    create policy "purchases_update_policy" on purchases
      for update
      using (
        shop_id in (
          select id from shops where owner_user_id = auth.uid()
        )
      )
      with check (
        shop_id in (
          select id from shops where owner_user_id = auth.uid()
        )
      );

    -- Users can delete purchases from their shops
    drop policy if exists "purchases_delete_policy" on purchases;
    create policy "purchases_delete_policy" on purchases
      for delete
      using (
        shop_id in (
          select id from shops where owner_user_id = auth.uid()
        )
      );
  end if;
end $$;

-- 8. PARTIES TABLE RLS POLICIES
do $$
begin
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'parties') then
    -- Users can only see parties from shops they own or are members of
    drop policy if exists "parties_select_policy" on parties;
    create policy "parties_select_policy" on parties
      for select
      using (
        shop_id in (
          select id from shops
          where owner_user_id = auth.uid()
          OR id in (
            select shop_id from shop_members
            where user_id = auth.uid() and status = 'active'
          )
        )
      );

    -- Users can insert parties into their shops
    drop policy if exists "parties_insert_policy" on parties;
    create policy "parties_insert_policy" on parties
      for insert
      with check (
        shop_id in (
          select id from shops where owner_user_id = auth.uid()
          OR id in (
            select shop_id from shop_members
            where user_id = auth.uid() and status = 'active'
          )
        )
      );

    -- Users can update parties in their shops
    drop policy if exists "parties_update_policy" on parties;
    create policy "parties_update_policy" on parties
      for update
      using (
        shop_id in (
          select id from shops where owner_user_id = auth.uid()
        )
      )
      with check (
        shop_id in (
          select id from shops where owner_user_id = auth.uid()
        )
      );

    -- Users can delete parties from their shops
    drop policy if exists "parties_delete_policy" on parties;
    create policy "parties_delete_policy" on parties
      for delete
      using (
        shop_id in (
          select id from shops where owner_user_id = auth.uid()
        )
      );
  end if;
end $$;

-- 9. CATEGORIES TABLE RLS POLICIES
do $$
begin
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'categories') then
    -- Users can only see categories from shops they own or are members of
    drop policy if exists "categories_select_policy" on categories;
    create policy "categories_select_policy" on categories
      for select
      using (
        shop_id in (
          select id from shops
          where owner_user_id = auth.uid()
          OR id in (
            select shop_id from shop_members
            where user_id = auth.uid() and status = 'active'
          )
        )
      );

    -- Users can insert categories into their shops
    drop policy if exists "categories_insert_policy" on categories;
    create policy "categories_insert_policy" on categories
      for insert
      with check (
        shop_id in (
          select id from shops where owner_user_id = auth.uid()
        )
      );

    -- Users can update categories in their shops
    drop policy if exists "categories_update_policy" on categories;
    create policy "categories_update_policy" on categories
      for update
      using (
        shop_id in (
          select id from shops where owner_user_id = auth.uid()
        )
      )
      with check (
        shop_id in (
          select id from shops where owner_user_id = auth.uid()
        )
      );

    -- Users can delete categories from their shops
    drop policy if exists "categories_delete_policy" on categories;
    create policy "categories_delete_policy" on categories
      for delete
      using (
        shop_id in (
          select id from shops where owner_user_id = auth.uid()
        )
      );
  end if;
end $$;

-- 10. RETURNS TABLE RLS POLICIES
do $$
begin
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'returns') then
    -- Users can only see returns from shops they own or are members of
    drop policy if exists "returns_select_policy" on returns;
    create policy "returns_select_policy" on returns
      for select
      using (
        shop_id in (
          select id from shops
          where owner_user_id = auth.uid()
          OR id in (
            select shop_id from shop_members
            where user_id = auth.uid() and status = 'active'
          )
        )
      );

    -- Users can insert returns into their shops
    drop policy if exists "returns_insert_policy" on returns;
    create policy "returns_insert_policy" on returns
      for insert
      with check (
        shop_id in (
          select id from shops where owner_user_id = auth.uid()
          OR id in (
            select shop_id from shop_members
            where user_id = auth.uid() and status = 'active'
          )
        )
      );

    -- Users can update returns in their shops
    drop policy if exists "returns_update_policy" on returns;
    create policy "returns_update_policy" on returns
      for update
      using (
        shop_id in (
          select id from shops where owner_user_id = auth.uid()
        )
      )
      with check (
        shop_id in (
          select id from shops where owner_user_id = auth.uid()
        )
      );

    -- Users can delete returns from their shops
    drop policy if exists "returns_delete_policy" on returns;
    create policy "returns_delete_policy" on returns
      for delete
      using (
        shop_id in (
          select id from shops where owner_user_id = auth.uid()
        )
      );
  end if;
end $$;

-- 11. WALLETS TABLE RLS POLICIES
do $$
begin
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'wallets') then
    -- Users can only see wallets from shops they own or are members of
    drop policy if exists "wallets_select_policy" on wallets;
    create policy "wallets_select_policy" on wallets
      for select
      using (
        shop_id in (
          select id from shops
          where owner_user_id = auth.uid()
          OR id in (
            select shop_id from shop_members
            where user_id = auth.uid() and status = 'active'
          )
        )
      );

    -- Users can insert wallets into their shops
    drop policy if exists "wallets_insert_policy" on wallets;
    create policy "wallets_insert_policy" on wallets
      for insert
      with check (
        shop_id in (
          select id from shops where owner_user_id = auth.uid()
        )
      );

    -- Users can update wallets in their shops
    drop policy if exists "wallets_update_policy" on wallets;
    create policy "wallets_update_policy" on wallets
      for update
      using (
        shop_id in (
          select id from shops where owner_user_id = auth.uid()
        )
      )
      with check (
        shop_id in (
          select id from shops where owner_user_id = auth.uid()
        )
      );

    -- Users can delete wallets from their shops
    drop policy if exists "wallets_delete_policy" on wallets;
    create policy "wallets_delete_policy" on wallets
      for delete
      using (
        shop_id in (
          select id from shops where owner_user_id = auth.uid()
        )
      );
  end if;
end $$;

-- 12. TRANSACTIONS TABLE RLS POLICIES
do $$
begin
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'transactions') then
    -- Users can only see transactions from shops they own or are members of
    drop policy if exists "transactions_select_policy" on transactions;
    create policy "transactions_select_policy" on transactions
      for select
      using (
        shop_id in (
          select id from shops
          where owner_user_id = auth.uid()
          OR id in (
            select shop_id from shop_members
            where user_id = auth.uid() and status = 'active'
          )
        )
      );

    -- Users can insert transactions into their shops
    drop policy if exists "transactions_insert_policy" on transactions;
    create policy "transactions_insert_policy" on transactions
      for insert
      with check (
        shop_id in (
          select id from shops where owner_user_id = auth.uid()
          OR id in (
            select shop_id from shop_members
            where user_id = auth.uid() and status = 'active'
          )
        )
      );

    -- Users can update transactions in their shops
    drop policy if exists "transactions_update_policy" on transactions;
    create policy "transactions_update_policy" on transactions
      for update
      using (
        shop_id in (
          select id from shops where owner_user_id = auth.uid()
        )
      )
      with check (
        shop_id in (
          select id from shops where owner_user_id = auth.uid()
        )
      );

    -- Users can delete transactions from their shops
    drop policy if exists "transactions_delete_policy" on transactions;
    create policy "transactions_delete_policy" on transactions
      for delete
      using (
        shop_id in (
          select id from shops where owner_user_id = auth.uid()
        )
      );
  end if;
end $$;

-- 13. ACTIVITY_LOGS TABLE RLS POLICIES
do $$
begin
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'activity_logs') then
    -- Users can only see activity logs from shops they own or are members of
    drop policy if exists "activity_logs_select_policy" on activity_logs;
    create policy "activity_logs_select_policy" on activity_logs
      for select
      using (
        shop_id in (
          select id from shops
          where owner_user_id = auth.uid()
          OR id in (
            select shop_id from shop_members
            where user_id = auth.uid() and status = 'active'
          )
        )
      );

    -- Users can insert activity logs into their shops
    drop policy if exists "activity_logs_insert_policy" on activity_logs;
    create policy "activity_logs_insert_policy" on activity_logs
      for insert
      with check (
        shop_id in (
          select id from shops where owner_user_id = auth.uid()
          OR id in (
            select shop_id from shop_members
            where user_id = auth.uid() and status = 'active'
          )
        )
      );
  end if;
end $$;

-- 14. NOTIFICATIONS TABLE RLS POLICIES
do $$
begin
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'notifications') then
    -- Users can only see their own notifications
    drop policy if exists "notifications_select_policy" on notifications;
    create policy "notifications_select_policy" on notifications
      for select
      using (user_id = auth.uid());

    -- Users can insert notifications (for system use)
    drop policy if exists "notifications_insert_policy" on notifications;
    create policy "notifications_insert_policy" on notifications
      for insert
      with check (true); -- Allow system to insert notifications

    -- Users can update their own notifications (mark as read)
    drop policy if exists "notifications_update_policy" on notifications;
    create policy "notifications_update_policy" on notifications
      for update
      using (user_id = auth.uid())
      with check (user_id = auth.uid());

    -- Users can delete their own notifications
    drop policy if exists "notifications_delete_policy" on notifications;
    create policy "notifications_delete_policy" on notifications
      for delete
      using (user_id = auth.uid());
  end if;
end $$;

-- 15. ROLES TABLE - Keep RLS disabled for public access
-- Roles are shared across all shops and should be readable by all users
do $$
begin
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'roles') then
    alter table roles disable row level security;
  end if;
end $$;

-- Security fix complete
comment on table shops is 'RLS enabled: Users can only access shops they own or are members of.';
