// ================================================== //
//          🚀 الكود الرئيسي عند تحميل الصفحة 🚀         //
// ================================================== //

let pendingForceLogoutReason = null;
let forceLogoutHandlerBound = false;

function showForceLogoutModal(reason = null) {
    if (document.readyState === 'loading') {
        pendingForceLogoutReason = reason || pendingForceLogoutReason || 'License expired or removed';
        window.addEventListener('DOMContentLoaded', () => showForceLogoutModal(pendingForceLogoutReason), { once: true });
        return;
    }

    const resolvedReason = (reason || pendingForceLogoutReason || 'License expired or removed').toString().trim();

    if (document.getElementById('force-logout-modal')) return;

    if (!document.getElementById('force-logout-styles')) {
        const style = document.createElement('style');
        style.id = 'force-logout-styles';
        style.textContent = `
            @keyframes slideIn {
                from { opacity: 0; transform: translateY(12px); }
                to   { opacity: 1; transform: translateY(0); }
            }
        `;
        document.head.appendChild(style);
    }

    const modal = document.createElement('div');
    modal.id = 'force-logout-modal';
    modal.style.cssText = `
        position: fixed;
        top: 0;
        left: 0;
        width: 100%;
        height: 100%;
        background: rgba(0, 0, 0, 0.5);
        display: flex;
        justify-content: center;
        align-items: center;
        z-index: 10000;
        backdrop-filter: blur(4px);
    `;

    const modalContent = document.createElement('div');
    modalContent.style.cssText = `
        background: linear-gradient(180deg, #6e6e6eff, #395f91ff);
        border-radius: 20px;
        border: 0.5px solid rgba(0, 0, 0, 0.38);
        padding: 40px 32px 32px;
        width: calc(100% - 48px);
        max-width: 400px;
        text-align: center;
        position: relative;
        overflow: hidden;
        animation: slideIn 0.25s ease-out;
    `;

    const topBar = document.createElement('div');
    topBar.style.cssText = `
        position: absolute;
        top: 0;
        left: 0;
        right: 0;
        height: 4px;
        background: #9c1f1fff;
        border-radius: 20px 20px 0 0;
    `;

    const iconWrap = document.createElement('div');
    iconWrap.style.cssText = `
        width: 64px;
        height: 64px;
        border-radius: 50%;
        background: #919191ff;
        margin: 0 auto 20px;
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 28px;
    `;
    iconWrap.textContent = '⏰';

    const title = document.createElement('h2');
    title.textContent = 'License expired';
    title.style.cssText = `
        color: #f00707bd;
        margin: 0 0 8px;
        font-size: 22px;
        font-weight: 500;
    `;

    const message = document.createElement('p');
    const defaultMessage = 'Your license has expired, disabled or removed. Please renew to continue using the Toolbox.';
    const messageText = resolvedReason && resolvedReason.toLowerCase() !== 'license expired or removed'
        ? resolvedReason
        : defaultMessage;
    message.textContent = messageText;
    message.style.cssText = `
        color: #1b1b1bff;
        margin: 0 0 28px;
        font-size: 18px;
        line-height: 1.6;
    `;

    const button = document.createElement('button');
    button.textContent = 'OK';
    button.style.cssText = `
        width: 100%;
        padding: 10px 0;
        font-size: 16px;
        border-radius: 8px;
        background: #868686ff;
        color: #dc2626;
        border: 0.5px solid #fca5a5;
        font-weight: 500;
        cursor: pointer;
        transition: opacity 0.15s ease, transform 0.15s ease;
    `;

    button.onmouseenter = () => { button.style.opacity = '0.8'; button.style.transform = 'translateY(-2px)'; };
    button.onmouseleave = () => { button.style.opacity = '1';   button.style.transform = 'translateY(0)'; };

    const supportLine = document.createElement('p');
    supportLine.style.cssText = `
        margin: 14px 0 0;
        font-size: 15px;
        color: #3b3b3bff;
    `;
    supportLine.innerHTML = 'Need help? <a href="#" style="color: #1b1b1bff; text-decoration: underline; text-underline-offset: 3px;">Contact support</a>';

    supportLine.querySelector('a').addEventListener('click', (e) => {
        e.preventDefault();
        window.electronAPI?.openExternalLink?.('https://wa.me/201096897507');
    });

    button.onclick = () => {
        try { document.body.removeChild(modal); } catch (e) {}

        try { localStorage.clear(); } catch (e) {}
        try { sessionStorage.clear(); } catch (e) {}

        const loginScreen = document.getElementById('login-screen');
        const appContainer = document.getElementById('app-container');
        if (appContainer) appContainer.style.display = 'none';
        if (loginScreen) loginScreen.style.display = 'flex';

        const licenseInput = document.getElementById('license-key-input');
        const loginMessage = document.getElementById('login-message');
        if (licenseInput) licenseInput.value = '';
        if (loginMessage) loginMessage.textContent = 'Your license has expired, disabled or removed.';
    };

    modalContent.appendChild(topBar);
    modalContent.appendChild(iconWrap);
    modalContent.appendChild(title);
    modalContent.appendChild(message);
    modalContent.appendChild(button);
    modalContent.appendChild(supportLine);
    modal.appendChild(modalContent);
    document.body.appendChild(modal);
}

function bindForceLogoutHandler() {
    if (forceLogoutHandlerBound) return;
    forceLogoutHandlerBound = true;

    if (window.electronAPI && typeof window.electronAPI.onForceLogout === 'function') {
        window.electronAPI.onForceLogout((event, data) => {
            try {
                const reason = data?.reason || data || null;
                showForceLogoutModal(reason);
            } catch (e) {
                console.warn('force-logout handler failed', e);
            }
        });
    } else {
        window.addEventListener('force-logout', (event) => {
            const payload = event?.detail || event?.payload || null;
            try {
                showForceLogoutModal(payload?.reason || payload || null);
            } catch (e) {
                console.warn('force-logout fallback failed', e);
            }
        });
    }
}

bindForceLogoutHandler();

window.addEventListener('DOMContentLoaded', () => {

    // --- 1. تعريف كل عناصر الواجهة التي نحتاجها ---
    const loginScreen = document.getElementById('login-screen');
    const appContainer = document.getElementById('app-container');
    const loginButton = document.getElementById('login-button');
    const licenseInput = document.getElementById('license-key-input');
    const rememberCheckbox = document.getElementById('remember-me-checkbox');
    const loginMessage = document.getElementById('login-message');
    const changeKeyButton = document.getElementById('change-key-button');
    const updateInfoDiv = document.getElementById('update-info');
    const userKeySpan = document.getElementById('user-key');
    const expiryDateSpan = document.getElementById('expiry-date');
    const hwidValueElement = document.getElementById('hwid-value');
    const copyButton = document.getElementById('copy-hwid-btn');

    // --- 2. منطق تسجيل الدخول والواجهة الرئيسية ---
    function showApp(loginResult) {
        if (loginScreen) loginScreen.style.display = 'none';
        if (appContainer) appContainer.style.display = 'block';
        if (userKeySpan) userKeySpan.textContent = loginResult.userKey;
        if (expiryDateSpan) expiryDateSpan.textContent = loginResult.expiry;
        if (changeKeyButton) {
            changeKeyButton.style.display = 'block';
            changeKeyButton.onclick = () => window.electronAPI.logoutRequest();
        }

        // تطبيق قيود الـ limited permissions للأكواد العامة فقط
        const permissions = (loginResult.permissions || 'all').trim().toLowerCase();
        const isGeneral = loginResult.isGeneral === true;

        if (isGeneral && permissions === 'limited') {
            applyLimitedPermissions();
        }

        // بعد ما الـ app يظهر، نطلب فحص تحديث جديد عشان تتعرض النتيجة
        if (updateInfoDiv) {
            updateInfoDiv.textContent = '🔍 جاري البحث عن تحديثات...';
            updateInfoDiv.style.color = '#aaaaaa';
        }
        if (window.electronAPI && window.electronAPI.checkForUpdates) {
            window.electronAPI.checkForUpdates();
        }
    }

    // الأقسام المقيدة في وضع limited
    const LIMITED_SECTIONS = ['programs', 'tools', 'windows', 'ai'];

    function showLimitedModal() {
        if (document.getElementById('limited-modal')) return;

        const overlay = document.createElement('div');
        overlay.id = 'limited-modal';
        overlay.style.cssText = `
            position: fixed; top: 0; left: 0; width: 100%; height: 100%;
            background: rgba(0,0,0,0.6); display: flex; justify-content: center;
            align-items: center; z-index: 99999; backdrop-filter: blur(4px);
        `;

        const box = document.createElement('div');
        box.style.cssText = `
            background: linear-gradient(160deg, #2a2a2a, #1a1a2e);
            border: 1px solid rgba(255,255,255,0.15);
            border-radius: 16px; padding: 36px 28px; text-align: center;
            max-width: 340px; width: calc(100% - 48px);
            animation: slideIn 0.2s ease-out;
            box-shadow: 0 8px 32px rgba(0,0,0,0.5);
        `;

        box.innerHTML = `
            <div style="font-size:40px; margin-bottom:12px;">🔒</div>
            <h3 style="color:#f87171; margin:0 0 10px; font-size:18px;">Your license is limited here</h3>
            <p style="color:#aaa; font-size:13px; margin:0 0 22px; line-height:1.5;">
                Ask for <strong style="color:#facc15;">VIP key</strong> to unlock this section
            </p>
            <button id="limited-modal-close" style="
                background: linear-gradient(90deg,#7c3aed,#4f46e5);
                color:#fff; border:none; border-radius:8px;
                padding:9px 28px; font-size:14px; cursor:pointer;
                font-weight:bold; letter-spacing:0.5px;
            ">OK</button>
        `;

        overlay.appendChild(box);
        document.body.appendChild(overlay);

        document.getElementById('limited-modal-close').onclick = () => overlay.remove();
        overlay.onclick = (e) => { if (e.target === overlay) overlay.remove(); };
    }

    function applyLimitedPermissions() {
        const btns = document.querySelectorAll('.main-section-btn');
        btns.forEach(btn => {
            const section = btn.getAttribute('data-section');
            if (LIMITED_SECTIONS.includes(section)) {
                // نسخ الزر بدون الأحداث القديمة
                const newBtn = btn.cloneNode(true);
                newBtn.onclick = (e) => {
                    e.stopPropagation();
                    showLimitedModal();
                };
                btn.parentNode.replaceChild(newBtn, btn);
                newBtn.style.opacity = '0.6';
                newBtn.title = 'VIP only';
            }
        });

        // قفل زر Panda AI Assistant في صندوق الترحيب
        const aiOpenBtn = document.getElementById('ai-open-btn');
        if (aiOpenBtn) {
            // نستخدم cloneNode للتخلص من أي Event Listeners سابقة تم إضافتها
            const newAiBtn = aiOpenBtn.cloneNode(true);
            newAiBtn.onclick = (e) => {
                e.stopPropagation();
                showLimitedModal();
            };
            // نتأكد من منع أي أحداث كليك أخرى
            newAiBtn.addEventListener('click', (e) => {
                e.stopImmediatePropagation();
                showLimitedModal();
            }, true);

            aiOpenBtn.parentNode.replaceChild(newAiBtn, aiOpenBtn);
            newAiBtn.style.opacity = '0.6';
            newAiBtn.style.cursor = 'not-allowed';
        }
    }

    // جلب وعرض HWID
    if (hwidValueElement && window.electronAPI && window.electronAPI.getHwid) {
        (async () => {
            const hwid = await window.electronAPI.getHwid();
            hwidValueElement.textContent = hwid;
            if (copyButton) {
                copyButton.addEventListener('click', () => {
                    navigator.clipboard.writeText(hwid).then(() => {
                        const copyTextSpan = copyButton.querySelector("span");
                        if (copyTextSpan) {
                            const originalText = copyTextSpan.textContent;
                            copyTextSpan.textContent = "تم النسخ!";
                            setTimeout(() => { copyTextSpan.textContent = originalText; }, 1500);
                        }
                    });
                });
            }
        })();
    }

    // الاستماع لنجاح الدخول التلقائي
    if (window.electronAPI && window.electronAPI.onLoginSuccessful) {
        window.electronAPI.onLoginSuccessful((loginData) => {
            if(loginMessage) loginMessage.textContent = 'تم الدخول بنجاح!';
            showApp(loginData);
        });
    }

    // معالجة الدخول اليدوي
if (loginButton) {
    loginButton.addEventListener('click', async () => {
        const key = licenseInput ? licenseInput.value.trim() : '';
        const remember = rememberCheckbox ? rememberCheckbox.checked : false;

        // إذا كان حقل الإدخال فارغاً، حاول الدخول تلقائياً
        if (!key) {
            if (loginMessage) loginMessage.textContent = 'جاري البحث عن أكواد محفوظة...';
            
            try {
                // استدعاء دالة الدخول التلقائي من main.js
                const result = await window.electronAPI.autoLoginRequest();
                
                if (result.success) {
                    showApp(result);
                } else {
                    if (loginMessage) {
                        loginMessage.textContent = result.message || 'لا توجد أكواد محفوظة. الرجاء إدخال كود.';
                    }
                }
            } catch (error) {
                if (loginMessage) {
                    loginMessage.textContent = 'فشل الدخول التلقائي. الرجاء إدخال كود.';
                }
            }
            return; // توقف هنا بعد محاولة الدخول التلقائي
        }
        // --- نهاية الكود الذي تمت إعادته ---

        // إذا كان هناك مفتاح مُدخل، استمر في عملية الدخول اليدوي
        if (loginMessage) loginMessage.textContent = 'جاري التحقق...';
        
        try {
            const result = await window.electronAPI.loginRequest(key, remember);
            if (result.success) {
                showApp(result);
            } else {
                if (loginMessage) loginMessage.textContent = `Error: ${result.message}`;
            }
        } catch (error) {
            if (loginMessage) loginMessage.textContent = 'حدث خطأ أثناء محاولة الدخول';
        }
    });
}


    // الاستماع لحالات التحديث
    if (window.electronAPI && window.electronAPI.onUpdateStatus) {
        window.electronAPI.onUpdateStatus(({ status, info }) => {
            console.log('[Renderer] update-status', status, info);
            if (!updateInfoDiv) return;

            const messages = {
                'checking':          { text: '🔍 جاري البحث عن تحديثات...', color: '#aaaaaa' },
                'up-to-date':        { text: '✅ البرنامج محدث',             color: '#4ade80' },
                'update-available':  { text: `🔄 تحديث ${info?.version ?? ''} متاح...`, color: '#facc15' },
                'download-progress': { text: `⬇️ جاري التنزيل ${Math.round(info?.percent ?? 0)}%`, color: '#60a5fa' },
                'update-downloaded': { text: `✅ تم تنزيل ${info?.version ?? 'التحديث'} - هيتثبت خلال 5 ثواني`, color: '#4ade80' },
                'error':             { text: '❌ خطأ في التحديث', color: '#f87171' },
            };

            const msg = messages[status];
            if (msg) {
                updateInfoDiv.textContent = msg.text;
                updateInfoDiv.style.color  = msg.color;
            }
        });
    }

    // استقبال معلومات الجهاز
    if (window.electronAPI && window.electronAPI.onSystemInfo) {
        window.electronAPI.onSystemInfo((data) => {
            const cpuEl = document.getElementById('cpu-name');
            const ramEl = document.getElementById('ram-info');
            const gpuEl = document.getElementById('gpu-name');
            if (cpuEl) cpuEl.textContent = data.cpu;
            if (ramEl) ramEl.textContent = data.ram;
            if (gpuEl) gpuEl.textContent = Array.isArray(data.gpu) ? data.gpu.join(' | ') : data.gpu;
        });
    }
    
        window.electronAPI.onPlayLoginSound(() => {
        const audio = new Audio('../sound-image/sound.mp3'); // ضع الملف بجانب index.html
        audio.volume = 1.0;
        audio.play().catch(err => console.log("Audio Error:", err));
    });
});

// الآمن: دالة تعرض مودال انتهاء الترخيص وتتحقق من أن DOM جاهز
// AI chat logic moved to src/ai-chat.js
