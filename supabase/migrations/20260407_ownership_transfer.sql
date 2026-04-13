-- Migration: Shop Ownership Transfer with OTP Verification
-- Date: 2026-04-07
-- Purpose: Enable shop owners to transfer ownership to another member with OTP verification

-- 1. Update rpc_send_custom_otp to support ownership transfer OTP type
create or replace function rpc_send_custom_otp(p_email text, p_type text) 
returns void as $$
declare
  v_code text;
  v_subject text;
  v_html text;
begin
  -- Generate 6-digit code
  v_code := floor(random() * 900000 + 100000)::text;
  
  -- Store in table
  insert into auth_otps (email, code) values (p_email, v_code);
  
  -- Prepare Email
  if p_type = 'otp-signup' then
    v_subject := 'Confirm Your Signup - Papyrus';
  elsif p_type = 'otp-delete-shop' then
    v_subject := 'CRITICAL: Shop Deletion Verification Code - Papyrus';
  elsif p_type = 'otp-ownership-transfer' then
    v_subject := 'CRITICAL: Shop Ownership Transfer Verification - Papyrus';
  else
    v_subject := 'Reset Your Password - Papyrus';
  end if;
  
  -- HTML template for ownership transfer (more urgent tone)
  if p_type = 'otp-ownership-transfer' then
    v_html := '<div style="font-family: sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 2px solid #dc2626; border-radius: 12px; text-align: center; background: #fef2f2;">' ||
              '<h2 style="color: #dc2626; margin-bottom: 16px;">⚠️ Shop Ownership Transfer</h2>' ||
              '<p style="color: #666; font-size: 16px;">You are about to transfer ownership of your shop. Use the verification code below to confirm:</p>' ||
              '<div style="background: #ffffff; padding: 16px; border-radius: 8px; margin: 24px 0; font-size: 32px; font-weight: bold; letter-spacing: 4px; color: #dc2626; border: 1px solid #fecaca;">' ||
              v_code || '</div>' ||
              '<p style="color: #999; font-size: 12px; margin-top: 24px;">⚠️ This action is irreversible. This code will expire in 10 minutes.</p>' ||
              '<p style="color: #999; font-size: 11px; margin-top: 8px;">If you did not initiate this transfer, please contact support immediately.</p>' ||
              '</div>';
  else
    v_html := '<div style="font-family: sans-serif; max-width: 400px; margin: 0 auto; padding: 20px; border: 1px solid #e0e0e0; border-radius: 12px; text-align: center;">' ||
              '<h2 style="color: #154834; margin-bottom: 24px;">Papyrus Business Suite</h2>' ||
              '<p style="color: #666; font-size: 16px;">Use the 6-digit code below to continue:</p>' ||
              '<div style="background: #f4f4f4; padding: 16px; border-radius: 8px; margin: 24px 0; font-size: 32px; font-weight: bold; letter-spacing: 4px; color: #154834;">' ||
              v_code || '</div>' ||
              '<p style="color: #999; font-size: 12px; margin-top: 24px;">This code will expire in 10 minutes.</p>' ||
              '</div>';
  end if;
          
  -- Send Email
  perform send_resend_email(p_email, v_subject, v_html);
end;
$$ language plpgsql security definer;

-- 2. Create RPC function for ownership transfer
-- This function validates the OTP and transfers ownership
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
begin
  -- Get current user ID (the one making the request)
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
  
  -- Verify current user is the one making the request
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
  
  -- Get shop name for logging
  select name into v_shop_name from shops where id = p_shop_id;
  
  -- Perform the ownership transfer
  update shops 
  set owner_user_id = p_new_owner_id
  where id = p_shop_id;
  
  -- Update the old owner's role to Manager (or keep as member)
  update shop_members 
  set role_id = (select id from roles where name = 'Manager' limit 1)
  where shop_id = p_shop_id 
  and user_id = p_current_owner_id;
  
  -- Update the new owner's role to Owner (or remove from members if they become owner)
  -- Option 1: Keep them in members with Owner role
  update shop_members 
  set role_id = (select id from roles where name = 'Owner' limit 1)
  where shop_id = p_shop_id 
  and user_id = p_new_owner_id;
  
  -- Delete used OTP
  delete from auth_otps 
  where email = (select email from auth.users where id = p_current_owner_id)
  and code = p_otp_code;
  
  -- Log the transfer in activity_logs
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

-- 3. Add RLS policy for activity_logs to allow ownership transfer logging
-- (Assuming activity_logs already has appropriate policies)
