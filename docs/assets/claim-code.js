const apiUrl = 'https://panda-code-service.mohamednasr9040.workers.dev/api/claim';

const translations = {
  ar: {
    pageTitle: 'استلام كود الباقة',
    heading: 'كود باقة {plan}',
    intro: 'تم تأكيد الدفع. أدخل بياناتك لإصدار كودك مرة واحدة.',
    name: 'الاسم', email: 'الإيميل', consent: 'أوافق على حفظ اسمي وإيميلي مع سجل الاشتراك والدعم.',
    issue: 'إصدار الكود', copy: 'نسخ الكود', needLink: 'يجب فتح رابط الاستلام الذي أُرسل إليك بعد تأكيد الدفع.',
    creating: 'جارٍ إنشاء كودك وتسجيل الترخيص…', issued: 'انسخ الكود الآن واحفظه في مكان آمن؛ لن يظهر مرة أخرى.',
    copied: 'تم نسخ الكود. احفظه الآن.', switch: 'English',
    invalid_or_expired_link: 'رابط استلام الكود غير صالح أو انتهت صلاحيته.',
    code_already_shown: 'تم عرض الكود من هذا الرابط سابقًا، ولا يمكن عرضه مرة أخرى.',
    invalid_customer_details: 'أدخل اسمًا صحيحًا وإيميلًا صحيحًا، ثم وافق على حفظ البيانات.',
    license_service_not_configured: 'خدمة إصدار التراخيص غير جاهزة حاليًا. تواصل مع الدعم.',
    license_sync_failed: 'تعذر تسجيل الترخيص الآن. أعد المحاولة بعد لحظات.',
    code_generation_failed: 'تعذر إنشاء الكود الآن. أعد المحاولة بعد لحظات.'
  },
  en: {
    pageTitle: 'Claim your plan code',
    heading: '{plan} plan code',
    intro: 'Your payment is confirmed. Enter your details to issue your one-time code.',
    name: 'Name', email: 'Email', consent: 'I agree to save my name and email for my subscription record and support.',
    issue: 'Issue code', copy: 'Copy code', needLink: 'Open the claim link sent to you after payment confirmation.',
    creating: 'Creating your code and registering the license…', issued: 'Copy and save your code now; it will not be shown again.',
    copied: 'Code copied. Save it somewhere safe.', switch: 'العربية',
    invalid_or_expired_link: 'This claim link is invalid or has expired.',
    code_already_shown: 'The code from this link was already shown and cannot be displayed again.',
    invalid_customer_details: 'Enter a valid name and email, then agree to save your details.',
    license_service_not_configured: 'The license service is not ready. Contact support.',
    license_sync_failed: 'The license could not be registered. Please try again shortly.',
    code_generation_failed: 'The code could not be created. Please try again shortly.'
  }
};

const planName = document.documentElement.dataset.planAr;
const planNameEn = document.documentElement.dataset.planEn;
let language = localStorage.getItem('panda-code-language') || (navigator.language.toLowerCase().startsWith('ar') ? 'ar' : 'en');

function t(key) {
  const plan = language === 'ar' ? planName : planNameEn;
  return (translations[language][key] || key).replace('{plan}', plan);
}

function applyLanguage(nextLanguage) {
  language = nextLanguage;
  localStorage.setItem('panda-code-language', language);
  document.documentElement.lang = language;
  document.documentElement.dir = language === 'ar' ? 'rtl' : 'ltr';
  document.title = t('pageTitle');
  document.querySelectorAll('[data-i18n]').forEach((element) => { element.textContent = t(element.dataset.i18n); });
  document.querySelector('[data-language-toggle]').textContent = t('switch');
}

async function claimCode() {
  const code = document.querySelector('[data-code]');
  const status = document.querySelector('[data-status]');
  const copy = document.querySelector('[data-copy]');
  const form = document.querySelector('[data-customer-form]');
  const token = new URLSearchParams(location.search).get('token');
  if (!token) {
    status.textContent = t('needLink');
    return;
  }
  if (!form) return;
  const formData = new FormData(form);
  status.textContent = t('creating');
  try {
    const response = await fetch(apiUrl, {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        token,
        name: formData.get('name'),
        email: formData.get('email'),
        consent: formData.get('consent') === 'on'
      })
    });
    const body = await response.json();
    if (!response.ok) throw new Error(body.error || 'unknown');
    code.textContent = body.code;
    code.hidden = false;
    copy.disabled = false;
    form.hidden = true;
    status.textContent = t('issued');
    history.replaceState({}, document.title, location.pathname);
  } catch (error) {
    status.textContent = translations[language][error.message] || t('license_sync_failed');
  }
}

document.querySelector('[data-copy]').addEventListener('click', async () => {
  await navigator.clipboard.writeText(document.querySelector('[data-code]').textContent);
  document.querySelector('[data-status]').textContent = t('copied');
});

document.querySelector('[data-customer-form]').addEventListener('submit', (event) => {
  event.preventDefault();
  claimCode();
});

document.querySelector('[data-language-toggle]').addEventListener('click', () => {
  applyLanguage(language === 'ar' ? 'en' : 'ar');
});

applyLanguage(language);
