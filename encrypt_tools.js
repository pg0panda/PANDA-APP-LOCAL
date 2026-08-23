// =================================================================
//          ✅ أداة التشفير (لإعادة بناء ملفاتك المحمية) ✅
// =================================================================
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

// --- الإعدادات ---
const sourceDir = path.join(__dirname, 'tools');
const outputDir = path.join(__dirname, 'src', 'encrypted-tools');   // اسم المجلد الذي سيتم حفظ الملفات المشفرة فيه
const addonPath = (process.type === 'renderer' || require('electron').app?.isPackaged)
    ? path.join(process.resourcesPath, 'panda_secure_addon.node')
    : path.join(__dirname, 'build', 'Release', 'panda_secure_addon.node');
const nativeAddon = require(addonPath);
const SALT_LENGTH = 16;
const AUTH_TAG_LENGTH = 16;
const DEFAULT_IV_LENGTH = 12;
const ENCRYPTION_VERSION = 2;

function decryptSerializedConfig(text, password) {
    const buf = Buffer.from(text, 'base64');
    const salt = buf.subarray(0, 16);
    const iv = buf.subarray(16, 32);
    const encrypted = buf.subarray(32);

    const key = crypto.scryptSync(password, salt, 32);
    const decipher = crypto.createDecipheriv('aes-256-cbc', key, iv);
    const decrypted = Buffer.concat([decipher.update(encrypted), decipher.final()]);
    return JSON.parse(decrypted.toString('utf8'));
}

function getCandidateEncryptedConfigPaths() {
    return [
        path.join(__dirname, 'src', '.env.encrypted'),
        path.join(__dirname, '.env.encrypted')
    ];
}

function readEncryptedConfigValue(key) {
    try {
        const candidatePaths = getCandidateEncryptedConfigPaths();
        let encryptedPath = null;

        for (const candidate of candidatePaths) {
            if (fs.existsSync(candidate)) {
                encryptedPath = candidate;
                break;
            }
        }

        if (!encryptedPath) {
            return null;
        }

        const masterPassword = nativeAddon.getMasterPassword();
        const raw = fs.readFileSync(encryptedPath, 'utf8').trim();
        const data = decryptSerializedConfig(raw, masterPassword);
        return data && data[key] ? data[key] : null;
    } catch (error) {
        console.warn(`[encrypt-tools] Could not read encrypted config value ${key}:`, error.message);
        return null;
    }
}

function getEncryptionKey(customKey = null) {
    const rawKey = customKey
        || process.env.ENCRYPTION_KEY
        || readEncryptedConfigValue('ENCRYPTION_KEY')
        || nativeAddon.getMasterPassword();
    const secretKey = typeof rawKey === 'string'
        ? rawKey.trim().replace(/^['"]|['"]$/g, '')
        : '';

    if (!secretKey) {
        throw new Error('Encryption key is missing.');
    }
    return secretKey;
}

function encryptBuffer(fileBuffer, customKey = null, ivLength = DEFAULT_IV_LENGTH) {
    const secretKey = getEncryptionKey(customKey);
    const salt = crypto.randomBytes(SALT_LENGTH);
    const key = crypto.pbkdf2Sync(secretKey, salt, 100000, 32, 'sha256');
    const iv = crypto.randomBytes(ivLength);
    const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
    const encrypted = Buffer.concat([cipher.update(fileBuffer), cipher.final()]);
    const authTag = cipher.getAuthTag();

    return Buffer.concat([
        Buffer.from([ENCRYPTION_VERSION, ivLength]),
        salt,
        iv,
        authTag,
        encrypted
    ]);
}

function decryptBuffer(encryptedBuffer, customKey = null) {
    const secretKey = getEncryptionKey(customKey);

    const tryDecrypt = (salt, iv, authTag, encryptedData) => {
        const key = crypto.pbkdf2Sync(secretKey, salt, 100000, 32, 'sha256');
        const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv);
        decipher.setAuthTag(authTag);
        return Buffer.concat([decipher.update(encryptedData), decipher.final()]);
    };

    if (encryptedBuffer.length > 0 && encryptedBuffer[0] === ENCRYPTION_VERSION) {
        const ivLength = encryptedBuffer[1];
        if (ivLength > 0 && ivLength <= 16) {
            const salt = encryptedBuffer.subarray(2, 2 + SALT_LENGTH);
            const ivOffset = 2 + SALT_LENGTH;
            const iv = encryptedBuffer.subarray(ivOffset, ivOffset + ivLength);
            const authTagOffset = ivOffset + ivLength;
            const authTag = encryptedBuffer.subarray(authTagOffset, authTagOffset + AUTH_TAG_LENGTH);
            const encryptedData = encryptedBuffer.subarray(authTagOffset + AUTH_TAG_LENGTH);
            if (encryptedData.length > 0) {
                try {
                    return tryDecrypt(salt, iv, authTag, encryptedData);
                } catch (error) {
                    if (!/Unsupported state|unable to authenticate|bad decrypt/i.test(error.message)) {
                        throw error;
                    }
                }
            }
        }
    }

    const legacyIvLengths = [12, 16];
    for (const ivLength of legacyIvLengths) {
        const salt = encryptedBuffer.subarray(0, SALT_LENGTH);
        const iv = encryptedBuffer.subarray(SALT_LENGTH, SALT_LENGTH + ivLength);
        const authTag = encryptedBuffer.subarray(SALT_LENGTH + ivLength, SALT_LENGTH + ivLength + AUTH_TAG_LENGTH);
        const encryptedData = encryptedBuffer.subarray(SALT_LENGTH + ivLength + AUTH_TAG_LENGTH);

        if (encryptedData.length > 0) {
            try {
                return tryDecrypt(salt, iv, authTag, encryptedData);
            } catch (error) {
                if (!/Unsupported state|unable to authenticate|bad decrypt/i.test(error.message)) {
                    throw error;
                }
            }
        }
    }

    throw new Error('Unable to decrypt data with the provided key.');
}

function encryptFileBuffer(fileBuffer, customKey = null, ivLength = DEFAULT_IV_LENGTH) {
    return encryptBuffer(fileBuffer, customKey, ivLength);
}

function runEncryption() {
    if (!fs.existsSync(outputDir)) {
        fs.mkdirSync(outputDir);
        console.log(`📁 تم إنشاء مجلد المخرجات: ${outputDir}`);
    }

    try {
        const toolFiles = fs.readdirSync(sourceDir);
        console.log(`🔍 تم العثور على ${toolFiles.length} أداة في '${sourceDir}'. بدء عملية التشفير...`);

        for (const toolName of toolFiles) {
            const sourceFilePath = path.join(sourceDir, toolName);
            const stats = fs.statSync(sourceFilePath);
            if (stats.isDirectory()) {
                console.log(`🟡 تم تجاهل المجلد: ${toolName}`);
                continue;
            }

            const outputFilePath = path.join(outputDir, toolName);
            const fileBuffer = fs.readFileSync(sourceFilePath);
            const encryptedBuffer = encryptFileBuffer(fileBuffer);
            fs.writeFileSync(outputFilePath, encryptedBuffer);
            console.log(`✅ تم تشفير وحفظ: ${toolName} -> ${outputFilePath}`);
        }

        console.log('\n🎉 اكتملت عملية التشفير بنجاح! يمكنك الآن استخدام هذه الملفات في تطبيقك.');
    } catch (error) {
        if (error.code === 'ENOENT') {
            console.error(`❌ خطأ: المجلد المصدر '${sourceDir}' غير موجود. الرجاء إنشاء المجلد ووضع أدواتك فيه.`);
        } else {
            console.error('❌ حدث خطأ أثناء عملية التشفير:', error);
        }
    }
}

if (require.main === module) {
    runEncryption();
}

module.exports = {
    SALT_LENGTH,
    AUTH_TAG_LENGTH,
    DEFAULT_IV_LENGTH,
    ENCRYPTION_VERSION,
    getEncryptionKey,
    encryptBuffer,
    decryptBuffer,
    encryptFileBuffer,
    runEncryption
};