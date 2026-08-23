/**
 * ============================================================
 *  🔐 config-loader.js
 *  البرنامج بيستخدم الملف ده عشان يجيب القيم من .env.encrypted
 *  الاستخدام:
 *      const config = require('./config-loader');
 *      const token  = config.get('GITHUB_TOKEN');
 * ============================================================
 */

const crypto = require('crypto');
const { app } = require('electron');
const fs     = require('fs');
const path   = require('path');
const addonPath = app.isPackaged
    ? path.join(process.resourcesPath, 'panda_secure_addon.node')
    : path.join(__dirname, '..', '..', 'build', 'Release', 'panda_secure_addon.node');
const nativeAddon = require(addonPath);
const MASTER_PASSWORD = nativeAddon.getMasterPassword();

function resolveExistingPath(...segments) {
    const candidates = [];

    if (app.isPackaged) {
        candidates.push(path.join(process.resourcesPath, 'app.asar', ...segments));
        candidates.push(path.join(app.getAppPath(), ...segments));
        candidates.push(path.join(process.resourcesPath, ...segments));
    }

    candidates.push(path.join(__dirname, ...segments));
    candidates.push(path.join(__dirname, '..', ...segments));

    for (const candidate of candidates) {
        if (candidate && fs.existsSync(candidate)) {
            return candidate;
        }
    }

    return candidates[0] || path.join(__dirname, ...segments);
}

const ENV_FILE = resolveExistingPath('.env.encrypted');

// ============================================================
//  دوال التشفير / الفك
// ============================================================
function deriveKey(password, salt) {
    return crypto.scryptSync(password, salt, 32);
}

function decrypt(base64Data, password) {
    const buf       = Buffer.from(base64Data, 'base64');
    const salt      = buf.subarray(0, 16);
    const iv        = buf.subarray(16, 32);
    const encrypted = buf.subarray(32);

    const key       = deriveKey(password, salt);
    const decipher  = crypto.createDecipheriv('aes-256-cbc', key, iv);

    const decrypted = Buffer.concat([
        decipher.update(encrypted),
        decipher.final()
    ]);

    return JSON.parse(decrypted.toString('utf8'));
}

// ============================================================
//  الـ cache — بيتحمل مرة واحدة في الذاكرة
//  ومش بيتكتب على الديسك أبداً
// ============================================================
let _cache = null;

function load() {
    if (_cache) return _cache;

    if (!fs.existsSync(ENV_FILE)) {
        throw new Error('❌ ملف .env.encrypted مش موجود! شغّل encrypt-config.js أولاً.');
    }

    try {
        const raw  = fs.readFileSync(ENV_FILE, 'utf8').trim();
        _cache     = decrypt(raw, MASTER_PASSWORD);
        return _cache;
    } catch (err) {
        throw new Error(`❌ فشل فك تشفير .env.encrypted: ${err.message}`);
    }
}

// ============================================================
//  الـ API العامة
// ============================================================
module.exports = {
    /**
     * بيجيب قيمة واحدة
     * config.get('GITHUB_TOKEN')
     */
    get(key) {
        return load()[key];
    },

    /**
     * بيجيب object فيه كل القيم دفعة واحدة
     * const { GITHUB_TOKEN, DOWNLOAD_TOKEN } = config.getAll();
     */
    getAll() {
        return { ...load() }; // نسخة — مش reference للأصل
    },

    /**
     * بيمسح الـ cache من الذاكرة
     * استخدمه لو عايز تقلل وقت القيم في RAM
     */
    clear() {
        _cache = null;
    }
};
