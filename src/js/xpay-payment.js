/**
 * PANDA TOOLBOX - XPay integration
 * Live payment link provided by the merchant account.
 */

const XPAY_PAYMENT_LINK = 'https://checkout.xpay.app/p/plink_live_7F4F4aOToGh95hcEAbLJnk';

window.processPayment = function () {
    if (typeof selectedProd === 'undefined' || !selectedProd) {
        alert('برجاء اختيار الباقة أولاً');
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
    } catch (err) {
        console.error('XPay Payment Link Error:', err);
        alert('حدث خطأ أثناء فتح بوابة الدفع XPay: ' + (err && err.message ? err.message : err));
    }
};
