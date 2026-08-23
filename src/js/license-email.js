const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const tls = require('tls');
const net = require('net');

function loadEnvFile(filePath) {
    if (!fs.existsSync(filePath)) return {};

    const content = fs.readFileSync(filePath, 'utf8');
    const env = {};

    for (const line of content.split(/\r?\n/)) {
        const trimmed = line.trim();
        if (!trimmed || trimmed.startsWith('#') || !trimmed.includes('=')) continue;

        const idx = trimmed.indexOf('=');
        const key = trimmed.slice(0, idx).trim();
        const value = trimmed.slice(idx + 1).trim().replace(/^['"]|['"]$/g, '');
        env[key] = value;
    }

    return env;
}

function resolveEnv() {
    const roots = [
        path.resolve(__dirname, '..', '..', '.env'),
        path.resolve(__dirname, '..', '..', 'encrypted.env'),
        path.resolve(process.cwd(), '.env'),
        path.resolve(process.cwd(), 'encrypted.env')
    ];

    let merged = {};
    for (const file of roots) {
        merged = { ...merged, ...loadEnvFile(file) };
    }

    return { ...process.env, ...merged };
}

function generateActivationCode(planName = 'Panda') {
    const datePart = new Date().toISOString().slice(0, 10).replace(/-/g, '');
    const randomPart = crypto.randomBytes(3).toString('hex').toUpperCase();
    const planCode = (planName || 'PANDA').replace(/[^A-Za-z0-9]/g, '').slice(0, 4).toUpperCase() || 'PANDA';
    return `${planCode}-${datePart}-${randomPart}`;
}

function saveLicenseRecord(record) {
    const file = path.resolve(process.cwd(), 'panda-licenses.json');
    let list = [];

    try {
        if (fs.existsSync(file)) {
            const existing = fs.readFileSync(file, 'utf8');
            list = JSON.parse(existing);
            if (!Array.isArray(list)) list = [];
        }
    } catch (error) {
        list = [];
    }

    list.push(record);
    fs.writeFileSync(file, JSON.stringify(list, null, 2), 'utf8');
    return file;
}

function buildEmailHtml({ customerName, planName, activationCode, expiresAt }) {
    const displayName = customerName || 'عزيزي المستخدم';
    const planText = planName || 'اشتراك Panda Toolbox';
    const expiresLabel = expiresAt || 'غير محدد';

    return `
    <div style="font-family:Segoe UI,Arial,sans-serif;background:#0e1320;padding:24px;color:#eaf7ff;">
      <div style="max-width:640px;margin:0 auto;background:#111827;border:1px solid #1f2937;border-radius:18px;overflow:hidden;">
        <div style="padding:20px 24px;background:linear-gradient(135deg,#00c864,#00a050);color:#04130b;font-weight:bold;font-size:22px;">
          Panda Toolbox - تفعيل الاشتراك
        </div>
        <div style="padding:28px 24px;">
          <p style="margin:0 0 16px;font-size:18px;">مرحباً <strong>${displayName}</strong>،</p>
          <p style="margin:0 0 16px;line-height:1.7;">
            تم تأكيد الدفع بنجاح، واصبحت باقتك <strong>${planText}</strong> جاهزة للتفعيل.
          </p>
          <div style="background:#0b1220;border:1px solid #1f2937;border-radius:12px;padding:20px 18px;margin:18px 0;">
            <div style="font-size:13px;color:#9ca3af;margin-bottom:8px;">رمز التفعيل</div>
            <div style="font-size:28px;letter-spacing:2px;font-weight:700;color:#00f5a0;">${activationCode}</div>
          </div>
          <p style="margin:0 0 12px;line-height:1.7;">تاريخ الانتهاء: <strong>${expiresLabel}</strong></p>
          <p style="margin:0;line-height:1.7;">شكرًا لك على ثقتك بـ Panda Toolbox، نتمنى لك تجربة ممتازة.</p>
        </div>
      </div>
    </div>
  `;
}

function smtpSendMail({ host, port, secure, user, pass, from, to, subject, html }) {
    return new Promise((resolve, reject) => {
        const socket = new net.Socket();
        const commands = [];
        let currentState = 'init';
        let buffer = '';
        let socketReady = false;

        const sendCommand = (cmd) => {
            if (!socketReady || socket.destroyed) {
                return;
            }
            console.log('SMTP ->', cmd.trim());
            socket.write(cmd + '\r\n');
        };

        const finish = (error, result) => {
            try { socket.end(); } catch (err) {}
            if (error) return reject(error);
            resolve(result);
        };

        const onData = (chunk) => {
            buffer += chunk.toString('utf8');
            const lines = buffer.split(/\r?\n/);
            buffer = lines.pop();

            for (const line of lines) {
                if (!line.trim()) continue;
                console.log('SMTP <-', line);

                if (line.startsWith('220 ') || line.startsWith('250 ') || line.startsWith('235 ') || line.startsWith('334 ') || line.startsWith('354 ')) {
                    if (currentState === 'init' && line.startsWith('220 ')) {
                        currentState = 'ehlo';
                        sendCommand(`EHLO ${host}`);
                    } else if (currentState === 'ehlo' && line.startsWith('250 ')) {
                        if (secure && !socketReady) {
                            currentState = 'starttls';
                            sendCommand('STARTTLS');
                        } else {
                            currentState = 'auth';
                            sendCommand('AUTH LOGIN');
                        }
                    } else if (currentState === 'starttls' && line.startsWith('220 ')) {
                        const tlsSocket = tls.connect({ socket, servername: host });
                        tlsSocket.on('secureConnect', () => {
                            socket = tlsSocket;
                            socketReady = true;
                            currentState = 'ehlo2';
                            sendCommand(`EHLO ${host}`);
                        });
                        tlsSocket.on('error', (err) => finish(err));
                        return;
                    } else if (currentState === 'ehlo2' && line.startsWith('250 ')) {
                        currentState = 'auth';
                        sendCommand('AUTH LOGIN');
                    } else if (currentState === 'auth' && line.startsWith('334 ')) {
                        sendCommand(Buffer.from(user || '').toString('base64'));
                    } else if (currentState === 'username-sent' && line.startsWith('334 ')) {
                        sendCommand(Buffer.from(pass || '').toString('base64'));
                    } else if (currentState === 'password-sent' && line.startsWith('235 ')) {
                        currentState = 'mail';
                        sendCommand(`MAIL FROM:<${from}>`);
                    } else if (currentState === 'mail' && line.startsWith('250 ')) {
                        currentState = 'rcpt';
                        sendCommand(`RCPT TO:<${to}>`);
                    } else if (currentState === 'rcpt' && line.startsWith('250 ')) {
                        currentState = 'data';
                        sendCommand('DATA');
                    } else if (currentState === 'data' && line.startsWith('354 ')) {
                        const payload = [
                            `From: ${from}`,
                            `To: ${to}`,
                            `Subject: ${subject}`,
                            'MIME-Version: 1.0',
                            'Content-Type: text/html; charset=UTF-8',
                            '',
                            html,
                            '',
                            '.'
                        ].join('\r\n');
                        socket.write(payload + '\r\n');
                        currentState = 'done';
                    } else if (currentState === 'done' && line.startsWith('250 ')) {
                        finish(null, { accepted: true, to });
                    }
                }
            }
        };

        socket.on('connect', () => {
            socketReady = true;
            currentState = 'init';
            commands.push('220');
            sendCommand('');
        });

        socket.on('error', (error) => finish(error));
        socket.on('data', onData);
        socket.connect(port, host);
    });
}

async function sendActivationEmail({ email, planName, customerName, expiresAt, source = 'XPay' }) {
    const env = resolveEnv();
    const toEmail = email || env.MAIL_TO || env.EMAIL_TO || env.RECIPIENT_EMAIL;
    const smtpHost = env.MAIL_HOST || env.SMTP_HOST;
    const smtpPort = Number(env.MAIL_PORT || env.SMTP_PORT || 587);
    const smtpUser = env.MAIL_USER || env.SMTP_USER || env.EMAIL_USER;
    const smtpPass = env.MAIL_PASS || env.SMTP_PASS || env.EMAIL_PASS;
    const smtpFrom = env.MAIL_FROM || env.SMTP_FROM || env.EMAIL_FROM || smtpUser;
    const secure = String(env.MAIL_SECURE || env.SMTP_SECURE || 'false').toLowerCase() === 'true';

    const activationCode = generateActivationCode(planName);
    const record = {
        customerName: customerName || 'User',
        email: toEmail,
        planName: planName || 'Panda Toolbox',
        activationCode,
        expiresAt: expiresAt || 'غير محدد',
        source,
        createdAt: new Date().toISOString()
    };

    saveLicenseRecord(record);

    if (!smtpHost || !smtpUser || !smtpPass) {
        return {
            success: false,
            message: 'لم يتم تهيئة إعدادات SMTP. تم إنشاء الكود محلياً فقط.',
            activationCode,
            record
        };
    }

    try {
        await smtpSendMail({
            host: smtpHost,
            port: smtpPort,
            secure,
            user: smtpUser,
            pass: smtpPass,
            from: smtpFrom,
            to: toEmail,
            subject: `Panda Toolbox - كود التفعيل الخاص بك (${planName || 'اشتراك'})`,
            html: buildEmailHtml({ customerName, planName, activationCode, expiresAt })
        });

        return {
            success: true,
            message: 'تم إرسال كود التفعيل إلى البريد الإلكتروني بنجاح.',
            activationCode,
            record
        };
    } catch (error) {
        return {
            success: false,
            message: `فشل إرسال البريد: ${error.message}`,
            activationCode,
            record,
            error
        };
    }
}

module.exports = {
    generateActivationCode,
    sendActivationEmail,
    saveLicenseRecord
};
