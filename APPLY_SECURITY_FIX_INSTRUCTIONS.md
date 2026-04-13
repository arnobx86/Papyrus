# Instructions to Apply SECURITY DEFINER Fix

## Problem
Supabase is showing a critical security error about the `member_shops` view being defined with `SECURITY DEFINER` property. This is a security risk because the view enforces permissions of the view creator, not the querying user.

## Root Cause
The `check_shop_access` function (defined in `20260329_fix_rls_recursion.sql`) is created with `SECURITY DEFINER` to bypass Row Level Security (RLS) when checking shop access. The `member_shops` view uses this function, causing the security warning.

## Solution
We've created a migration file that:
1. Adds a comment explaining why `check_shop_access` needs to remain `SECURITY DEFINER`
2. Updates the `member_shops` view to explicitly use `SECURITY INVOKER` (which satisfies security scanners)
3. Adds comments explaining the security model

## Migration File
Location: `Apps/Papyrus/supabase/migrations/20260405_fix_security_definer_issue_v2.sql`

## How to Apply the Migration

### Option 1: Supabase Dashboard (Recommended)
1. Go to your Supabase project dashboard: https://supabase.com/dashboard
2. Select your Papyrus project
3. Go to **SQL Editor** in left sidebar
4. Click **New query**
5. Copy the entire contents of `Apps/Papyrus/supabase/migrations/20260405_fix_security_definer_issue_v2.sql`
6. Paste into the SQL Editor and click **Run**
7. Verify migration runs successfully (no errors)
8. You should see output confirming the view was recreated

### Option 2: Supabase CLI (if installed)
```bash
cd Apps/Papyrus
npx supabase db push
```

### Option 3: Direct SQL Execution
If you have a database client, run the SQL commands directly:
```sql
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
```

## Verification Steps

After applying the migration, verify the fix by:

### Step 1: Check View Security Properties
Run this SQL query in Supabase SQL Editor:
```sql
SELECT 
  schemaname,
  viewname,
  definition,
  security_invoker
FROM pg_views 
WHERE viewname = 'member_shops';
```

You should see `security_invoker = true` in the results.

### Step 2: Test View Functionality
Run this SQL query to ensure the view still works:
```sql
SELECT COUNT(*) FROM member_shops;
```

This should return a count (0 or more) without errors.

### Step 3: Check Function Security
Run this SQL query to verify the function comment was added:
```sql
SELECT 
  proname,
  prosecdef,
  obj_description(oid) as comment
FROM pg_proc 
WHERE proname = 'check_shop_access';
```

You should see `prosecdef = true` (meaning SECURITY DEFINER) and a comment explaining why.

### Step 4: Verify Security Error is Resolved
1. Go to your Supabase project dashboard
2. Navigate to **Database** > **Tables & Views**
3. Check if the security warning for `member_shops` is gone
4. Alternatively, check the **Security** section for any remaining warnings

## Expected Outcome
- The security error/warning about `member_shops` view should disappear
- The view should continue to work correctly (shop owners and members can see their shops)
- No functionality should be broken

## Rollback Plan
If something goes wrong, you can revert to the original view:
```sql
-- Revert to original view (without security_invoker)
drop view if exists member_shops;
create or replace view member_shops as
select s.*
from shops s
where check_shop_access(s.id);
```

## Testing After Migration
1. Open the Papyrus app
2. Log in as a shop owner
3. Verify you can see your shops
4. Log in as a shop member
5. Verify you can see shops you're a member of
6. Test creating new shops, adding members, etc.

## Timeline
Apply this migration as soon as possible to resolve the security warning and ensure compliance with security best practices.

## Support
If you encounter any issues:
1. Check the migration ran without errors
2. Verify the view exists and is accessible
3. Test with different user roles
4. Contact development support if problems persist