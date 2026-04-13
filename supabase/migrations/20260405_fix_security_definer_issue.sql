-- Fix SECURITY DEFINER issue for member_shops view
-- The check_shop_access function was defined with SECURITY DEFINER which causes security warnings
-- This migration provides a safer alternative that maintains functionality while fixing security issues

-- 1. First, check if we can safely change the function to SECURITY INVOKER
-- We'll create a new function with a different name first for testing
create or replace function check_shop_access_safe(p_shop_id uuid)
returns boolean as $$
declare
  v_is_owner boolean;
  v_is_member boolean;
begin
  -- Use a safer approach: check access without disabling RLS
  -- First check if user is owner (shops table has RLS allowing owners to see their shops)
  select exists (
    select 1 from shops
    where id = p_shop_id and owner_user_id = auth.uid()
  ) into v_is_owner;
  
  if v_is_owner then
    return true;
  end if;
  
  -- Check if user is an active member (shop_members table has RLS allowing users to see their own memberships)
  select exists (
    select 1 from shop_members
    where shop_id = p_shop_id and user_id = auth.uid() and status = 'active'
  ) into v_is_member;
  
  return v_is_member;
end;
$$ language plpgsql security invoker;

-- 2. Update member_shops view to use the safe function and explicitly set security_invoker
-- This ensures the view runs with the privileges of the invoking user
drop view if exists member_shops;
create or replace view member_shops with (security_invoker = true) as
select s.*
from shops s
where check_shop_access_safe(s.id);

-- 3. Test the new function works correctly by creating a test view
-- (This is optional and can be removed after verification)
create or replace view test_shop_access as
select
  s.id as shop_id,
  s.name as shop_name,
  check_shop_access_safe(s.id) as has_access,
  check_shop_access(s.id) as has_access_old
from shops s
limit 5;

-- 4. After verifying the new function works, rename it to replace the old one
-- First, drop the old function
drop function if exists check_shop_access(uuid);

-- Rename the new function to the original name
alter function check_shop_access_safe(uuid) rename to check_shop_access;

-- 5. Update the view to use the renamed function
drop view if exists member_shops;
create or replace view member_shops with (security_invoker = true) as
select s.*
from shops s
where check_shop_access(s.id);

-- 6. Clean up test view
drop view if exists test_shop_access;

-- 7. Add comments explaining the security model
comment on function check_shop_access is 'Checks if current user has access to a shop (owner or active member). Uses SECURITY INVOKER and respects RLS policies.';
comment on view member_shops is 'Shows shops that the current user has access to (as owner or active member). Uses SECURITY INVOKER to respect RLS.';

-- 8. Important: Verify that RLS policies on shops and shop_members tables allow
--    users to see records where they are owners/members
--    Existing policies should be:
--    - shops: SELECT using (owner_user_id = auth.uid())
--    - shop_members: SELECT using (user_id = auth.uid())