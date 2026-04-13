-- Final fix for activity logging functions
-- This migration ensures the get_recent_activity function can be recreated without errors
-- by using create or replace and dropping all possible overloaded versions

-- First, drop all possible versions of the functions with CASCADE to handle dependencies
drop function if exists get_recent_activity(uuid, integer) cascade;
drop function if exists get_recent_activity(uuid) cascade;
drop function if exists get_recent_activity(uuid, bigint) cascade;

-- Also drop log_activity functions with all possible signatures
drop function if exists log_activity(text, uuid, text, text, jsonb) cascade;
drop function if exists log_activity(text, uuid, uuid, text, text, text, jsonb) cascade;
drop function if exists log_activity(text, uuid) cascade;

-- Ensure activity_logs table has all required columns
create table if not exists activity_logs (
    id uuid primary key default gen_random_uuid(),
    shop_id uuid not null references shops(id) on delete cascade,
    user_id uuid references auth.users(id) on delete set null,
    user_email text,
    action text not null,
    entity_type text,
    entity_id text,
    details jsonb default '{}',
    created_at timestamp with time zone default now()
);

-- Add user_email column if it doesn't exist
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

-- Enable RLS if not already enabled
alter table activity_logs enable row level security;

-- Drop existing RLS policies to recreate them
drop policy if exists "Users can view activity logs for their shops" on activity_logs;
drop policy if exists "Users can insert activity logs for their shops" on activity_logs;

-- RLS Policies
-- Users can view activity logs for their shops
create policy "Users can view activity logs for their shops"
    on activity_logs for select
    using (
        exists (
            select 1 from shop_members
            where shop_members.shop_id = activity_logs.shop_id
            and shop_members.user_id = auth.uid()
            and shop_members.status = 'active'
        )
        or exists (
            select 1 from shops
            where shops.id = activity_logs.shop_id
            and shops.owner_user_id = auth.uid()
        )
    );

-- Users can insert activity logs for their shops
create policy "Users can insert activity logs for their shops"
    on activity_logs for insert
    with check (
        exists (
            select 1 from shop_members
            where shop_members.shop_id = activity_logs.shop_id
            and shop_members.user_id = auth.uid()
            and shop_members.status = 'active'
        )
        or exists (
            select 1 from shops
            where shops.id = activity_logs.shop_id
            and shops.owner_user_id = auth.uid()
        )
    );

-- Create indexes for performance if they don't exist
create index if not exists idx_activity_logs_shop_id on activity_logs(shop_id);
create index if not exists idx_activity_logs_created_at on activity_logs(created_at desc);

-- Create or replace log_activity function with explicit user_id and user_email parameters
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

-- Create or replace get_recent_activity function
create or replace function get_recent_activity(
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

-- Add comments explaining the functions
comment on function log_activity is 'Logs an activity with explicit user_id and user_email parameters';
comment on function get_recent_activity is 'Retrieves recent activities for a shop';

-- 🚀 End of migration