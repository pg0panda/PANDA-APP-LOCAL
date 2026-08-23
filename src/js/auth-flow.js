const path = require('path');
const { BrowserWindow, ipcMain } = require('electron');

function createAuthFlowManager(deps = {}) {
    const app = deps.app;
    const BrowserWindowCtor = deps.BrowserWindow || BrowserWindow;
    const ipcMainRef = deps.ipcMain || ipcMain;
    const store = deps.store;
    const userHWID = deps.userHWID;
    const githubLicenseManager = deps.githubLicenseManager;

    function showAutoLoginWindow(storedKey, keyType) {
        return new Promise((resolve) => {
            const banIconPath = path.join(__dirname, '..', 'sound-image', 'app.ico');
            const autoLoginWindow = new BrowserWindowCtor({
                width: 500,
                height: 650,
                frame: false,
                transparent: true,
                resizable: false,
                alwaysOnTop: false,
                skipTaskbar: false,
                icon: banIconPath,
                webPreferences: {
                    nodeIntegration: true,
                    contextIsolation: false
                }
            });

            autoLoginWindow.loadFile(path.join(__dirname, '..', 'html', 'autologin.html'));

            let resolved = false;
            const resolver = (result) => {
                if (!resolved) {
                    resolved = true;
                    if (!autoLoginWindow.isDestroyed()) {
                        autoLoginWindow.close();
                    }
                    resolve(result);
                }
            };

            ipcMainRef.once('modal-response', async (event, action) => {
                console.log(`[Modal] تم استلام الرد: ${action}`);
                if (action === 'quick') {
                    console.log(`[Modal] المستخدم اختار الدخول السريع، نوع المفتاح: ${keyType}`);
                    const loginResult = await githubLicenseManager.checkGitHubLicense(storedKey);
                    console.log('[Modal] نتيجة الدخول السريع:', loginResult);
                    resolver(loginResult);
                } else {
                    console.log('[Modal] المستخدم اختار الدخول اليدوي.');
                    resolver({ success: false, message: 'اختار المستخدم الدخول اليدوي' });
                }
            });

            autoLoginWindow.on('closed', () => {
                if (!resolved) {
                    console.log('[Modal] تم إغلاق نافذة الدخول السريع (بدون اختيار).');
                    resolver({ success: false, message: 'تم إغلاق النافذة' });
                }
            });
        });
    }

    function registerAuthHandlers() {
        ipcMainRef.handle('login-request', async (event, { licenseKey, rememberMe }) => {
            try {
                if (!licenseKey || !licenseKey.trim()) {
                    return { success: false, message: 'الرجاء إدخال مفتاح ترخيص.' };
                }
                console.log(`[Login Request] محاولة تسجيل دخول بالمفتاح: ${licenseKey}`);

                const banCheck = await githubLicenseManager.checkDeviceBan();
                if (banCheck.banned) {
                    console.log('[Login Request] 🚫 الجهاز محظور.');
                    const { hwid, macAddress } = await githubLicenseManager.getDeviceIdentifiers();
                    githubLicenseManager.showBanWindow(banCheck.reason, banCheck.bannedAt || '—', hwid, macAddress, banCheck.banExpiry || 'Permanent').then(() => {
                        githubLicenseManager.forceLogout();
                        app.quit();
                    });
                    return { success: false, message: '🚫 تم حظر هذا الجهاز.' };
                }

                const generalKeyResult = await githubLicenseManager.checkGeneralKey(licenseKey, true);
                if (generalKeyResult.success) {
                    console.log('[Login Request] ✅ كود عام صالح.');
                    if (rememberMe) {
                        store.set('GitHub-Key', generalKeyResult.activationData);
                    }
                    await githubLicenseManager.startLicenseWatcher(licenseKey, true);
                    await githubLicenseManager.startSecurityWatcher(true, licenseKey);
                    return generalKeyResult;
                }

                const githubResult = await githubLicenseManager.checkGitHubLicense(licenseKey, true);
                if (githubResult?.success) {
                    console.log('[Login Request] ✅ تم التحقق عبر GitHub.');
                    if (!rememberMe) {
                        store.delete('GitHub-Key');
                        console.log('[Login Request] ⚠️ لم يتم حفظ الترخيص محلياً.');
                    }
                    await githubLicenseManager.startLicenseWatcher(licenseKey);
                    await githubLicenseManager.startSecurityWatcher();
                    return { ...githubResult, isGeneral: false, permissions: 'all' };
                }

                if (githubResult && githubResult.message) {
                    console.log(`[Login Request] ❌ فشل GitHub: ${githubResult.message}`);
                    return githubResult;
                }

                console.log('[Login Request] ❌ فشل التحقق بالكامل.');
                return { success: false, message: 'المفتاح الذي أدخلته غير صحيح.' };
            } catch (error) {
                console.error('[Login Request] ❌ خطأ:', error);
                return { success: false, message: 'حدث خطأ أثناء تسجيل الدخول.' };
            }
        });

        ipcMainRef.handle('check-stored-license', async () => {
            const githubKey = store.get('GitHub-Key');
            let loginResult = null;

            if (githubKey && githubKey.key) {
                loginResult = await githubLicenseManager.checkGitHubLicense(githubKey.key);
            }

            if (!loginResult) {
                return { success: false, message: 'لا يوجد مفتاح محفوظ' };
            }

            return loginResult;
        });

        ipcMainRef.handle('auto-login-request', async () => {
            console.log('[Auto Login] محاولة الدخول التلقائي...');
            const localLicenseInfo = store.get('GitHub-Key');
            if (localLicenseInfo && localLicenseInfo.key) {
                console.log(`[Auto Login] العثور على كود GitHub محفوظ: ${localLicenseInfo.key}`);
                const localResult = await githubLicenseManager.checkGitHubLicense(localLicenseInfo.key);
                if (localResult && localResult.success) {
                    console.log('[Auto Login] نجح الدخول بالكود المحلي');
                    return {
                        success: true,
                        message: 'تم الدخول بالكود المحلي المحفوظ',
                        userKey: localResult.userKey,
                        expiry: localResult.expiry,
                        isGeneral: localLicenseInfo.isGeneral === true,
                        permissions: localLicenseInfo.permissions || 'all'
                    };
                } else if (localResult && localResult.message === 'Expired') {
                    console.log('[Auto Login] الكود المحلي منتهي الصلاحية');
                }
            }

            console.log('[Auto Login] لا توجد أكواد محفوظة صالحة');
            return {
                success: false,
                message: 'لا توجد أكواد محفوظة صالحة. الرجاء إدخال كود جديد.'
            };
        });
    }

    return { showAutoLoginWindow, registerAuthHandlers };
}

module.exports = { createAuthFlowManager };
