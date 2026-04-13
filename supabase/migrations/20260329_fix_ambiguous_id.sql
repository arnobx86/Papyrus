-- Fix ambiguous column "id" error in get_recent_activity function
-- The error occurs because the function has an OUT parameter named "id"
-- which conflicts with column references in the query

-- First drop the function if it exists (to avoid "cannot change return type" error)
drop function if exists get_recent_activity(uuid, integer);

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
        select 1 from shops s
        where s.id = p_shop_id
        and (
            s.owner_user_id = auth.uid()
            or s.id in (
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
        al.id,
        al.action,
        al.entity_type,
        al.details,
        al.created_at,
        u.email::text as user_email
    from activity_logs al
    left join auth.users u on al.user_id = u.id
    where al.shop_id = p_shop_id
    order by al.created_at desc
    limit p_limit;
end;
$$ language plpgsql security definer;

-- Also check and fix log_activity function if it has similar issues
-- (log_activity doesn't have RETURN TABLE, so it should be fine)

comment on function get_recent_activity is 'SECURE: Returns recent activity for a shop. Fixed ambiguous column id error.';