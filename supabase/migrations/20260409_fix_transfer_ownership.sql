-- Fix ownership transfer so previous owner is inserted as Manager in shop_members if missing
create or replace function rpc_transfer_shop_ownership(
  p_shop_id uuid,
  p_current_owner_id uuid,
  p_new_owner_id uuid,
  p_otp_code text
) returns jsonb as $$
declare
  v_is_owner boolean;
  v_is_member boolean;
  v_otp_valid boolean;
  v_current_user_id uuid;
  v_shop_name text;
  v_manager_role_id uuid;
  v_owner_role_id uuid;
begin
  -- Get current user ID
  v_current_user_id := auth.uid();
  
  -- Verify current user is the shop owner
  select exists (
    select 1 from shops 
    where id = p_shop_id 
    and owner_user_id = p_current_owner_id
  ) into v_is_owner;
  
  if not v_is_owner then
    return jsonb_build_object('success', false, 'error', 'Only the shop owner can initiate ownership transfer');
  end if;
  
  if v_current_user_id != p_current_owner_id then
    return jsonb_build_object('success', false, 'error', 'Unauthorized: You are not the shop owner');
  end if;
  
  -- Verify the new owner is a member of the shop
  select exists (
    select 1 from shop_members 
    where shop_id = p_shop_id 
    and user_id = p_new_owner_id
    and status = 'active'
  ) into v_is_member;
  
  if not v_is_member then
    return jsonb_build_object('success', false, 'error', 'The new owner must be an active member of the shop');
  end if;
  
  -- Verify OTP
  select exists (
    select 1 from auth_otps 
    where email = (select email from auth.users where id = p_current_owner_id)
    and code = p_otp_code 
    and expires_at > now()
  ) into v_otp_valid;
  
  if not v_otp_valid then
    return jsonb_build_object('success', false, 'error', 'Invalid or expired OTP code');
  end if;
  
  -- Get shop name
  select name into v_shop_name from shops where id = p_shop_id;

  -- Get Role IDs (try to get shop-specific roles first due to recent multi-tenant fix, fallback to global)
  select id into v_manager_role_id from roles where name = 'Manager' and (shop_id = p_shop_id or shop_id is null) order by shop_id nulls last limit 1;
  select id into v_owner_role_id from roles where name = 'Owner' and (shop_id = p_shop_id or shop_id is null) order by shop_id nulls last limit 1;
  
  -- Perform the ownership transfer
  update shops 
  set owner_user_id = p_new_owner_id
  where id = p_shop_id;
  
  -- Update or insert old owner as Manager
  if exists (select 1 from shop_members where shop_id = p_shop_id and user_id = p_current_owner_id) then
    update shop_members set role_id = v_manager_role_id where shop_id = p_shop_id and user_id = p_current_owner_id;
  else
    insert into shop_members (shop_id, user_id, role_id, status)
    values (p_shop_id, p_current_owner_id, v_manager_role_id, 'active');
  end if;
  
  -- Update new owner to Owner
  update shop_members 
  set role_id = v_owner_role_id
  where shop_id = p_shop_id 
  and user_id = p_new_owner_id;
  
  -- Delete used OTP
  delete from auth_otps 
  where email = (select email from auth.users where id = p_current_owner_id)
  and code = p_otp_code;
  
  -- Log the transfer
  insert into activity_logs (shop_id, user_id, action, entity_type, entity_id, details)
  values (
    p_shop_id,
    p_current_owner_id,
    'Transfer Ownership',
    'shop',
    p_shop_id,
    jsonb_build_object(
      'message', 'Transferred ownership of ' || v_shop_name || ' to member',
      'previous_owner_id', p_current_owner_id,
      'new_owner_id', p_new_owner_id
    )
  );
  
  return jsonb_build_object(
    'success', true, 
    'message', 'Ownership transferred successfully',
    'new_owner_id', p_new_owner_id
  );
end;
$$ language plpgsql security definer;
