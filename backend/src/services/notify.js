/**
 * Verification delivery — email + SMS OTP.
 *
 * Pluggable providers, controlled by environment variables:
 *   RESEND_API_KEY  → real email via Resend (https://resend.com, free tier)
 *   TERMII_API_KEY  → real SMS via Termii (https://termii.com, Nigerian SMS)
 *
 * DEV MODE: when a key is missing the OTP is returned in the API response
 * (`devCode`) and logged, so the full verification flow works end-to-end
 * without any external accounts. Add the keys on Render to go live —
 * zero code changes needed.
 */

const RESEND_KEY = process.env.RESEND_API_KEY || '';
const TERMII_KEY = process.env.TERMII_API_KEY || '';
const EMAIL_FROM = process.env.EMAIL_FROM || 'LuxFeast <onboarding@resend.dev>';
const TERMII_SENDER = process.env.TERMII_SENDER_ID || 'N-Alert';

async function sendEmailCode(email, code) {
  if (!RESEND_KEY) {
    console.log(`[DEV EMAIL] OTP for ${email}: ${code}`);
    return { delivered: false, dev: true };
  }
  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { Authorization: `Bearer ${RESEND_KEY}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      from: EMAIL_FROM,
      to: [email],
      subject: `${code} is your LuxFeast verification code`,
      html: `<div style="font-family:Georgia,serif;background:#0A0A0F;color:#F5F0E6;padding:32px;border-radius:16px">
               <h1 style="color:#D4AF37;margin:0 0 8px">LuxFeast</h1>
               <p>Your verification code is:</p>
               <p style="font-size:34px;letter-spacing:10px;color:#D4AF37;font-weight:bold">${code}</p>
               <p style="color:#9A948A;font-size:13px">Expires in 10 minutes. If you didn't request this, ignore this email.</p>
             </div>`,
    }),
  });
  if (!res.ok) throw new Error(`Email send failed: ${await res.text()}`);
  return { delivered: true };
}

async function sendSmsCode(phone, code) {
  if (!TERMII_KEY) {
    console.log(`[DEV SMS] OTP for ${phone}: ${code}`);
    return { delivered: false, dev: true };
  }
  const res = await fetch('https://api.ng.termii.com/api/sms/send', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      api_key: TERMII_KEY,
      to: phone,
      from: TERMII_SENDER,
      sms: `Your LuxFeast verification code is ${code}. Expires in 10 minutes.`,
      type: 'plain',
      channel: 'generic',
    }),
  });
  if (!res.ok) throw new Error(`SMS send failed: ${await res.text()}`);
  return { delivered: true };
}

const generateCode = () => String(Math.floor(100000 + Math.random() * 900000));

module.exports = { sendEmailCode, sendSmsCode, generateCode };
