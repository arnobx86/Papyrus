-- CRITICAL SECURITY FIX: Secure RPC functions to prevent shop access bypass
-- These functions were using security definer without proper access checks

-- 1. FIX log_activity function - Only allow logging to shops user has access to
create or replace function log_activity(
    p_action text,
    p_shop_id uuid,
    p_entity_type text default null,
    p_entity_id text default null,
    p_details jsonb default '{}'::jsonb
) returns void as $$
declare
    v_has_access boolean;
begin
    -- Check if user has access to the shop (owner or member)
    select exists (
        select 1 from shops
        where id = p_shop_id
        and (
            owner_user_id = auth.uid()
            or id in (
                select shop_id from shop_members
                where user_id = auth.uid() and status = 'active'
            )
        )
    ) into v_has_access;
    
    -- Only allow logging if user has access
    if not v_has_access then
        raise exception 'Access denied: You do not have permission to log activity for this shop';
    end if;
    
    insert into activity_logs (user_id, shop_id, action, entity_type, entity_id, details)
    values (auth.uid(), p_shop_id, p_action, p_entity_type, p_entity_id, p_details);
end;
$$ language plpgsql security definer;

-- 2. FIX get_recent_activity function - Only allow viewing activity from shops user has access to
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
declare
    v_has_access boolean;
begin
    -- Check if user has access to the shop (owner or member)
    select exists (
        select 1 from shops
        where id = p_shop_id
        and (
            owner_user_id = auth.uid()
            or id in (
                select shop_id from shop_members
                where user_id = auth.uid() and status = 'active'
            )
        )
    ) into v_has_access;
    
    -- Only allow viewing if user has access
    if not v_has_access then
        raise exception 'Access denied: You do not have permission to view activity for this shop';
    end if;
    
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

-- 3. Check for other RPC functions that might bypass RLS
-- Search for functions that take shop_id as parameter and use security definer

-- 4. FIX delete_shop_cascade function - Only allow owners to delete their shops
create or replace function delete_shop_cascade(p_shop_id uuid)
returns void as $$
declare
    v_is_owner boolean;
begin
    -- Check if user is the owner of the shop
    select exists (
        select 1 from shops
        where id = p_shop_id
        and owner_user_id = auth.uid()
    ) into v_is_owner;
    
    -- Only allow deletion if user is the owner
    if not v_is_owner then
        raise exception 'Access denied: Only shop owners can delete shops';
    end if;
    
    -- Delete Child Records across all business tables
    DELETE FROM sale_items WHERE sale_id IN (SELECT id FROM sales WHERE shop_id = p_shop_id);
    DELETE FROM purchase_items WHERE purchase_id IN (SELECT id FROM purchases WHERE shop_id = p_shop_id);
    
    DELETE FROM ledger_entries WHERE shop_id = p_shop_id;
    DELETE FROM transactions WHERE shop_id = p_shop_id;
    DELETE FROM returns WHERE shop_id = p_shop_id;
    DELETE FROM sales WHERE shop_id = p_shop_id;
    DELETE FROM purchases WHERE shop_id = p_shop_id;
    DELETE FROM products WHERE shop_id = p_shop_id;
    DELETE FROM parties WHERE shop_id = p_shop_id;
    DELETE FROM categories WHERE shop_id = p_shop_id;
    DELETE FROM wallets WHERE shop_id = p_shop_id;
    DELETE FROM activity_logs WHERE shop_id = p_shop_id;
    DELETE FROM approval_requests WHERE shop_id = p_shop_id;
    DELETE FROM shop_members WHERE shop_id = p_shop_id;
    DELETE FROM shop_invitations WHERE shop_id = p_shop_id;
    
    -- Finally delete the shop itself
    DELETE FROM shops WHERE id = p_shop_id;
end;
$$ language plpgsql security definer;

-- Security fix complete
comment on function log_activity is 'SECURE: Only allows logging to shops user owns or is a member of.';
comment on function get_recent_activity is 'SECURE: Only allows viewing activity from shops user owns or is a member of.';
comment on function delete_shop_cascade is 'SECURE: Only allows shop owners to delete their own shops.';
