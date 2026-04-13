-- Create activity_logs table
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

-- Enable RLS
alter table activity_logs enable row level security;

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

-- Create index for performance
create index if not exists idx_activity_logs_shop_id on activity_logs(shop_id);
create index if not exists idx_activity_logs_created_at on activity_logs(created_at desc);

-- Function to log activity
create or replace function log_activity(
    p_action text,
    p_shop_id uuid,
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
        auth.uid(),
        auth.email(),
        p_action,
        p_entity_type,
        p_entity_id,
        p_details
    );
end;
$$ language plpgsql security definer;

-- Function to get recent activity
-- Drop existing function if it exists with different signature
drop function if exists get_recent_activity(uuid, integer);

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
