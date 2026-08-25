const PLANS = new Set(['day', 'week', 'month', '3months', '6months', 'year']);

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
  return origin && origin === env.PAGES_ORIGIN ? origin : '';
}

async function sha256(value) {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, '0')).join('');
}

function secureToken() {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return btoa(String.fromCharCode(...bytes)).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
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
      'INSERT INTO purchases (provider_payment_id, plan, redemption_token_hash) VALUES (?, ?, ?)'
    ).bind(paymentId, plan, tokenHash).run();
  } catch (error) {
    // Payment IDs are unique: duplicate delivery from the provider must not mint another code.
    if (String(error.message).includes('UNIQUE')) return json({ error: 'payment_already_processed' }, 409, origin);
    throw error;
  }

  return json({
    redemptionUrl: `${env.PAGES_ORIGIN}/${plan}.html?token=${encodeURIComponent(token)}`
  }, 201, origin);
}

async function claimCode(request, env, origin) {
  if (!origin) return json({ error: 'origin_not_allowed' }, 403);
  const body = await request.json().catch(() => null);
  const token = body && body.token;
  if (!token || typeof token !== 'string' || token.length > 200) return json({ error: 'invalid_token' }, 400, origin);

  const tokenHash = await sha256(token);
  // D1 batch is atomic: a code can never be assigned to two payments.
  const purchase = await env.DB.prepare(
    'SELECT id, plan, code_id FROM purchases WHERE redemption_token_hash = ?'
  ).bind(tokenHash).first();
  if (!purchase) return json({ error: 'invalid_or_expired_link' }, 404, origin);
  if (purchase.code_id) return json({ error: 'code_already_shown' }, 409, origin);

  const candidate = await env.DB.prepare(
    'SELECT id, code FROM codes WHERE plan = ? AND claimed_at IS NULL ORDER BY id LIMIT 1'
  ).bind(purchase.plan).first();
  if (!candidate) return json({ error: 'codes_unavailable' }, 503, origin);

  const now = new Date().toISOString();
  const result = await env.DB.batch([
    env.DB.prepare('UPDATE codes SET claimed_at = ?, claimed_purchase_id = ? WHERE id = ? AND claimed_at IS NULL')
      .bind(now, purchase.id, candidate.id),
    // This second predicate prevents a losing concurrent request from linking
    // its purchase to a code that the other request has just claimed.
    env.DB.prepare(`UPDATE purchases SET code_id = ?, claimed_at = ?
      WHERE id = ? AND code_id IS NULL
      AND EXISTS (SELECT 1 FROM codes WHERE id = ? AND claimed_purchase_id = ?)`)
      .bind(candidate.id, now, purchase.id, candidate.id, purchase.id)
  ]);
  if (result[0].meta.changes !== 1 || result[1].meta.changes !== 1) {
    return json({ error: 'claim_conflict_retry' }, 409, origin);
  }

  return json({ code: candidate.code, plan: purchase.plan }, 200, origin);
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
    if (request.method === 'POST' && url.pathname === '/api/claim') return claimCode(request, env, origin);
    // Call only from a verified XPay webhook or a private owner tool, never from browser JavaScript.
    if (request.method === 'POST' && url.pathname === '/internal/create-purchase') return createPurchase(request, env, origin);
    return json({ error: 'not_found' }, 404, origin);
  }
};
