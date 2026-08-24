شرح سريع لإعداد صفحة التأكيد وسيرفر استقبال الإرسالات

ملخص:
- الصفحات: `src/html/success_form_day.html`, `src/html/success_form_week.html`, `src/html/success_form_generic.html`.
- سيرفر ويب محلي: `xpay-webhook-server.js` يستقبل POST على `/submit` ويخزن البيانات في `data/submissions.json`.
- عامل المعالجة: `server/poller.js` يقرأ `data/submissions.json` كل 30 ثانية، ينشئ كودًا مناسبًا ويُرسله عبر جيميل.

إعداد جيميل (مهم):
- يفضل إنشاء App Password في حساب Google أو تفعيل إعداد SMTP.
- يمكن وضع الإعدادات بطريقتين:
  1. متغيرات بيئة: `GMAIL_USER` و`GMAIL_PASS` ثم تشغيل `npm run poller`.
  2. أو ملف `server/config.json` بالشكل:
{
  "gmail": { "user": "your@gmail.com", "pass": "app-password" }
}

تشغيل محلي (مثال):

1) تثبيت الحزم:

npm install express body-parser nodemailer cors

2) تشغيل السيرفر:

npm run start:webhook

3) تشغيل العامل الذي يرسل الأكواد:

npm run poller

تعديل صفحة الدفع (مقدم الدفع):
- اجعل رابط النجاح (return URL) يوجّه المستخدم إلى إحدى الصفحات HTML أعلاه.
- إذا كان السيرفر يعمل على مضيف مختلف أو منفذ مختلف، أضف `?webhook=` مع عنوان endpoint، مثال:

https://yourdomain.com/src/html/success_form_day.html?webhook=https://your-server.example.com/submit

ملاحظات أمان:
- لا تضع مفاتيح أو بيانات حساسة في صفحات HTML العامة.
- الملفات داخل `data/` و`server/config.json` مُدرجة في `.gitignore` ولا تُرفع إلى GitHub.

إذا تحب، أستطيع الآن:
- ضبط إرسال البريد ليستخدم Gmail OAuth بدل كلمة المرور (أكثر أمانًا)، أو
- إنشاء مثال Action على GitHub لنشر الصفحات كـ GitHub Pages (صفحات فقط، لكن السيرفر يجب أن يكون متاحًا لاستقبال الإرسالات).