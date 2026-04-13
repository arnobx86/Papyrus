-- Fix OTP email sending issues
-- 1. Update send_resend_email function to use correct sender address
-- 2. Update rpc_send_custom_otp to use professional HTML template matching Edge Function
-- 3. Update handle_new_invitation_email to use professional HTML template

-- Update the send_resend_email function with error handling
create or replace function send_resend_email(
  p_to text,
  p_subject text,
  p_html text
) returns void as $$
declare
  request_id bigint;
begin
  -- Log attempt
  raise notice 'Sending email to % with subject: %', p_to, p_subject;
  
  -- Make HTTP request using pg_net
  select net.http_post(
    url := 'https://api.resend.com/emails',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer re_9vNeMKyk_Jp223UJhKFvKaTT1V4vjNJrq'
    ),
    body := jsonb_build_object(
      'from', 'Papyrus <papyrus@arnob.pro.bd>',
      'to', array[p_to],
      'subject', p_subject,
      'html', p_html
    )
  ) into request_id;
  
  -- Log request ID
  raise notice 'Email send request submitted with ID: %', request_id;
  
exception
  when others then
    raise warning 'Failed to send email: %', SQLERRM;
    -- Re-raise the exception
    raise;
end;
$$ language plpgsql security definer;

-- Update the rpc_send_custom_otp function to use professional HTML template
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
  
  -- Prepare Email Subject
  if p_type = 'otp-signup' then
    v_subject := 'Confirm Your Signup - Papyrus';
  elsif p_type = 'otp-delete-shop' then
    v_subject := 'CRITICAL: Shop Deletion Verification Code - Papyrus';
  else
    v_subject := 'Reset Your Password - Papyrus';
  end if;
  
  -- Professional HTML template matching Edge Function
  v_html := '
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<title>OTP Verification</title>
</head>

<body style="margin:0; padding:0; background-color:#f4f6f8; font-family:Arial, sans-serif;">

  <table width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#f4f6f8; padding:20px 0;">
    <tr>
      <td align="center">

        <!-- Main Container -->
        <table width="420" cellpadding="0" cellspacing="0" border="0" style="background:#ffffff; border-radius:12px; overflow:hidden; box-shadow:0 8px 20px rgba(0,0,0,0.05);">

          <!-- Header -->
          <tr>
            <td style="background:#195243; padding:20px; text-align:center; color:#ffffff; font-size:22px; font-weight:bold;">
              Papyrus
            </td>
          </tr>

          <!-- Body -->
          <tr>
            <td style="padding:30px 25px; text-align:center;">

              <h2 style="margin:0; color:#333;">Verify Your Account</h2>

              <p style="margin:15px 0 25px; color:#666; font-size:14px;">
                Use the OTP below to complete your verification. This code is valid for a limited time.
              </p>

              <!-- OTP Box -->
              <div style="
                display:inline-block;
                padding:15px 25px;
                background:#f1f7f5;
                border:2px dashed #195243;
                border-radius:8px;
                font-size:28px;
                letter-spacing:6px;
                font-weight:bold;
                color:#195243;
              ">
                ' || v_code || '
              </div>

              <p style="margin:25px 0 10px; color:#999; font-size:13px;">
                If you didn''t request this, you can safely ignore this email.
              </p>

            </td>
          </tr>

          <!-- Divider -->
          <tr>
            <td style="height:1px; background:#eeeeee;"></td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="padding:20px; text-align:center; font-size:12px; color:#888;">
              © 2026 Papyrus. All rights reserved.<br/>
              Secure Business Management System
            </td>
          </tr>

        </table>

      </td>
    </tr>
  </table>

</body>
</html>';
    
  -- Send Email
  perform send_resend_email(p_email, v_subject, v_html);
end;
$$ language plpgsql security definer;

-- Update the invitation email template to match Edge Function styling
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
  
  -- Professional HTML template matching Edge Function
  v_html := '
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<title>Invitation - Papyrus</title>
</head>

<body style="margin:0; padding:0; background-color:#f4f6f8; font-family:Arial, sans-serif;">

  <table width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#f4f6f8; padding:20px 0;">
    <tr>
      <td align="center">

        <!-- Main Container -->
        <table width="420" cellpadding="0" cellspacing="0" border="0" style="background:#ffffff; border-radius:12px; overflow:hidden; box-shadow:0 8px 20px rgba(0,0,0,0.05);">

          <!-- Header -->
          <tr>
            <td style="background:#195243; padding:20px; text-align:center; color:#ffffff; font-size:22px; font-weight:bold;">
              Papyrus
            </td>
          </tr>

          <!-- Body -->
          <tr>
            <td style="padding:30px 25px; text-align:center;">

              <h2 style="margin:0; color:#333;">You''ve been invited to join ' || v_shop_name || '!</h2>

              <p style="margin:15px 0 25px; color:#666; font-size:14px;">
                Hello,
              </p>
              
              <p style="margin:15px 0; color:#666; font-size:14px;">
                The owner of <strong>' || v_shop_name || '</strong> has invited you to join their team as a <strong>' || v_role_name || '</strong>.
              </p>

              <p style="margin:15px 0; color:#666; font-size:14px;">
                To accept this invitation:
              </p>
              
              <ol style="text-align:left; margin:20px 0; padding-left:20px; color:#666; font-size:14px;">
                <li>Open the Papyrus app.</li>
                <li>Sign in or create an account with this email address.</li>
                <li>Go to your shop selection screen to see and accept the invite.</li>
              </ol>

              <p style="margin:25px 0 10px; color:#999; font-size:13px;">
                We look forward to having you on the team!
              </p>

            </td>
          </tr>

          <!-- Divider -->
          <tr>
            <td style="height:1px; background:#eeeeee;"></td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="padding:20px; text-align:center; font-size:12px; color:#888;">
              © 2026 Papyrus. All rights reserved.<br/>
              Secure Business Management System
            </td>
          </tr>

        </table>

      </td>
    </tr>
  </table>

</body>
</html>';
    
  perform send_resend_email(new.invited_email_or_phone, 'Invitation to join ' || v_shop_name || ' on Papyrus', v_html);
  
  return new;
end;
$$ language plpgsql security definer;
