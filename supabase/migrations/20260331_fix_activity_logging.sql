-- Fix activity logging functions
-- This migration updates the log_activity function to accept user_id and user_email as parameters
-- instead of relying on auth.uid() and auth.email() which may not work correctly in security definer functions

-- Drop existing functions
drop function if exists log_activity(text, uuid, text, text, jsonb);
drop function if exists get_recent_activity(uuid, integer);

-- Create updated log_activity function that accepts user_id and user_email
create or replace function log_activity(
    p_action text,
    p_shop_id uuid,
    p_user_id uuid default null,
    p_user_email text default null,
    p_entity_type text default null,
    p_entity_id text default null,
    p_details jsonb default '{}'
)
returns void as $$
begin
    insert into activity_logs (
        shop_id,
        user_id,
        user_email,
        action,
        entity_type,
        entity_id,
        details
    )
    values (
        p_shop_id,
        p_user_id,
        p_user_email,
        p_action,
        p_entity_type,
        p_entity_id,
        p_details
    );
end;
$$ language plpgsql security definer;

-- Recreate get_recent_activity function (unchanged)
create function get_recent_activity(
    p_shop_id uuid,
    p_limit int default 20
)
returns table (
    id uuid,
    shop_id uuid,
    user_id uuid,
    user_email text,
    action text,
    entity_type text,
    entity_id text,
    details jsonb,
    created_at timestamp with time zone
) as $$
begin
    return query
    select
        al.id,
        al.shop_id,
        al.user_id,
        al.user_email,
        al.action,
        al.entity_type,
        al.entity_id,
        al.details,
        al.created_at
    from activity_logs al
    where al.shop_id = p_shop_id
    order by al.created_at desc
    limit p_limit;
end;
$$ language plpgsql security definer;

-- Add comment explaining the change
comment on function log_activity is 'Logs an activity with explicit user_id and user_email parameters instead of relying on auth context';

-- Test data insertion (optional - can be removed)
-- insert into activity_logs (shop_id, user_id, user_email, action, entity_type, entity_id, details)
-- values (
--     '00000000-0000-0000-0000-000000000000', -- replace with actual shop_id
--     '00000000-0000-0000-0000-000000000000', -- replace with actual user_id
--     'test@example.com',
--     'Test Action',
--     'test',
--     'test-123',
--     '{"message": "Test activity log entry"}'::jsonb
-- );