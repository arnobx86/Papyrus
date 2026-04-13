-- FIX INFINITE RECURSION IN RLS POLICIES
-- This migration replaces complex recursive policies with simple, non-recursive ones

-- 1. FIRST, DISABLE ALL RLS POLICIES THAT MIGHT CAUSE RECURSION (with existence checks)
do $$
begin
  -- Core tables that should always exist
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'shops') then
    alter table shops disable row level security;
  end if;
  
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'shop_invitations') then
    alter table shop_invitations disable row level security;
  end if;
  
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'shop_members') then
    alter table shop_members disable row level security;
  end if;
  
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'products') then
    alter table products disable row level security;
  end if;
  
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'sales') then
    alter table sales disable row level security;
  end if;
  
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'purchases') then
    alter table purchases disable row level security;
  end if;
  
  -- Optional tables that might not exist
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'parties') then
    alter table parties disable row level security;
  end if;
  
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'categories') then
    alter table categories disable row level security;
  end if;
  
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'returns') then
    alter table returns disable row level security;
  end if;
  
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'wallets') then
    alter table wallets disable row level security;
  end if;
  
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'transactions') then
    alter table transactions disable row level security;
  end if;
  
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'activity_logs') then
    alter table activity_logs disable row level security;
  end if;
  
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'notifications') then
    alter table notifications disable row level security;
  end if;
  
  -- Handle roles table (should be publicly readable)
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'roles') then
    alter table roles disable row level security;
  end if;
  
  -- Handle users table if it exists in public schema
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'users') then
    alter table users disable row level security;
  end if;
end $$;

-- 2. CREATE A HELPER FUNCTION TO CHECK SHOP ACCESS (NON-RECURSIVE)
create or replace function check_shop_access(p_shop_id uuid)
returns boolean as $$
begin
  -- Check if user is owner of the shop
  if exists (select 1 from shops where id = p_shop_id and owner_user_id = auth.uid()) then
    return true;
  end if;
  
  -- Check if user is an active member of the shop
  if exists (select 1 from shop_members where shop_id = p_shop_id and user_id = auth.uid() and status = 'active') then
    return true;
  end if;
  
  return false;
end;
$$ language plpgsql security definer;

-- 3. RE-ENABLE RLS WITH SIMPLE, NON-RECURSIVE POLICIES

-- SHOPS TABLE: Only owners can see their shops
alter table shops enable row level security;
drop policy if exists "shops_select_policy" on shops;
create policy "shops_select_policy" on shops
  for select using (owner_user_id = auth.uid());

drop policy if exists "shops_insert_policy" on shops;
create policy "shops_insert_policy" on shops
  for insert with check (owner_user_id = auth.uid());

drop policy if exists "shops_update_policy" on shops;
create policy "shops_update_policy" on shops
  for update using (owner_user_id = auth.uid()) with check (owner_user_id = auth.uid());

drop policy if exists "shops_delete_policy" on shops;
create policy "shops_delete_policy" on shops
  for delete using (owner_user_id = auth.uid());

-- SHOP_INVITATIONS TABLE: Simple policies without subqueries to shops
alter table shop_invitations enable row level security;

-- For SELECT: Use the helper function
drop policy if exists "shop_invitations_select_policy" on shop_invitations;
create policy "shop_invitations_select_policy" on shop_invitations
  for select using (
    -- Invited user can see their own invitations (using auth.email() function)
    invited_email_or_phone = auth.email()
    OR
    -- Shop owner can see invitations (using helper function)
    check_shop_access(shop_id)
  );

-- For INSERT/UPDATE/DELETE: Only shop owners
drop policy if exists "shop_invitations_insert_policy" on shop_invitations;
create policy "shop_invitations_insert_policy" on shop_invitations
  for insert with check (check_shop_access(shop_id));

drop policy if exists "shop_invitations_update_policy" on shop_invitations;
create policy "shop_invitations_update_policy" on shop_invitations
  for update using (check_shop_access(shop_id)) with check (check_shop_access(shop_id));

drop policy if exists "shop_invitations_delete_policy" on shop_invitations;
create policy "shop_invitations_delete_policy" on shop_invitations
  for delete using (check_shop_access(shop_id));

-- SHOP_MEMBERS TABLE: Users can only see their own memberships
alter table shop_members enable row level security;
drop policy if exists "shop_members_select_policy" on shop_members;
create policy "shop_members_select_policy" on shop_members
  for select using (user_id = auth.uid());

drop policy if exists "shop_members_insert_policy" on shop_members;
create policy "shop_members_insert_policy" on shop_members
  for insert with check (user_id = auth.uid());

drop policy if exists "shop_members_update_policy" on shop_members;
create policy "shop_members_update_policy" on shop_members
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "shop_members_delete_policy" on shop_members;
create policy "shop_members_delete_policy" on shop_members
  for delete using (user_id = auth.uid());

-- 4. FOR OTHER TABLES (products, sales, purchases, etc.): Use helper function
-- We'll enable them with simple policies using the helper function

-- PRODUCTS TABLE
alter table products enable row level security;
drop policy if exists "products_select_policy" on products;
create policy "products_select_policy" on products
  for select using (check_shop_access(shop_id));

drop policy if exists "products_insert_policy" on products;
create policy "products_insert_policy" on products
  for insert with check (check_shop_access(shop_id));

drop policy if exists "products_update_policy" on products;
create policy "products_update_policy" on products
  for update using (check_shop_access(shop_id)) with check (check_shop_access(shop_id));

drop policy if exists "products_delete_policy" on products;
create policy "products_delete_policy" on products
  for delete using (check_shop_access(shop_id));

-- SALES TABLE
alter table sales enable row level security;
drop policy if exists "sales_select_policy" on sales;
create policy "sales_select_policy" on sales
  for select using (check_shop_access(shop_id));

drop policy if exists "sales_insert_policy" on sales;
create policy "sales_insert_policy" on sales
  for insert with check (check_shop_access(shop_id));

drop policy if exists "sales_update_policy" on sales;
create policy "sales_update_policy" on sales
  for update using (check_shop_access(shop_id)) with check (check_shop_access(shop_id));

drop policy if exists "sales_delete_policy" on sales;
create policy "sales_delete_policy" on sales
  for delete using (check_shop_access(shop_id));

-- PURCHASES TABLE
alter table purchases enable row level security;
drop policy if exists "purchases_select_policy" on purchases;
create policy "purchases_select_policy" on purchases
  for select using (check_shop_access(shop_id));

drop policy if exists "purchases_insert_policy" on purchases;
create policy "purchases_insert_policy" on purchases
  for insert with check (check_shop_access(shop_id));

drop policy if exists "purchases_update_policy" on purchases;
create policy "purchases_update_policy" on purchases
  for update using (check_shop_access(shop_id)) with check (check_shop_access(shop_id));

drop policy if exists "purchases_delete_policy" on purchases;
create policy "purchases_delete_policy" on purchases
  for delete using (check_shop_access(shop_id));

-- 5. UPDATE THE MEMBER_SHOPS VIEW TO USE HELPER FUNCTION
drop view if exists member_shops;
create or replace view member_shops as
select s.*
from shops s
where check_shop_access(s.id);

-- 6. SECURITY NOTE
comment on function check_shop_access is 'Non-recursive function to check if user has access to a shop (owner or active member). Used in RLS policies to avoid infinite recursion.';