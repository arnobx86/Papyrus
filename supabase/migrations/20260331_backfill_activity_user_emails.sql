-- Backfill user_email for existing activity logs
-- This migration updates existing activity_logs records to have user_email values
-- based on the user_id or a default value

-- First, ensure the user_email column exists
do $$
begin
    if not exists (
        select 1 from information_schema.columns 
        where table_name = 'activity_logs' 
        and column_name = 'user_email'
    ) then
        alter table activity_logs add column user_email text;
    end if;
end $$;

-- Update activities where user_id exists but user_email is null
-- Try to get email from auth.users table
update activity_logs al
set user_email = (
    select email 
    from auth.users u 
    where u.id = al.user_id
    limit 1
)
where al.user_id is not null 
and (al.user_email is null or al.user_email = '');

-- For activities where we couldn't get email from auth.users,
-- create a fallback email based on user_id
update activity_logs al
set user_email = 'user_' || substring(al.user_id::text from 1 for 8) || '@papyrus.app'
where al.user_id is not null 
and (al.user_email is null or al.user_email = '');

-- For activities with no user_id at all (system activities),
-- set a default system email
update activity_logs al
set user_email = 'system@papyrus.app'
where al.user_id is null 
and (al.user_email is null or al.user_email = '');

-- Add a comment explaining what we did
comment on column activity_logs.user_email is 'Email of the user who performed the activity. Backfilled from auth.users where possible, otherwise generated.';

-- Verify the update
do $$
declare
    total_count integer;
    null_count integer;
    updated_count integer;
begin
    select count(*) into total_count from activity_logs;
    select count(*) into null_count from activity_logs where user_email is null or user_email = '';
    select count(*) into updated_count from activity_logs where user_email is not null and user_email != '';
    
    raise notice 'Activity logs backfill completed:';
    raise notice '  Total records: %', total_count;
    raise notice '  Records with null/empty email before: %', null_count;
    raise notice '  Records with valid email after: %', updated_count;
end $$;