/**
 * Backward compatibility shim.
 * This app now uses XPay instead of Kashier.
 */

window.processPayment = function () {
    if (typeof selectedProd === 'undefined' || !selectedProd) {
        alert('برجاء اختيار الباقة أولاً');
        return;
    }

    if (typeof selectedPay === 'undefined' || !selectedPay) {
        alert('برجاء اختيار طريقة الدفع');
        return;
    }

    try {
        const merchantId = 'YOUR_XPAY_MERCHANT_ID';
        const publicKey = 'YOUR_XPAY_PUBLIC_KEY';
        const amount = selectedProd.price;
        const orderId = 'PANDA_' + Date.now();
        const currency = 'EGP';

        const xpayUrl = `https://checkout.xpay.app/?merchantId=${merchantId}` +
            `&amount=${amount}` +
            `&currency=${currency}` +
            `&orderId=${encodeURIComponent(orderId)}` +
            `&publicKey=${encodeURIComponent(publicKey)}` +
            `&package=${encodeURIComponent(selectedProd.name)}` +
            `&method=${encodeURIComponent(selectedPay)}`;

        if (window.electronAPI && window.electronAPI.openExternalLink) {
            window.electronAPI.openExternalLink(xpayUrl);
        } else {
            window.open(xpayUrl, '_blank');
        }
    } catch (err) {
        console.error('XPay compatibility error:', err);
        alert('حدث خطأ أثناء إعداد بوابة الدفع XPay: ' + (err && err.message ? err.message : err));
    }
};