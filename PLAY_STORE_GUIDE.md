# دليل رفع التطبيق على جوجل بلاي

## البيانات المحدثة ✅
- **اسم التطبيق:** Nabaa
- **Package Name:** com.nabaa.app
- **الإصدار:** 1.0.0 (build 1)

## الخطوات المتبقية:

### 1️⃣ إنشاء ملف التوقيع (Keystore)
```bash
keytool -genkey -v -keystore ~/key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

**ستُطلب منك المعلومات التالية:**
- First name and last name
- Organizational Unit (مثل: Development)
- Organization (مثل: Nabaa)
- City
- State/Province
- Country code (SA للسعودية)
- Password (تذكره جيداً ✅)

### 2️⃣ رفع ملف AAB على Google Play Console
1. اذهب إلى Google Play Console
2. اختر التطبيق (Nabaa)
3. اذهب إلى: Testing → Internal testing
4. ارفع ملف AAB: `build/app/outputs/bundle/release/app-release.aab`

### 3️⃣ ملء بيانات المتجر
**ستحتاج إلى:**
- ✏️ وصف التطبيق (Description)
- 📸 لقطات الشاشة (2-8 لقطات)
- 🎨 أيقونة التطبيق (512x512)
- 🏷️ الفئة (Category)
- 📧 بريد المطور

### 4️⃣ نشر التطبيق
1. أكمل جميع البيانات المطلوبة
2. اضغط "Review" ثم "Publish to Production"

---

**ملاحظات مهمة:**
- تأكد من أن لديك حساب Google Play Developer ($30)
- تحتاج إلى بطاقة ائتمان لتأكيد الهوية
- قد يستغرق المراجعة 1-3 ساعات قبل النشر
