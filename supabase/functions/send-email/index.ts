import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

const supabase = createClient(SUPABASE_URL!, SUPABASE_SERVICE_ROLE_KEY!)

serve(async (req) => {
  const { to, subject, html, shopName, roleName, type, code } = await req.json()

  let emailHtml = html;
  let emailSubject = subject;

  if (type === 'otp-signup' || type === 'otp-reset') {
    const isSignup = type === 'otp-signup';
    emailSubject = isSignup ? 'Confirm Your Signup - Papyrus' : 'Reset Your Password - Papyrus';
    emailHtml = `
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
                ${code}
              </div>

              <p style="margin:25px 0 10px; color:#999; font-size:13px;">
                If you didn't request this, you can safely ignore this email.
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
</html>
`;

    // Store OTP in database
    await supabase.from('auth_otps').insert({
      email: to,
      code: code,
    });
  } else if (!html) {
    // Standard Invitation
    emailSubject = `Invitation to join ${shopName} on Papyrus`;
    emailHtml = `
      <div style="font-family: sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e0e0e0; border-radius: 8px;">
        <h2 style="color: #154834;">You've been invited to join ${shopName}!</h2>
        <p>Hello,</p>
        <p>The owner of <strong>${shopName}</strong> has invited you to join their team as a <strong>${roleName}</strong>.</p>
        <p>To accept this invitation:</p>
        <ol>
          <li>Open the Papyrus app.</li>
          <li>Sign in or create an account with this email address.</li>
          <li>Go to your shop selection screen to see and accept the invite.</li>
        </ol>
        <p>We look forward to having you on the team!</p>
        <hr style="border: 0; border-top: 1px solid #eee; margin: 20px 0;" />
        <p style="font-size: 12px; color: #666;">This is an automated notification from Papyrus Business Suite.</p>
      </div>
    `;
  }

  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${RESEND_API_KEY}`,
    },
    body: JSON.stringify({
      from: 'Papyrus <papyrus@arnob.pro.bd>',
      to: [to],
      subject: emailSubject,
      html: emailHtml,
    }),
  })

  const data = await res.json()

  return new Response(JSON.stringify(data), {
    headers: { 'Content-Type': 'application/json' },
    status: res.status,
  })
})
