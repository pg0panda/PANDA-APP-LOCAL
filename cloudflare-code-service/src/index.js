const PLANS = new Set(['day', 'week', 'month', '3months', '6months', 'year']);
// XPay amounts are expressed in EGP minor units. Keep these aligned with the
// six Payment Links configured in Panda's XPay account.
const PLAN_BY_AMOUNT = new Map([
  [2500, 'day'], [10000, 'week'], [26000, 'month'],
  [65000, '3months'], [110000, '6months'], [200000, 'year']
]);
const PLAN_LICENSE_DETAILS = {
  day: { prefix: 'day', durationDays: 1 },
  week: { prefix: 'week', durationWeeks: 1 },
  month: { prefix: 'month', durationMonths: 1 },
  '3months': { prefix: '3m', durationMonths: 3 },
  '6months': { prefix: '6m', durationMonths: 6 },
  year: { prefix: 'year', durationYears: 1 }
};
const GITHUB_LICENSE_REPO = 'pg0panda/KEYS';
const GITHUB_LICENSE_BRANCH = 'main';
const GITHUB_LICENSE_FILE = 'KEYS.json';

const json = (body, status = 200, origin = '') => new Response(JSON.stringify(body), {
  status,
  headers: {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store',
    'access-control-allow-origin': origin,
    'vary': 'Origin'
  }
});

function allowedOrigin(request, env) {
  const origin = request.headers.get('Origin') || '';
  // PAGES_ORIGIN includes the GitHub repository path, while the browser's
  // Origin header contains only scheme + host.
  const pagesOrigin = new URL(env.PAGES_ORIGIN).origin;
  return origin && origin === pagesOrigin ? origin : '';
}

async function sha256(value) {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, '0')).join('');
}

function constantTimeEqual(left, right) {
  if (left.length !== right.length) return false;
  let difference = 0;
  for (let index = 0; index < left.length; index += 1) difference |= left.charCodeAt(index) ^ right.charCodeAt(index);
  return difference === 0;
}

function getSignatureParts(header) {
  const parts = Object.fromEntries((header || '').split(',').map((part) => part.trim().split('=')));
  return { timestamp: parts.t, signature: parts.v1 };
}

async function verifyXPaySignature(rawBody, signatureHeader, secret) {
  const { timestamp, signature } = getSignatureParts(signatureHeader);
  if (!timestamp || !signature || !/^\d+$/.test(timestamp)) return false;
  if (Math.abs(Math.floor(Date.now() / 1000) - Number(timestamp)) > 300) return false;
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const bytes = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(`${timestamp}.${rawBody}`));
  const expected = [...new Uint8Array(bytes)].map((byte) => byte.toString(16).padStart(2, '0')).join('');
  return constantTimeEqual(expected, signature);
}

function secureToken() {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return btoa(String.fromCharCode(...bytes)).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
}

function generateLicenseCode(plan, suffixLength = 4) {
  const details = PLAN_LICENSE_DETAILS[plan];
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const random = crypto.getRandomValues(new Uint8Array(suffixLength));
  const suffix = [...random].map((value) => alphabet[value % alphabet.length]).join('');
  return `vip-${details.prefix}-${suffix}`;
}

function decodeBase64Utf8(value) {
  return new TextDecoder().decode(Uint8Array.from(atob(value.replaceAll('\n', '')), (char) => char.charCodeAt(0)));
}

function encodeBase64Utf8(value) {
  return btoa(String.fromCharCode(...new TextEncoder().encode(value)));
}

async function syncLicenseToGitHub(codeRecord, plan, xpaySessionId, env) {
  if (!env.GITHUB_LICENSE_TOKEN) throw new Error('github_not_configured');
  const url = `https://api.github.com/repos/${GITHUB_LICENSE_REPO}/contents/${GITHUB_LICENSE_FILE}`;
  const headers = {
    accept: 'application/vnd.github+json',
    authorization: `Bearer ${env.GITHUB_LICENSE_TOKEN}`,
    'user-agent': 'Panda-Code-Service'
  };
  const details = PLAN_LICENSE_DETAILS[plan];

  for (let attempt = 0; attempt < 3; attempt += 1) {
    const read = await fetch(`${url}?ref=${GITHUB_LICENSE_BRANCH}`, { headers });
    if (!read.ok) throw new Error('github_read_failed');
    const file = await read.json();
    const licenses = JSON.parse(decodeBase64Utf8(file.content));
    if (!Array.isArray(licenses)) throw new Error('github_file_invalid');
    const existing = licenses.find((license) => license.key === codeRecord.code);
    if (existing) {
      const comment = String(existing.comment || '');
      return { alreadySynced: comment.includes(`رقم عملية XPay: ${xpaySessionId}`) || comment.includes(`رقم الطلب: ${xpaySessionId}`) };
    }

    licenses.push({
      key: codeRecord.code,
      enabled: 'yes',
      ...(details.durationDays ? { durationDays: details.durationDays } : {}),
      ...(details.durationWeeks ? { durationWeeks: details.durationWeeks } : {}),
      ...(details.durationMonths ? { durationMonths: details.durationMonths } : {}),
      ...(details.durationYears ? { durationYears: details.durationYears } : {}),
      comment: `الاسم: ${codeRecord.customer_name}\nالإيميل: ${codeRecord.customer_email}\nرقم عملية XPay: ${xpaySessionId}`
    });
    const write = await fetch(url, {
      method: 'PUT',
      headers: { ...headers, 'content-type': 'application/json' },
      body: JSON.stringify({
        message: `Add paid license ${codeRecord.code}`,
        content: encodeBase64Utf8(JSON.stringify(licenses, null, 2)),
        sha: file.sha,
        branch: GITHUB_LICENSE_BRANCH
      })
    });
    if (write.ok) return { alreadySynced: true };
    if (write.status !== 409 && write.status !== 422) throw new Error('github_write_failed');
  }
  throw new Error('github_write_conflict');
}

async function createPurchase(request, env, origin) {
  if (request.headers.get('x-panda-webhook-secret') !== env.WEBHOOK_SECRET) {
    return json({ error: 'unauthorized' }, 401, origin);
  }

  const body = await request.json().catch(() => null);
  const { paymentId, plan } = body || {};
  if (!paymentId || typeof paymentId !== 'string' || !PLANS.has(plan)) {
    return json({ error: 'invalid_payment' }, 400, origin);
  }

  const token = secureToken();
  const tokenHash = await sha256(token);
  try {
    await env.DB.prepare(
      'INSERT INTO purchases (provider_payment_id, plan, redemption_token_hash, redemption_token) VALUES (?, ?, ?, ?)'
    ).bind(paymentId, plan, tokenHash, token).run();
  } catch (error) {
    // Payment IDs are unique: duplicate delivery from the provider must not mint another code.
    if (String(error.message).includes('UNIQUE')) return json({ error: 'payment_already_processed' }, 409, origin);
    throw error;
  }

  return json({
    redemptionUrl: `${env.PAGES_ORIGIN}/${plan}.html?token=${encodeURIComponent(token)}`
  }, 201, origin);
}

async function createPurchaseForXPay(session, env) {
  const paymentId = session.id;
  // Use the subtotal (the actual plan price), not the final total: XPay may
  // add VAT or a customer-paid platform fee to amountTotal.
  const plan = PLAN_BY_AMOUNT.get(Number(session.amountSubtotal ?? session.amountTotal));
  if (!paymentId || !plan) throw new Error('unrecognized_payment');

  const token = secureToken();
  const tokenHash = await sha256(token);
  try {
    await env.DB.prepare(
      'INSERT INTO purchases (provider_payment_id, plan, redemption_token_hash, redemption_token) VALUES (?, ?, ?, ?)'
    ).bind(paymentId, plan, tokenHash, token).run();
  } catch (error) {
    if (String(error.message).includes('UNIQUE')) return;
    throw error;
  }
}

async function xpayWebhook(request, env) {
  const rawBody = await request.text();
  const valid = await verifyXPaySignature(rawBody, request.headers.get('XPay-Signature'), env.XPAY_WEBHOOK_SECRET);
  if (!valid) return new Response('invalid signature', { status: 400 });
  const event = JSON.parse(rawBody);
  const session = event?.data?.object;
  const fulfilsPaidOrder = (
    (event.type === 'checkout.session.completed' || event.type === 'checkout.session.async_payment_succeeded') &&
    session?.status === 'complete' && session?.paymentStatus === 'paid'
  );
  if (fulfilsPaidOrder) {
    try {
      await createPurchaseForXPay(session, env);
    } catch (error) {
      console.error('XPay fulfillment error', error);
      return new Response('unable to fulfill', { status: 500 });
    }
  }
  return new Response('ok', { status: 200 });
}

async function xpayReturn(url, env) {
  const paymentId = url.searchParams.get('session_id');
  if (!paymentId || paymentId.length > 200) return new Response('رابط العودة غير صالح.', { status: 400 });
  const purchase = await env.DB.prepare(
    'SELECT plan, redemption_token FROM purchases WHERE provider_payment_id = ?'
  ).bind(paymentId).first();
  if (purchase?.redemption_token) {
    return Response.redirect(`${env.PAGES_ORIGIN}/${purchase.plan}.html?token=${encodeURIComponent(purchase.redemption_token)}`, 302);
  }
  return new Response(`<!doctype html><meta charset="utf-8"><meta http-equiv="refresh" content="3"><title>تأكيد الدفع</title><body dir="rtl" style="font-family:sans-serif;text-align:center;padding:4rem"><h2>جارٍ تأكيد الدفع…</h2><p>سيتم تحويلك تلقائيًا خلال ثوانٍ.</p></body>`, {
    headers: { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store' }
  });
}

async function claimCode(request, env, origin) {
  if (!origin) return json({ error: 'origin_not_allowed' }, 403);
  const body = await request.json().catch(() => null);
  const { token, name, email, consent } = body || {};
  if (!token || typeof token !== 'string' || token.length > 200) return json({ error: 'invalid_token' }, 400, origin);
  const customerName = typeof name === 'string' ? name.trim().replace(/\s+/g, ' ') : '';
  const customerEmail = typeof email === 'string' ? email.trim().toLowerCase() : '';
  if (customerName.length < 2 || customerName.length > 100 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(customerEmail) || customerEmail.length > 254 || consent !== true) {
    return json({ error: 'invalid_customer_details' }, 400, origin);
  }

  const tokenHash = await sha256(token);
  const purchase = await env.DB.prepare(
    'SELECT id, plan, code_id, provider_payment_id FROM purchases WHERE redemption_token_hash = ?'
  ).bind(tokenHash).first();
  if (!purchase) return json({ error: 'invalid_or_expired_link' }, 404, origin);
  if (purchase.code_id) return json({ error: 'code_already_shown' }, 409, origin);

  const now = new Date().toISOString();
  let codeRecord = await env.DB.prepare(
    'SELECT id, code, customer_name, customer_email, license_synced_at FROM codes WHERE claimed_purchase_id = ?'
  ).bind(purchase.id).first();

  if (!codeRecord) {
    for (let attempt = 0; attempt < 5 && !codeRecord; attempt += 1) {
      const code = generateLicenseCode(purchase.plan, 4 + attempt);
      try {
        const inserted = await env.DB.prepare(`INSERT INTO codes
          (code, plan, claimed_at, claimed_purchase_id, customer_name, customer_email)
          VALUES (?, ?, ?, ?, ?, ?)`)
          .bind(code, purchase.plan, now, purchase.id, customerName, customerEmail).run();
        codeRecord = { id: inserted.meta.last_row_id, code, customer_name: customerName, customer_email: customerEmail, license_synced_at: null };
      } catch (error) {
        if (!String(error.message).includes('UNIQUE')) throw error;
        codeRecord = await env.DB.prepare(
          'SELECT id, code, customer_name, customer_email, license_synced_at FROM codes WHERE claimed_purchase_id = ?'
        ).bind(purchase.id).first();
      }
    }
  }
  if (!codeRecord) return json({ error: 'code_generation_failed' }, 503, origin);

  try {
    if (!codeRecord.license_synced_at) {
      let synced = false;
      for (let attempt = 0; attempt < 5 && !synced; attempt += 1) {
        const result = await syncLicenseToGitHub(codeRecord, purchase.plan, purchase.provider_payment_id, env);
        if (result.alreadySynced) {
          synced = true;
          break;
        }
        // A legacy key had the same short suffix. Replace it before retrying;
        // D1's UNIQUE constraint also prevents duplicates among generated keys.
        const replacement = generateLicenseCode(purchase.plan, 5 + attempt);
        await env.DB.prepare('UPDATE codes SET code = ? WHERE id = ? AND license_synced_at IS NULL')
          .bind(replacement, codeRecord.id).run();
        codeRecord.code = replacement;
      }
      if (!synced) throw new Error('code_generation_failed');
      await env.DB.prepare('UPDATE codes SET license_synced_at = ? WHERE id = ?').bind(new Date().toISOString(), codeRecord.id).run();
    }
  } catch (error) {
    console.error('GitHub license sync error', error);
    return json({ error: error.message === 'github_not_configured' ? 'license_service_not_configured' : 'license_sync_failed' }, 502, origin);
  }

  const result = await env.DB.prepare('UPDATE purchases SET code_id = ?, claimed_at = ? WHERE id = ? AND code_id IS NULL')
    .bind(codeRecord.id, new Date().toISOString(), purchase.id).run();
  if (result.meta.changes !== 1) return json({ error: 'code_already_shown' }, 409, origin);

  return json({ code: codeRecord.code, plan: purchase.plan }, 200, origin);
}

export default {
  async fetch(request, env) {
    const origin = allowedOrigin(request, env);
    const url = new URL(request.url);
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: {
        'access-control-allow-origin': origin,
        'access-control-allow-methods': 'POST, OPTIONS',
        'access-control-allow-headers': 'content-type',
        'vary': 'Origin'
      }});
    }
    if (request.method === 'POST' && url.pathname === '/webhooks/xpay') return xpayWebhook(request, env);
    if (request.method === 'GET' && url.pathname === '/return/xpay') return xpayReturn(url, env);
    if (request.method === 'POST' && url.pathname === '/api/claim') return claimCode(request, env, origin);
    // Call only from a verified XPay webhook or a private owner tool, never from browser JavaScript.
    if (request.method === 'POST' && url.pathname === '/internal/create-purchase') return createPurchase(request, env, origin);
    return json({ error: 'not_found' }, 404, origin);
  }
};
