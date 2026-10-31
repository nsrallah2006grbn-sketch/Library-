# المكتبة الطلابية العربية: التشغيل والنشر

## ما الذي يفعله النظام
- تسجيل الدخول: اختيار الدولة ← رقم هاتف من نفس الدولة ← رمز SMS.
- التحقق في الخادم (Cloud Function باسم verifyAccess) من ثلاثة أشياء: مطابقة رمز الهاتف للدولة، ومطابقة دولة الـ IP، وعدم وجود VPN/Proxy.
- قواعد Firestore وStorage تمنع قراءة أي كتاب أو رفعه ما لم يكن حقل verified = true في مستند المستخدم، والعميل لا يستطيع تعديل هذا الحقل.
- يُعاد الفحص عند فتح التطبيق وكلما عاد المستخدم إليه.
- الدولة تُقفل عند أول تحقق ولا يمكن تغييرها (لتغييرها احذف مستند المستخدم من مجموعة users يدويًا).
- الكتب المرفوعة تكون pending، والأدمن يفتح الكتاب بالضغط عليه ثم يقبل أو يرفض.
- صفحة الويب (flutter build web) هي صفحة تعريفية بزر تحميل من Google Play.

## 1) التجهيز
1. ثبّت Flutter ثم داخل هذا المجلد: flutter create --org com.yourname --project-name arabic_student_library .
2. أنشئ مشروع Firebase وفعّل خطة Blaze (مطلوبة لـ Cloud Functions ولرسائل SMS بكميات حقيقية).
3. فعّل: Authentication > Phone، وFirestore، وStorage، وApp Check (Play Integrity).
4. Authentication > Settings > SMS region policy: اختر "Allow" وحدد الدول العربية فقط.
5. flutterfire configure (يولّد firebase_options.dart، اختر android وweb).
6. أضف بصمة SHA-256 لتطبيقك في إعدادات Firebase (مطلوبة للتحقق بالهاتف وPlay Integrity).
7. في android/app/build.gradle اجعل minSdk = 23.

## 2) نشر الخادم
1. احصل على مفتاح من ipinfo.io. فحص VPN/Proxy يحتاج خطة تدعم Privacy Detection (مدفوعة). بدونها يعمل فحص دولة الـ IP فقط.
2. firebase functions:secrets:set IPINFO_TOKEN
3. firebase deploy --only functions,firestore:rules,storage
4. بعد التأكد أن كل شيء يعمل، فعّل Enforce في App Check لخدمات Functions وFirestore وStorage.

## 3) تعيين الأدمن
سجّل دخولك بالتطبيق، انسخ UID من Firebase > Authentication، ثم أنشئ مستندًا في مجموعة admins معرّفه = UID.

## 4) التشغيل والتجربة
flutter run. في وضع debug يطبع App Check رمزًا في السجل، سجّله في Firebase > App Check > Manage debug tokens. للتجربة بدون رسائل SMS حقيقية استخدم أرقام الاختبار من إعدادات Phone في Firebase.

## 5) البناء والنشر على Google Play
1. أنشئ keystore وأعدّ android/key.properties.
2. flutter build appbundle --release --obfuscate --split-debug-info=build/symbols
3. ارفع app-release.aab في Play Console (حساب مطوّر 25 دولارًا مرة واحدة).
4. أكمل نموذج Data safety (رقم الهاتف، الدولة، الـ IP)، ورابط سياسة الخصوصية، وتصنيف المحتوى.

## 6) متطلبات سياسة Google Play
- محتوى يرفعه المستخدمون: الإشراف موجود (موافقة الأدمن)، ويلزم أيضًا زر «إبلاغ» داخل التطبيق.
- حذف الحساب: يلزم خيار حذف الحساب وبياناته من داخل التطبيق ومن رابط ويب.
- إن كان الجمهور أطفالًا دون 13 سنة تنطبق سياسة العائلات، وجمع رقم الهاتف والـ IP منهم له شروط خاصة.
- حقوق النشر: لا ترفع إلا كتبًا مسموحًا بنشرها (كثير من المناهج الرسمية لها شروط).
