/**
 * ============================================================
 *  🔐 encrypt-config.js
 *  شغّل الملف ده مرة واحدة بس عشان تعمل .env.encrypted
 *  node encrypt-config.js
 * ============================================================
 */

const crypto = require('crypto');
const fs     = require('fs');
const path   = require('path');

// ============================================================
//  ⬇️  ضع قيمك هنا، بعد كده امسح الملف ده
// ============================================================
const SECRET_CONFIG = {
    GITHUB_OWNER:            'pg0panda',
    GITHUB_REPO:             'KEYS',
    GITHUB_BRANCH:           'main',
    GITHUB_FILE_PATH:        'KEYS.json',
    GITHUB_TOKEN:            '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',
    DOWNLOAD_TOKEN:          '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',
    BAN_FILE_PATH:           'BAN.json',
    GENERAL_KEYS_FILE_PATH:  'GENERAL_KEYS.json',
    ENCRYPTION_KEY:          '(%%%%PANDA-TOOL-BOX-SECRET-KEY-123-*#@-ALLYOUNEEDINONETOOL-PG-progamer%%%%)',
};
// ============================================================

// كلمة سر ثابتة — غيّرها لأي حاجة تحبها (مش هتنساها لأن البرنامج بيستخدمها)
const MASTER_PASSWORD = 'PANDA_APP_2026_SECRET_KEY(config-loader-2026-token-1234567890-abcdef-ghijklmnop-xyz-#$#$%%^**(panda))';

function deriveKey(password, salt) {
    return crypto.scryptSync(password, salt, 32);
}

function encrypt(data, password) {
    const salt = crypto.randomBytes(16);
    const key  = deriveKey(password, salt);
    const iv   = crypto.randomBytes(16);

    const cipher     = crypto.createCipheriv('aes-256-cbc', key, iv);
    const encrypted  = Buffer.concat([
        cipher.update(JSON.stringify(data), 'utf8'),
        cipher.final()
    ]);

    // نحفظ: salt + iv + encrypted data كلها مع بعض في ملف واحد
    const result = Buffer.concat([salt, iv, encrypted]);
    return result.toString('base64');
}

// ============================================================
//  تشفير وحفظ
// ============================================================
const encryptedData = encrypt(SECRET_CONFIG, MASTER_PASSWORD);
const outputPath    = path.join(__dirname, 'src', '.env.encrypted');

fs.writeFileSync(outputPath, encryptedData, 'utf8');

console.log('✅ تم إنشاء .env.encrypted بنجاح!');
console.log('⚠️  احذف ملف encrypt-config.js دلوقتي!');
console.log('⚠️  متحطش .env.encrypted في Git!');
