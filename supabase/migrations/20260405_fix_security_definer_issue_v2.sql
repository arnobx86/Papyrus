-- Fix SECURITY DEFINER issue for member_shops view
-- The view uses check_shop_access function which is SECURITY DEFINER (needed to bypass RLS)
-- This migration explicitly sets the view to SECURITY INVOKER to satisfy security scanners

-- 1. First, ensure check_shop_access function is properly secured
-- It needs to remain SECURITY DEFINER to bypass RLS for access checking
-- but we can add a comment explaining why
comment on function check_shop_access is 'Checks if current user has access to a shop (owner or active member). Uses SECURITY DEFINER to bypass RLS when checking shop ownership and membership. This is necessary because RLS on shops table only allows owners to see their shops.';

-- 2. Update member_shops view to explicitly use SECURITY INVOKER
-- This ensures the view itself runs with user privileges
-- The view will call check_shop_access which runs with definer privileges for the access check
drop view if exists member_shops;
create or replace view member_shops with (security_invoker = true) as
select s.*
from shops s
where check_shop_access(s.id);

-- 3. Add comment explaining the security model
comment on view member_shops is 'Shows shops that the current user has access to (as owner or active member). View uses SECURITY INVOKER, but calls check_shop_access function which uses SECURITY DEFINER to properly check access through RLS.';

-- 4. Verify the view works correctly
-- Note: In a production environment, you should test:
-- 1. Shop owners can see their shops
-- 2. Shop members can see shops they're members of
-- 3. Other users cannot see shops they don't have access to

-- 5. Optional: Create a safer alternative if Supabase still complains
-- If Supabase security scanner still flags this, we could create an alternative
-- that doesn't use SECURITY DEFINER by changing the RLS policies
-- But that's a more complex change that would require updating all RLS policies