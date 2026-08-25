const apiUrl = 'https://REPLACE_WITH_YOUR_WORKER.workers.dev/api/claim';

const messages = {
  invalid_or_expired_link: 'رابط استلام الكود غير صالح أو انتهت صلاحيته.',
  code_already_shown: 'تم عرض الكود من هذا الرابط سابقًا، ولا يمكن عرضه مرة أخرى.',
  codes_unavailable: 'لا يوجد كود متاح حاليًا لهذه الباقة. تواصل مع الدعم.',
  claim_conflict_retry: 'يتم تأكيد الكود الآن. أعد تحميل الصفحة بعد لحظات.'
};

async function claimCode() {
  const code = document.querySelector('[data-code]');
  const status = document.querySelector('[data-status]');
  const copy = document.querySelector('[data-copy]');
  const token = new URLSearchParams(location.search).get('token');
  if (!token) {
    status.textContent = 'يجب فتح رابط الاستلام الذي أُرسل إليك بعد تأكيد الدفع.';
    return;
  }
  status.textContent = 'جارٍ تجهيز كودك…';
  try {
    const response = await fetch(apiUrl, {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ token })
    });
    const body = await response.json();
    if (!response.ok) throw new Error(body.error || 'unknown');
    code.textContent = body.code;
    code.hidden = false;
    copy.disabled = false;
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

claimCode();
