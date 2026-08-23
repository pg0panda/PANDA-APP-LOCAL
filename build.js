const builder = require("electron-builder");
const { execSync } = require('child_process');
const packageJson = require('./package.json');

// 🔐 تشغيل dotenv لقراءة ملف الـ .env المخفي
require('dotenv').config();

// جلب التوكن من بيئة الجهاز الحالية أو من ملف .env بشكل سري وبدون كتابته هنا
const GH_TOKEN = process.env.GITHUB_TOKEN; 

if (!GH_TOKEN) {
  console.error("❌ خطأ: لم يتم العثور على GITHUB_TOKEN في ملف .env!");
  process.exit(1);
}

console.log("🚀 Starting build & publish...");

builder.build({
  config: {
    appId: "com.pg.panda.toolbox",
    productName: "Panda-Toolbox",
    artifactName: "Panda-Toolbox-Setup-${version}.${ext}",
    directories: {
      output: "dist",
      buildResources: "src"
    },
    "files": [
      "src/**/*",
      "build/Release/panda_secure_addon.node",
      "!native-src/**",
      "!binding.gyp",
      "!build/binding.sln",
      "!build/*.vcxproj*",
      "!build/Release/*.obj",
      "!build/Release/*.lib",
      "!build/Release/*.exp"
    ],
    publish: [
      {
        provider: "github",
        owner: "pg0panda",
        repo: "panda-app",
        releaseType: 'release'
      }
    ],
    win: {
      target: "nsis",
      icon: "src/sound-image/app.ico", // تأكد من المسار الصحيح للأيقونة هنا
      requestedExecutionLevel: "requireAdministrator"
    },
    nsis: {
      oneClick: false, // 🛑 تحويله لواجهة Next > Next خطوة بخطوة
      perMachine: true,
      allowToChangeInstallationDirectory: true, // 🛑 السماح للمستخدم باختيار مسار التثبيت
      createDesktopShortcut: true,
      createStartMenuShortcut: true,
      shortcutName: "Panda Toolbox",
      uninstallDisplayName: "Panda-Toolbox (إزالة التثبيت)",
      deleteAppDataOnUninstall: true, // 🛑 مسح البيانات الحساسة والتوكنز عند الحذف
      runAfterFinish: true, // 🛑 إمكانية تشغيل البرنامج فور انتهاء التثبيت
      differentialPackage: true
    }
  },
  publish: 'always'
}).then(() => {
  console.log("✅ Build & publish completed!");

  try {
    const version = packageJson.version;

    // نشر release إذا كان draft
    execSync(`gh release edit v${version} --draft=false --repo pg0panda/panda-app`, {
      stdio: 'inherit',
      env: { ...process.env, GITHUB_TOKEN: GH_TOKEN }
    });

    console.log("🎉 Release published successfully and set as latest!");
  } catch (error) {
    console.log("⚠️ Could not auto-publish release:", error.message);
    console.log("📝 You may need to manually publish the release on GitHub");
  }
}).catch((error) => {
  console.error("❌ Build process failed:", error);
});