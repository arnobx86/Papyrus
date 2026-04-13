# How to Run Migrations

## ⚠️ URGENT: Fix for "vat_percent column does not exist" Error

If you're seeing the error "column 'vat_percent' of relation 'purchases' does not exist" when trying to save purchases or sales, run this migration immediately:

### Option 1: Supabase Dashboard (Recommended)
1. Go to your Supabase project dashboard: https://supabase.com/dashboard
2. Select your Papyrus project
3. Go to **SQL Editor** in left sidebar
4. Click **New query**
5. Copy entire contents of `supabase/migrations/20260402_fix_vat_percent_and_rpc.sql`
6. Paste into the SQL Editor and click **Run**
7. Verify migration runs successfully (no errors)
8. **Check the output** - you should see "✓ vat_percent column exists in purchases table" and "✓ vat_percent column exists in sales table"

### Option 2: Supabase CLI (if installed)
```bash
cd Apps/Papyrus
supabase db push  # Push all pending migrations
```

### What This Migration Does
This comprehensive migration:
1. **Adds `vat_percent` column** to `purchases` table if it doesn't exist
2. **Adds `vat_percent` column** to `sales` table if it doesn't exist
3. **Creates RPC functions** to bypass PostgREST schema cache:
   - `insert_purchase()` - Inserts new purchases
   - `update_purchase()` - Updates existing purchases
   - `insert_sale()` - Inserts new sales
   - `update_sale()` - Updates existing sales
4. **Verifies columns exist** with detailed output

### After Running This Migration
1. **Restart your Flutter app** (critical!)
2. Try saving a new purchase or sale
3. The error should be resolved

---

## Activity Logging Migration (Required for Dashboard Activity History)

### Option 1: Supabase Dashboard (Recommended)
1. Go to your Supabase project dashboard: https://supabase.com/dashboard
2. Select your Papyrus project
3. Go to **SQL Editor** in left sidebar
4. Click **New query**
5. Copy entire contents of `supabase/migrations/20260331_activity_logging.sql`
6. Paste into the SQL Editor and click **Run**
7. Verify migration runs successfully (no errors)

### Option 2: Supabase CLI (if installed)
```bash
cd Apps/Papyrus
supabase db push  # Push all pending migrations
```

### What This Migration Does
This migration creates the activity logging system:
1. Creates `activity_logs` table to track all user activities
2. Sets up RLS policies for secure access
3. Creates `log_activity()` function to log activities
4. Creates `get_recent_activity()` function to retrieve recent activities

### Verification Steps
After running the migration:
1. The Dashboard's Activity History should start showing activities
2. Activities like creating sales, purchases, adding transactions will be logged
3. The Activity History screen will display recent activities

---

## Activity Logging Fix Migration (Required if activities are still not showing)

If you've already run the activity logging migration but Dashboard's recent activity is still not showing any activity, run this fix migration.

### Option 1: Supabase Dashboard (Recommended)
1. Go to your Supabase project dashboard: https://supabase.com/dashboard
2. Select your Papyrus project
3. Go to **SQL Editor** in left sidebar
4. Click **New query**
5. Copy entire contents of `supabase/migrations/20260331_fix_activity_logging.sql`
6. Paste into the SQL Editor and click **Run**
7. Verify migration runs successfully (no errors)

### Option 2: Supabase CLI (if installed)
```bash
cd Apps/Papyrus
supabase db push  # Push all pending migrations
```

### What This Fix Migration Does
This migration fixes the activity logging system by:
1. Updating the `log_activity()` function to accept `user_id` and `user_email` as parameters
2. Removing dependency on `auth.uid()` and `auth.email()` which may not work correctly in `security definer` functions
3. Ensuring activities are properly logged with user information

### Verification Steps After Fix
After running the fix migration:
1. Perform any action in the app (e.g., add a product, create a sale)
2. Check the Dashboard's Activity History - it should now show the activity
3. The Activity History screen should display recent activities with user information

---

## Activity Logging Columns Fix Migration (Required if seeing "column al.user_email does not exist" error)

If you're seeing the error "column al.user_email does not exist" in the console logs, run this additional fix migration.

### Option 1: Supabase Dashboard (Recommended)
1. Go to your Supabase project dashboard: https://supabase.com/dashboard
2. Select your Papyrus project
3. Go to **SQL Editor** in left sidebar
4. Click **New query**
5. Copy entire contents of `supabase/migrations/20260331_fix_activity_logging_columns.sql`
6. Paste into the SQL Editor and click **Run**
7. Verify migration runs successfully (no errors)

### Option 2: Supabase CLI (if installed)
```bash
cd Apps/Papyrus
supabase db push  # Push all pending migrations
```

### What This Fix Migration Does
This migration fixes the "column al.user_email does not exist" error by:
1. Ensuring the `activity_logs` table exists with all required columns
2. Adding the `user_email` column if it doesn't exist
3. Recreating RLS policies and indexes
4. Dropping and recreating the functions with correct signatures

### Verification Steps After Columns Fix
After running this migration:
1. Restart your Flutter app
2. Check the console logs - the "column al.user_email does not exist" error should be gone
3. Perform any action in the app (e.g., add a product)
4. Check the Dashboard's Activity History - it should now show activities

---

## Final Activity Functions Fix Migration (Required if seeing "cannot change return type of existing function" error)

If you're getting the error "ERROR: 42P13: cannot change return type of existing function" when running migrations, run this final fix migration.

### Option 1: Supabase Dashboard (Recommended)
1. Go to your Supabase project dashboard: https://supabase.com/dashboard
2. Select your Papyrus project
3. Go to **SQL Editor** in left sidebar
4. Click **New query**
5. Copy entire contents of `supabase/migrations/20260331_final_fix_activity_functions.sql`
6. Paste into the SQL Editor and click **Run**
7. Verify migration runs successfully (no errors)

### Option 2: Supabase CLI (if installed)
```bash
cd Apps/Papyrus
supabase db push  # Push all pending migrations
```

### What This Final Fix Migration Does
This migration fixes the "cannot change return type of existing function" error by:
1. Dropping ALL possible overloaded versions of the functions with CASCADE
2. Using `create or replace function` instead of `create function` to avoid conflicts
3. Ensuring the activity_logs table has all required columns
4. Recreating RLS policies and indexes
5. Creating robust versions of both `log_activity()` and `get_recent_activity()` functions

### When to Run This Migration
Run this migration if:
- You get "cannot change return type of existing function" error
- Previous activity logging migrations have failed
- You want a clean, guaranteed-to-work migration

### Verification Steps After Final Fix
After running this migration:
1. Restart your Flutter app
2. Check the console logs - there should be no SQL errors
3. Perform any action in the app (e.g., add a product, create a sale)
4. Check the Dashboard's Activity History - it should now show activities
5. Run the verification SQL queries in the "Verification Steps for Activity Logging System" section below

---

## RLS Recursion Fix Migration

### Option 1: Supabase Dashboard (Recommended)
1. Go to your Supabase project dashboard: https://supabase.com/dashboard
2. Select your Papyrus project
3. Go to **SQL Editor** in left sidebar
4. Click **New query**
5. Copy entire contents of `supabase/migrations/20260329_fix_rls_recursion.sql`
6. Paste into the SQL Editor and click **Run**
7. Verify migration runs successfully (no errors)

### Option 2: Supabase CLI (if installed)
```bash
cd Apps/Papyrus
supabase db reset  # Only if you want to reset and apply all migrations
# OR
supabase db push  # Push all pending migrations
```

### What This Migration Fixes
This migration resolves "infinite recursion detected in policy for relation" errors by:

1. **Disabling all RLS policies** that cause circular references
2. **Creating a helper function** `check_shop_access()` that uses `security definer` to avoid recursion
3. **Re-enabling RLS with simple policies** using helper function
4. **Fixing policies for**:
   - shops table (owners only)
   - shop_invitations table (owners + invited users)
   - shop_members table (users see their own memberships)
   - products, sales, purchases tables (shop access based)

### Verification Steps
After running the migration:

1. **Test shop creation** - Should no longer show "infinite recursion" error
2. **Test shop fetching** - Owners should see their shops, members should see shops they belong to
3. **Test invitations** - Should be fetchable without recursion errors

### Rollback Instructions
If issues occur, you can run the rescue migration:
```sql
-- In Supabase SQL Editor, run:
-- supabase/migrations/20260327_rescue_migration.sql
-- This disables RLS on all tables as a fallback
```

### Expected Outcome
- ✅ No more "infinite recursion detected in policy for relation 'shops'"
- ✅ No more "infinite recursion detected in policy for relation 'shop_invitations'"
- ✅ Shop creation works normally
- ✅ Shop fetching works for owners and members
- ✅ Invitation management works correctly

---

## Verification Steps for Activity Logging System

After running all the activity logging migrations, follow these steps to verify the system is working:

### Step 1: Check Database Structure
Run this SQL query in Supabase SQL Editor to verify the activity_logs table exists with correct columns:
```sql
-- Check if activity_logs table exists with correct columns
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'activity_logs'
ORDER BY ordinal_position;
```

Expected output should include these columns:
- id (uuid)
- shop_id (uuid)
- user_id (uuid)
- user_email (text)
- action (text)
- entity_type (text)
- entity_id (text)
- details (jsonb)
- created_at (timestamp with time zone)

### Step 2: Verify Functions Exist
Run this SQL query to check if the functions exist:
```sql
-- Check if log_activity function exists
SELECT proname, proargnames, prorettype
FROM pg_proc
WHERE proname IN ('log_activity', 'get_recent_activity');

-- Alternative: Check with \df in psql
-- \df log_activity
-- \df get_recent_activity
```

### Step 3: Test Activity Logging Manually
Run this SQL to test logging an activity:
```sql
-- First, get a shop_id and user_id from your database
SELECT id as shop_id FROM shops LIMIT 1;
SELECT id as user_id, email as user_email FROM auth.users LIMIT 1;

-- Then test the log_activity function (replace with actual IDs)
SELECT log_activity(
  'Test Action',
  '00000000-0000-0000-0000-000000000000', -- Replace with actual shop_id
  '00000000-0000-0000-0000-000000000000', -- Replace with actual user_id
  'test@example.com', -- Replace with actual user_email
  'test',
  'test-123',
  '{"message": "Test activity log entry"}'::jsonb
);

-- Check if activity was logged
SELECT * FROM activity_logs ORDER BY created_at DESC LIMIT 5;
```

### Step 4: Test Retrieving Activities
Run this SQL to test the get_recent_activity function:
```sql
-- Test getting recent activities (replace with actual shop_id)
SELECT * FROM get_recent_activity('00000000-0000-0000-0000-000000000000', 10);
```

### Step 5: Test in Flutter App
1. **Restart your Flutter app**
2. **Perform any action** in the app (e.g., add a product, create a sale, invite a team member)
3. **Check the console logs** for ActivityService messages
4. **Go to Dashboard** and check if Activity History shows the activity

## Backfill User Emails for Existing Activities (Optional but Recommended)

If your activity logs show "System" instead of user emails for existing activities, run this migration to backfill user_email values for all existing activity logs.

### Why This Is Needed
- Older activities were logged before the `user_email` column was added
- Some activities may have `user_id` but no `user_email`
- This migration will populate `user_email` for all existing records

### How to Run
#### Option 1: Supabase Dashboard (Recommended)
1. Go to your Supabase project dashboard: https://supabase.com/dashboard
2. Select your Papyrus project
3. Go to **SQL Editor** in left sidebar
4. Click **New query**
5. Copy entire contents of `supabase/migrations/20260331_backfill_activity_user_emails.sql`
6. Paste into the SQL Editor and click **Run**
7. Verify migration runs successfully (no errors)

#### Option 2: Supabase CLI (if installed)
```bash
cd Apps/Papyrus
supabase db push  # Push all pending migrations
```

### What This Migration Does
1. Ensures the `user_email` column exists in `activity_logs` table
2. Updates activities where `user_id` exists but `user_email` is null:
   - Tries to get email from `auth.users` table
   - If not found, creates a fallback email like `user_<user_id_prefix>@papyrus.app`
3. Updates system activities (no `user_id`) with `system@papyrus.app`
4. Provides statistics on how many records were updated

### Verification
After running the migration:
1. Check the console output for statistics
2. Run this SQL to verify:
```sql
SELECT COUNT(*) as total,
       COUNT(CASE WHEN user_email IS NULL OR user_email = '' THEN 1 END) as empty,
       COUNT(CASE WHEN user_email LIKE 'user_%@papyrus.app' THEN 1 END) as generated,
       COUNT(CASE WHEN user_email = 'system@papyrus.app' THEN 1 END) as system
FROM activity_logs;
```

### Troubleshooting Common Issues

#### Issue 1: "column al.user_email does not exist"
**Solution**: Run the `20260331_fix_activity_logging_columns.sql` migration.

#### Issue 2: "function get_recent_activity does not exist"
**Solution**: Run all three activity logging migrations in order:
1. `20260331_activity_logging.sql`
2. `20260331_fix_activity_logging.sql`
3. `20260331_fix_activity_logging_columns.sql`

#### Issue 3: "ERROR: 42P13: cannot change return type of existing function"
**Solution**: Run the final fix migration:
1. `20260331_final_fix_activity_functions.sql`

This error occurs when trying to recreate a function that already exists with a different signature. The final fix migration drops all possible overloaded versions and uses `create or replace function` to avoid conflicts.

#### Issue 4: Activities logged but not showing in Dashboard
**Possible causes**:
1. The Dashboard is not calling `getRecentActivity()` - check `home_screen.dart`
2. The shop_id parameter is incorrect - check console logs
3. RLS policies blocking access - check RLS policies on activity_logs table

#### Issue 5: No console logs from ActivityService
**Check**:
1. Make sure you're running in debug mode
2. Check the `log` method in `activity_service.dart` is being called
3. Verify the `logActivity` method in `shop_provider.dart` is being called

#### Issue 6: Activities show "System" instead of user email
**Solution**:
1. Run the backfill migration: `20260331_backfill_activity_user_emails.sql`
2. Make sure new activities are logged with user email by checking console logs
3. Verify the updated display logic in `home_screen.dart` and `activity_history_screen.dart`

### Final Verification
If all steps pass, the activity logging system should be working correctly:
- ✅ Activities are logged when actions are performed
- ✅ Dashboard shows recent activities
- ✅ No errors in console logs
- ✅ Database contains activity records

---

## PostgREST Schema Reload Migration (Required if seeing "Could not find column" errors)

If you're seeing errors like "Could not find the 'vat_percent' column of 'purchases' in the schema cache" when saving purchases or sales, this means PostgREST's schema cache needs to be refreshed.

### When to Run This Migration
Run this migration if:
- You see "Could not find column" errors when saving purchases or sales
- You've added new columns to tables but they're not recognized by the app
- You've run schema migrations but the app still can't see the new columns

### Option 1: Supabase Dashboard (Recommended)
1. Go to your Supabase project dashboard: https://supabase.com/dashboard
2. Select your Papyrus project
3. Go to **SQL Editor** in left sidebar
4. Click **New query**
5. Copy entire contents of `supabase/migrations/20260402_reload_postgrest_schema.sql`
6. Paste into the SQL Editor and click **Run**
7. Verify migration runs successfully (no errors)

### Option 2: Supabase CLI (if installed)
```bash
cd Apps/Papyrus
supabase db push  # Push all pending migrations
```

### What This Migration Does
This migration forces PostgREST to reload its schema cache by:
1. Sending a `NOTIFY pgrst, 'reload schema'` command to PostgreSQL
2. Using `pg_notify()` as an alternative method
3. Making PostgREST aware of newly added columns like `vat_percent`

### Verification Steps After Schema Reload
After running this migration:
1. **Restart your Flutter app** (important!)
2. Try saving a new purchase or sale
3. The "Could not find column" error should be gone
4. The `vat_percent` field should work correctly

### Alternative: Manual Schema Reload
If the migration doesn't work, you can manually reload the PostgREST schema:

#### Option A: Via Supabase Dashboard
1. Go to your Supabase project dashboard
2. Navigate to **Settings** → **API**
3. Click the **Reload Schema** button (if available)

#### Option B: Via SQL Editor
Run this SQL query directly:
```sql
NOTIFY pgrst, 'reload schema';
```

#### Option C: Restart PostgREST Service
If you have access to the Supabase CLI or Docker:
```bash
# If using Supabase CLI locally
supabase stop
supabase start

# Or if using Docker
docker restart <postgrest-container-name>
```

### Troubleshooting PostgREST Schema Issues

#### Issue 1: Schema reload doesn't work immediately
**Solution**: PostgREST may take a few seconds to reload. Wait 10-15 seconds and try again.

#### Issue 2: Still seeing "Could not find column" error after reload
**Possible causes**:
1. The column doesn't actually exist in the database - verify with:
   ```sql
   SELECT column_name, data_type
   FROM information_schema.columns
   WHERE table_name = 'purchases' AND column_name = 'vat_percent';
   ```
2. PostgREST needs to be restarted - try the manual restart options above
3. There's a caching issue in the Flutter app - restart the app completely

#### Issue 3: Migration runs but error persists
**Solution**:
1. Verify the column exists in the database (see Issue 2 above)
2. Check if there are any RLS policies blocking access to the column
3. Try running the schema reload migration again
4. As a last resort, restart the entire Supabase project (if self-hosted)

### Expected Outcome
After successfully running this migration:
- ✅ PostgREST schema cache is refreshed
- ✅ New columns like `vat_percent` are recognized
- ✅ Purchases and sales can be saved without "Could not find column" errors
- ✅ The app can access all database columns correctly

---

## Purchase and Sales RPC Functions Migration (Required if PostgREST schema reload doesn't work)

If the PostgREST schema reload migration doesn't resolve the "Could not find column" error, this migration provides an alternative solution using RPC functions that bypass PostgREST's schema cache entirely.

### When to Run This Migration
Run this migration if:
- You've run the PostgREST schema reload migration but still see "Could not find column" errors
- You want a more reliable solution that doesn't depend on PostgREST's schema cache
- You're experiencing persistent issues with saving purchases or sales

### Option 1: Supabase Dashboard (Recommended)
1. Go to your Supabase project dashboard: https://supabase.com/dashboard
2. Select your Papyrus project
3. Go to **SQL Editor** in left sidebar
4. Click **New query**
5. Copy entire contents of `supabase/migrations/20260402_purchase_sales_rpc_functions.sql`
6. Paste into the SQL Editor and click **Run**
7. Verify migration runs successfully (no errors)

### Option 2: Supabase CLI (if installed)
```bash
cd Apps/Papyrus
supabase db push  # Push all pending migrations
```

### What This Migration Does
This migration creates RPC functions that bypass PostgREST's schema cache:
1. **`insert_purchase()`** - Inserts a new purchase with all columns including `vat_percent`
2. **`update_purchase()`** - Updates an existing purchase with all columns including `vat_percent`
3. **`insert_sale()`** - Inserts a new sale with all columns including `vat_percent`
4. **`update_sale()`** - Updates an existing sale with all columns including `vat_percent`

These functions use `SECURITY DEFINER` to execute with elevated privileges and bypass PostgREST's schema validation.

### How It Works
Instead of using Supabase's direct `insert()` and `update()` methods (which go through PostgREST), the app now calls these RPC functions:
- `supabase.rpc('insert_purchase', params: {...})`
- `supabase.rpc('update_purchase', params: {...})`
- `supabase.rpc('insert_sale', params: {...})`
- `supabase.rpc('update_sale', params: {...})`

The RPC functions execute directly in PostgreSQL, bypassing PostgREST's schema cache entirely.

### Verification Steps After RPC Functions Migration
After running this migration:
1. **Restart your Flutter app** (important!)
2. Try saving a new purchase or sale
3. The "Could not find column" error should be gone
4. The `vat_percent` field should work correctly

### Troubleshooting RPC Functions

#### Issue 1: "function insert_purchase does not exist"
**Solution**: Make sure you've run the `20260402_purchase_sales_rpc_functions.sql` migration.

#### Issue 2: "permission denied for function insert_purchase"
**Solution**: The migration includes `GRANT EXECUTE` statements. If you still see this error, run:
```sql
GRANT EXECUTE ON FUNCTION insert_purchase TO authenticated;
GRANT EXECUTE ON FUNCTION update_purchase TO authenticated;
GRANT EXECUTE ON FUNCTION insert_sale TO authenticated;
GRANT EXECUTE ON FUNCTION update_sale TO authenticated;
```

#### Issue 3: RPC function returns null or error
**Solution**: Check the function parameters match what's being passed from the app. The parameters should be prefixed with `p_`:
- `p_shop_id`, `p_supplier_id`, `p_invoice_number`, etc.

### Expected Outcome
After successfully running this migration:
- ✅ Purchases and sales can be saved without "Could not find column" errors
- ✅ The `vat_percent` column is properly saved and retrieved
- ✅ No dependency on PostgREST's schema cache
- ✅ More reliable and consistent behavior
