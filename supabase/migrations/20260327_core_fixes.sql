-- 1. Fix Shops Schema
alter table shops add column if not exists metadata jsonb default '{}'::jsonb;

-- 2. Setup Roles Table
create table if not exists roles (
  id uuid default gen_random_uuid() primary key,
  name text not null unique,
  description text,
  created_at timestamptz default now()
);

-- Seed Roles
insert into roles (name, description) values 
('Owner', 'Full access to all shop features and team management'),
('Manager', 'Management access to shop, inventory and sales. Cannot delete shop.'),
('Sales Representative', 'Can create sales and view inventory.'),
('Inventory Staff', 'Can manage products and purchase stock.')
on conflict (name) do nothing;

-- 3. Activity Logs Table
create table if not exists activity_logs (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id),
  shop_id uuid references shops(id) on delete cascade,
  action text not null,
  entity_type text,
  entity_id text,
  details jsonb default '{}'::jsonb,
  created_at timestamptz default now()
);

-- 4. RPC for efficient logging from app
create or replace function log_activity(
  p_action text,
  p_shop_id uuid,
  p_entity_type text default null,
  p_entity_id text default null,
  p_details jsonb default '{}'::jsonb
) returns void as $$
begin
  insert into activity_logs (user_id, shop_id, action, entity_type, entity_id, details)
  values (auth.uid(), p_shop_id, p_action, p_entity_type, p_entity_id, p_details);
end;
$$ language plpgsql security definer;

-- 5. RPC to get recent activity with user names
DROP FUNCTION IF EXISTS get_recent_activity(uuid, integer) CASCADE;
create or replace function get_recent_activity(p_shop_id uuid, p_limit int default 20)
returns table (
  id uuid,
  action text,
  entity_type text,
  details jsonb,
  created_at timestamptz,
  user_email text
) as $$
begin
  return query
  select 
    al.id, al.action, al.entity_type, al.details, al.created_at, u.email::text
  from activity_logs al
  left join auth.users u on al.user_id = u.id
  where al.shop_id = p_shop_id
  order by al.created_at desc
  limit p_limit;
end;
$$ language plpgsql security definer;
