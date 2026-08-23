const fs = require('fs');
const path = require('path');
const os = require('os');
const crypto = require('crypto');

// ===================================
// الإعدادات
// ===================================

const storePath = path.join(
    os.homedir(),
    'AppData',
    'Roaming',
    'keypanda.lince'
);

const SECRET_KEY = crypto
    .createHash('sha256')
    .update('PANDA-SECRET-KEY-9xA#kL2@vQ7!mP1$Zr8^TxW')
    .digest();

const HMAC_KEY = crypto
    .createHash('sha256')
    .update('PANDA-HMAC-KEY-Q7#mX2@Lp9!Vt4$Kr8^NzW1&Fa6')
    .digest();

const IV = Buffer.alloc(16, 0);

// ===================================
// تشفير
// ===================================

function encrypt(text) {
    const cipher = crypto.createCipheriv(
        'aes-256-cbc',
        SECRET_KEY,
        IV
    );

    let encrypted = cipher.update(
        text,
        'utf8',
        'hex'
    );

    encrypted += cipher.final('hex');

    return encrypted;
}

// ===================================
// فك التشفير
// ===================================

function decrypt(encryptedText) {
    const decipher = crypto.createDecipheriv(
        'aes-256-cbc',
        SECRET_KEY,
        IV
    );

    let decrypted = decipher.update(
        encryptedText,
        'hex',
        'utf8'
    );

    decrypted += decipher.final('utf8');

    return decrypted;
}

// ===================================
// إنشاء توقيع HMAC
// ===================================

function createSignature(data) {
    return crypto
        .createHmac('sha256', HMAC_KEY)
        .update(data)
        .digest('hex');
}

// ===================================
// كتابة البيانات
// ===================================

function writeStore(data) {

    try {

        const jsonData = JSON.stringify(data);

        const encryptedData = encrypt(jsonData);

        const signature = createSignature(encryptedData);

        const finalData = JSON.stringify({
            signature,
            data: encryptedData
        });

        fs.writeFileSync(
            storePath,
            finalData,
            'utf8'
        );

    } catch (error) {

        console.error(
            'فشل كتابة الملف:',
            error.message
        );

    }

}

// ===================================
// قراءة البيانات
// ===================================

function readStore() {

    try {

        if (!fs.existsSync(storePath)) {
            return {};
        }

        const rawFile = fs.readFileSync(
            storePath,
            'utf8'
        );

        if (!rawFile) {
            return {};
        }

        const parsed = JSON.parse(rawFile);

        // ===========================
        // التحقق من التوقيع
        // ===========================

        const expectedSignature =
            createSignature(parsed.data);

        if (
            parsed.signature !== expectedSignature
        ) {

            console.error(
                '🚨 تم اكتشاف تعديل في الملف!'
            );

            // حذف الملف فوراً
            try {
                fs.unlinkSync(storePath);
            } catch {}

            // قفل البرنامج
            process.exit(1);

        }

        // ===========================
        // فك التشفير
        // ===========================

        const decrypted =
            decrypt(parsed.data);

        return JSON.parse(decrypted);

    } catch (error) {

        console.error(
            'فشل قراءة الملف:',
            error.message
        );

        return {};
    }

}

// ===================================
// API
// ===================================

module.exports = {

    get(key) {

        const data = readStore();

        return data[key];

    },

    set(key, value) {

        const data = readStore();

        data[key] = value;

        writeStore(data);

    },

    delete(key) {

        const data = readStore();

        delete data[key];

        writeStore(data);

    }

};

console.log(
    '✅ Secure protected store ready.'
);
