/**
 * PANDA TOOLBOX - XPay integration
 * Live payment link provided by the merchant account.
 */

const XPAY_PAYMENT_LINK = 'https://checkout.xpay.app/p/plink_live_7F4F4aOToGh95hcEAbLJnk';

function getPlanExpiryLabel(planName) {
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

window.processPayment = function () {
    if (typeof selectedProd === 'undefined' || !selectedProd) {
        alert('برجاء اختيار الباقة أولاً');
        return;
    }

    const emailField = document.getElementById('customer-email');
    if (emailField && (!emailField.value || !emailField.value.trim())) {
        alert('برجاء إدخال البريد الإلكتروني قبل فتح بوابة الدفع');
        return;
    }

    const toast = document.getElementById('toast');
    if (toast) toast.classList.add('show');

    try {
        const link = selectedProd.link || XPAY_PAYMENT_LINK;
        console.log('Panda XPay Payment Link:', link);

        if (window.electronAPI && window.electronAPI.openExternalLink) {
            window.electronAPI.openExternalLink(link);
        } else {
            window.open(link, '_blank');
        }

        const confirmButton = document.getElementById('paid-confirm-btn');
        if (confirmButton) confirmButton.style.display = 'block';
    } catch (err) {
        console.error('XPay Payment Link Error:', err);
        alert('حدث خطأ أثناء فتح بوابة الدفع XPay: ' + (err && err.message ? err.message : err));
    }
};

window.processPaymentSuccess = async function () {
    if (typeof selectedProd === 'undefined' || !selectedProd) {
        alert('برجاء اختيار الباقة أولاً');
        return;
    }

    const emailField = document.getElementById('customer-email');
    const nameField = document.getElementById('customer-name');

    const email = (emailField && emailField.value ? emailField.value.trim() : '');
    const customerName = (nameField && nameField.value ? nameField.value.trim() : 'مستخدم');

    if (!email) {
        alert('برجاء إدخال البريد الإلكتروني قبل إرسال كود التفعيل');
        return;
    }

    try {
        if (window.electronAPI && typeof window.electronAPI.sendActivationEmail === 'function') {
            const result = await window.electronAPI.sendActivationEmail({
                email,
                planName: selectedProd.name,
                customerName,
                expiresAt: getPlanExpiryLabel(selectedProd.name)
            });

            if (result && result.success) {
                alert('✅ تم تأكيد الدفع بنجاح\nتم إرسال كود التفعيل إلى البريد الإلكتروني: ' + email);
            } else {
                const message = result && result.message ? result.message : 'لم يتم إرسال البريد الإلكتروني، لكن الكود تم إنشاؤه محلياً.';
                alert(message);
            }
            return;
        }

        alert('تم تأكيد الدفع يدويًا، ولكن هذه النسخة ليست متصلة بـ Electron لتسليم البريد تلقائيًا.');
    } catch (error) {
        console.error('Payment success handling error:', error);
        alert('حدث خطأ أثناء تأكيد الدفع وإنشاء كود التفعيل');
    }
};
