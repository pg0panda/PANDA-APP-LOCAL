const http = require('http');
const crypto = require('crypto');
const { sendActivationEmail, generateActivationCode } = require('./src/js/license-email');

const PORT = Number(process.env.WEBHOOK_PORT || process.env.PORT || 3000);
const WEBHOOK_SECRET = process.env.XPAY_WEBHOOK_SECRET || '';

function jsonResponse(res, statusCode, payload) {
    res.writeHead(statusCode, { 'Content-Type': 'application/json; charset=utf-8' });
    res.end(JSON.stringify(payload));
}

function readBody(req) {
    return new Promise((resolve, reject) => {
        const chunks = [];

        req.on('data', (chunk) => chunks.push(chunk));
        req.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
        req.on('error', reject);
    });
}

function getHeaderValue(req, names) {
    for (const name of names) {
        const value = req.headers[name.toLowerCase()];
        if (value) return Array.isArray(value) ? value[0] : value;
    }
    return '';
}

function normalizeStatus(payload) {
    const event = payload?.event || payload?.type || payload?.status || payload?.state || '';
    const status = (payload?.status || payload?.state || payload?.payment_status || payload?.paymentStatus || payload?.data?.status || payload?.data?.state || '').toString().toLowerCase();
    const success = payload?.success === true || payload?.paid === true || payload?.is_paid === true || status === 'paid' || status === 'succeeded' || status === 'success' || status === 'completed' || status === 'approved' || event === 'payment.success' || event === 'checkout.success';
    return { success, status, event };
}

function extractCustomerInfo(payload) {
    const data = payload?.data || payload;
    const customer = data?.customer || payload?.customer || {};
    const payer = data?.payer || payload?.payer || {};
    const email = customer.email || payer.email || data?.email || payload?.email || data?.customer_email || payload?.customer_email || '';
    const name = customer.name || payer.name || data?.customer_name || payload?.customer_name || customer.full_name || customer.first_name || '';
    const plan = data?.plan_name || payload?.plan_name || data?.product_name || payload?.product_name || data?.product?.name || payload?.product?.name || 'Panda Toolbox';
    return { email, name, plan };
}

function verifyWebhookSignature(rawBody, signature) {
    if (!WEBHOOK_SECRET) return true;
    if (!signature) return false;

    const expected = crypto
        .createHmac('sha256', WEBHOOK_SECRET)
        .update(rawBody)
        .digest('hex');

    const provided = signature.toLowerCase().replace(/^sha256=/i, '');
    return crypto.timingSafeEqual(Buffer.from(expected), Buffer.from(provided));
}

function getExpirationLabel(planName) {
    const labels = {
        'يوم واحد': 'بعد 30 يوم',
        'أسبوع': 'بعد 7 أيام',
        'شهر واحد': 'بعد 30 يوم',
        '3 شهور': 'بعد 3 أشهر',
        '6 شهور': 'بعد 6 أشهر',
        'سنة كاملة': 'بعد 12 شهر'
    };

    return labels[planName] || 'بعد 30 يوم';
}

async function processSuccessfulPayment(payload) {
    const { email, name, plan } = extractCustomerInfo(payload);
    const normalizedPlan = plan || 'Panda Toolbox';

    if (!email) {
        return {
            ok: false,
            message: 'No email found in webhook payload',
            payload
        };
    }

    const result = await sendActivationEmail({
        email,
        planName: normalizedPlan,
        customerName: name || 'مستخدم',
        expiresAt: getExpirationLabel(normalizedPlan),
        source: 'XPay Webhook'
    });

    return {
        ok: true,
        result,
        activationCode: result?.activationCode || generateActivationCode(normalizedPlan)
    };
}

const server = http.createServer(async (req, res) => {
    if (req.method === 'GET' && req.url === '/health') {
        return jsonResponse(res, 200, { ok: true, message: 'XPay webhook server is running' });
    }

    if (req.method !== 'POST' || req.url !== '/xpay/webhook') {
        return jsonResponse(res, 404, { ok: false, message: 'Not found' });
    }

    try {
        const rawBody = await readBody(req);
        const signature = getHeaderValue(req, ['x-pay-signature', 'x-signature', 'x-pay-webhook-signature', 'signature']);

        if (WEBHOOK_SECRET && !verifyWebhookSignature(rawBody, signature)) {
            return jsonResponse(res, 401, { ok: false, message: 'Invalid webhook signature' });
        }

        const payload = rawBody ? JSON.parse(rawBody) : {};
        const { success, status, event } = normalizeStatus(payload);

        if (!success) {
            return jsonResponse(res, 200, {
                ok: true,
                ignored: true,
                status,
                event,
                message: 'Webhook received but payment is not successful yet.'
            });
        }

        const processed = await processSuccessfulPayment(payload);

        if (!processed.ok) {
            return jsonResponse(res, 400, processed);
        }

        return jsonResponse(res, 200, {
            ok: true,
            status: 'processed',
            message: 'Activation code generated and email sent successfully.',
            activationCode: processed.activationCode,
            result: processed.result
        });
    } catch (error) {
        console.error('Webhook error:', error);
        return jsonResponse(res, 500, {
            ok: false,
            message: 'Webhook processing failed',
            error: error.message
        });
    }
});

server.listen(PORT, () => {
    console.log(`XPay webhook server is listening on http://localhost:${PORT}`);
    console.log('Use this URL in XPay dashboard: http://localhost:' + PORT + '/xpay/webhook');
});
