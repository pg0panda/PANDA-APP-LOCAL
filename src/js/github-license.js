const path = require('path');
const os = require('os');
const { BrowserWindow, ipcMain } = require('electron');
const { machineIdSync } = require('node-machine-id');
const si = require('systeminformation');
const store = require('./storage');
const _cfg = require('./config-loader');

function createGitHubLicenseManager(deps = {}) {
    const app = deps.app;
    const closeAllPowerShell = deps.closeAllPowerShell || (() => {});
    const resolveAppPath = deps.resolveAppPath || ((...segments) => path.join(__dirname, ...segments));
    const configLoader = deps.configLoader || _cfg;

    const GITHUB_CONFIG = {
        REPO: {
            owner: configLoader.get('GITHUB_OWNER'),
            repo: configLoader.get('GITHUB_REPO'),
            branch: configLoader.get('GITHUB_BRANCH'),
            filePath: configLoader.get('GITHUB_FILE_PATH'),
            token: configLoader.get('GITHUB_TOKEN')
        },
        DOWNLOAD_TOKEN: configLoader.get('DOWNLOAD_TOKEN'),
        BAN_FILE_PATH: configLoader.get('BAN_FILE_PATH'),
        GENERAL_KEYS_FILE_PATH: configLoader.get('GENERAL_KEYS_FILE_PATH')
    };

    let securityWatcherInterval = null;
    let licenseWatcherInterval = null;

    function getEgyptDate(date = new Date()) {
        try {
            const options = {
                timeZone: 'Africa/Cairo',
                year: 'numeric',
                month: '2-digit',
                day: '2-digit',
                hour: '2-digit',
                minute: '2-digit',
                second: '2-digit',
                hour12: true
            };

            const parts = new Intl.DateTimeFormat('en-US', options).formatToParts(date);
            const get = (type) => parts.find(p => p.type === type)?.value || '';

            return `${get('year')}-${get('month')}-${get('day')} ${get('hour')}:${get('minute')}:${get('second')} ${get('dayPeriod')}`;
        } catch (err) {
            console.error('❌ Failed to format Egypt date:', err);
            return null;
        }
    }

    function parseEgyptDate(dateString) {
        if (!dateString || typeof dateString !== 'string' || dateString === 'Lifetime') {
            return null;
        }

        try {
            const match = dateString.match(/^(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2}):(\d{2})\s+(AM|PM)$/i);
            if (!match) {
                return null;
            }

            let [, year, month, day, hour, minute, second, period] = match;
            year = Number(year);
            month = Number(month);
            day = Number(day);
            hour = Number(hour);
            minute = Number(minute);
            second = Number(second);
            period = period.toUpperCase();

            if (period === 'PM' && hour !== 12) hour += 12;
            if (period === 'AM' && hour === 12) hour = 0;

            return new Date(year, month - 1, day, hour, minute, second);
        } catch (err) {
            console.error('❌ Failed to parse Egypt date:', err);
            return null;
        }
    }

    async function getDeviceIdentifiers() {
        try {
            const networkInterfaces = await si.networkInterfaces();
            const primaryInterface = networkInterfaces.find(iface => iface.mac && iface.mac !== '00:00:00:00:00:00' && !iface.internal);
            const macAddress = primaryInterface ? primaryInterface.mac : 'N/A';
            const hwid = machineIdSync();
            console.log(`[Device ID] HWID: ${hwid}, MAC: ${macAddress}`);
            return { hwid, macAddress };
        } catch (error) {
            console.error('[Device ID] ❌ فشل في جلب معرفات الجهاز:', error);
            return { hwid: machineIdSync(), macAddress: 'N/A' };
        }
    }

    async function readBanListFromGitHub() {
        const { owner, repo, branch, token, BAN_FILE_PATH } = { ...GITHUB_CONFIG.REPO, ...GITHUB_CONFIG };
        const url = `https://api.github.com/repos/${owner}/${repo}/contents/${BAN_FILE_PATH}?ref=${branch}`;
        const response = await fetch(url, {
            method: 'GET',
            headers: {
                Accept: 'application/vnd.github.v3+json',
                Authorization: `token ${token}`,
                'User-Agent': 'License-Manager-App'
            }
        });

        if (!response.ok) {
            throw new Error(`[BAN] GitHub API error: ${response.status}`);
        }

        const data = await response.json();
        const content = Buffer.from(data.content, 'base64').toString('utf8');
        const banList = JSON.parse(content);
        console.log(`[BAN] ✅ تم تحميل ${banList.length} مدخل من BAN.json`);
        return { banList, sha: data.sha };
    }

    async function checkDeviceBan() {
        try {
            const { hwid, macAddress } = await getDeviceIdentifiers();
            const { banList } = await readBanListFromGitHub();

            console.log(`[BAN] 🔍 HWID الحالي: ${hwid}`);
            console.log(`[BAN] 🔍 MAC الحالي: ${macAddress}`);

            const bannedEntry = banList.find(entry => {
                if (!entry.banned || entry.banned.trim().toLowerCase() !== 'yes') return false;

                const entryHwid = (entry.hwid || '').trim().toLowerCase();
                const entryMac = (entry.macAddress || '').trim().toLowerCase();
                const curHwid = (hwid || '').trim().toLowerCase();
                const curMac = (macAddress || '').trim().toLowerCase();

                const hwidMatch = entryHwid && entryHwid === curHwid;
                const macMatch = entryMac && entryMac === curMac;

                console.log(`[BAN] 🔎 مقارنة: HWID(${hwidMatch}) MAC(${macMatch})`);
                return hwidMatch || macMatch;
            });

            if (bannedEntry) {
                let resolvedExpiry = 'Permanent';

                if (bannedEntry.banExpiryDate && bannedEntry.banExpiryDate !== 'Permanent') {
                    resolvedExpiry = bannedEntry.banExpiryDate;
                } else {
                    const seconds = Number(bannedEntry.durationSeconds) || 0;
                    const minutes = Number(bannedEntry.durationMinutes) || 0;
                    const hours = Number(bannedEntry.durationHours) || 0;
                    const days = Number(bannedEntry.durationDays) || 0;
                    const weeks = Number(bannedEntry.durationWeeks) || 0;
                    const months = Number(bannedEntry.durationMonths) || 0;
                    const years = Number(bannedEntry.durationYears) || 0;
                    const hasDuration = seconds || minutes || hours || days || weeks || months || years;

                    if (hasDuration) {
                        const startDate = bannedEntry.bannedAt ? (parseEgyptDate(bannedEntry.bannedAt) || new Date()) : new Date();
                        const d = new Date(startDate);
                        d.setFullYear(d.getFullYear() + years);
                        d.setMonth(d.getMonth() + months);
                        d.setDate(d.getDate() + (weeks * 7) + days);
                        d.setHours(d.getHours() + hours);
                        d.setMinutes(d.getMinutes() + minutes);
                        d.setSeconds(d.getSeconds() + seconds);
                        resolvedExpiry = getEgyptDate(d);
                    }
                }

                if (resolvedExpiry !== 'Permanent') {
                    const expiryDate = parseEgyptDate(resolvedExpiry);
                    if (expiryDate && new Date() > expiryDate) {
                        console.log(`[BAN] ✅ البان كان مؤقتاً وانتهى في ${resolvedExpiry} - الجهاز مسموح له بالدخول.`);
                        return { banned: false };
                    }
                }

                console.log(`[BAN] 🚫 الجهاز محظور! السبب: ${bannedEntry.reason || 'No reason'}`);
                return {
                    banned: true,
                    reason: bannedEntry.reason || 'You are banned.',
                    bannedAt: bannedEntry.bannedAt || null,
                    banExpiry: resolvedExpiry
                };
            }

            console.log('[BAN] ✅ الجهاز غير محظور.');
            return { banned: false };
        } catch (err) {
            console.error('[BAN] ❌ فشل التحقق من البان:', err.message);
            return {
                banned: true,
                reason: 'فشل الاتصال بخادم التحقق. تأكد من اتصالك بالإنترنت.'
            };
        }
    }

    async function readGeneralKeysFromGitHub() {
        const { owner, repo, branch, token, GENERAL_KEYS_FILE_PATH } = { ...GITHUB_CONFIG.REPO, ...GITHUB_CONFIG };
        const url = `https://api.github.com/repos/${owner}/${repo}/contents/${GENERAL_KEYS_FILE_PATH}?ref=${branch}`;
        const response = await fetch(url, {
            method: 'GET',
            headers: {
                Accept: 'application/vnd.github.v3+json',
                Authorization: `token ${token}`,
                'User-Agent': 'License-Manager-App'
            }
        });

        if (!response.ok) {
            throw new Error(`[General Keys] GitHub API error: ${response.status}`);
        }

        const data = await response.json();
        const content = Buffer.from(data.content, 'base64').toString('utf8');
        const keys = JSON.parse(content);
        console.log(`[General Keys] ✅ تم تحميل ${keys.length} كود عام من GENERAL_KEYS.json`);
        return { keys, sha: data.sha };
    }

    async function updateGeneralKeysToGitHub(keys, currentSha) {
        const { owner, repo, branch, token, GENERAL_KEYS_FILE_PATH } = { ...GITHUB_CONFIG.REPO, ...GITHUB_CONFIG };
        console.log(`[General Keys] 💾 تحديث ${GENERAL_KEYS_FILE_PATH} في ${owner}/${repo}...`);
        const url = `https://api.github.com/repos/${owner}/${repo}/contents/${GENERAL_KEYS_FILE_PATH}`;
        const content = Buffer.from(JSON.stringify(keys, null, 2)).toString('base64');
        const response = await fetch(url, {
            method: 'PUT',
            headers: {
                Accept: 'application/vnd.github.v3+json',
                Authorization: `token ${token}`,
                'User-Agent': 'License-Manager-App',
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                message: `Update general keys - ${new Date().toLocaleString('ar-EG')}`,
                content,
                sha: currentSha,
                branch
            })
        });

        if (!response.ok) {
            throw new Error(`GitHub update error: ${response.status} ${response.statusText}`);
        }

        const result = await response.json();
        console.log('[General Keys] ✅ تم تحديث GENERAL_KEYS.json بنجاح');
        return result.content.sha;
    }

    async function checkGeneralKey(licenseKey, shouldActivate = false) {
        try {
            const { keys, sha } = await readGeneralKeysFromGitHub();
            const keyIndex = keys.findIndex(k => k.key === licenseKey && k.type === 'general');

            if (keyIndex === -1) {
                return { success: false, isGeneral: false };
            }

            const found = keys[keyIndex];
            if (found.enabled && found.enabled.trim().toLowerCase() === 'no') {
                console.log(`[General Keys] 🚫 الكود العام موقوف (enabled: no): ${licenseKey}`);
                return { success: false, isGeneral: false, message: 'This general key is disabled.' };
            }

            const { hwid, macAddress } = await getDeviceIdentifiers();
            if (!Array.isArray(found.devices)) found.devices = [];

            const maxDevices = Number(found.maxDevices) > 0 ? Number(found.maxDevices) : 1;
            const now = new Date();
            let deviceEntry = found.devices.find(d => d.hwid === hwid);

            if (deviceEntry) {
                if (deviceEntry.expiryDate && deviceEntry.expiryDate !== 'Lifetime') {
                    const deviceExpiry = parseEgyptDate(deviceEntry.expiryDate);
                    if (deviceExpiry && now > deviceExpiry) {
                        console.log(`[General Keys] ❌ انتهت صلاحية هذا الجهاز على الكود العام: ${licenseKey}`);
                        return { success: false, isGeneral: true, message: 'انتهت صلاحية استخدامك لهذا الكود العام.' };
                    }
                }

                console.log(`[General Keys] ✅ كود عام صالح لهذا الجهاز: ${licenseKey}`);
                const permissions = (found.permissions || 'all').trim().toLowerCase();
                return {
                    success: true,
                    isGeneral: true,
                    userKey: licenseKey,
                    expiry: deviceEntry.expiryDate,
                    permissions,
                    message: 'تم التحقق من الكود العام بنجاح!',
                    activationData: {
                        key: licenseKey,
                        activationDate: deviceEntry.activationDate,
                        expiryDate: deviceEntry.expiryDate,
                        hwid,
                        macAddress,
                        isGeneral: true,
                        permissions
                    }
                };
            }

            if (found.devices.length >= maxDevices) {
                console.log(`[General Keys] 🚫 الكود العام وصل للحد الأقصى من الأجهزة (${maxDevices}): ${licenseKey}`);
                return { success: false, isGeneral: false, message: 'تم الوصول إلى الحد الأقصى لعدد الأجهزة المسموح بها لهذا الكود.' };
            }

            if (!shouldActivate) {
                console.log(`[General Keys] ℹ️ هذا الجهاز غير مسجل على الكود العام: ${licenseKey}`);
                return { success: false, isGeneral: true, message: 'هذا الجهاز غير مسجل على هذا الكود العام.' };
            }

            console.log(`[General Keys] 🆕 تسجيل جهاز جديد على الكود العام: ${licenseKey}`);
            let expiryDate = 'Lifetime';

            if (found.durationDays === -1) {
                expiryDate = 'Lifetime';
            } else {
                const dateToModify = new Date(now);
                let hasDuration = false;
                if (found.durationYears) { dateToModify.setFullYear(dateToModify.getFullYear() + Number(found.durationYears)); hasDuration = true; }
                if (found.durationMonths) { dateToModify.setMonth(dateToModify.getMonth() + Number(found.durationMonths)); hasDuration = true; }
                if (found.durationWeeks) { dateToModify.setDate(dateToModify.getDate() + (Number(found.durationWeeks) * 7)); hasDuration = true; }
                if (found.durationDays) { dateToModify.setDate(dateToModify.getDate() + Number(found.durationDays)); hasDuration = true; }
                if (found.durationHours) { dateToModify.setHours(dateToModify.getHours() + Number(found.durationHours)); hasDuration = true; }
                if (found.durationMinutes) { dateToModify.setMinutes(dateToModify.getMinutes() + Number(found.durationMinutes)); hasDuration = true; }
                if (found.durationSeconds) { dateToModify.setSeconds(dateToModify.getSeconds() + Number(found.durationSeconds)); hasDuration = true; }
                expiryDate = hasDuration ? getEgyptDate(dateToModify) : 'Lifetime';
            }

            const newDevice = { hwid, macAddress, activationDate: getEgyptDate(now), expiryDate };
            found.devices.push(newDevice);
            keys[keyIndex] = found;

            try {
                await updateGeneralKeysToGitHub(keys, sha);
                console.log('[General Keys] ✅ تم تسجيل الجهاز وتحديث GENERAL_KEYS.json');
            } catch (updateErr) {
                console.warn('[General Keys] ⚠️ فشل تحديث GENERAL_KEYS.json:', updateErr.message);
            }

            return {
                success: true,
                isGeneral: true,
                userKey: licenseKey,
                expiry: expiryDate,
                permissions: (found.permissions || 'all').trim().toLowerCase(),
                message: 'تم التحقق من الكود العام وتسجيل جهازك بنجاح!',
                activationData: {
                    key: licenseKey,
                    activationDate: newDevice.activationDate,
                    expiryDate,
                    hwid,
                    macAddress,
                    isGeneral: true,
                    permissions: (found.permissions || 'all').trim().toLowerCase()
                }
            };
        } catch (err) {
            console.warn('[General Keys] ⚠️ فشل التحقق من الأكواد العامة:', err.message);
            return { success: false, isGeneral: false };
        }
    }

    function showBanWindow(reason, bannedAt, hwid, macAddress, banExpiry = 'Permanent') {
        return new Promise((resolve) => {
            const banIconPath = resolveAppPath('sound-image', 'app.ico');
            const banWindow = new BrowserWindow({
                width: 500,
                height: 650,
                frame: false,
                transparent: true,
                resizable: false,
                alwaysOnTop: true,
                skipTaskbar: true,
                center: true,
                icon: banIconPath,
                webPreferences: {
                    nodeIntegration: true,
                    contextIsolation: false
                }
            });

            banWindow.loadFile(resolveAppPath('html', 'banned.html'));
            banWindow.webContents.on('did-finish-load', () => {
                banWindow.webContents.send('ban-data', { reason, bannedAt, hwid, macAddress, banExpiry });
            });

            ipcMain.once('ban-close', () => {
                if (!banWindow.isDestroyed()) banWindow.close();
                resolve();
            });

            banWindow.on('closed', () => resolve());
        });
    }

    async function startSecurityWatcher(isGeneralKeyManual = false, manualKey = null) {
        if (securityWatcherInterval) {
            clearInterval(securityWatcherInterval);
        }

        console.log('[Security Watcher] ▶️ تم تشغيل مراقبة البان والأكواد العامة (كل 60 ثانية).');

        const runCheck = async () => {
            console.log('[Security Watcher] 🔄 جاري الفحص الدوري...');

            try {
                const banCheck = await checkDeviceBan();
                if (banCheck.banned) {
                    console.log('[Security Watcher] 🚫 الجهاز محظور! جاري إغلاق البرنامج...');
                    stopSecurityWatcher();
                    if (licenseWatcherInterval) clearInterval(licenseWatcherInterval);
                    setTimeout(async () => {
                        const { hwid, macAddress } = await getDeviceIdentifiers();
                        await showBanWindow(banCheck.reason, banCheck.bannedAt || '—', hwid, macAddress, banCheck.banExpiry || 'Permanent');
                        closeAllPowerShell();
                        app.quit();
                    }, 500);
                    return;
                }
            } catch (err) {
                console.warn('[Security Watcher] ⚠️ خطأ في فحص البان:', err.message);
            }

            try {
                const savedKey = store.get('GitHub-Key');
                const isGeneral = isGeneralKeyManual || (savedKey && savedKey.isGeneral === true);
                const keyToCheck = manualKey || (savedKey ? savedKey.key : null);

                if (isGeneral && keyToCheck) {
                    const generalCheck = await checkGeneralKey(keyToCheck, false);
                    if (!generalCheck.success) {
                        console.log('[Security Watcher] ❌ الكود العام لم يعد موجوداً، جاري تسجيل الخروج...');
                        if (savedKey) store.delete('GitHub-Key');
                        BrowserWindow.getAllWindows().forEach(w => {
                            if (!w.isDestroyed()) {
                                w.webContents.send('force-logout', { reason: generalCheck.message || 'الكود العام الذي استخدمته لم يعد صالحاً.' });
                            }
                        });
                    } else {
                        console.log('[Security Watcher] ✅ الكود العام لا يزال صالحاً.');
                    }
                }
            } catch (err) {
                console.warn('[Security Watcher] ⚠️ خطأ في فحص الكود العام:', err.message);
            }

            console.log('[Security Watcher] ✅ انتهى الفحص الدوري.');
        };

        await runCheck();
        securityWatcherInterval = setInterval(runCheck, 60000);
    }

    function stopSecurityWatcher() {
        if (securityWatcherInterval) {
            clearInterval(securityWatcherInterval);
            securityWatcherInterval = null;
            console.log('[Security Watcher] ⏹️ تم إيقاف المراقبة.');
        }
    }

    async function startLicenseWatcher(licenseKey, isGeneralKeyManual = false) {
        if (licenseWatcherInterval) {
            clearInterval(licenseWatcherInterval);
        }

        const savedKey = store.get('GitHub-Key');
        const isGeneralKey = isGeneralKeyManual || (savedKey && savedKey.isGeneral === true);
        console.log('[License Watcher] تشغيل المراقبة - ' + (isGeneralKey ? 'كود عام' : 'كود خاص') + ' - كل 30 ثانية');

        licenseWatcherInterval = setInterval(async () => {
            try {
                let result;
                if (isGeneralKey) {
                    result = await checkGeneralKey(licenseKey, false);
                    console.log('[License Watcher] فحص الكود العام...');
                } else {
                    result = await checkGitHubLicense(licenseKey, false);
                    console.log('[License Watcher] فحص الكود الخاص...');
                }

                if (result && result.success === false) {
                    console.log('[License Watcher] الترخيص لم يعد صالحا - جاري تسجيل الخروج...');
                    forceLogout();
                    return;
                }

                console.log('[License Watcher] الترخيص مازال صالحا.');
            } catch (err) {
                console.error('[License Watcher] خطأ اثناء مراقبة الترخيص:', err);
            }
        }, 30000);
    }

    function forceLogout() {
        closeAllPowerShell();
        try {
            if (licenseWatcherInterval) {
                clearInterval(licenseWatcherInterval);
                licenseWatcherInterval = null;
            }
            stopSecurityWatcher();
            console.log('🔒 تم تسجيل الخروج إجبارياً.');
            closeAllPowerShell();
            const windows = BrowserWindow.getAllWindows();
            windows.forEach((win) => {
                if (!win || win.isDestroyed()) return;
                try {
                    win.webContents.send('force-logout', { reason: 'License expired or removed' });
                } catch (err) {
                    console.warn('⚠️ Failed to send force-logout to window:', err);
                }
            });
        } catch (err) {
            console.error('❌ Force logout error:', err);
        }
    }

    async function checkGitHubLicense(licenseKey, shouldActivate = false) {
        try {
            if (!licenseKey) {
                return { success: false, message: 'License key is required.' };
            }

            const existingLicense = store.get('GitHub-Key');
            const { hwid, macAddress } = await getDeviceIdentifiers();

            if (existingLicense && existingLicense.key === licenseKey) {
                if (existingLicense.hwid && existingLicense.hwid !== hwid) {
                    console.log('[GitHub Auth] ❌ الكود المحلي مرتبط بجهاز آخر.');
                    store.delete('GitHub-Key');
                    return { success: false, message: 'This license is locked to another device.' };
                }

                if (existingLicense.expiryDate && existingLicense.expiryDate !== 'Lifetime') {
                    const localExpiryDate = parseEgyptDate(existingLicense.expiryDate);
                    if (localExpiryDate && new Date() > localExpiryDate) {
                        console.log('[GitHub Auth] ❌ الكود منتهي الصلاحية محلياً.');
                        store.delete('GitHub-Key');
                        return { success: false, message: 'Expired' };
                    }
                }

                console.log('[GitHub Auth] 🔄 الكود صالح محلياً. جاري التحقق من GitHub...');
            }

            if (!shouldActivate && !existingLicense) {
                console.log('[GitHub Auth] ℹ️ لا يوجد ترخيص محلي، سيتم التحقق من GitHub مباشرة.');
            }

            const { licenses } = await readLicensesFromGitHub();
            const foundLicense = licenses.find(lic => lic.key === licenseKey);

            if (!foundLicense) {
                console.log('[GitHub Auth] ❌ الكود غير موجود في GitHub.');
                if (existingLicense && existingLicense.key === licenseKey) {
                    store.delete('GitHub-Key');
                }
                return { success: false, message: 'License not found.' };
            }

            console.log('[GitHub Auth] 🚀 تم العثور على الكود.');

            if (foundLicense.enabled && foundLicense.enabled.trim().toLowerCase() === 'no') {
                console.log('[GitHub Auth] 🚫 الكود موقوف (enabled: no).');
                forceLogout();
                return { success: false, message: 'This license has been disabled.' };
            }

            if (foundLicense.hwid && foundLicense.hwid !== hwid) {
                console.log('[GitHub Auth] ❌ الكود مرتبط بجهاز آخر.');
                return { success: false, message: 'This license is locked to another device.' };
            }

            let expiryDate = null;
            let activationDate = null;
            let needsUpdate = false;
            const now = new Date();

            if (foundLicense.activationDate) {
                console.log('[GitHub Auth] 📅 الكود مفعل مسبقاً.');
                activationDate = foundLicense.activationDate;
                expiryDate = foundLicense.expiryDate === 'Lifetime' ? 'Lifetime' : parseEgyptDate(foundLicense.expiryDate);
                if (expiryDate !== 'Lifetime' && expiryDate && now > expiryDate) {
                    console.log('[GitHub Auth] ❌ الكود منتهي الصلاحية.');
                    store.delete('GitHub-Key');
                    return { success: false, message: 'This license is expired.' };
                }
            } else {
                if (!shouldActivate) {
                    return { success: false, message: 'License is not activated yet.' };
                }

                console.log('[GitHub Auth] 🆕 تفعيل جديد...');
                needsUpdate = true;
                activationDate = getEgyptDate(now);
                if (foundLicense.durationDays === -1) {
                    expiryDate = 'Lifetime';
                } else {
                    const dateToModify = new Date(now);
                    if (foundLicense.durationYears) dateToModify.setFullYear(dateToModify.getFullYear() + Number(foundLicense.durationYears));
                    if (foundLicense.durationMonths) dateToModify.setMonth(dateToModify.getMonth() + Number(foundLicense.durationMonths));
                    if (foundLicense.durationDays) dateToModify.setDate(dateToModify.getDate() + Number(foundLicense.durationDays));
                    if (foundLicense.durationWeeks) dateToModify.setDate(dateToModify.getDate() + (Number(foundLicense.durationWeeks) * 7));
                    if (foundLicense.durationHours) dateToModify.setHours(dateToModify.getHours() + Number(foundLicense.durationHours));
                    if (foundLicense.durationMinutes) dateToModify.setMinutes(dateToModify.getMinutes() + Number(foundLicense.durationMinutes));
                    if (foundLicense.durationSeconds) dateToModify.setSeconds(dateToModify.getSeconds() + Number(foundLicense.durationSeconds));
                    expiryDate = dateToModify;
                }
            }

            if (needsUpdate) {
                try {
                    console.log('[GitHub Auth] 💾 تحديث GitHub...');
                    const licenseIndex = licenses.findIndex(lic => lic.key === licenseKey);
                    if (licenseIndex > -1) {
                        licenses[licenseIndex] = {
                            ...licenses[licenseIndex],
                            activationDate,
                            expiryDate: expiryDate === 'Lifetime' ? 'Lifetime' : getEgyptDate(expiryDate),
                            hwid,
                            macAddress
                        };
                        await updateLicensesToGitHub(licenses, sha);
                        console.log('[GitHub Auth] ✅ تم تحديث GitHub.');
                    }
                } catch (updateError) {
                    console.warn('[GitHub Auth] ⚠️ فشل تحديث GitHub:', updateError.message);
                }
            }

            const activationData = {
                key: licenseKey,
                activationDate,
                expiryDate: expiryDate === 'Lifetime' ? 'Lifetime' : getEgyptDate(expiryDate),
                hwid,
                macAddress
            };
            store.set('GitHub-Key', activationData);
            return {
                success: true,
                message: 'تم التحقق من الكود بنجاح!',
                userKey: licenseKey,
                expiry: activationData.expiryDate,
                activationData
            };
        } catch (error) {
            console.error('[GitHub Auth] ❌ خطأ:', error);
            const existingLicense = store.get('GitHub-Key');
            if (existingLicense && existingLicense.key === licenseKey) {
                console.log('[GitHub Auth] 🔄 استخدام البيانات المحلية.');
                return { success: true, message: 'تم التحقق محلياً (GitHub غير متاح).', userKey: existingLicense.key, expiry: existingLicense.expiryDate, activationData: existingLicense };
            }
            return { success: false, message: 'فشل في التحقق من GitHub.' };
        }
    }

    async function readLicensesFromGitHub() {
        const { owner, repo, branch, filePath, token } = GITHUB_CONFIG.REPO;
        console.log(`[GitHub API] 📖 قراءة ${filePath} من ${owner}/${repo}...`);
        const url = `https://api.github.com/repos/${owner}/${repo}/contents/${filePath}?ref=${branch}`;
        const response = await fetch(url, {
            method: 'GET',
            headers: {
                Accept: 'application/vnd.github.v3+json',
                Authorization: `token ${token}`,
                'User-Agent': 'License-Manager-App'
            }
        });

        if (!response.ok) {
            throw new Error(`GitHub API error: ${response.status} ${response.statusText}`);
        }

        const data = await response.json();
        const content = Buffer.from(data.content, 'base64').toString('utf8');
        const licenses = JSON.parse(content);
        console.log(`[GitHub API] ✅ تم تحميل ${licenses.length} ترخيص من GitHub`);
        return { licenses, sha: data.sha };
    }

    async function updateLicensesToGitHub(licenses, currentSha) {
        const { owner, repo, branch, filePath, token } = GITHUB_CONFIG.REPO;
        console.log(`[GitHub API] 💾 تحديث ${filePath} في ${owner}/${repo}...`);
        const url = `https://api.github.com/repos/${owner}/${repo}/contents/${filePath}`;
        const content = Buffer.from(JSON.stringify(licenses, null, 2)).toString('base64');
        const response = await fetch(url, {
            method: 'PUT',
            headers: {
                Accept: 'application/vnd.github.v3+json',
                Authorization: `token ${token}`,
                'User-Agent': 'License-Manager-App',
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                message: `Update licenses - ${new Date().toLocaleString('ar-EG')}`,
                content,
                sha: currentSha,
                branch
            })
        });

        if (!response.ok) {
            throw new Error(`GitHub update error: ${response.status} ${response.statusText}`);
        }

        const result = await response.json();
        console.log('[GitHub API] ✅ تم تحديث GitHub بنجاح');
        return result.content.sha;
    }

    return {
        GITHUB_CONFIG,
        checkDeviceBan,
        checkGeneralKey,
        checkGitHubLicense,
        getDeviceIdentifiers,
        getEgyptDate,
        parseEgyptDate,
        readBanListFromGitHub,
        readGeneralKeysFromGitHub,
        readLicensesFromGitHub,
        showBanWindow,
        startLicenseWatcher,
        startSecurityWatcher,
        stopSecurityWatcher,
        forceLogout,
        updateGeneralKeysToGitHub,
        updateLicensesToGitHub
    };
}

module.exports = { createGitHubLicenseManager };
