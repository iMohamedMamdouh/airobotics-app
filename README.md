# حورس — Horus 🤖

تطبيق Android بسيط بيشتغل على التابلت اللي على الروبوت. حورس هو الروبوت الذكي من **AI Robotics**: بيسمع سؤال الزائر (بالصوت أو بالكتابة) ويرد عليه **بصوت ذكر** عن طريق **Gemini Live API**.

## المميزات

- محادثة صوتية مباشرة: الزائر بيتكلم، وحورس بيرد بصوت طبيعي (Gemini native audio).
- وش متحرك لحورس بيتغير حسب الحالة: جاهز، سامعك، بيفكر، بيتكلم.
- الكلام بيظهر مكتوب على الشاشة (سؤال الزائر ورد حورس).
- ممكن الزائر يكتب سؤاله بدل ما يتكلم.
- حورس بيرحب بالزائر أول ما يضغط على الميكروفون.
- لو الزائر لمس وش حورس وهو بيتكلم، حورس يسكت.
- وضع Kiosk: التطبيق بياخد الشاشة كلها والشاشة ماتطفيش.
- المحادثة بتقفل لوحدها بعد دقيقة سكوت وترجع لشاشة الترحيب.
- بيدور في Google لو اتسأل عن حاجة بتتغير زي الأخبار أو الطقس.
- إعدادات مخفية: **ضغطة طويلة على اللوجو** بتفتح إعدادات الصوت والمقاطعة ومدة السكوت.

## التشغيل

### 1) إعداد Firebase (مرة واحدة)

1. ادخل على <https://console.firebase.google.com> واعمل مشروع جديد (مثلاً `airobotics-horus`).
2. من القائمة: **AI Logic** ← **Get started** ← اختار **Gemini Developer API** (فيه باقة مجانية).
3. من **Project settings** ← **Your apps** ← **Add app** ← **Android**:
   - Package name: `com.airobotics.horus`
   - انزل الملف `google-services.json` (هنحتاج منه أرقام بس، مش هنحطه في المشروع).
4. من الملف ده خد القيم دي:

| القيمة | مكانها في `google-services.json` |
|---|---|
| `FIREBASE_API_KEY` | `client[0].api_key[0].current_key` |
| `FIREBASE_APP_ID` | `client[0].client_info.mobilesdk_app_id` |
| `FIREBASE_MESSAGING_SENDER_ID` | `project_info.project_number` |
| `FIREBASE_PROJECT_ID` | `project_info.project_id` |

### 2) ملف البيانات السرية

```bash
cp config/secrets.example.json config/secrets.json
# افتح config/secrets.json واكتب القيم
```

الملف `config/secrets.json` مش بيترفع على GitHub (موجود في `.gitignore`).

### 3) التشغيل على التابلت

```bash
flutter pub get
flutter run --dart-define-from-file=config/secrets.json
```

علشان تعمل ملف APK تنزله على التابلت:

```bash
flutter build apk --release --dart-define-from-file=config/secrets.json
# الملف هيكون في: build/app/outputs/flutter-apk/app-release.apk
```

## تعديل شخصية حورس ومعلومات الشركة

كل حاجة عن شخصية حورس موجودة في ملف واحد: [`lib/config/horus_persona.dart`](lib/config/horus_persona.dart)

- `companyInfo`: معلومات الشركة (الخدمات، العنوان، التليفون...). **لازم تكتب البيانات الحقيقية مكان الأقواس `[...]`**.
- `systemInstruction`: طريقة كلام حورس (عامية مصرية، ردود قصيرة، ...).
- `greetingPrompt`: الترحيب اللي بيقوله أول ما الزائر يضغط.

## تغيير موديل Gemini

الموديل مكتوب في `GEMINI_LIVE_MODEL` جوه `config/secrets.json`. لو جوجل نزلت موديل Live أحدث، غيّر الاسم هناك من غير ما تعدل الكود. أسماء الموديلات المتاحة موجودة في Firebase Console في صفحة AI Logic.

## ملاحظات للروبوت

- **الصدى:** لو السماعة عالية وحورس بيسمع صوته ويقاطع نفسه، سيب اختيار "يسمح للزائر يقاطع حورس" مقفول (ده الافتراضي). كده الميكروفون بيقفل وحورس بيتكلم.
- **Kiosk كامل:** علشان الزائر مايقدرش يخرج من التطبيق، فعّل **Screen pinning** من إعدادات Android (Security ← App pinning).
- **الأمان قبل الاستخدام الفعلي:** فعّل **Firebase App Check** (Play Integrity) علشان محدش يستخدم الـ API key بتاعك من برة التطبيق.

## هيكل المشروع

```
lib/
├── main.dart                     # تشغيل Firebase و Kiosk mode
├── theme.dart                    # الألوان (من لوجو AI Robotics) والخط
├── config/
│   ├── app_config.dart           # قراءة المفاتيح من secrets.json
│   └── horus_persona.dart        # شخصية حورس ومعلومات الشركة
├── services/
│   ├── horus_controller.dart     # المحادثة مع Gemini Live
│   ├── audio_input.dart          # الميكروفون (PCM 16kHz)
│   ├── audio_output.dart         # تشغيل صوت حورس (PCM 24kHz)
│   └── settings_store.dart       # حفظ الإعدادات
├── screens/
│   ├── home_screen.dart          # الشاشة الرئيسية
│   └── settings_sheet.dart       # الإعدادات المخفية
└── widgets/
    └── horus_face.dart           # وش حورس المتحرك
```
