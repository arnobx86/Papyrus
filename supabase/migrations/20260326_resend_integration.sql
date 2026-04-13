-- 1. Enable extensions
create extension if not exists pg_net;

-- 2. Auth OTPs table (if not exists)
create table if not exists auth_otps (
  id uuid default gen_random_uuid() primary key,
  email text not null,
  code text not null,
  expires_at timestamptz not null default (now() + interval '10 minutes'),
  created_at timestamptz not null default now()
);

-- Index for fast lookup
create index if not exists idx_auth_otps_email_code on auth_otps(email, code);

-- 3. Resend Email Function
-- This function calls the Resend API via pg_net
create or replace function send_resend_email(
  p_to text,
  p_subject text,
  p_html text
) returns void as $$
declare
  request_id bigint;
begin
  select net.http_post(
    url := 'https://api.resend.com/emails',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer re_9vNeMKyk_Jp223UJhKFvKaTT1V4vjNJrq'
    ),
    body := jsonb_build_object(
      'from', 'Papyrus <onboarding@resend.dev>',
      'to', array[p_to],
      'subject', p_subject,
      'html', p_html
    )
  ) into request_id;
end;
$$ language plpgsql security definer;

-- 4. RPC for Sending OTP
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
  else
    v_subject := 'Reset Your Password - Papyrus';
  end if;
  
  v_html := '<div style="font-family: sans-serif; max-width: 400px; margin: 0 auto; padding: 20px; border: 1px solid #e0e0e0; border-radius: 12px; text-align: center;">' ||
            '<h2 style="color: #154834; margin-bottom: 24px;">Papyrus Business Suite</h2>' ||
            '<p style="color: #666; font-size: 16px;">Use the 6-digit code below to continue:</p>' ||
            '<div style="background: #f4f4f4; padding: 16px; border-radius: 8px; margin: 24px 0; font-size: 32px; font-weight: bold; letter-spacing: 4px; color: #154834;">' ||
            v_code || '</div>' ||
            '<p style="color: #999; font-size: 12px; margin-top: 24px;">This code will expire in 10 minutes.</p>' ||
            '</div>';
            
  -- Send Email
  perform send_resend_email(p_email, v_subject, v_html);
end;
$$ language plpgsql security definer;

-- 5. Trigger for Invitations
create or replace function handle_new_invitation_email() 
returns trigger as $$
declare
  v_shop_name text;
  v_role_name text;
  v_html text;
begin
  -- Get shop and role names
  select name into v_shop_name from shops where id = new.shop_id;
  select name into v_role_name from roles where id = new.role_id;
  
  v_html := '<div style="font-family: sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e0e0e0; border-radius: 8px;">' ||
            '<h2 style="color: #154834;">You''ve been invited to join ' || v_shop_name || '!</h2>' ||
            '<p>Hello,</p>' ||
            '<p>You have been invited to join <strong>' || v_shop_name || '</strong> as a <strong>' || v_role_name || '</strong>.</p>' ||
            '<p>To accept this invitation, sign in or create an account in the Papyrus app.</p>' ||
            '</div>';
            
  perform send_resend_email(new.invited_email_or_phone, 'Invitation to join ' || v_shop_name, v_html);
  
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_new_invitation on shop_invitations;
create trigger on_new_invitation
  after insert on shop_invitations
  for each row execute function handle_new_invitation_email();

-- 6. RPC for Verifying OTP (Server-side to avoid timezone issues)
create or replace function rpc_verify_custom_otp(p_email text, p_code text) 
returns boolean as $$
declare
  is_valid boolean;
begin
  select exists (
    select 1 from auth_otps 
    where email = p_email 
    and code = p_code 
    and expires_at > now()
  ) into is_valid;
  
  return is_valid;
end;
$$ language plpgsql security definer;
