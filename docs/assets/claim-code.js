const apiUrl = 'https://panda-code-service.mohamednasr9040.workers.dev/api/claim';

const messages = {
  invalid_or_expired_link: 'رابط استلام الكود غير صالح أو انتهت صلاحيته.',
  code_already_shown: 'تم عرض الكود من هذا الرابط سابقًا، ولا يمكن عرضه مرة أخرى.',
  invalid_customer_details: 'أدخل اسمًا صحيحًا وإيميلًا صحيحًا، ثم وافق على حفظ البيانات.',
  license_service_not_configured: 'خدمة إصدار التراخيص غير جاهزة حاليًا. تواصل مع الدعم.',
  license_sync_failed: 'تعذر تسجيل الترخيص الآن. أعد المحاولة بعد لحظات.',
  code_generation_failed: 'تعذر إنشاء الكود الآن. أعد المحاولة بعد لحظات.'
};

async function claimCode() {
  const code = document.querySelector('[data-code]');
  const status = document.querySelector('[data-status]');
  const copy = document.querySelector('[data-copy]');
  const form = document.querySelector('[data-customer-form]');
  const token = new URLSearchParams(location.search).get('token');
  if (!token) {
    status.textContent = 'يجب فتح رابط الاستلام الذي أُرسل إليك بعد تأكيد الدفع.';
    return;
  }
  if (!form) return;
  const formData = new FormData(form);
  status.textContent = 'جارٍ إنشاء كودك وتسجيل الترخيص…';
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
    status.textContent = 'انسخ الكود الآن واحفظه في مكان آمن؛ لن يظهر مرة أخرى.';
    history.replaceState({}, document.title, location.pathname);
  } catch (error) {
    status.textContent = messages[error.message] || 'تعذر الحصول على الكود. حاول مرة أخرى أو تواصل مع الدعم.';
  }
}

document.querySelector('[data-copy]').addEventListener('click', async () => {
  await navigator.clipboard.writeText(document.querySelector('[data-code]').textContent);
  document.querySelector('[data-status]').textContent = 'تم نسخ الكود. احفظه الآن.';
});

document.querySelector('[data-customer-form]').addEventListener('submit', (event) => {
  event.preventDefault();
  claimCode();
});
