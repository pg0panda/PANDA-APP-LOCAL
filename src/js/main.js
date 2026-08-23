//$OutputEncoding = [Console]::OutputEncoding = [Text.UTF8Encoding]::UTF8



const path = require('path');
const { https } = require('follow-redirects'  );
const nativeHttps = require('https');
const os = require('os');
const { app, BrowserWindow, ipcMain, dialog, shell, screen, globalShortcut, Notification } = require('electron');
const fs = require('fs');
const { machineIdSync } = require('node-machine-id');
const { autoUpdater } = require('electron-updater');
const log = require('electron-log');
autoUpdater.autoDownload = true;
autoUpdater.autoInstallOnAppQuit = true;
const si = require('systeminformation');
const crypto = require('crypto');
const { exec, spawn, execSync } = require('child_process');
const store = require('./storage.js');
const { askAI } = require('./ai');
const { decryptBuffer } = require('../../encrypt_tools');
const { createGitHubLicenseManager } = require('./github-license');
const { createAuthFlowManager } = require('./auth-flow');
const _cfg = require('./config-loader');
const { registerSmartDiscordRpc } = require('./discord');
const { sendActivationEmail } = require('./license-email');

function resolveAppPath(...segments) {
    const candidates = [];

    if (app && app.isPackaged) {
        candidates.push(path.join(process.resourcesPath, 'app.asar', ...segments));
        candidates.push(path.join(process.resourcesPath, 'app.asar', 'src', ...segments));
        if (app.getAppPath) {
            candidates.push(path.join(app.getAppPath(), ...segments));
            candidates.push(path.join(app.getAppPath(), 'src', ...segments));
        }
        candidates.push(path.join(process.resourcesPath, ...segments));
        candidates.push(path.join(process.resourcesPath, 'src', ...segments));
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

if (process.platform === 'win32') {
    try {
        require('child_process').execSync('chcp 65001 > nul');
    } catch (e) {}
}

// --- المتغيرات العامة ---
let loadingWindow; // نافذة التحميل
let mainWindow; // النافذة الرئيسية
let paymentWindow; // نافذة الدفع
let currentDownloadRequest = null;
let currentFileStream = null;

const userHWID = machineIdSync();
console.log(`HWID للجهاز الحالي: ${userHWID}`);


function updateLoadingStatus(message, progress = null, detail = null) {
    if (!loadingWindow || loadingWindow.isDestroyed()) {
        return;
    }

    try {
        loadingWindow.webContents.send('loading-status', {
            message: message || 'Preparing...',
            progress: typeof progress === 'number' ? Math.max(0, Math.min(100, progress)) : null,
            detail: detail || ''
        });
    } catch (error) {
        console.warn('⚠️ فشل تحديث نافذة التحميل:', error.message);
    }
}

function closeLoadingScreen() {
    if (loadingWindow && !loadingWindow.isDestroyed()) {
        loadingWindow.close();
        loadingWindow = null;
    }
}

// --- دالة إنشاء نافذة التحميل (النسخة المُحسّنة والجمالية) ---
function createLoadingScreen() {
const banIconPath = resolveAppPath('sound-image', 'app.ico');

    loadingWindow = new BrowserWindow({
        width: 450,
        height: 350,
        frame: false,
        transparent: true,
        center: true,
        resizable: false,
        maximizable: false,
        autoHideMenuBar: true,
        alwaysOnTop: false,
        skipTaskbar: true,
        icon: banIconPath,
        modal: true,
        webPreferences: {
            nodeIntegration: true,
            contextIsolation: false,
        }
    });


    loadingWindow.loadFile(resolveAppPath('html', 'loading.html')).catch((error) => {
        console.error('❌ فشل تحميل شاشة التحميل:', error);
    });

    // بعد أن يتم تحميل النافذة، نرسل لها مسار الصورة
    loadingWindow.webContents.on('did-finish-load', () => {
        if (loadingWindow && !loadingWindow.isDestroyed()) {
            loadingWindow.show();
        }

        let imageSrc;
        const iconPath = resolveAppPath('sound-image', 'icon.png');
        try {
            // نحول مسار الملف إلى صيغة Base64 لضمان عمله دائمًا
            const imageBuffer = fs.readFileSync(iconPath);
            imageSrc = `data:image/png;base64,${imageBuffer.toString('base64')}`;
        } catch (error) {
            console.error("لم يتم العثور على 'icon.png'، سيتم استخدام الصورة الاحتياطية.", error);
            imageSrc = 'https://raw.githubusercontent.com/electron-userland/electron-builder/master/packages/electron-builder/templates/icons/icon.png';
        }
        // نرسل مسار الصورة إلى الواجهة الرسومية
        loadingWindow.webContents.send('set-logo', imageSrc);
        updateLoadingStatus('Preparing environment...', 5, 'Starting Panda Toolbox...');
    });

    loadingWindow.on('closed', () => { loadingWindow = null; });
}


async function createWindow() {

    mainWindow = new BrowserWindow({
        width: 900,
        height: 650,
        frame: false,
        resizable: false,
        maximizable: false,
        autoHideMenuBar: true,
        icon: resolveAppPath('sound-image', 'app.ico'),
        show: false, // **مهم: إخفاء النافذة الرئيسية عند إنشائها**
        webPreferences: {
            preload: resolveAppPath('preload.js'),
            contextIsolation: true,
            nodeIntegration: false,
            enableRemoteModule: false,
        }
    });

   mainWindow.webContents.on('did-finish-load', () => {
        console.log("✅ [MainWindow] تم تحميل محتوى index.html بنجاح.");
        console.log("📤 [MainWindow] جاري إرسال معلومات النظام...");
        
        // 2. أرسل البيانات فقط بعد أن تكون الصفحة جاهزة
        sendSystemInfo(mainWindow);
    });

    // 3. ابدأ تحميل الملف
    console.log("⏳ [MainWindow] جاري تحميل ملف index.html...");
    await mainWindow.loadFile(resolveAppPath('html', 'index.html'));
    // ------------------------------------

    return mainWindow;
}

// دالة جلب معلومات الجهاز (تبقى كما هي، لا تحتاج لتعديل)
async function sendSystemInfo(window) {
    if (!window || window.isDestroyed()) {
        console.warn("⚠️ تعذر إرسال معلومات النظام لأن النافذة غير موجودة.");
        return;
    }
    try {
        const cpuInfo = await si.cpu();
        const memInfo = await si.mem();
        const gpuInfo = await si.graphics();

        let gpuModels = ['N/A']; // إرسالها كمصفوفة
        if (gpuInfo.controllers && gpuInfo.controllers.length > 0) {
            gpuModels = gpuInfo.controllers.map(gpu => gpu.model);
        }

        const data = {
            cpu: cpuInfo.brand || 'N/A',
            ram: `${(memInfo.total / 1024 / 1024 / 1024).toFixed(1)} GB`,
            gpu: gpuModels // إرسال المصفوفة
        };
        
        window.webContents.send('system-info', data);
        console.log("✅ [SystemInfo] تم إرسال البيانات بنجاح:", data);

    } catch (error) {
        console.error('❌ [SystemInfo] فشل في جلب معلومات النظام:', error);
    }
}

// =================================================================
//          دالة showWelcomeWindow في main.js
// =================================================================
function showWelcomeWindow() {
    const userName = os.userInfo().username;
    const { width } = screen.getPrimaryDisplay().workAreaSize;
    const welcomeWidth = 400;
    const welcomeHeight = 122;
    const margin = 16;

    const welcomeWindow = new BrowserWindow({
        width: welcomeWidth,
        height: welcomeHeight,
        frame: false,
        transparent: true,
        alwaysOnTop: true,
        resizable: false,
        hasShadow: false,
        skipTaskbar: true,
        hasShadow: false,
        backgroundColor: '#00000000',
        x: Math.max(0, width - welcomeWidth - margin),
        y: margin,
        webPreferences: {
            nodeIntegration: true,
            contextIsolation: false,
            backgroundThrottling: false
        }
    });

    welcomeWindow.loadFile(resolveAppPath('html', 'welcome.html')).catch((error) => {
        console.error('❌ فشل تحميل شاشة الترحيب:', error);
    });

    welcomeWindow.webContents.on('did-finish-load', () => {
        if (welcomeWindow && !welcomeWindow.isDestroyed()) {
            welcomeWindow.show();
        }
        welcomeWindow.webContents.send('set-user-name', userName);
    });

    // نقفلها بعد 10 ثواني
    setTimeout(() => {
        if (welcomeWindow && !welcomeWindow.isDestroyed()) {
            welcomeWindow.close();
        }
    }, 10000);

    return welcomeWindow;
}

// =================================================================
//      🐙 GitHub License System
//      يتم التعامل مع كل منطق GitHub والـ license داخل github-license.js
// =================================================================

let githubLicenseManager = null;
let authFlowManager = null;

function initializeAuthModules() {
    if (githubLicenseManager && authFlowManager) {
        return;
    }

    githubLicenseManager = createGitHubLicenseManager({
        app,
        BrowserWindow,
        ipcMain,
        store,
        configLoader: _cfg,
        closeAllPowerShell,
        resolveAppPath,
        userHWID
    });

    authFlowManager = createAuthFlowManager({
        app,
        BrowserWindow,
        ipcMain,
        store,
        userHWID,
        githubLicenseManager
    });

    authFlowManager.registerAuthHandlers();
}

app.whenReady().then(async () => {
    console.log("🚀 التطبيق جاهز...");

    initializeAuthModules();

    // ✅ إنشاء loading screen الأول
    createLoadingScreen();

    updateLoadingStatus('Checking security...', 10, 'Verifying device status...');
    const startupBanCheck = await githubLicenseManager.checkDeviceBan();
    if (startupBanCheck.banned) {
        console.log(`[Startup] 🚫 الجهاز محظور - إغلاق التطبيق.`);
        const { hwid: banHwid, macAddress: banMac } = await githubLicenseManager.getDeviceIdentifiers();
        updateLoadingStatus('Blocked', 100, 'Device is restricted');
        await githubLicenseManager.showBanWindow(
            startupBanCheck.reason,
            startupBanCheck.bannedAt || '—',
            banHwid,
            banMac,
            startupBanCheck.banExpiry || 'Permanent'
        );
        closeLoadingScreen();
        closeAllPowerShell();
        app.quit();
        return;
    }

    updateLoadingStatus('Preparing interface...', 35, 'Loading the main window...');
    await createWindow();

    updateLoadingStatus('Checking saved access...', 70, 'Validating your license state...');

    // منع DevTools
    globalShortcut.register('Control+Shift+I', () => false);

    // --- منطق بدء التشغيل (GitHub فقط) ---

    let loginSuccessful = false;
    const localLicenseInfo = store.get("GitHub-Key");

    if (localLicenseInfo && localLicenseInfo.key) {
        updateLoadingStatus('Checking saved license...', 75, 'Validating your license...');
        const githubResult = await githubLicenseManager.checkGitHubLicense(localLicenseInfo.key);

        if (githubResult && githubResult.success) {
            console.log(`[Startup] ✅ الكود ${localLicenseInfo.key} صالح من GitHub.`);
            updateLoadingStatus('Completing login...', 85, 'Preparing your session...');
            const choice = await authFlowManager.showAutoLoginWindow(githubResult.userKey, 'github');
            if (choice.success) {
                mainWindow.webContents.send('login-successful', choice);
                mainWindow.webContents.send('play-login-sound');
                loginSuccessful = true;
                await githubLicenseManager.startSecurityWatcher();
            } else {
                console.log(`[Startup] المستخدم رفض الدخول التلقائي بالكود من GitHub.`);
            }
        } else if (githubResult && githubResult.message === "Expired") {
            console.log(`[Startup] ❌ الكود ${localLicenseInfo.key} منتهي الصلاحية.`);
        } else {
            console.log(`[Startup] ❌ فشل التحقق من GitHub للكود ${localLicenseInfo.key}.`);
        }
    }

    updateLoadingStatus('Finishing launch...', 95, 'Opening Panda Toolbox...');
    mainWindow.show();
    closeLoadingScreen();

    showWelcomeWindow();

    if (!loginSuccessful) {
        mainWindow.webContents.send('auto-login-failed');
    }

    globalShortcut.register('Control+R', () => {
        console.log('🔄 جاري إعادة تشغيل البرنامج...');
        closeAllPowerShell();
        app.relaunch();
        app.exit();
    });
});


// =================================================================
//   ✅ معالج طلب الدخول النهائي
// =================================================================

async function quickLoginWithLicense(key) {
    return githubLicenseManager ? githubLicenseManager.checkGitHubLicense(key, true) : { success: false, message: 'المحرّك غير جاهز بعد.' };
}

function showAutoLoginWindow(storedKey, keyType) {
    return authFlowManager ? authFlowManager.showAutoLoginWindow(storedKey, keyType) : Promise.resolve({ success: false, message: 'المحرّك غير جاهز بعد.' });
}

async function loginWithLicenseNormal(licenseKey, rememberMe) {
    return githubLicenseManager ? githubLicenseManager.checkGitHubLicense(licenseKey, true) : { success: false, message: 'المحرّك غير جاهز بعد.' };
}

ipcMain.handle('ask-ai', async (event, message) => {
    try {
        const reply = await askAI(message);
        return { success: true, reply };
    } catch (err) {
        console.error(err);
        return { success: false, reply: 'AI Error' };
    }
});

ipcMain.handle('get-hwid', () => userHWID);
ipcMain.handle('get-app-version', () => app.getVersion());
ipcMain.on('check-for-updates', () => {
    autoUpdater.checkForUpdatesAndNotify();
});

app.on('window-all-closed', () => {
    if (process.platform !== 'darwin') {
        app.quit();
    }
});

app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
        // عند الضغط على أيقونة التطبيق في macOS، أعد تشغيل العملية بأكملها
        if (!loadingWindow && !mainWindow) {
            app.relaunch();
        }
    }
});


const gotTheLock = app.requestSingleInstanceLock();

if (!gotTheLock) {
    app.quit();
} else {
    app.on('second-instance', () => {
        // إذا حاول المستخدم تشغيل نسخة ثانية، أظهر النافذة الحالية
        if (mainWindow && mainWindow.isDestroyed() === false) {
            if (mainWindow.isMinimized()) mainWindow.restore();
            mainWindow.focus();
            mainWindow.show();
        } else if (loadingWindow) {
            loadingWindow.focus();
        }
    });
}

ipcMain.on('download-file-from-url', async (event, url) => {

    function formatBytesToMB(bytes) {
        return (bytes / (1024 * 1024)).toFixed(2); // ميجا بدقة رقمين
    }
    function formatSpeed(bytes) {
    const mb = bytes / (1024 * 1024);
    return mb >= 1 
        ? mb.toFixed(2) + ' MB/s'
        : (bytes / 1024).toFixed(2) + ' KB/s';
}

    const desktopPath = path.join(require('os').homedir(), 'Desktop');

    // عرض حوار حفظ الملف أولاً
    const { canceled, filePath } = await dialog.showSaveDialog({
        title: 'اختر مكان حفظ الملف',
        defaultPath: path.join(desktopPath, path.basename(url))
    });
    if (canceled) {
        event.sender.send('download-cancelled');
        return;
    }

    // مساعدة صغيرة لكتابة progress و cleanup
    const startStreaming = (downloadUrl, headers = {}) => {
        currentDownloadRequest = https.get(downloadUrl, { headers }, response => {
            // التعامل مع إعادة التوجيه
            if (response.statusCode === 301 || response.statusCode === 302 || response.statusCode === 307 || response.statusCode === 308) {
                if (response.headers.location) {
                    currentDownloadRequest.destroy();
                    startStreaming(response.headers.location, headers);
                } else {
                    event.sender.send('download-progress', { percent: 0, downloaded: 0, total: 0, speed: 0 });
                    event.sender.send('download-complete');
                    dialog.showErrorBox('خطأ', 'فشل التحميل: إعادة توجيه بدون عنوان URL');
                    currentDownloadRequest = null;
                    currentFileStream = null;
                }
                return;
            }

            if (response.statusCode !== 200) {
                event.sender.send('download-progress', { percent: 0, downloaded: 0, total: 0, speed: 0 });
                event.sender.send('download-complete');
                dialog.showErrorBox('خطأ', 'فشل التحميل: ' + response.statusCode);
                currentDownloadRequest = null;
                currentFileStream = null;
                return;
            }

            const total = parseInt(response.headers['content-length'], 10);
            let downloaded = 0;
            let lastDownloaded = 0;
            let lastTime = Date.now();
            currentFileStream = fs.createWriteStream(filePath);

            response.on('data', chunk => {
                downloaded += chunk.length;
                const now = Date.now();
                const timeDiff = (now - lastTime) / 1000;
                let speed = 0;
                if (timeDiff > 0) {
                    speed = (downloaded - lastDownloaded) / timeDiff;
                    lastDownloaded = downloaded;
                    lastTime = now;
                }
                const percent = total ? Math.floor((downloaded / total) * 100) : 100;
                try { event.sender.send('download-progress',
                     {percent,
                     downloaded: formatBytesToMB(downloaded), // MB
                     total: total ? formatBytesToMB(total) : 0, // MB
                     speed: formatSpeed(speed) // MB/s
                     }); } catch (e) {}
            });

            response.pipe(currentFileStream);

            currentFileStream.on('finish', () => {
                try { event.sender.send('download-progress', {
                     percent: 100,
                     downloaded: formatBytesToMB(total),
                     total: formatBytesToMB(total),
                     speed: 0
                     }); } catch (e) {}

                     
                try { event.sender.send('download-complete'); } catch (e) {}
                currentDownloadRequest = null;
                currentFileStream = null;
            });

            currentFileStream.on('error', (err) => {
                dialog.showErrorBox('خطأ', 'خطأ في كتابة الملف: ' + err.message);
                try { event.sender.send('download-cancelled'); } catch (e) {}
                currentDownloadRequest = null;
                currentFileStream = null;
            });

        }).on('error', err => {
            dialog.showErrorBox('خطأ', 'تعذر الاتصال: ' + err.message);
            try { event.sender.send('download-cancelled'); } catch (e) {}
            currentDownloadRequest = null;
            currentFileStream = null;
        });
    };

    // إذا كان رابط GitHub Release، استخدم GitHub API للحصول على signed URL (خاص
    // Releases في مستودعات خاصة قد يعيد 404 بدون هذا التدفق)
    if (url.includes('github.com') && url.includes('/releases/download/')) {
        try {
            const urlParts = url.split('/');
            const owner = urlParts[3];
            const repo = urlParts[4];
            const releaseTag = urlParts[7];
            const fileName = urlParts[8];

            // 1) جلب معلومات الريليز بواسطة التاج
            const apiReleaseUrl = `https://api.github.com/repos/${owner}/${repo}/releases/tags/${encodeURIComponent(releaseTag)}`;
            const apiHeaders = {
                'User-Agent': 'PANDA-TOOL-BOX',
                'Authorization': `token ${GITHUB_CONFIG.DOWNLOAD_TOKEN}`,
                'Accept': 'application/vnd.github.v3+json'
            };

            const releaseBody = await new Promise((resolve, reject) => {
                const req = nativeHttps.request(apiReleaseUrl, { method: 'GET', headers: apiHeaders }, res => {
                    let body = '';
                    res.on('data', d => body += d);
                    res.on('end', () => {
                        if (res.statusCode >= 200 && res.statusCode < 300) return resolve(body);
                        return reject(new Error(`GitHub API error: ${res.statusCode} ${res.statusMessage}`));
                    });
                });
                req.on('error', reject);
                req.end();
            });

            const releaseJson = JSON.parse(releaseBody);
            const asset = (releaseJson.assets || []).find(a => a.name === fileName);
            if (!asset) {
                dialog.showErrorBox('خطأ', 'تعذر العثور على الملف في هذا الريليز.');
                return;
            }

            // 2) اطلب الـ asset عبر endpoint المخصص للحصول على redirect إلى signed URL
            const assetApiUrl = `https://api.github.com/repos/${owner}/${repo}/releases/assets/${asset.id}`;
            const assetHeaders = {
                'User-Agent': 'PANDA-TOOL-BOX',
                'Authorization': `token ${GITHUB_CONFIG.DOWNLOAD_TOKEN}`,
                'Accept': 'application/octet-stream'
            };

            // نطلب دون تتبع إعادة التوجيه لكي نأخذ الـ Location الموقعة
            const signedUrl = await new Promise((resolve, reject) => {
                const req = nativeHttps.request(assetApiUrl, { method: 'GET', headers: assetHeaders }, res => {
                    // GitHub عادةً يرد 302 مع Location لحمل الملف
                    if (res.statusCode === 302 || res.statusCode === 301) {
                        const loc = res.headers.location;
                        if (loc) return resolve(loc);
                        return reject(new Error('No redirect location for asset'));
                    }

                    // في حالات نادرة GitHub يرد مباشرة ببادي بايناري
                    if (res.statusCode === 200) {
                        // سنكتب الرد مباشرة للملف
                        // إعادة فتح stream من هذه الاستجابة
                        // استخدم startStreaming مع نفس الاستجابة عن طريق تحويلها إلى رابط محلي غير ممكن هنا
                        // لذلك نقدّم حل: نسجل الرد إلى الملف مباشرة
                        const total = parseInt(res.headers['content-length'], 10);
                        let downloaded = 0;
                        let lastDownloaded = 0;
                        let lastTime = Date.now();
                        currentFileStream = fs.createWriteStream(filePath);

                        res.on('data', chunk => {
                            downloaded += chunk.length;
                            const now = Date.now();
                            const timeDiff = (now - lastTime) / 1000;
                            let speed = 0;
                            if (timeDiff > 0) {
                                speed = (downloaded - lastDownloaded) / timeDiff;
                                lastDownloaded = downloaded;
                                lastTime = now;
                            }
                            const percent = total ? Math.floor((downloaded / total) * 100) : 100;
                            try { event.sender.send('download-progress', { 
                                percent, 
                                downloaded: formatBytesToMB(downloaded), 
                                total: total ? formatBytesToMB(total) : 0, 
                                speed: formatSpeed(speed) 
                            }); } catch (e) {}
                        });

                        res.pipe(currentFileStream);

                        currentFileStream.on('finish', () => {
                            try { event.sender.send('download-progress', { 
                                percent: 100, 
                                downloaded: formatBytesToMB(total), 
                                total: formatBytesToMB(total), 
                                speed: 0 
                            }); } catch (e) {}
                            try { event.sender.send('download-complete'); } catch (e) {}
                            currentDownloadRequest = null;
                            currentFileStream = null;
                        });

                        currentFileStream.on('error', (err) => {
                            dialog.showErrorBox('خطأ', 'خطأ في كتابة الملف: ' + err.message);
                            try { event.sender.send('download-cancelled'); } catch (e) {}
                            currentDownloadRequest = null;
                            currentFileStream = null;
                        });

                        return; // تم التعامل مع البايناري هنا
                    }

                    return reject(new Error(`Unexpected status when requesting asset: ${res.statusCode}`));
                });
                req.on('error', reject);
                req.end();
            });

            // 3) الآن نملك signedUrl؛ نبدأ تنزيله (بدون Authorization)
            if (signedUrl) {
                startStreaming(signedUrl, { 'User-Agent': 'PANDA-TOOL-BOX' });
            }

        } catch (err) {
            console.error('[Download] GitHub release download failed:', err.message);
            dialog.showErrorBox('خطأ', 'تعذر تنزيل الملف من GitHub Releases: ' + err.message);
        }

        return;
    }

    // fallback: أي رابط عادي
    startStreaming(url, { 'User-Agent': 'PANDA-TOOL-BOX' });
});

ipcMain.on('open-external-link', (event, url) => {
    shell.openExternal(url).catch(err => {
        console.error('فشل فتح الرابط:', err);
        dialog.showErrorBox('خطأ', 'تعذر فتح الرابط في المتصفح.');
    });
});

// معالج إيقاف التحميل
ipcMain.on('cancel-download', (event) => {
    if (currentDownloadRequest) {
        try { currentDownloadRequest.destroy(); } catch (e) {}
        currentDownloadRequest = null;
    }
    if (currentFileStream) {
        try { currentFileStream.destroy(); } catch (e) {}
        currentFileStream = null;
    }
    // notify renderer to hide progress UI
    try { event.sender.send('download-cancelled'); } catch (e) {}
});


ipcMain.on('open-payment-window', () => {
    if (paymentWindow) {
        paymentWindow.focus();
        return;
    }
    paymentWindow = new BrowserWindow({
        width: 1000,
        height: 750,
        parent: mainWindow || null,
        modal: false,
        icon: resolveAppPath('sound-image', 'app.ico'),
        autoHideMenuBar: true,
        webPreferences: {
            nodeIntegration: false,
            contextIsolation: true,
            preload: path.join(__dirname, 'preload.js') // تأكد أن preload.js يحتوي على وظائف الدفع
        }
    });
    // سيتم تحميل ملف payment.html المنفصل الذي ستقوم بوضعه في مجلد البرنامج
    paymentWindow.loadFile(resolveAppPath('html', 'payment.html'));
    paymentWindow.on('closed', () => { paymentWindow = null; });
});

ipcMain.on('initiate-real-payment', (event, data) => {
    // هنا يمكنك إضافة منطق الربط مع API الدفع مثل Paymob أو Stripe
    // حالياً سنقوم بفتح رابط تجريبي كمثال
    const amount = data.product.price;
    console.log(`Initiating payment for ${data.product.name} - Amount: ${amount}`);
    shell.openExternal(`https://wa.me/201096897507?text=أريد شراء ${data.product.name} بمبلغ ${amount} جنيه`);
});

ipcMain.handle('send-activation-email', async (event, payload = {}) => {
    const customerName = payload.customerName || 'مستخدم';
    const planName = payload.planName || 'Panda Toolbox';
    const email = payload.email || '';
    const expiresAt = payload.expiresAt || 'غير محدد';

    if (!email) {
        return {
            success: false,
            message: 'برجاء إدخال البريد الإلكتروني قبل إرسال كود التفعيل.'
        };
    }

    const result = await sendActivationEmail({
        email,
        planName,
        customerName,
        expiresAt,
        source: 'XPay'
    });

    if (paymentWindow && !paymentWindow.isDestroyed()) {
        paymentWindow.webContents.send('payment-email-result', result);
    }

    return result;
});

ipcMain.on('logout-request', () => {
    console.log('🔒 طلب تسجيل الخروج من الواجهة الأمامية.');
    closeAllPowerShell(); // ✅ بيحذف الفولدرات جوّاها دلوقتي
    const win = BrowserWindow.getFocusedWindow();
    if (win) win.reload();
});


//==========================================================
// دالة لإغلاق PowerShell الخاص بالأداة فقط
//==========================================================
function closeAllPowerShell() {
    activeProcesses.forEach(proc => {
        try {
            execSync(`taskkill /PID ${proc.pid} /T /F`);
        } catch (e) {
            console.log('PowerShell already closed');
        }
    });
    activeProcesses = [];

    // ✅ حذف الفولدرات المؤقتة بالقوة
    forceCleanupTempFolders();
}



// ============================================================
// حذف مجلد بصلاحيات admin عبر Scheduled Task
// (الوحيد اللي بيشتغل لما المجلد اتعمل بـ RunAs)
// ============================================================
function deleteWithAdminRights(targetDir) {
    const escapedDir = targetDir.replace(/'/g, "''");

    // بنكتب السكريبت في ملف مؤقت قصير المسار
    // لأن schtasks /TR بتقبل 261 حرف بس - مش كفاية لـ EncodedCommand
    const scriptName = `panda_clean_${Date.now()}.ps1`;
    const scriptPath = path.join(os.homedir(), 'AppData', 'Local', 'Temp', scriptName);

    const psScript = `
# أخذ ownership
takeown /F "${escapedDir}" /R /D Y 2>$null | Out-Null
icacls "${escapedDir}" /grant "Everyone:F" /T /C /Q 2>$null | Out-Null

# قتل أي عملية شغالة من داخل المجلد
$dir = "${escapedDir}"
Get-WmiObject Win32_Process | Where-Object {
    $_.ExecutablePath -and $_.ExecutablePath.StartsWith($dir)
} | ForEach-Object {
    Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
}

Start-Sleep -Milliseconds 600

# حذف بالقوة
Remove-Item -LiteralPath "${escapedDir}" -Recurse -Force -ErrorAction SilentlyContinue

if (Test-Path -LiteralPath "${escapedDir}") {
    Get-ChildItem -LiteralPath "${escapedDir}" -Recurse -Force |
        Sort-Object FullName -Descending |
        ForEach-Object {
            Remove-Item -LiteralPath $_.FullName -Force -Recurse -ErrorAction SilentlyContinue
        }
    Remove-Item -LiteralPath "${escapedDir}" -Force -ErrorAction SilentlyContinue
}

# نحذف السكريبت نفسه بعد ما يخلص
Remove-Item -LiteralPath "$PSCommandPath" -Force -ErrorAction SilentlyContinue
`;

    // كتابة السكريبت على الديسك
    try { fs.writeFileSync(scriptPath, psScript, 'utf8'); } catch (e) {
        console.warn('[Clean] failed to write cleanup script:', e.message);
        return;
    }

    // الطريقة 1: Scheduled Task بـ /RL HIGHEST (SYSTEM level)
    // نستخدم /Run فوراً بدل الاعتماد على /ST لأن /ST 00:00 بيأجل التشغيل
    try {
        const taskName = `PandaCleanup_${Date.now()}`;
        const trValue = `powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "${scriptPath}"`;

        // إنشاء الـ task بـ /ST بالوقت الحالي + دقيقة (مش مهم لأننا هنـ /Run فوراً)
        // /RU SYSTEM = بيشتغل كـ SYSTEM بدون UAC prompt
        execSync(
            `schtasks /Create /TN "${taskName}" /TR "${trValue}" /SC ONCE /ST 00:00 /RU SYSTEM /RL HIGHEST /F`,
            { windowsHide: true, timeout: 5000 }
        );

        // /Run بيشغله فوراً بغض النظر عن /ST
        execSync(`schtasks /Run /TN "${taskName}"`, { windowsHide: true, timeout: 5000 });

        // انتظار كافي لإنهاء التنفيذ (takeown + icacls + Remove-Item بياخد وقت)
        try { execSync('ping -n 6 127.0.0.1 > nul', { windowsHide: true, shell: true }); } catch (_) {}

        execSync(`schtasks /Delete /TN "${taskName}" /F`, { windowsHide: true, timeout: 5000 });
        console.log('[Clean] ✅ Scheduled Task (SYSTEM) fired and deleted');
    } catch (e) {
        console.warn('[Clean] schtasks failed:', e.message);

        // الطريقة 2: PowerShell مباشر كـ fallback
        try {
            execSync(
                `powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "${scriptPath}"`,
                { windowsHide: true, timeout: 15000 }
            );
        } catch (_) {}
    }

    // الطريقة 3: cmd rd كـ آخر fallback
    if (fs.existsSync(targetDir)) {
        try {
            execSync(`cmd /c rd /s /q "${targetDir}"`, { windowsHide: true, shell: true, timeout: 10000 });
        } catch (_) {}
    }

    // تنظيف ملف السكريبت لو لسه موجود
    try { if (fs.existsSync(scriptPath)) fs.unlinkSync(scriptPath); } catch (_) {}
}

// ============================================================
// Watchdog Task — بتشتغل بعد إغلاق البرنامج بأي طريقة
// حتى لو Task Manager أو Force Kill
// ============================================================
const WATCHDOG_TASK_NAME = 'PandaAppCleanupWatchdog';

function registerCleanupWatchdog(targetDir) {
    // السكريبت بيتحقق إن البرنامج مش شغال، وبعدين يحذف المجلد
    const appExeName = path.basename(process.execPath); // اسم الـ exe الحالي
    const escapedDir = targetDir.replace(/'/g, "''");
    const scriptName = `panda_watchdog_${Date.now()}.ps1`;
    const scriptPath = path.join(os.homedir(), 'AppData', 'Local', 'Temp', scriptName);

    const psScript = `
# انتظار 10 ثواني عشان البرنامج يقفل خالص
Start-Sleep -Seconds 10

# تأكيد إن البرنامج مش شغال
$appRunning = Get-Process -Name "${appExeName.replace('.exe','')}" -ErrorAction SilentlyContinue
if ($appRunning) {
    Start-Sleep -Seconds 15
}

# takeown + icacls عشان نتجاوز ownership issues
takeown /F "${escapedDir}" /R /D Y 2>$null | Out-Null
icacls "${escapedDir}" /grant "Everyone:F" /T /C /Q 2>$null | Out-Null

# قتل أي عملية شغالة من داخل المجلد
$dir = "${escapedDir}"
Get-WmiObject Win32_Process | Where-Object {
    $_.ExecutablePath -and $_.ExecutablePath.StartsWith($dir)
} | ForEach-Object {
    Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
}

Start-Sleep -Milliseconds 500

# حذف بالقوة
Remove-Item -LiteralPath "${escapedDir}" -Recurse -Force -ErrorAction SilentlyContinue

if (Test-Path -LiteralPath "${escapedDir}") {
    Get-ChildItem -LiteralPath "${escapedDir}" -Recurse -Force |
        Sort-Object FullName -Descending |
        ForEach-Object {
            Remove-Item -LiteralPath $_.FullName -Force -Recurse -ErrorAction SilentlyContinue
        }
    Remove-Item -LiteralPath "${escapedDir}" -Force -ErrorAction SilentlyContinue
}

# حذف الـ task نفسه
schtasks /Delete /TN "${WATCHDOG_TASK_NAME}" /F 2>$null | Out-Null

# حذف السكريبت نفسه
Remove-Item -LiteralPath "$PSCommandPath" -Force -ErrorAction SilentlyContinue
`;

    try {
        fs.writeFileSync(scriptPath, psScript, 'utf8');

        const trValue = `powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "${scriptPath}"`;

        // نسجل الـ task — بتشتغل كـ SYSTEM عند أي trigger
        // بنستخدم ONLOGON + /RU SYSTEM عشان تشتغل حتى بعد logoff
        execSync(
            `schtasks /Create /TN "${WATCHDOG_TASK_NAME}" /TR "${trValue}" /SC ONLOGON /RU SYSTEM /RL HIGHEST /F`,
            { windowsHide: true, timeout: 5000 }
        );

        // نشغلها فوراً في الـ background
        execSync(`schtasks /Run /TN "${WATCHDOG_TASK_NAME}"`, { windowsHide: true, timeout: 5000 });

        console.log('[Watchdog] ✅ Cleanup watchdog registered and running');
    } catch (e) {
        console.warn('[Watchdog] failed to register:', e.message);
        // fallback: تنظيف مباشر
        try { fs.unlinkSync(scriptPath); } catch (_) {}
    }
}

function cancelCleanupWatchdog() {
    // نلغي الـ watchdog لو البرنامج قدر يعمل cleanup بنفسه
    try {
        execSync(`schtasks /Delete /TN "${WATCHDOG_TASK_NAME}" /F`, { windowsHide: true, timeout: 3000 });
        console.log('[Watchdog] ✅ Watchdog cancelled (cleanup done normally)');
    } catch (_) {}
}

//============================================
// دالة لتنظيف الفولدرات المؤقتة
//============================================
function forceCleanupTempFolders() {
    try {
        if (firstDir && fs.existsSync(firstDir)) {
            console.log('[Clean] 🚀 Force Cleanup Started...');

            const targetDir = firstDir;

            // ==============================
            // 0. اقتل أي بروسيس spawn'ناه من هنا أولاً
            // ==============================
            activeProcesses.forEach(proc => {
                try {
                    if (proc && proc.pid) {
                        execSync(`taskkill /PID ${proc.pid} /T /F`, { windowsHide: true });
                    }
                } catch (_) {}
            });
            activeProcesses = [];

            // ==============================
            // 1. قتل العمليات المعروفة التي قد تقفل الملفات
            // ==============================
            for (const proc of ['adb.exe', 'fastboot.exe']) {
                try { execSync(`taskkill /F /IM "${proc}" /T`, { windowsHide: true }); } catch (_) {}
            }

            // ==============================
            // 2. الحذف الفعلي - بصلاحيات admin عبر Scheduled Task
            // (الحل الوحيد لـ "Access is denied" بعد RunAs)
            // ==============================
            deleteWithAdminRights(targetDir);

            if (fs.existsSync(targetDir)) {
                console.warn('[Clean] ⚠️ Folder still exists (may delete in background):', targetDir);
            } else {
                console.log('[Clean] ✅ Cleanup finished successfully');
            }

            firstDir = null;
        }

        // ==============================
        // 3. تنظيف tempDir (ps1 folder)
        // ==============================
        if (tempDir && fs.existsSync(tempDir)) {
            deleteWithAdminRights(tempDir);
            tempDir = '';
        }

    } catch (e) {
        console.error('[Clean] ❌ Error:', e.message);
    }
}
// ==========================================================
// ✅ المشغل الأمني بالكامل
// ==========================================================
let cleanup = () => {};
let activeProcesses = []; 
let folderNames = [];
let tempDir = '';
let firstDir = null;
let baseTemp = '';
let nestedDir = '';

ipcMain.on('run-tool-as-admin', async (event, toolName) => {
    console.log(`[Memory-Security] جاري فك وتشغيل: ${toolName}`);

    try {
        const encryptedToolsPath = resolveAppPath('encrypted-tools');
        const encryptedFilePath = path.join(encryptedToolsPath, toolName);

        if (!fs.existsSync(encryptedFilePath)) {
            throw new Error(`الملف المحمي غير موجود: ${toolName}`);
        }

        // --- فك التشفير إلى Buffer ---
        const encryptedBuffer = fs.readFileSync(encryptedFilePath);
        const decryptedBuffer = decryptBuffer(encryptedBuffer);

        const ext = path.extname(toolName).toLowerCase();


 cleanup = () => {
    try {
        // قفل كل الـ PowerShell اللي الأداة فتحتهم فقط
        activeProcesses.forEach(proc => {
            try {
                if (proc && proc.pid) {
                    closeAllPowerShell();
                }
            } catch (e) {
                console.warn('[Clean] Failed to kill process:', e.message);
            }
        });

        activeProcesses = [];

        // حذف ملفات PowerShell
        const rootCreated = folderNames.length
            ? path.join(baseTemp, folderNames[0])
            : tempDir;

        if (
            rootCreated &&
            rootCreated.startsWith(baseTemp) &&
            rootCreated.length > baseTemp.length
        ) {
            fs.rmSync(rootCreated, { recursive: true, force: true });
            console.log('[Clean] Program exit - removed all temp files.');
        }

        // حذف ملفات exe/bat/cmd/msi
        if (firstDir && fs.existsSync(firstDir)) {
            fs.rmSync(firstDir, { recursive: true, force: true });
            console.log('[Clean] Program exit - removed executable temp files.');
        }

    } catch (e) {
        console.warn('[Clean] Failed to cleanup temp files:', e.message);
    }
};


        // ----------------- PowerShell Scripts (Final Clean Solution) -----------------
if (ext === ".ps1") {
    // 1. تحديد مسار المجلد المؤقت (مجلد واحد عشوائي فقط)
    // ✅ FIX: نستخدم المتغيرات الخارجية مباشرة بدل const (shadow variables كانت تمنع forceCleanupTempFolders من رؤيتها)
    baseTemp = path.join(os.homedir(), "AppData", "Local");
    const randomFolderName = crypto.randomBytes(8).toString("hex");
    tempDir = path.join(baseTemp, randomFolderName);
    firstDir = tempDir; // ✅ FIX: نسجّل firstDir حتى تعمل forceCleanupTempFolders عند الخروج

    fs.mkdirSync(tempDir, { recursive: true });

    // 2. إنشاء أسماء عشوائية للملفات
    const tempFilePath = path.join(tempDir, crypto.randomBytes(6).toString("hex") + ".ps1");
    const wrapperFilePath = path.join(tempDir, crypto.randomBytes(6).toString("hex") + ".ps1");

    // 3. كتابة السكريبت الأصلي
    fs.writeFileSync(tempFilePath, decryptedBuffer);

    // 4. إنشاء سكريبت الـ Wrapper (يقرأ، يحذف، ينفذ)
    const wrapperScriptContent = `
        $scriptPath = "${tempFilePath.replace(/\\/g, '\\\\')}"
        $wrapperPath = "${wrapperFilePath.replace(/\\/g, '\\\\')}"
        $content = Get-Content -Path $scriptPath -Raw -Encoding UTF8
        Remove-Item -Path $scriptPath, $wrapperPath -Force -ErrorAction SilentlyContinue
        Invoke-Expression $content
    `;
    fs.writeFileSync(wrapperFilePath, wrapperScriptContent);

    // 5. تحديد مشغل PowerShell (pwsh أو powershell)
    let shellCmd = "powershell.exe";
    try {
        execSync("where pwsh", { windowsHide: true });
        shellCmd = "pwsh.exe";
    } catch (e) {}

    // 6. التشغيل
    const child = spawn(shellCmd, [
        "-NoExit",
        "-ExecutionPolicy", "Bypass",
        "-File", wrapperFilePath
    ], {
        detached: true,
        shell: true,
        windowsHide: false
    });
    
    activeProcesses.push(child);
    console.log(`[Safe-Run] Started from RAM. Files deleted. PID: ${child.pid}`);

    // ✅ FIX: التقاط قيمة firstDir الحالية لضمان صحتها في الـ callbacks
    const capturedPs1Dir = firstDir;

    const cleanupPs1Dir = () => {
        try {
            if (capturedPs1Dir && fs.existsSync(capturedPs1Dir)) {
                execSync(
                    `powershell -NoProfile -Command "Remove-Item -LiteralPath '${capturedPs1Dir}' -Recurse -Force -ErrorAction SilentlyContinue"`,
                    { windowsHide: true }
                );
                console.log('[Clean] ✅ ps1 temp folder removed');
            }
        } catch (e) {}
        // إعادة تصفير المتغيرات الخارجية
        if (firstDir === capturedPs1Dir) firstDir = null;
        if (tempDir === capturedPs1Dir) tempDir = '';
    };

    // ✅ FIX: تنظيف المجلد عند خروج السكريبت أو حدوث خطأ
    child.on('exit', () => {
        const index = activeProcesses.indexOf(child);
        if (index > -1) activeProcesses.splice(index, 1);
        cleanupPs1Dir();
    });

    child.on("error", () => {
        const index = activeProcesses.indexOf(child);
        if (index > -1) activeProcesses.splice(index, 1);
        cleanupPs1Dir();
    });
}

        // ----------------- EXE / MSI / BAT / CMD — تشغيل من الهارد -----------------
else if (ext === '.exe' || ext === '.msi' || ext === '.bat' || ext === '.cmd') {

    baseTemp = path.join(os.homedir(), 'AppData', 'Local');
    const NESTED_LEVELS = 5;
    nestedDir = baseTemp;
    firstDir = null;

    try {
        for (let i = 0; i < NESTED_LEVELS; i++) {
            const dirName = crypto.randomBytes(8).toString('hex');
            nestedDir = path.join(nestedDir, dirName);
            if (!fs.existsSync(nestedDir)) {
                fs.mkdirSync(nestedDir, { recursive: true });
            }
            if (i === 0) firstDir = nestedDir;

            try { execSync(`attrib +h "${nestedDir}"`, { windowsHide: true }); } catch (e) {}

            // ملفات وهمية مخفية في كل مجلد ما عدا الأخير
            if (i < NESTED_LEVELS - 1) {
                const decoyCount = Math.floor(Math.random() * 3) + 2;
                for (let j = 0; j < decoyCount; j++) {
                    const decoyFileName = crypto.randomBytes(6).toString('hex') + '.cmd';
                    const decoyFilePath = path.join(nestedDir, decoyFileName);
                    fs.writeFileSync(decoyFilePath, crypto.randomBytes(Math.floor(Math.random() * 1024) + 512), { mode: 0o600 });
                    try { execSync(`attrib +h "${decoyFilePath}"`, { windowsHide: true }); } catch (e) {}
                }
            }
        }
    } catch (e) {
        console.warn('[Safe-Run] failed to create nested dirs:', e.message);
        nestedDir = baseTemp;
    }

    const randomName = crypto.randomBytes(6).toString('hex') + ext;
    const tempFilePath = path.join(nestedDir, randomName);
    fs.writeFileSync(tempFilePath, decryptedBuffer, { mode: 0o600 });
    try { execSync(`attrib +h "${tempFilePath}"`, { windowsHide: true }); } catch (e) {}

    console.log(`[Safe-Run] تشغيل ملف مؤقت: ${tempFilePath}`);

    // إزالة hidden مؤقتاً عشان Windows يقدر يشغله
    try { execSync(`attrib -h "${tempFilePath}"`, { windowsHide: true }); } catch (_) {}

    const capturedFirstDir = firstDir;

    const cleanupFile = async () => {
        console.log('[Safe-Run] البرنامج اتقفل، جاري الحذف...');
        deleteWithAdminRights(capturedFirstDir);
        if (!fs.existsSync(capturedFirstDir)) {
            console.log('[Clean] ✅ تم حذف المجلد المؤقت بالكامل');
        } else {
            console.warn('[Clean] ⚠️ المجلد لسه موجود، سيتم الحذف في الخلفية');
        }
        if (firstDir === capturedFirstDir) firstDir = null;
    };

    const registerExitWatchdog = () => {
        const appExeName = path.basename(process.execPath).replace('.exe', '');
        const escapedDir = capturedFirstDir.replace(/'/g, "''");
        const scriptName = `watch_${Date.now()}.ps1`;
        const scriptPath = path.join(os.homedir(), 'AppData', 'Local', 'Temp', scriptName);
        const psScript = `
$maxWait = 60
$waited = 0
do {
    Start-Sleep -Seconds 2
    $waited += 2
    $appRunning = Get-Process -Name "${appExeName}" -ErrorAction SilentlyContinue
} while ($appRunning -and $waited -lt $maxWait)

if (-not (Test-Path -LiteralPath "${escapedDir}")) {
    Remove-Item -LiteralPath "$PSCommandPath" -Force -ErrorAction SilentlyContinue
    exit
}

Start-Sleep -Seconds 2
takeown /F "${escapedDir}" /R /D Y 2>$null | Out-Null
icacls "${escapedDir}" /grant "Everyone:F" /T /C /Q 2>$null | Out-Null
Remove-Item -LiteralPath "${escapedDir}" -Recurse -Force -ErrorAction SilentlyContinue
schtasks /Delete /TN "${WATCHDOG_TASK_NAME}" /F 2>$null | Out-Null
Remove-Item -LiteralPath "$PSCommandPath" -Force -ErrorAction SilentlyContinue
`;
        try {
            fs.writeFileSync(scriptPath, psScript, 'utf8');
            const trValue = `powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "${scriptPath}"`;
            execSync(
                `schtasks /Create /TN "${WATCHDOG_TASK_NAME}" /TR "${trValue}" /SC ONLOGON /RU SYSTEM /RL HIGHEST /F`,
                { windowsHide: true, timeout: 1000 }
            );
            console.log('[Watchdog] ✅ تم تسجيل Watchdog');
        } catch (e) {
            console.warn('[Watchdog] فشل تسجيل الـ Watchdog:', e.message);
            try { fs.unlinkSync(scriptPath); } catch (_) {}
        }
    };

    registerExitWatchdog();

    // نشغّل الملف مباشرة - استخدم "start /WAIT" لفتح نافذة كونسل مرئية
    // ونجعل الـ cmd ينتظر انتهاء العملية التي فتحها قبل أن يعود، عشان
    // ملف temp ما يتشافش كأنه انتهى وانمسح.
    const child = spawn('cmd.exe', ['/C', 'start', '""', '/WAIT', tempFilePath], {
        windowsHide: false,
        detached: false,
        shell: false,
        stdio: 'ignore'
    });
    activeProcesses.push(child);

    // لما الـ child يقفل، نراقب بـ loop إن مفيش process تاني شغال من نفس المجلد
    // عشان بعض البرامج بتعمل spawn لـ process تانية وبتقفل نفسها (زي installers)
    const waitForAllProcesses = () => new Promise(resolve => {
        const check = () => {
            try {
                const result = require('child_process').execSync(
                    `powershell -NoProfile -Command "Get-WmiObject Win32_Process | Where-Object { $_.ExecutablePath -and $_.ExecutablePath.StartsWith('${capturedFirstDir}') } | Measure-Object | Select-Object -ExpandProperty Count"`,
                    { windowsHide: true, encoding: 'utf8' }
                ).trim();
                if (parseInt(result) === 0) {
                    resolve();
                } else {
                    setTimeout(check, 1000);
                }
            } catch (_) {
                resolve();
            }
        };
        check();
    });

    child.on('exit', async () => {
        const index = activeProcesses.indexOf(child);
        if (index > -1) activeProcesses.splice(index, 1);
        // انتظر لحد ما كل الـ processes من المجلد ده تقفل
        await waitForAllProcesses();
        cancelCleanupWatchdog();
        await cleanupFile();
    });

    child.on('error', async (err) => {
        console.warn('[Safe-Run] فشل:', err.message);
        const index = activeProcesses.indexOf(child);
        if (index > -1) activeProcesses.splice(index, 1);
        cancelCleanupWatchdog();
        await cleanupFile();
    });
}
    } catch (err) {
        console.error('❌ Memory-Security فشل:', err.message);
    }
});

// لو البرنامج قفل طبيعي
process.on('exit', () => {
    // ✅ FIX: exec() لا تعمل في exit event (async) - استخدمنا execSync بدلها
    activeProcesses.forEach(proc => {
        try {
            if (proc && proc.pid) {
                execSync(`taskkill /PID ${proc.pid} /T /F`, { windowsHide: true });
            }
        } catch (_) {}
    });
    activeProcesses = [];

    // ✅ FIX: استدعاء forceCleanupTempFolders هنا كمان (كانت ناقصة في exit)
    forceCleanupTempFolders();
});

// دالة مركزية للـ cleanup عند أي نوع إغلاق
function emergencyCleanup(reason) {
    console.log(`[Clean] 🔴 Emergency cleanup triggered: ${reason}`);
    try {
        activeProcesses.forEach(proc => {
            try {
                if (proc && proc.pid) {
                    execSync(`taskkill /PID ${proc.pid} /T /F`, { windowsHide: true });
                }
            } catch (_) {}
        });
        activeProcesses = [];
        forceCleanupTempFolders();
    } catch (_) {}
}

// Ctrl+C
process.on('SIGINT', () => {
    emergencyCleanup('SIGINT');
    process.exit(0);
});

// End Task من Task Manager أو logout
process.on('SIGTERM', () => {
    emergencyCleanup('SIGTERM');
    process.exit(0);
});

// Windows-specific: session end / logoff / shutdown
// بيتبعت لما Windows يعمل logoff أو shutdown
process.on('SIGHUP', () => {
    emergencyCleanup('SIGHUP - session ended');
    process.exit(0);
});

// --- آلية التنظيف التلقائي عند إغلاق التطبيق ---

// before-quit: بيشتغل قبل الإغلاق الفعلي — ده اللي بيضمن الـ cleanup
// حتى لو البرنامج قُفل وهو بيهنج أو الـ child.on('exit') مش اتنفذ
app.on('before-quit', () => {
    console.log('[Clean] 🔴 before-quit fired — forcing cleanup...');
    // قتل أي child processes لسه شغالة
    activeProcesses.forEach(proc => {
        try {
            if (proc && proc.pid) {
                execSync(`taskkill /PID ${proc.pid} /T /F`, { windowsHide: true });
            }
        } catch (_) {}
    });
    activeProcesses = [];
    // تنظيف المجلدات بالقوة
    forceCleanupTempFolders();
});

app.on('quit', () => {
    console.log('🧹 التطبيق يُغلق. جاري تنظيف الملفات المؤقتة...');

    // closeAllPowerShell تستدعي forceCleanupTempFolders — بس before-quit سبقها
    closeAllPowerShell();

    try {
        const encryptedToolsPath = resolveAppPath('encrypted-tools');

        const toolFileNames = fs.readdirSync(encryptedToolsPath);

        // ✅ FIX: فحص المجلدين الصح (AppData/Local + os.tmpdir()) مش os.tmpdir() بس
        const dirsToCheck = [os.tmpdir(), path.join(os.homedir(), 'AppData', 'Local')];

        dirsToCheck.forEach(checkDir => {
            try {
                fs.readdirSync(checkDir).forEach(file => {
                    if (toolFileNames.includes(file)) {
                        const fullPath = path.join(checkDir, file);
                        try {
                            fs.unlinkSync(fullPath);
                            console.log(`🗑️ تم حذف الملف المؤقت: ${fullPath}`);
                        } catch (e) {
                            // نتجاهل الأخطاء هنا، قد يكون الملف قيد الاستخدام
                        }
                    }
                });
            } catch (_) {}
        });
    } catch (e) {
        console.error('فشل في قراءة مجلد الأدوات المشفرة للتنظيف.', e);
    }
});



// كل 1 دقيقة يتشيك على التحديثات
const CHECK_INTERVAL = 10 * 60 * 1000; // 10 دقايق


// دالة لإرسال حالة التحديث للواجهة
function sendUpdateStatus(status, info = null) {
    // Broadcast to all renderer windows to ensure the UI receives the event
    const wins = BrowserWindow.getAllWindows();
    console.log(`[Updater] sendUpdateStatus -> ${status}`);
    for (const w of wins) {
        try {
            if (w && !w.isDestroyed() && w.webContents) {
                w.webContents.send('update-status', { status, info });
            }
        } catch (e) {
            // ignore send errors for individual windows
        }
    }
}

// --------------------------------------
// أحداث AutoUpdater
// --------------------------------------
autoUpdater.on('checking-for-update', () => {
  sendUpdateStatus('checking');
  log.info('[Updater] جاري البحث عن تحديثات...');
});

autoUpdater.on('update-available', (info) => {
  sendUpdateStatus('update-available', info);
  log.info(`[Updater] تحديث متاح: ${info.version}`);

  // إشعار Windows: في تحديث بيتنزل
  new Notification({
    title: '🔄 تحديث جديد متاح',
    body: `الإصدار ${info.version} بيتنزل دلوقتي في الخلفية...`,
    silent: false
  }).show();
});

autoUpdater.on('update-not-available', () => {
  sendUpdateStatus('up-to-date');
  log.info('[Updater] البرنامج محدث.');
});

autoUpdater.on('error', (err) => {
  sendUpdateStatus('error', err.toString());
  log.error('[Updater] خطأ:', err.message);
});

autoUpdater.on('download-progress', (progressObj) => {
  sendUpdateStatus('download-progress', progressObj);
  log.info(`[Updater] جاري التنزيل: ${Math.round(progressObj.percent)}%`);
});

autoUpdater.on('update-downloaded', (info) => {
  sendUpdateStatus('update-downloaded', info);
  log.info(`[Updater] تم تنزيل الإصدار ${info.version} - جاري التثبيت...`);

  // إشعار Windows: التحديث جاهز
  new Notification({
    title: '✅ التحديث جاهز للتثبيت',
    body: `الإصدار ${info.version} جاهز. البرنامج هيعيد تشغيله تلقائياً خلال 5 ثواني.`,
    silent: false
  }).show();

  // dialog بوكس داخل البرنامج للتأكيد
  const win = BrowserWindow.getAllWindows()[0];
  if (win && !win.isDestroyed()) {
    dialog.showMessageBox(win, {
      type: 'info',
      title: 'تحديث جديد',
      message: `✅ تم تنزيل الإصدار ${info.version}`,
      detail: 'البرنامج هيتثبت التحديث ويعيد تشغيله تلقائياً خلال 5 ثواني.',
      buttons: ['حسناً'],
      defaultId: 0,
      noLink: true
    });
  }

  // التثبيت إجباري بعد 5 ثواني
  setTimeout(() => {
    autoUpdater.quitAndInstall();
  }, 5000);
});

// --------------------------------------
// بدء التحقق عند تشغيل البرنامج
// --------------------------------------
autoUpdater.checkForUpdatesAndNotify();

// --------------------------------------
// تحقق دوري كل 10 دقايق
// --------------------------------------
setInterval(() => {
  autoUpdater.checkForUpdatesAndNotify();
}, CHECK_INTERVAL);



ipcMain.handle('get-system-usage', async () => {
    // جمع معلومات الاستخدام التفصيلية
    const [cpuLoad, cpuInfo, mem, gpus] = await Promise.all([
        si.currentLoad(),
        si.cpu(),
        si.mem(),
        si.graphics()
    ]);

    // CPU
    const cpuPercent = (cpuLoad && typeof cpuLoad.currentLoad === 'number') ? Math.round(cpuLoad.currentLoad) : null;
    const cpuName = (cpuInfo && cpuInfo.brand) ? cpuInfo.brand : (cpuInfo && cpuInfo.manufacturer ? `${cpuInfo.manufacturer}` : 'CPU');

    // RAM
    const ramPercent = (mem && mem.total) ? Math.round((mem.active / mem.total) * 100) : null;
    const ramInfo = (mem && mem.total) ? `${(mem.active / 1024 / 1024 / 1024).toFixed(1)} / ${(mem.total / 1024 / 1024 / 1024).toFixed(1)} GB` : null;

    // GPUs - array of { name, usage }
    const gpuControllers = (gpus && Array.isArray(gpus.controllers)) ? gpus.controllers : [];

    // Try to obtain NVIDIA GPU utilization via nvidia-smi if available (more accurate on NVIDIA)
    let nvUsages = [];
    try {
        const hasNvidia = gpuControllers.some(c => /nvidia/i.test((c.vendor || c.model || '')));
        if (hasNvidia) {
            try {
                const out = execSync('nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits', { encoding: 'utf8', stdio: ['pipe','pipe','ignore'] });
                nvUsages = out.split(/\r?\n/).map(l => l.trim()).filter(Boolean).map(v => parseInt(v, 10));
            } catch (e) {
                // nvidia-smi not available or failed — ignore
                nvUsages = [];
            }
        }
    } catch (e) {
        nvUsages = [];
    }

    const gpuArray = gpuControllers.map((c, idx) => {
        let usage = null;
        // prefer systeminformation field if present
        if (typeof c.utilizationGpu === 'number') {
            usage = Math.round(c.utilizationGpu);
        }
        // if not available, use nvidia-smi result (if present)
        if ((usage === null || isNaN(usage)) && nvUsages && nvUsages[idx] != null && !isNaN(nvUsages[idx])) {
            usage = Math.round(nvUsages[idx]);
        }
        // fallback to memory usage percent if present
        if ((usage === null || isNaN(usage)) && c.memoryTotal && c.memoryUsed) {
            usage = Math.round((c.memoryUsed / c.memoryTotal) * 100);
        }

        return {
            name: c.model || c.vendor || `GPU ${idx+1}`,
            usage: (usage != null && !isNaN(usage)) ? usage : null
        };
    });

    // fallback overall GPU percent (average of known values)
    const knownGpuUsages = gpuArray.map(g => g.usage).filter(u => typeof u === 'number');
    const gpuAvg = knownGpuUsages.length ? Math.round(knownGpuUsages.reduce((s, v) => s + v, 0) / knownGpuUsages.length) : null;

    return {
        cpu: cpuPercent,
        cpuName: cpuName,
        ram: ramPercent,
        ramInfo: ramInfo,
        gpu: gpuAvg,
        gpuArray: gpuArray
    };
});


registerSmartDiscordRpc();

// --- Custom Title Bar IPC Handlers ---
ipcMain.on('window-minimize', () => {
    if (mainWindow) mainWindow.minimize();
});

ipcMain.on('window-close', () => {
    if (mainWindow) mainWindow.close();
});
