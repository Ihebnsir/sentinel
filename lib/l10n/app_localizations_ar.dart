// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'Sentinel';

  @override
  String get commonCancel => 'إلغاء';

  @override
  String get commonContinue => 'متابعة';

  @override
  String get commonLater => 'لاحقًا';

  @override
  String get commonAccept => 'قبول';

  @override
  String get commonClose => 'إغلاق';

  @override
  String get commonDetails => 'التفاصيل';

  @override
  String get commonOn => 'مفعّل';

  @override
  String get commonOff => 'غير مفعّل';

  @override
  String get commonOffFeminine => 'غير مفعّلة';

  @override
  String get commonUnknown => 'غير معروف';

  @override
  String get commonUnknownFeminine => 'غير معروفة';

  @override
  String get commonYes => 'نعم';

  @override
  String get commonNo => 'لا';

  @override
  String get commonAndroidOnly => 'متاح على أندرويد';

  @override
  String get commonOpenSettings => 'فتح الإعدادات';

  @override
  String get commonComingSoon => 'قريبًا';

  @override
  String get commonAnalysisFailedPull =>
      'فشل التحليل. اسحب الشاشة إلى الأسفل لإعادة المحاولة.';

  @override
  String commonDateAtTime(String date, String time) {
    return '$date على الساعة $time';
  }

  @override
  String get commonOutOf100 => 'من 100';

  @override
  String get commonLoading => 'جارٍ التحميل';

  @override
  String scoreSemantics(int score) {
    return 'درجة الأمان: $score من 100';
  }

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navApps => 'التطبيقات';

  @override
  String get navMessages => 'الرسائل';

  @override
  String get navVault => 'الخزنة';

  @override
  String get homeGreeting => 'مرحبًا';

  @override
  String get homeTitleFailed => 'تعذّر التحليل';

  @override
  String get homeTitleDefault => 'أمان الهاتف';

  @override
  String get homeTitleProtected => 'هاتفك محميّ جيدًا';

  @override
  String get homeTitleToImprove => 'بعض النقاط تحتاج إلى تحسين';

  @override
  String get homeTitleExposed => 'هاتفك معرَّض للخطر';

  @override
  String homeAndroidVersion(String version) {
    return 'أندرويد $version';
  }

  @override
  String homeAndroidVersionPatch(String version, String date) {
    return 'أندرويد $version · تصحيح الأمان بتاريخ $date';
  }

  @override
  String get homeAnalyzing => 'جارٍ التحليل…';

  @override
  String get homeAndroidOnly => 'تحليل الهاتف متاح على أندرويد.';

  @override
  String get homeToGainPoints => 'لكسب المزيد من النقاط';

  @override
  String get homeNothingToFix => 'لا شيء يحتاج إلى إصلاح حاليًا.';

  @override
  String homeWifiAlert(String title) {
    return '$title: تجنّب العمليات البنكية والشراء.';
  }

  @override
  String get scoreLockTitle => 'اضبط قفل الشاشة';

  @override
  String get scoreLockDesc =>
      'رمز أو نمط يمنع الوصول إلى بياناتك إذا ضاع الهاتف';

  @override
  String get scoreRootTitle => 'يبدو أن صلاحيات الجذر (root) مفعّلة على هاتفك';

  @override
  String get scoreRootDesc =>
      'صلاحيات الجذر تتجاوز حماية أندرويد، ولا يمكن إزالتها من الإعدادات';

  @override
  String get scoreUpdateTitle => 'ثبّت تحديث الأمان';

  @override
  String get scoreUpdateUnknown => 'تاريخ آخر تصحيح أمني غير معروف';

  @override
  String get scoreUpdateOld => 'مرّ أكثر من 3 أشهر على آخر تصحيح أمني';

  @override
  String get scoreBiometricTitle => 'فعّل فتح القفل بالبصمة';

  @override
  String get scoreBiometricDesc => 'البصمة أو الوجه لفتح الهاتف';

  @override
  String get scoreDevOptionsTitle => 'أوقف خيارات المطوّرين';

  @override
  String get scoreDevOptionsDesc => 'تتيح الوصول إلى إعدادات حساسة في النظام';

  @override
  String get scoreUsbTitle => 'أوقف تصحيح أخطاء USB';

  @override
  String get scoreUsbDesc => 'قد يصل حاسوب موصول بالهاتف إلى بياناتك';

  @override
  String get scoreEncryptTitle => 'شفّر وحدة التخزين';

  @override
  String get scoreEncryptDesc => 'تبقى ملفاتك غير قابلة للقراءة دون رمزك';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String settingsAppVersion(String version) {
    return 'Sentinel $version';
  }

  @override
  String get settingsLanguage => 'اللغة';

  @override
  String get settingsLanguageSystem => 'لغة الهاتف';

  @override
  String get settingsTheme => 'المظهر';

  @override
  String get settingsThemeSystem => 'مثل الهاتف';

  @override
  String get settingsThemeLight => 'فاتح';

  @override
  String get settingsThemeDark => 'داكن';

  @override
  String get settingsReplayOnboarding => 'إعادة عرض التعريف بالتطبيق';

  @override
  String get settingsPrivacy => 'سياسة الخصوصية';

  @override
  String get settingsLicenses => 'التراخيص';

  @override
  String get settingsLicensesDetail =>
      'المكتبات، الخط، قوائم الحظر، برامج التجسس';

  @override
  String get settingsLicenseLegalese => 'رخصة MIT';

  @override
  String get settingsAudit => 'تقرير التدقيق الأمني';

  @override
  String get settingsReportFlaw => 'الإبلاغ عن ثغرة';

  @override
  String get settingsReportFlawDetail => 'بشكل خاص عبر GitHub (يفتح المتصفّح)';

  @override
  String get onboardingNext => 'التالي';

  @override
  String get onboardingStart => 'ابدأ';

  @override
  String get onboarding1Title => 'Sentinel يحرس هاتفك';

  @override
  String get onboarding1Line1 => 'درجة أمان والإعدادات التي يجب تصحيحها.';

  @override
  String get onboarding1Line2 =>
      'التطبيقات المشبوهة: تطبيقات مزيّفة وبرامج تجسس.';

  @override
  String get onboarding1Line3 => 'رسائل الاحتيال، تُحلَّل على الهاتف نفسه.';

  @override
  String get onboarding1Line4 => 'خزنة مشفّرة لكلمات المرور.';

  @override
  String get onboarding1Line5 =>
      'جدار حماية يحظر المواقع الخطيرة وأدوات التتبّع.';

  @override
  String get onboarding2Title => 'كل شيء يبقى على هاتفك';

  @override
  String get onboarding2Line1 =>
      'لا حساب ولا إعلانات ولا إحصاءات. رسائلك وكلمات مرورك وقائمة تطبيقاتك لا تغادر الهاتف أبدًا.';

  @override
  String get onboarding2Line2 =>
      'هناك ثلاثة اتصالات بالشبكة فقط، كلها اختيارية، ولا تحدث إلا إذا فعّلتها:';

  @override
  String get onboarding2Line3 =>
      '• التحقق من تسريب كلمات المرور (Have I Been Pwned): تُرسَل 5 أحرف من بصمة، ولا تُرسَل كلمة المرور أبدًا.';

  @override
  String get onboarding2Line4 =>
      '• جدار حماية DNS: تُرسَل أسماء المواقع المسموح بها مشفّرةً إلى خادم Quad9.';

  @override
  String get onboarding2Line5 => '• تحديث قوائم الحظر: تنزيل بسيط من GitHub.';

  @override
  String get onboarding3Title => 'الأذونات في الوقت المناسب';

  @override
  String get onboarding3Line1 => 'لا يطلب Sentinel أي شيء الآن.';

  @override
  String get onboarding3Line2 =>
      'يُطلب كل إذن (الإشعارات، الوصول إلى الإشعارات، VPN، البصمة) فقط عندما تفعّل الميزة التي تحتاجه، مع شرح.';

  @override
  String get onboarding3Line3 => 'يمكنك إيقاف كل شيء في أي وقت.';

  @override
  String get privacyBriefTitle => 'باختصار';

  @override
  String get privacyBrief1 =>
      'لا يملك Sentinel أي خادم ولا حساب ولا إعلانات ولا إحصاءات استخدام ولا تقارير أعطال. تتم جميع التحليلات على الهاتف.';

  @override
  String get privacyBrief2 =>
      'لا يتصل Sentinel بالإنترنت إلا من أجل الميزات الاختيارية الثلاث المذكورة أدناه، وبعد موافقتك فقط.';

  @override
  String get privacyNetworkTitle => 'الاتصالات الوحيدة بالشبكة (اختيارية)';

  @override
  String get privacyNetwork1 =>
      '1. التحقق من تسريب كلمات المرور (الخزنة). بعد موافقتك، يحسب Sentinel بصمة SHA-1 لكل كلمة مرور ولا يرسل إلا أحرفها الخمسة الأولى إلى Have I Been Pwned (api.pwnedpasswords.com) عبر HTTPS. لا تغادر كلمة المرور ولا بصمتها الكاملة الهاتف أبدًا. ترى الخدمة عنوان IP الخاص بك. يمكنك سحب هذه الموافقة، وعندها تُمحى النتائج.';

  @override
  String get privacyNetwork2 =>
      '2. جدار حماية DNS. عند تفعيله، تمرّ أسماء المواقع التي تطلبها تطبيقاتك عبر Sentinel. تتلقى المواقع المحظورة ردًّا على الهاتف نفسه، وتُرسَل الأسماء الأخرى مشفّرةً إلى خادم Quad9 (DNS عبر TLS أو عبر HTTPS). يرى Quad9 هذه الأسماء وعنوان IP الخاص بك، وفق سياسة الخصوصية الخاصة به. إذا حظرت شبكةٌ DNS المشفّر، فلا يُرسَل أي شيء دون تشفير إلا إذا سمحت بذلك لهذه الشبكة.';

  @override
  String get privacyNetwork3 =>
      '3. تحديث قوائم الحظر. غير مفعّل افتراضيًا. إذا شغّلته أو فعّلت التحديث التلقائي (مرة واحدة في اليوم على الأكثر)، ينزّل Sentinel القوائم من GitHub (raw.githubusercontent.com) دون ملفات تعريف ارتباط ودون أي معلومة عنك. يرى GitHub عنوان IP الخاص بك.';

  @override
  String get privacyNetwork4 =>
      'تُفتح روابط «فتح الموقع» (النصائح، المصادر، تقرير التدقيق) في متصفّحك، فقط عندما تلمسها.';

  @override
  String get privacyLocalTitle => 'ما يبقى على الهاتف';

  @override
  String get privacyLocal1 =>
      'الخزنة (كلمات المرور والملاحظات): مشفّرة بكلمة مرورك الرئيسية (Argon2id، AES-256-GCM).';

  @override
  String get privacyLocal2 =>
      'اختياراتك: الموافقة على التحقق من التسريبات، إعدادات جدار الحماية وقائمة المواقع المسموح بها، تفعيل الحماية التلقائية أو عدمه، مشاهدة التعريف بالتطبيق، اللغة، المظهر.';

  @override
  String get privacyLocal3 => 'قوائم الحظر وتحديثاتها.';

  @override
  String get privacyLocal4 =>
      'تقارير «تحليل تطبيق»: قائمة المواقع التي اتصل بها التطبيق المختار، وتُمحى بعد 24 ساعة من التحليل على الأكثر.';

  @override
  String get privacyLocal5 =>
      'النسخ الاحتياطي في أندرويد معطَّل: لا يُرسَل أي شيء إلى السحابة. لا تُنشأ نسخة احتياطية من الخزنة (ملف ‎.sentinel مشفّر) إلا إذا طلبتها، وفي المكان الذي تختاره.';

  @override
  String get privacyNeverTitle => 'ما لا يسجّله Sentinel أبدًا';

  @override
  String get privacyNever1 =>
      'نص الرسائل ورموز QR التي يتم تحليلها (الملصوقة أو المشارَكة أو الممسوحة أو المقروءة من الإشعارات): يُحلَّل في الذاكرة ثم يُنسى. لا تُحفظ صورة الكاميرا أبدًا.';

  @override
  String get privacyNever2 =>
      'سجلّ تصفّحك: لا يحتفظ جدار الحماية إلا بعدّادات، ولا يحتفظ أبدًا باسم أي موقع (إلا أثناء تحليل تطبيق تشغّله بنفسك).';

  @override
  String get privacyNever3 =>
      'اسم شبكة Wi-Fi وموقعك: لا يطلب Sentinel إذن تحديد الموقع.';

  @override
  String get privacyPermissionsTitle => 'الأذونات';

  @override
  String get privacyPermissions1 =>
      'قائمة التطبيقات المثبّتة: لاكتشاف التطبيقات المزيّفة وبرامج التجسس. لا تُرسَل أبدًا.';

  @override
  String get privacyPermissions2 =>
      'الإشعارات: يُطلب هذا الإذن عند تفعيل الحماية التلقائية أو جدار الحماية، لعرض التنبيهات.';

  @override
  String get privacyPermissions3 =>
      'الوصول إلى الإشعارات: إعداد في أندرويد تفتحه بنفسك من أجل الحماية التلقائية، ويقرأ Sentinel الرسائل الواردة للبحث فيها عن عمليات احتيال.';

  @override
  String get privacyPermissions4 =>
      'VPN: يُطلب عند تفعيل جدار الحماية. لا يلتقط إلا طلبات DNS، وليس بقية حركة البيانات.';

  @override
  String get privacyPermissions5 =>
      'البصمة: فقط إذا اخترت فتح الخزنة دون كتابة كلمة مرورك الرئيسية.';

  @override
  String get privacyPermissions6 =>
      'الكاميرا: تُطلب عند الضغط على «مسح رمز QR»، فقط لقراءة الرمز، على الهاتف.';

  @override
  String get privacyEraseTitle => 'محو بياناتك';

  @override
  String get privacyErase1 =>
      'إلغاء تثبيت Sentinel يمحو كل ما سجّله على الهاتف. لا توجد أي نسخة في مكان آخر.';

  @override
  String get auditFrameTitle => 'إطار التدقيق';

  @override
  String get auditFrame1 =>
      'تدقيق أمني وفق معيار OWASP MASVS v2، من 21 إلى 24 أكتوبر 2026، على الإصدار 1.0.0 من Sentinel: تحليل الشيفرة وحركة الشبكة والتخزين ومكوّنات أندرويد.';

  @override
  String get auditFrame2 =>
      'أُجري لصالح مالك التطبيق، على شيفرته الخاصة: ليس تدقيقًا مستقلًا.';

  @override
  String get auditResultsTitle => 'النتائج';

  @override
  String get auditResults1 =>
      '17 ملاحظة، منها واحدة عالية الخطورة وأربع متوسطة.';

  @override
  String get auditResults2 =>
      'تم إصلاح 14 منها، ولكل منها اختبار آلي. وقُبلت 3 عن وعي (نموذج مكافحة الاحتيال مقروء لأن التطبيق مفتوح المصدر، عدم تثبيت الشهادات، ملاحظة مطابقة أصلًا).';

  @override
  String get auditResults3 =>
      'منذ ذلك الحين، يشفّر جدار الحماية جميع طلباته، ولم يعد التطبيق يتصل بأي جهة دون موافقة.';

  @override
  String get auditLimitsTitle => 'الحدود';

  @override
  String get auditLimits1 =>
      'لا يوجد تطبيق آمن بنسبة 100٪. المخاطر الرئيسية المتبقية تتعلق بالهاتف: إصدار أندرويد قديم جدًا، أو برنامج تجسس مُنح إذن تسهيلات الاستخدام أو صلاحيات الجذر.';

  @override
  String get auditReadFull => 'قراءة التقرير الكامل على GitHub';

  @override
  String get verdictScam => 'احتيال محتمل';

  @override
  String get verdictSuspect => 'مشبوه';

  @override
  String get verdictNothing => 'لا شيء مشبوه';

  @override
  String get adviceScam =>
      'لا تضغط على الرابط ولا تشارك أي رمز. لن يطلب منك البنك أو البريد أبدًا الدفع عبر رسالة SMS. احذف هذه الرسالة.';

  @override
  String get adviceSuspect =>
      'كن حذرًا: لا تفتح الرابط ولا تقدّم أي معلومة. إذا ساورك الشك، فاتصل بالجهة المعنية على الرقم المذكور في موقعها الرسمي.';

  @override
  String get adviceNothing =>
      'لم يُعثر على أي علامة احتيال. ابقَ يقظًا مع ذلك: لا تشارك رموزك أو كلمات مرورك أبدًا.';

  @override
  String get reasonHiddenCharacters =>
      'أحرف غير مرئية أو تعكس اتجاه النص (أسلوب احتيال)';

  @override
  String reasonScamWords(String words) {
    return 'كلمات معتادة في رسائل الاحتيال: $words';
  }

  @override
  String reasonQuotedWord(String word) {
    return '«$word»';
  }

  @override
  String get listSeparator => '، ';

  @override
  String reasonLinkImpersonation(String host, String brand) {
    return '«$host» ينتحل صفة $brand لكنه ليس موقعه الرسمي';
  }

  @override
  String reasonLinkIp(String host) {
    return 'يستخدم الرابط عنوان IP ($host) بدلًا من اسم موقع';
  }

  @override
  String reasonLinkPunycode(String host) {
    return '«$host» يحتوي على أحرف متنكّرة (punycode) ليشبه موقعًا حقيقيًا';
  }

  @override
  String reasonLinkAt(String host) {
    return 'يحتوي الرابط على «@»: الوجهة الحقيقية هي «$host»';
  }

  @override
  String reasonLinkShortener(String host) {
    return 'رابط مختصر ($host): العنوان الحقيقي مخفي';
  }

  @override
  String reasonLinkTld(String tld) {
    return 'الامتداد «.$tld» يُستخدم كثيرًا في عمليات الاحتيال';
  }

  @override
  String reasonLinkSubdomains(String host) {
    return '«$host» يحتوي على نطاقات فرعية كثيرة، وهي حيلة للخداع';
  }

  @override
  String get reasonLinkHttp => 'الرابط غير آمن (http بدلًا من https)';

  @override
  String get messagesHint => 'الصق رسالة SMS أو رسالة واتساب أو رابطًا';

  @override
  String get messagesPaste => 'لصق';

  @override
  String get messagesClear => 'مسح';

  @override
  String get messagesAnalyze => 'تحليل';

  @override
  String get messagesFailed => 'فشل التحليل. حاول مرة أخرى.';

  @override
  String get messagesLocalNote =>
      'يتم التحليل على هاتفك، ولا تُرسَل الرسالة إلى أي مكان.';

  @override
  String messagesProbability(String percent) {
    return 'احتمال الاحتيال: $percent٪';
  }

  @override
  String get alertDefaultReason =>
      'تشبه هذه الرسالة عمليات الاحتيال المعروفة. لا تضغط على أي رابط.';

  @override
  String get alertTitleSms => 'احتيال محتمل في رسالة SMS';

  @override
  String get alertTitleMessage => 'احتيال محتمل في رسالة';

  @override
  String alertTitleApp(String app) {
    return 'احتيال محتمل على $app';
  }

  @override
  String get autoProtectionTitle => 'الحماية التلقائية';

  @override
  String get autoProtectionOn =>
      'يحلّل الرسائل الواردة وينبّهك في حال وجود احتيال.';

  @override
  String get autoProtectionNotificationsBlocked =>
      'إشعارات Sentinel محظورة: لن يتم تنبيهك في حال وجود احتيال.';

  @override
  String get autoProtectionAllowNotifications => 'السماح بإشعارات Sentinel';

  @override
  String get autoProtectionRemoveAccess =>
      'إزالة الوصول أيضًا من إعدادات أندرويد';

  @override
  String get autoProtectionDoesTitle => 'ما يفعله Sentinel';

  @override
  String get autoProtectionDoes1 => 'يقرأ نص إشعارات تطبيقات المراسلة لديك.';

  @override
  String get autoProtectionDoes2 => 'يحلّله على هاتفك.';

  @override
  String get autoProtectionDoes3 => 'ينبّهك إذا كان احتيالًا.';

  @override
  String get autoProtectionNeverTitle => 'ما لا يفعله Sentinel أبدًا';

  @override
  String get autoProtectionNever1 => 'إرسال رسائلك عبر الإنترنت.';

  @override
  String get autoProtectionNever2 => 'حفظها.';

  @override
  String get autoProtectionNever3 => 'قراءة إشعارات التطبيقات الأخرى.';

  @override
  String get wifiLevelDanger => 'خطر';

  @override
  String get wifiLevelWeak => 'ضعيف';

  @override
  String get wifiLevelOk => 'جيد';

  @override
  String get wifiLevelExcellent => 'ممتاز';

  @override
  String get wifiLevelNone => 'لا يوجد';

  @override
  String get wifiLevelUnknown => 'غير معروف';

  @override
  String get wifiSecurityOpen => 'لا توجد (شبكة مفتوحة)';

  @override
  String get wifiSecurityWpa2 => 'WPA2 أو WPA';

  @override
  String get wifiSecurityEnterprise => 'مؤسسات (WPA2 / WPA3)';

  @override
  String get wifiAdviceNoBanking =>
      'تجنّب العمليات البنكية والشراء على هذه الشبكة';

  @override
  String get wifiAdviceUseMobile => 'استخدم بيانات الهاتف المحمول بدلًا منها';

  @override
  String get wifiAdviceUpgradeBox =>
      'إذا كان هذا جهاز الراوتر الخاص بك، فاختر WPA2 أو WPA3 في إعداداته';

  @override
  String get wifiAdvicePublicUnknown =>
      'على شبكة Wi-Fi عامة، تجنّب العمليات البنكية والشراء';

  @override
  String get wifiNoneTitle => 'لا توجد شبكة Wi-Fi';

  @override
  String get wifiNoneSummary => 'أنت غير متصل بأي شبكة Wi-Fi.';

  @override
  String get wifiNoneExplanation =>
      'أنت غير متصل بأي شبكة Wi-Fi: لا شيء للتحقق منه حاليًا.';

  @override
  String get wifiPublicTitle => 'شبكة Wi-Fi عامة';

  @override
  String get wifiPublicSummary => 'شبكة مشتركة بصفحة تسجيل دخول.';

  @override
  String get wifiCaptiveExplanation =>
      'تطلب هذه الشبكة تسجيل الدخول عبر صفحة (فندق، محطة، مقهى…). يتشاركها كثير من الناس.';

  @override
  String get wifiCaptiveAdvice =>
      'لا تستخدم أبدًا كلمات مرورك المعتادة في صفحة تسجيل الدخول';

  @override
  String get wifiDnsOffExplanation =>
      'خاصية DNS الخاص غير مفعّلة: يمكن للشبكة رؤية أسماء المواقع التي تزورها.';

  @override
  String get wifiDnsOffAdvice => 'فعّل DNS الخاص (الوضع التلقائي) من الإعدادات';

  @override
  String get wifiOpenTitle => 'شبكة Wi-Fi مفتوحة';

  @override
  String get wifiOpenSummary => 'هذه الشبكة غير محمية.';

  @override
  String get wifiOpenExplanation =>
      'هذه الشبكة غير محمية. يمكن للأشخاص المتصلين بالشبكة نفسها رؤية ما ترسله.';

  @override
  String get wifiWepTitle => 'حماية WEP قديمة';

  @override
  String get wifiWepSummary => 'يمكن كسر حمايتها في دقائق.';

  @override
  String get wifiWepExplanation =>
      'تستخدم هذه الشبكة WEP، وهي حماية تعود إلى عام 1999 ويمكن كسرها في دقائق. إنها تقريبًا مثل شبكة مفتوحة.';

  @override
  String get wifiWpaTitle => 'حماية WPA قديمة';

  @override
  String get wifiWpaSummary => 'حماية قديمة وضعيفة.';

  @override
  String get wifiWpaExplanation =>
      'تستخدم هذه الشبكة WPA، وهي حماية قديمة بها ثغرات معروفة.';

  @override
  String get wifiOweTitle => 'شبكة Wi-Fi عامة مشفّرة';

  @override
  String get wifiOweSummary => 'مشفّرة، لكنها مفتوحة للجميع.';

  @override
  String get wifiOweExplanation =>
      'تشفّر هذه الشبكة العامة اتصالاتك (Enhanced Open)، فلا يستطيع الآخرون قراءتها. لكن يمكن لأي شخص الاتصال بها، ويمكن لشبكة مزيّفة أن تنتحل صفة الشبكة الحقيقية.';

  @override
  String get wifiWpa2Title => 'شبكة Wi-Fi محمية (WPA2)';

  @override
  String get wifiWpa2Summary => 'محمية بكلمة مرور.';

  @override
  String get wifiWpa2Explanation =>
      'هذه الشبكة محمية بكلمة مرور (WPA2). لا يستطيع من لا يعرفها قراءة ما ترسله.';

  @override
  String get wifiWpa3Title => 'شبكة Wi-Fi محمية جدًا (WPA3)';

  @override
  String get wifiWpa3Summary => 'أفضل حماية Wi-Fi متوفرة حاليًا.';

  @override
  String get wifiWpa3Explanation =>
      'تستخدم هذه الشبكة WPA3، وهي أحدث حماية. حتى من يعرف كلمة المرور لا يستطيع قراءة اتصالاتك.';

  @override
  String get wifiEnterpriseTitle => 'شبكة Wi-Fi للمؤسسات';

  @override
  String get wifiEnterpriseSummary => 'يتصل كل شخص باسم مستخدم خاص به.';

  @override
  String get wifiEnterpriseExplanation =>
      'تمنح شبكة المؤسسات هذه (WPA2 / WPA3-Enterprise) كل شخص اسم مستخدم ومفتاحًا خاصين به.';

  @override
  String get wifiUnknownTitle => 'أمان غير معروف';

  @override
  String get wifiUnknownSummary => 'نوع الحماية غير متوفر.';

  @override
  String get wifiUnknownOldAndroid =>
      'في أندرويد 11 والإصدارات الأقدم، تتطلب معرفة حماية شبكة Wi-Fi إذن تحديد الموقع، وهو إذن لا يطلبه Sentinel.';

  @override
  String get wifiUnknownExplanation =>
      'لم يُشر أندرويد إلى نوع حماية هذه الشبكة.';

  @override
  String get wifiSectionTitle => 'شبكة Wi-Fi';

  @override
  String get wifiUnavailableTitle => 'المعلومة غير متوفرة';

  @override
  String get wifiUnavailableSummary =>
      'تعذّر على أندرويد قراءة حالة شبكة Wi-Fi.';

  @override
  String get wifiDetailProtection => 'الحماية';

  @override
  String get wifiDetailCaptive => 'صفحة تسجيل الدخول';

  @override
  String get wifiDetailPrivateDns => 'DNS الخاص';

  @override
  String get wifiOurAdvice => 'نصائحنا';

  @override
  String get wifiEnablePrivateDns => 'تفعيل DNS الخاص';

  @override
  String get wifiPrivateDnsHelp =>
      'يفتح «الشبكة والإنترنت». قد تجد DNS الخاص أحيانًا ضمن «إعدادات متقدمة» أو «المزيد من إعدادات الاتصال».';

  @override
  String get riskLevelSystem => 'النظام';

  @override
  String get riskLevelLow => 'منخفض';

  @override
  String get riskLevelModerate => 'متوسط';

  @override
  String get riskLevelHigh => 'مرتفع';

  @override
  String get riskStalkerware => 'برنامج تجسس معروف (stalkerware)';

  @override
  String riskModifiedCopy(String brand) {
    return 'نسخة معدّلة من $brand (توقيعها مختلف عن توقيع الناشر الرسمي)';
  }

  @override
  String riskImpersonation(String brand) {
    return 'ينتحل صفة $brand، لكنه ليس التطبيق الرسمي';
  }

  @override
  String riskKnownMod(String brand) {
    return 'نسخة معدّلة غير رسمية من $brand: يمكنها قراءة رسائلك';
  }

  @override
  String get riskSpyProfile =>
      'أيقونة مخفية وأذونات وصول معتادة لدى برامج التجسس';

  @override
  String get riskBankingCombo =>
      'مزيج معتاد لدى التطبيقات التي تسرق الحسابات البنكية';

  @override
  String get riskAccessibility =>
      'يمكنه قراءة كل ما يظهر على الشاشة والتصرّف نيابةً عنك';

  @override
  String get riskUnknownSource => 'مثبّت من خارج متجر Play';

  @override
  String get riskDeviceAdmin =>
      'يملك صلاحيات مسؤول الجهاز وقد يصعّب إلغاء تثبيته';

  @override
  String get riskDebugCert => 'موقّع بشهادة اختبار';

  @override
  String get riskSms => 'يمكنه قراءة رسائل SMS، بما فيها رموز التحقق البنكية';

  @override
  String get riskNotifications => 'يمكنه قراءة جميع إشعاراتك، بما فيها رسائلك';

  @override
  String get riskMicrophone => 'يمكنه استخدام الميكروفون';

  @override
  String get riskCallLog => 'يمكنه الاطلاع على سجلّ مكالماتك';

  @override
  String get riskOverlay => 'يمكنه الظهور فوق التطبيقات الأخرى';

  @override
  String get riskBackgroundLocation => 'يمكنه معرفة موقعك حتى عندما لا تستخدمه';

  @override
  String get riskOldTarget => 'مصمَّم لإصدار قديم من أندرويد، بحماية أقل';

  @override
  String get riskOtherStore =>
      'مثبّت من متجر غير متجر Play (بإجراءات فحص مختلفة)';

  @override
  String get riskContacts => 'يمكنه قراءة جهات اتصالك';

  @override
  String get riskCamera => 'يمكنه استخدام الكاميرا';

  @override
  String appsAnalyzed(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم تحليل $n تطبيق',
      many: 'تم تحليل $n تطبيقًا',
      few: 'تم تحليل $n تطبيقات',
      two: 'تم تحليل تطبيقين',
      one: 'تم تحليل تطبيق واحد',
      zero: 'لم يُحلَّل أي تطبيق',
    );
    return '$_temp0';
  }

  @override
  String appsSummaryNoneToReview(String analyzed) {
    return '$analyzed، ولا يحتاج أي منها إلى مراجعة.';
  }

  @override
  String appsSummaryToReview(String analyzed, String count) {
    return '$analyzed، منها $count تحتاج إلى مراجعة.';
  }

  @override
  String get appsEmptyTitle => 'حلّل تطبيقاتك';

  @override
  String get appsEmptyMessage =>
      'يتحقق Sentinel من أذونات كل تطبيق مثبّت وينبّهك إلى التطبيقات التي تطلب أكثر من اللازم.';

  @override
  String get appsStartScan => 'بدء التحليل';

  @override
  String get appsAndroidOnly => 'تحليل التطبيقات متاح على أندرويد.';

  @override
  String get appsShowSystem => 'إظهار تطبيقات النظام';

  @override
  String get appsSpywareFound => 'تم العثور على برنامج تجسس محتمل';

  @override
  String get appsSpywareReadAdvice => 'اقرأ النصائح قبل حذفه.';

  @override
  String get appsSeeAdvice => 'عرض النصائح';

  @override
  String get appsScanning => 'جارٍ تحليل تطبيقاتك…';

  @override
  String get appsSystemApp => 'تطبيق من نظام أندرويد';

  @override
  String get appsNoWorry => 'لا توجد مؤشرات مقلقة';

  @override
  String get detailPreinstalled => 'مثبّت مسبقًا';

  @override
  String get detailUnknownSource => 'مصدر غير معروف';

  @override
  String detailKnownSpyware(String name) {
    return 'برنامج تجسس معروف: $name';
  }

  @override
  String detailSignatureVerified(String brand) {
    return 'تم التحقق من توقيع $brand';
  }

  @override
  String detailSignatureDifferent(String brand) {
    return 'توقيع مختلف عن توقيع الناشر الرسمي لـ$brand';
  }

  @override
  String detailNotOfficial(String brand) {
    return 'هذا ليس التطبيق الرسمي لـ$brand';
  }

  @override
  String detailKnownMod(String brand) {
    return 'نسخة معدّلة غير رسمية من $brand';
  }

  @override
  String detailUnchecked(String brand) {
    return 'البصمة الرسمية لـ$brand غير مسجّلة بعد في Sentinel';
  }

  @override
  String get detailSignatureUnreadable => 'توقيع غير مقروء';

  @override
  String get detailSha256 => 'بصمة SHA-256';

  @override
  String get detailCertificate => 'الشهادة';

  @override
  String get detailPublisherMissing => 'الناشر غير محدد';

  @override
  String detailOtherCertificates(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'و$n شهادة أخرى (قديمة أو متعددة)',
      many: 'و$n شهادة أخرى (قديمة أو متعددة)',
      few: 'و$n شهادات أخرى (قديمة أو متعددة)',
      two: 'وشهادتان أخريان (قديمة أو متعددة)',
      one: 'وشهادة أخرى واحدة (قديمة أو متعددة)',
    );
    return '$_temp0';
  }

  @override
  String get detailWhatToDo => 'ماذا أفعل؟';

  @override
  String get detailManagePermissions => 'إدارة الأذونات';

  @override
  String get detailUninstall => 'إلغاء التثبيت';

  @override
  String get detailRiskLevel => 'مستوى الخطر';

  @override
  String get detailSource => 'المصدر';

  @override
  String get detailInstalledOn => 'تاريخ التثبيت';

  @override
  String get detailUpdatedOn => 'تاريخ التحديث';

  @override
  String get detailWhyLevel => 'سبب هذا المستوى';

  @override
  String get detailSystemExplanation =>
      'هذا التطبيق جزء من أندرويد أو من الشركة المصنّعة لهاتفك. أذوناته الواسعة طبيعية لعمله.';

  @override
  String get detailSignature => 'التوقيع';

  @override
  String get detailGrantedPermissions => 'الأذونات الممنوحة';

  @override
  String get detailNoPermissions => 'لم يُمنح أي إذن';

  @override
  String detailOtherPermissions(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'و$n إذن تقني آخر',
      many: 'و$n إذنًا تقنيًا آخر',
      few: 'و$n أذونات تقنية أخرى',
      two: 'وإذنان تقنيان آخران',
      one: 'وإذن تقني آخر',
    );
    return '$_temp0';
  }

  @override
  String get spywareTitle => 'قبل أن تتصرّف في هذا التطبيق';

  @override
  String get spywareParagraph1 =>
      'إذا كنت تظن أن شخصًا من محيطك ثبّت هذا التطبيق، فقد يؤدي حذفه إلى تنبيهه. إذا كنت في خطر، فاتصل أولًا بجمعية مساعدة أو بالشرطة.';

  @override
  String get spywareParagraph2 =>
      'قبل التصرّف، يمكنك تدوين اسم التطبيق والتقاط صورة للشاشة: قد يفيد ذلك كدليل.';

  @override
  String get spywareParagraph3 =>
      'لا ينبّه Sentinel أي أحد ولا يرسل أي إشعار بهذا الشأن.';

  @override
  String get spywareGetHelp => 'الحصول على مساعدة';

  @override
  String get spywareCoalition =>
      'Coalition Against Stalkerware: نصائح للأشخاص الخاضعين للمراقبة وجهات اتصال لجمعيات المساعدة.';

  @override
  String get spywareBrowserNote =>
      'يُفتح الموقع في متصفّحك وسيبقى في سجلّه. يمكنك أيضًا نسخ العنوان وفتحه في وضع التصفّح الخاص، أو من جهاز آخر.';

  @override
  String get spywareOpenSite => 'فتح الموقع';

  @override
  String get spywareCopyAddress => 'نسخ العنوان';

  @override
  String get spywareAddressCopied => 'تم نسخ العنوان';

  @override
  String get spywareIocCredit =>
      'قائمة برامج التجسس: مشروع Stalkerware Indicators (Echap)، برخصة CC BY 4.0.';

  @override
  String get permReadSms => 'قراءة رسائل SMS';

  @override
  String get permReceiveSms => 'استقبال رسائل SMS';

  @override
  String get permSendSms => 'إرسال رسائل SMS (قد تكون مدفوعة)';

  @override
  String get permReceiveMms => 'استقبال رسائل MMS';

  @override
  String get permReadCallLog => 'الاطلاع على سجلّ المكالمات';

  @override
  String get permWriteCallLog => 'تعديل سجلّ المكالمات';

  @override
  String get permCallPhone => 'إجراء مكالمات';

  @override
  String get permAnswerPhoneCalls => 'الرد على المكالمات';

  @override
  String get permReadPhoneState => 'معرفة حالة الهاتف والمكالمات';

  @override
  String get permReadPhoneNumbers => 'معرفة رقم هاتفك';

  @override
  String get permReadContacts => 'قراءة جهات اتصالك';

  @override
  String get permWriteContacts => 'تعديل جهات اتصالك';

  @override
  String get permGetAccounts => 'رؤية الحسابات المسجّلة على الهاتف';

  @override
  String get permReadCalendar => 'قراءة تقويمك';

  @override
  String get permWriteCalendar => 'تعديل تقويمك';

  @override
  String get permRecordAudio => 'استخدام الميكروفون';

  @override
  String get permCamera => 'استخدام الكاميرا';

  @override
  String get permBodySensors => 'قراءة مستشعرات الجسم (نبض القلب…)';

  @override
  String get permBodySensorsBackground => 'قراءة مستشعرات الجسم في الخلفية';

  @override
  String get permActivityRecognition => 'رصد نشاطك البدني';

  @override
  String get permAccessFineLocation => 'معرفة موقعك الدقيق';

  @override
  String get permAccessCoarseLocation => 'معرفة موقعك التقريبي';

  @override
  String get permAccessBackgroundLocation =>
      'معرفة موقعك حتى عندما يكون التطبيق مغلقًا';

  @override
  String get permAccessMediaLocation => 'معرفة أماكن التقاط صورك';

  @override
  String get permReadExternalStorage => 'قراءة ملفاتك';

  @override
  String get permWriteExternalStorage => 'تعديل ملفاتك';

  @override
  String get permManageExternalStorage => 'الوصول إلى جميع ملفاتك';

  @override
  String get permReadMediaImages => 'رؤية صورك';

  @override
  String get permReadMediaVideo => 'رؤية مقاطع الفيديو الخاصة بك';

  @override
  String get permReadMediaAudio => 'الوصول إلى ملفاتك الصوتية';

  @override
  String get permReadMediaVisualUserSelected => 'رؤية الصور التي تختارها';

  @override
  String get permBluetooth => 'استخدام البلوتوث';

  @override
  String get permBluetoothConnect => 'الاتصال بأجهزة البلوتوث';

  @override
  String get permBluetoothScan => 'البحث عن أجهزة البلوتوث';

  @override
  String get permNearbyWifiDevices => 'العثور على أجهزة Wi-Fi القريبة';

  @override
  String get permNfc => 'استخدام NFC (الدفع اللاتلامسي…)';

  @override
  String get permInternet => 'الوصول إلى الإنترنت';

  @override
  String get permAccessNetworkState => 'معرفة حالة الاتصال';

  @override
  String get permAccessWifiState => 'رؤية شبكات Wi-Fi';

  @override
  String get permChangeWifiState => 'تشغيل Wi-Fi أو إيقافه';

  @override
  String get permSystemAlertWindow => 'الظهور فوق التطبيقات الأخرى';

  @override
  String get permPostNotifications => 'عرض الإشعارات';

  @override
  String get permRequestInstallPackages => 'اقتراح تثبيت تطبيقات أخرى';

  @override
  String get permRequestDeletePackages => 'اقتراح إلغاء تثبيت تطبيقات';

  @override
  String get permQueryAllPackages => 'رؤية قائمة تطبيقاتك';

  @override
  String get permPackageUsageStats => 'معرفة التطبيقات التي تستخدمها';

  @override
  String get permReceiveBootCompleted => 'التشغيل عند بدء تشغيل الهاتف';

  @override
  String get permForegroundService => 'العمل باستمرار في الخلفية';

  @override
  String get permWakeLock => 'منع الهاتف من الدخول في وضع السكون';

  @override
  String get permVibrate => 'تشغيل اهتزاز الهاتف';

  @override
  String get permUseBiometric => 'استخدام البصمة أو الوجه';

  @override
  String get permUseFingerprint => 'استخدام بصمة الإصبع';

  @override
  String get permScheduleExactAlarm => 'جدولة منبّهات دقيقة';

  @override
  String get permUseFullScreenIntent => 'عرض تنبيهات بملء الشاشة';

  @override
  String get firewallTitle => 'جدار حماية DNS';

  @override
  String firewallOnBlocked(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'مفعّل · $n طلب محظور',
      many: 'مفعّل · $n طلبًا محظورًا',
      few: 'مفعّل · $n طلبات محظورة',
      two: 'مفعّل · طلبان محظوران',
      one: 'مفعّل · طلب واحد محظور',
      zero: 'مفعّل · لم يُحظر أي طلب',
    );
    return '$_temp0';
  }

  @override
  String get categoryMalware => 'البرمجيات الخبيثة والتصيّد';

  @override
  String get categoryImpersonation => 'انتحال العلامات التجارية';

  @override
  String get categoryTrackers => 'أدوات التتبّع';

  @override
  String get categoryAds => 'الإعلانات';

  @override
  String get categoryOther => 'نطاقات أخرى';

  @override
  String categoryBrandsWatched(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n علامة مراقَبة · المواقع التي تنتحلها',
      many: '$n علامة مراقَبة · المواقع التي تنتحلها',
      few: '$n علامات مراقَبة · المواقع التي تنتحلها',
      two: 'علامتان مراقَبتان · المواقع التي تنتحلهما',
      one: 'علامة واحدة مراقَبة · المواقع التي تنتحلها',
      zero: 'لا توجد علامات مراقَبة',
    );
    return '$_temp0';
  }

  @override
  String domainsCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n نطاق',
      many: '$n نطاقًا',
      few: '$n نطاقات',
      two: 'نطاقان',
      one: 'نطاق واحد',
      zero: '$n نطاق',
    );
    return '$_temp0';
  }

  @override
  String get firewallListsBundled => 'القوائم المرفقة بالتطبيق';

  @override
  String firewallLastUpdate(String date) {
    return 'آخر تحديث: $date';
  }

  @override
  String get firewallLastAttemptFailed => 'فشلت المحاولة الأخيرة';

  @override
  String get analysisErrorFirewallOff => 'فعّل جدار حماية DNS أولًا.';

  @override
  String get analysisErrorRunning => 'هناك تحليل جارٍ بالفعل.';

  @override
  String get analysisErrorUnknownApp => 'لم يعد هذا التطبيق مثبّتًا.';

  @override
  String get analysisErrorFailed => 'تعذّر بدء التحليل.';

  @override
  String durationMinutes(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n دقيقة',
      many: '$n دقيقة',
      few: '$n دقائق',
      two: 'دقيقتان',
      one: 'دقيقة واحدة',
      zero: '$n دقيقة',
    );
    return '$_temp0';
  }

  @override
  String durationMinutesLong(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n دقيقة',
      many: '$n دقيقة',
      few: '$n دقائق',
      two: 'دقيقتين',
      one: 'دقيقة واحدة',
      zero: '$n دقيقة',
    );
    return '$_temp0';
  }

  @override
  String durationSeconds(String n) {
    return '$n ث';
  }

  @override
  String durationMinutesSeconds(String minutes, String seconds) {
    return '$minutes د $seconds ث';
  }

  @override
  String durationMinutesOnly(String minutes) {
    return '$minutes د';
  }

  @override
  String get durationLessThanSecond => 'أقل من ثانية';

  @override
  String reportStoppedEarly(String duration, String planned) {
    return '$duration (أُوقف قبل انتهاء المدة المقررة: $planned)';
  }

  @override
  String reportNoDomain(String app) {
    return 'لم يتصل $app بأي نطاق أثناء التحليل.';
  }

  @override
  String reportContacted(String app, String domains) {
    return 'اتصل $app بـ$domains';
  }

  @override
  String reportNothingKnown(String start) {
    return '$start، ولا يُعرف أي منها كأداة تتبّع أو إعلان أو موقع خطير.';
  }

  @override
  String reportIncluding(String start, String parts) {
    return '$start، منها $parts.';
  }

  @override
  String reportDangerousCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n موقع خطير',
      many: '$n موقعًا خطيرًا',
      few: '$n مواقع خطيرة',
      two: 'موقعان خطيران',
      one: 'موقع خطير واحد',
      zero: '$n موقع خطير',
    );
    return '$_temp0';
  }

  @override
  String reportTrackersCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n أداة تتبّع',
      many: '$n أداة تتبّع',
      few: '$n أدوات تتبّع',
      two: 'أداتا تتبّع',
      one: 'أداة تتبّع واحدة',
      zero: '$n أداة تتبّع',
    );
    return '$_temp0';
  }

  @override
  String reportAdsCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n إعلان',
      many: '$n إعلانًا',
      few: '$n إعلانات',
      two: 'إعلانان',
      one: 'إعلان واحد',
      zero: '$n إعلان',
    );
    return '$_temp0';
  }

  @override
  String get listLastSeparator => ' و';

  @override
  String get analysisLessThanMinuteLeft => 'تبقّت أقل من دقيقة';

  @override
  String analysisMinutesLeft(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تبقّت $n دقيقة',
      many: 'تبقّت $n دقيقة',
      few: 'تبقّت $n دقائق',
      two: 'تبقّت دقيقتان',
      one: 'تبقّت دقيقة واحدة',
      zero: 'تبقّت $n دقيقة',
    );
    return '$_temp0';
  }

  @override
  String analysisDomainsSeen(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n نطاق مرصود',
      many: '$n نطاقًا مرصودًا',
      few: '$n نطاقات مرصودة',
      two: 'نطاقان مرصودان',
      one: 'نطاق واحد مرصود',
      zero: 'لم يُرصد أي نطاق',
    );
    return '$_temp0';
  }

  @override
  String get analysisSectionTitle => 'تحليل تطبيق';

  @override
  String analysisRunning(String app) {
    return 'جارٍ تحليل $app';
  }

  @override
  String get analysisUnprotectedWarning =>
      'التطبيقات الأخرى غير محمية بجدار الحماية حتى نهاية التحليل.';

  @override
  String get analysisStop => 'إيقاف التحليل';

  @override
  String get analysisIntroActive =>
      'اكتشف المواقع التي يتصل بها تطبيق ما خلال بضع دقائق: أدوات التتبّع والإعلانات والمواقع الخطيرة.';

  @override
  String get analysisIntroInactive => 'فعّل جدار الحماية لتحليل تطبيق.';

  @override
  String get analysisChooseApp => 'اختيار تطبيق';

  @override
  String get analysisRecentReports => 'تقارير آخر 24 ساعة';

  @override
  String get analysisScreenIntro =>
      'اختر التطبيق المراد مراقبته. سيسجّل Sentinel لبضع دقائق المواقع (النطاقات) التي يتصل بها.';

  @override
  String get analysisListFailed => 'تعذّر عرض قائمة التطبيقات.';

  @override
  String get analysisNoApps => 'لا توجد تطبيقات لتحليلها.';

  @override
  String analysisSheetTitle(String app) {
    return 'تحليل $app';
  }

  @override
  String analysisSheetLine1(String duration, String app) {
    return 'خلال $duration، لا تمرّ عبر جدار الحماية إلا طلبات $app: كل نطاق يُرصد يعود إليه.';
  }

  @override
  String get analysisSheetLine2 =>
      'التطبيقات الأخرى غير محمية خلال هذه المدة: لا حظر ولا تنبيهات. تجنّب فتح روابط مجهولة.';

  @override
  String get analysisSheetLine3 =>
      'في النهاية، يعود جدار الحماية العادي تلقائيًا. يمكنك الإيقاف قبل ذلك من Sentinel أو من الإشعار.';

  @override
  String get analysisSheetLine4 =>
      'يبقى التقرير على هذا الهاتف 24 ساعة على الأكثر، ثم يُحذف. ولا يُرسَل أبدًا.';

  @override
  String analysisSheetLine5(String app) {
    return 'سيُفتح $app: استخدمه كالمعتاد.';
  }

  @override
  String reportDateLine(String date, String duration) {
    return 'تحليل بتاريخ $date · $duration';
  }

  @override
  String get reportDomainsContacted => 'النطاقات التي تم الاتصال بها';

  @override
  String get reportDangerousSites => 'مواقع خطيرة';

  @override
  String get reportTruncated =>
      'القائمة غير مكتملة: اتصل التطبيق بعدد كبير جدًا من النطاقات المختلفة.';

  @override
  String get reportSeeApp => 'عرض التطبيق';

  @override
  String get reportDelete => 'حذف هذا التقرير';

  @override
  String reportLocalOnly(String date) {
    return 'يبقى هذا التقرير على هذا الهاتف فقط حتى $date، ثم يُحذف تلقائيًا. ولا يُرسَل أبدًا.';
  }

  @override
  String get reportApproximate =>
      'عدد الطلبات تقريبي: يحتفظ أندرويد ببعض الردود في الذاكرة لبضع دقائق.';

  @override
  String reportRequests(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n طلب',
      many: '$n طلبًا',
      few: '$n طلبات',
      two: 'طلبان',
      one: 'طلب واحد',
      zero: '$n طلب',
    );
    return '$_temp0';
  }

  @override
  String reportImitates(String brand) {
    return 'ينتحل صفة $brand';
  }

  @override
  String get reportBlocked => 'محظور';

  @override
  String get firewallIntro =>
      'يحظر المواقع الخطيرة وأدوات التتبّع قبل أن يتصل بها أي تطبيق. يتم كل شيء على هاتفك.';

  @override
  String get firewallSinceActivation => 'منذ التفعيل';

  @override
  String get firewallQueriesAnalyzed => 'الطلبات التي تم تحليلها';

  @override
  String get firewallQueriesBlocked => 'الطلبات المحظورة';

  @override
  String get firewallListsLoading => 'جارٍ تحميل القوائم…';

  @override
  String get firewallOneVpn =>
      'يسمح أندرويد بشبكة VPN واحدة فقط في كل مرة: إذا فعّلت شبكة أخرى، يتوقف جدار الحماية.';

  @override
  String get firewallUpdated => 'تم تحديث القوائم.';

  @override
  String get firewallUpdateFailed =>
      'تعذّر التحديث: تم الاحتفاظ بالقوائم الحالية.';

  @override
  String get firewallInvalidDomain => 'نطاق غير صالح، مثال: example.com';

  @override
  String get firewallDomainRefused =>
      'تم رفض النطاق (صيغة غير صالحة أو القائمة ممتلئة)';

  @override
  String get firewallExplain1 =>
      'سيطلب منك أندرويد السماح بـ«اتصال VPN»: هكذا يرى Sentinel أسماء المواقع المطلوبة.';

  @override
  String get firewallExplain2 =>
      'لا تمرّ عبر Sentinel إلا طلبات أسماء المواقع (DNS)، ولا تتغير بقية حركة بياناتك.';

  @override
  String get firewallExplain3 =>
      'تُطلب المواقع المسموح بها من Quad9 (خادم سويسري) بشكل مشفّر: لم تعد شبكتك ترى أسماء المواقع.';

  @override
  String get firewallExplain4 =>
      'لا يُسجَّل أي موقع تزوره: توجد عدّادات فقط (إلا أثناء تحليل تطبيق تشغّله بنفسك).';

  @override
  String get firewallExplain5 =>
      'يبقى إشعار هادئ ظاهرًا طوال تفعيل جدار الحماية.';

  @override
  String get firewallUpdateTitle => 'تحديث القوائم';

  @override
  String get firewallConsent1 =>
      'ينزّل Sentinel قوائم الحظر من GitHub (raw.githubusercontent.com) عبر HTTPS، مرة واحدة يوميًا على الأكثر.';

  @override
  String get firewallConsent2 =>
      'لا تُرسَل أي معلومة عنك: لا المواقع التي تزورها ولا أي مُعرِّف. وكما في أي اتصال، يرى GitHub عنوان IP لهاتفك.';

  @override
  String get firewallConsent3 =>
      'تُفحص كل قائمة (الحجم، الصيغة، الاتساق) قبل استخدامها. وفي حال وجود مشكلة، يُحتفظ بالنسخة السابقة.';

  @override
  String get blocklistCacheNote =>
      'قد تستغرق التغييرات بضع دقائق لتُطبَّق (ذاكرة DNS المؤقتة في المتصفّح).';

  @override
  String get blocklistListsTitle => 'قوائم الحظر';

  @override
  String get blocklistAdsWarning => 'قد يمنع بعض التطبيقات من العمل.';

  @override
  String get blocklistImpersonationWarning =>
      'قد يحظر موقعًا حقيقيًا غير مُدرج: أضفه حينها إلى القائمة البيضاء.';

  @override
  String get blocklistAutoUpdateTitle => 'التحديثات التلقائية';

  @override
  String get blocklistUpdateDaily => 'التحديث يوميًا';

  @override
  String get blocklistUpdateNote =>
      'تُنزَّل القوائم عبر HTTPS من GitHub، مرة واحدة يوميًا على الأكثر. لا تُرسَل أي معلومة عنك.';

  @override
  String get blocklistUpdating => 'جارٍ التحديث…';

  @override
  String get blocklistUpdateNow => 'تحديث';

  @override
  String get allowlistTitle => 'القائمة البيضاء';

  @override
  String get allowlistIntro =>
      'لا تُحظر هذه المواقع أبدًا حتى لو وردت في إحدى القوائم، ولا نطاقاتها الفرعية أيضًا.';

  @override
  String get allowlistHint => 'example.com';

  @override
  String get allowlistAdd => 'إضافة';

  @override
  String get allowlistEmpty => 'لا توجد مواقع حتى الآن.';

  @override
  String allowlistRemove(String domain) {
    return 'إزالة $domain';
  }

  @override
  String get sourcesTitle => 'المصادر والتراخيص';

  @override
  String get sourcesSeeSource => 'عرض المصدر';

  @override
  String get upstreamIdle => 'في انتظار الطلب الأول';

  @override
  String get upstreamDot => 'مشفّر (DNS-over-TLS)';

  @override
  String get upstreamDoh => 'مشفّر (DNS-over-HTTPS)';

  @override
  String get upstreamPlain => 'غير مشفّر: مسموح به على هذه الشبكة';

  @override
  String get upstreamFailing => 'تعذّر الوصول إلى Quad9 بشكل مشفّر';

  @override
  String get upstreamFailingHelp =>
      'تحظر هذه الشبكة DNS المشفّر، لذلك لن تُفتح المواقع. لا يرسل Sentinel طلباتك دون تشفير أبدًا من دون موافقتك. إذا كنت تثق بهذه الشبكة، يمكنك السماح بذلك أدناه: ستصبح عندها أسماء المواقع التي تزورها مرئية على الشبكة.';

  @override
  String get upstreamLabel => 'الطلبات إلى Quad9';

  @override
  String get upstreamAllowPlain => 'السماح بـDNS غير المشفّر على هذه الشبكة';

  @override
  String get dnsStrictTitle => 'DNS خاص غير متوافق';

  @override
  String dnsStrictMessage(String server) {
    return 'تم ضبط DNS الخاص لديك على «$server» (الوضع الصارم). مع جدار الحماية، لن يُفتح أي موقع. اختر «تلقائي» في الإعدادات: Sentinel يشفّر طلبات DNS الخاصة بك أصلًا.';
  }

  @override
  String get dnsStrictOpenSettings => 'فتح إعدادات DNS الخاص';

  @override
  String get networkProtectionTitle => 'حماية الشبكة';

  @override
  String get vaultSettingsTitle => 'إعدادات الخزنة';

  @override
  String get vaultLock => 'قفل';

  @override
  String get vaultEmptyTitle => 'كلمات مرورك، مشفّرة';

  @override
  String get vaultEmptyMessage =>
      'احفظ كلمات مرورك وملاحظاتك السرية. تُشفَّر على هاتفك ولا يستطيع أي شخص آخر قراءتها.';

  @override
  String get vaultCreate => 'إنشاء خزنتي';

  @override
  String get vaultUnreadableTitle => 'الخزنة غير مقروءة';

  @override
  String get vaultUnreadableMessage =>
      'يبدو أن ملف الخزنة تالف أو معدَّل. لا يستطيع Sentinel فتحه.';

  @override
  String get vaultCreateFailed => 'فشل إنشاء الخزنة.';

  @override
  String get vaultCreateIntro =>
      'اختر كلمة مرور رئيسية: تفتح الخزنة وتشفّر كل محتواها.';

  @override
  String get vaultCreateWarning =>
      'لا أحد، ولا حتى Sentinel، يستطيع استرجاع كلمة المرور هذه. ستحصل بعد ذلك على مفتاح استرداد: دوّنه، فهو الطريقة الوحيدة لفتح الخزنة إذا نسيتها.';

  @override
  String get vaultMasterPassword => 'كلمة المرور الرئيسية';

  @override
  String get vaultConfirmation => 'التأكيد';

  @override
  String get vaultPasswordsDiffer => 'كلمتا المرور غير متطابقتين';

  @override
  String get vaultUnderstood => 'فهمت أن كلمة المرور هذه لا يمكن استرجاعها';

  @override
  String get vaultCreating => 'جارٍ الإنشاء…';

  @override
  String get vaultRestoreBackup => 'استعادة نسخة احتياطية';

  @override
  String get vaultFingerprintsChanged =>
      'تغيّرت البصمات المسجّلة على الهاتف. افتح الخزنة بكلمة مرورك، ثم أعد تفعيل البصمة.';

  @override
  String get vaultTooManyTries => 'محاولات كثيرة جدًا. استخدم كلمة مرورك.';

  @override
  String get vaultFingerprintFailed =>
      'تعذّر فتح الخزنة بالبصمة. استخدم كلمة مرورك.';

  @override
  String get vaultWeeklyPassword =>
      'من أجل أمانك، تُطلب كلمة المرور الرئيسية مرة واحدة على الأقل كل 7 أيام.';

  @override
  String get vaultLockedTitle => 'الخزنة مقفلة';

  @override
  String get vaultUseFingerprintOrPassword =>
      'استخدم بصمتك أو كلمة مرورك الرئيسية.';

  @override
  String get vaultEnterMasterPassword => 'أدخل كلمة مرورك الرئيسية.';

  @override
  String get vaultOpenWithFingerprint => 'الفتح بالبصمة';

  @override
  String get vaultOrWithPassword => 'أو بكلمة المرور:';

  @override
  String get vaultWrongPassword => 'كلمة المرور غير صحيحة.';

  @override
  String vaultRetryIn(String seconds) {
    return 'أعد المحاولة بعد $seconds ث.';
  }

  @override
  String get vaultOpening => 'جارٍ الفتح…';

  @override
  String get vaultOpen => 'فتح الخزنة';

  @override
  String get vaultForgotPassword => 'هل نسيت كلمة المرور؟';

  @override
  String get vaultSaveFailed => 'فشل الحفظ.';

  @override
  String get vaultForgotTitle => 'نسيان كلمة المرور';

  @override
  String get vaultKeyAccepted =>
      'تم قبول المفتاح. اختر كلمة مرور رئيسية جديدة.';

  @override
  String get vaultEnterRecoveryKey =>
      'أدخل مفتاح الاسترداد الذي دوّنته عند إنشاء الخزنة. تُقبل الشَّرطات والأحرف الصغيرة.';

  @override
  String get vaultRecoveryKeyLabel => 'مفتاح الاسترداد';

  @override
  String get vaultWrongRecoveryKey => 'مفتاح الاسترداد غير صحيح';

  @override
  String get vaultNewMasterPassword => 'كلمة مرور رئيسية جديدة';

  @override
  String get vaultNewKeyWillBeCreated =>
      'سيُنشأ مفتاح استرداد جديد، ولن يعمل المفتاح القديم بعد ذلك.';

  @override
  String get vaultSaving => 'جارٍ الحفظ…';

  @override
  String get vaultSave => 'حفظ';

  @override
  String vaultKeyCopied(String seconds) {
    return 'تم نسخ المفتاح. سيُمحى من الحافظة بعد $seconds ث.';
  }

  @override
  String get vaultYourRecoveryKey => 'مفتاح الاسترداد الخاص بك';

  @override
  String get vaultWriteKeyDown =>
      'اكتبه على ورقة واحفظه في مكان آمن. إنه الطريقة الوحيدة لفتح الخزنة إذا نسيت كلمة مرورك.';

  @override
  String get vaultKeyShownOnce => 'لن يُعرض مرة أخرى أبدًا.';

  @override
  String get vaultCopy => 'نسخ';

  @override
  String get vaultRetypeLast4 =>
      'للتأكد من أنك دوّنته، أعد كتابة آخر 4 أحرف منه.';

  @override
  String get vaultLast4Label => 'آخر 4 أحرف';

  @override
  String get vaultKeyNoted => 'لقد دوّنت مفتاحي';

  @override
  String get vaultKeyCreateFailed => 'فشل إنشاء المفتاح.';

  @override
  String get vaultKeyOfferTitle => 'جديد: مفتاح الاسترداد';

  @override
  String get vaultKeyOfferText =>
      'إذا نسيت كلمة مرورك الرئيسية، فمفتاح الاسترداد هو الطريقة الوحيدة لفتح الخزنة. أنشئه الآن ودوّنه على ورقة.';

  @override
  String get vaultCreateKey => 'إنشاء مفتاحي';

  @override
  String get backupEmpty => 'هذا الملف فارغ.';

  @override
  String get backupUnreadable =>
      'هذا الملف ليس نسخة احتياطية من Sentinel، أو أنه تالف.';

  @override
  String get backupNewerVersion =>
      'هذه النسخة الاحتياطية من إصدار أحدث من Sentinel. حدّث التطبيق ثم أعد المحاولة.';

  @override
  String get backupTooBig =>
      'هذا الملف أكبر من أن يكون نسخة احتياطية من Sentinel.';

  @override
  String get backupCannotReadFile => 'تعذّرت قراءة هذا الملف.';

  @override
  String get backupWrongPassword =>
      'كلمة المرور غير صحيحة، أو تم تعديل الملف بعد تصديره.';

  @override
  String get backupCannotRead => 'تعذّرت قراءة هذه النسخة الاحتياطية.';

  @override
  String get backupRestoreFailed => 'فشلت الاستعادة.';

  @override
  String get backupIntroFile =>
      'اختر ملف .sentinel الذي أنشأته عبر «تصدير نسخة احتياطية مشفّرة» على هاتفك القديم.';

  @override
  String get backupIntroPassword =>
      'أدخل كلمة المرور التي اخترتها عند التصدير.';

  @override
  String backupIntroNewPassword(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n عنصر',
      many: '$n عنصرًا',
      few: '$n عناصر',
      two: 'عنصران',
      one: 'عنصر واحد',
      zero: 'لا توجد عناصر',
    );
    return 'تم فتح النسخة الاحتياطية: $_temp0. اختر كلمة المرور الرئيسية لهذا الهاتف.';
  }

  @override
  String get backupPasswordLabel => 'كلمة مرور النسخة الاحتياطية';

  @override
  String get backupNewKeyNote => 'سيُنشأ مفتاح استرداد جديد لهذا الهاتف.';

  @override
  String get backupChooseFile => 'اختيار الملف';

  @override
  String get backupRestoring => 'جارٍ الاستعادة…';

  @override
  String get backupRestore => 'استعادة';

  @override
  String get vaultAdd => 'إضافة';

  @override
  String get vaultEmptyList => 'خزنتك فارغة. أضف أول كلمة مرور أو ملاحظة سرية.';

  @override
  String get vaultNoResults => 'لا توجد نتائج.';

  @override
  String get vaultHealthTitle => 'صحة كلمات المرور';

  @override
  String get vaultAllGood => 'كل شيء على ما يرام';

  @override
  String vaultToFix(String count) {
    return '$count للتصحيح';
  }

  @override
  String get vaultSearch => 'بحث';

  @override
  String get vaultTypePassword => 'كلمة مرور';

  @override
  String get vaultTypeNote => 'ملاحظة سرية';

  @override
  String vaultPasswordCopied(String seconds) {
    return 'تم نسخ كلمة المرور. ستُمحى من الحافظة بعد $seconds ث.';
  }

  @override
  String get vaultNeedTitle => 'أعطِ هذا العنصر عنوانًا.';

  @override
  String vaultDeleteItemTitle(String title) {
    return 'حذف «$title»؟';
  }

  @override
  String get vaultDeleteItemText => 'سيُمحى هذا العنصر نهائيًا من الخزنة.';

  @override
  String get vaultDelete => 'حذف';

  @override
  String get vaultNewPassword => 'كلمة مرور جديدة';

  @override
  String get vaultNewNote => 'ملاحظة سرية جديدة';

  @override
  String get vaultFieldTitle => 'العنوان';

  @override
  String get vaultFieldNote => 'ملاحظة';

  @override
  String get vaultFieldUsername => 'اسم المستخدم';

  @override
  String get vaultFieldWebsite => 'الموقع الإلكتروني';

  @override
  String get vaultHideGenerator => 'إخفاء المولّد';

  @override
  String get vaultGenerate => 'توليد';

  @override
  String generatorLength(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'الطول: $n حرف',
      many: 'الطول: $n حرفًا',
      few: 'الطول: $n أحرف',
      two: 'الطول: حرفان',
      one: 'الطول: حرف واحد',
      zero: 'الطول: $n حرف',
    );
    return '$_temp0';
  }

  @override
  String get generatorUppercase => 'أحرف كبيرة (A-Z)';

  @override
  String get generatorDigits => 'أرقام (0-9)';

  @override
  String get generatorSymbols => 'رموز (!#\$…)';

  @override
  String get generatorNewPassword => 'كلمة مرور جديدة';

  @override
  String healthToFix(String count) {
    return '$count للتصحيح. المس عنصرًا لتغيير كلمة مروره.';
  }

  @override
  String get healthBreached => 'موجودة في تسريبات';

  @override
  String get healthNoBreach => 'لم يُعثر على أي كلمة مرور في التسريبات.';

  @override
  String get healthReused => 'مستخدمة أكثر من مرة';

  @override
  String get healthAllUnique => 'كل كلمة مرور فريدة.';

  @override
  String healthAlsoUsedFor(String titles) {
    return 'مستخدمة أيضًا لـ: $titles';
  }

  @override
  String get healthWeak => 'ضعيفة جدًا';

  @override
  String get healthNoWeak => 'لا توجد كلمة مرور ضعيفة جدًا.';

  @override
  String get healthEasyToGuess => 'سهلة التخمين';

  @override
  String get healthCheckIntro =>
      'تحقّق مما إذا كانت كلمات مرورك تظهر في تسريبات معروفة (Have I Been Pwned).';

  @override
  String get healthCheckButton => 'التحقق من التسريبات';

  @override
  String healthChecking(String done, String total) {
    return 'جارٍ التحقق… $done / $total';
  }

  @override
  String get healthRetry => 'إعادة المحاولة';

  @override
  String breachMessage(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ظهرت كلمة المرور هذه $n مرة في تسريبات بيانات. غيّرها.',
      few: 'ظهرت كلمة المرور هذه $n مرات في تسريبات بيانات. غيّرها.',
      two: 'ظهرت كلمة المرور هذه مرتين في تسريبات بيانات. غيّرها.',
      one: 'ظهرت كلمة المرور هذه مرة واحدة في تسريبات بيانات. غيّرها.',
    );
    return '$_temp0';
  }

  @override
  String breachShort(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ظهرت $n مرة في تسريبات',
      few: 'ظهرت $n مرات في تسريبات',
      two: 'ظهرت مرتين في تسريبات',
      one: 'ظهرت مرة واحدة في تسريبات',
    );
    return '$_temp0';
  }

  @override
  String get breachConsentTitle => 'التحقق من التسريبات؟';

  @override
  String get breachConsentText =>
      'يرسل Sentinel فقط أول 5 أحرف من بصمة (hash) كل كلمة مرور إلى Have I Been Pwned. لا تغادر كلمة مرورك الهاتف أبدًا.';

  @override
  String get breachConsentDetail =>
      'تردّ الخدمة بقائمة من التسريبات المعروفة، وتتم المقارنة على هاتفك. يمكنك سحب هذه الموافقة من إعدادات الخزنة.';

  @override
  String get breachConsentCheck => 'تحقّق';

  @override
  String get breachErrorTimeout => 'الخدمة لا تستجيب. أعد المحاولة لاحقًا.';

  @override
  String get breachErrorOffline =>
      'لا يوجد اتصال بالإنترنت. تحقّق من Wi-Fi أو بيانات الهاتف المحمول.';

  @override
  String get breachErrorTooMany => 'طلبات كثيرة جدًا. أعد المحاولة بعد قليل.';

  @override
  String breachErrorUnavailable(String code) {
    return 'خدمة Have I Been Pwned غير متاحة (خطأ $code).';
  }

  @override
  String get clipboardSharedTitle => 'حافظة مشتركة';

  @override
  String get clipboardSharedWarning =>
      'في هذا الإصدار من أندرويد، يمكن لجميع التطبيقات قراءة ما تنسخه. ستُفرَّغ الحافظة بعد 10 ثوانٍ.';

  @override
  String get clipboardCopyAnyway => 'النسخ على أي حال';

  @override
  String get fieldShow => 'إظهار';

  @override
  String get fieldHide => 'إخفاء';

  @override
  String get strengthWeak => 'ضعيفة';

  @override
  String get strengthMedium => 'متوسطة';

  @override
  String get strengthStrong => 'قوية';

  @override
  String strengthLine(String strength) {
    return 'القوة: $strength';
  }

  @override
  String strengthLineTooShort(String strength, String length, String min) {
    return 'القوة: $strength · $length / $min حرفًا كحدّ أدنى';
  }

  @override
  String get vaultFingerprintEnabled => 'تم تفعيل الفتح بالبصمة.';

  @override
  String get vaultBiometricTooManyTries =>
      'محاولات كثيرة جدًا. أعد المحاولة بعد لحظات.';

  @override
  String get vaultNoFingerprint => 'لا توجد بصمة مسجّلة على هذا الهاتف.';

  @override
  String get vaultFingerprintActivationFailed => 'فشل تفعيل البصمة.';

  @override
  String get vaultNewKeyTitle => 'مفتاح استرداد جديد؟';

  @override
  String get vaultNewKeyText =>
      'لن يعمل المفتاح القديم بعد الآن. لا تنسَ تدوين المفتاح الجديد.';

  @override
  String get vaultDeleteFailed => 'فشل الحذف.';

  @override
  String get vaultFingerprintWeekly =>
      'تبقى كلمة المرور مطلوبة مرة واحدة على الأقل كل 7 أيام.';

  @override
  String get vaultBreachSettingDetail =>
      'Have I Been Pwned. لا يُرسَل إلا جزء من بداية البصمة، وليس كلمة المرور أبدًا.';

  @override
  String get vaultChangeMaster => 'تغيير كلمة المرور الرئيسية';

  @override
  String get vaultNewRecoveryKey => 'إنشاء مفتاح استرداد جديد';

  @override
  String get vaultExport => 'تصدير نسخة احتياطية مشفّرة';

  @override
  String get vaultDeleteVault => 'حذف الخزنة';

  @override
  String get vaultDeleteVaultTitle => 'حذف الخزنة؟';

  @override
  String vaultDeleteVaultText(String word) {
    return 'ستُمحى جميع كلمات المرور والملاحظات نهائيًا. اكتب $word للتأكيد.';
  }

  @override
  String get vaultDeleteWord => 'حذف';

  @override
  String get vaultMasterChanged => 'تم تغيير كلمة المرور الرئيسية.';

  @override
  String get vaultCurrentPassword => 'كلمة المرور الحالية';

  @override
  String get vaultWrongPasswordShort => 'كلمة المرور غير صحيحة';

  @override
  String get vaultChange => 'تغيير';

  @override
  String get exportSaved =>
      'تم حفظ النسخة الاحتياطية. احتفظ بكلمة مرورها في مكان آمن.';

  @override
  String get exportCancelled => 'تم إلغاء التصدير.';

  @override
  String get exportFileFailed => 'فشل حفظ الملف.';

  @override
  String get exportFailed => 'فشل التصدير.';

  @override
  String get exportIntro =>
      'للانتقال إلى هاتف جديد: ملف .sentinel مشفّر بكلمة المرور التي تختارها هنا. من دون كلمة المرور هذه، لا يستطيع أحد قراءته، ولا حتى Sentinel.';

  @override
  String get exportStore =>
      'احفظ الملف أينما شئت (Drive، مفتاح USB، حاسوب)، ولا تُضِعه ولا تُضِع كلمة مروره.';

  @override
  String get exportPasswordLabel => 'كلمة مرور التصدير';

  @override
  String get exportEncrypting => 'جارٍ التشفير…';

  @override
  String get exportButton => 'تصدير';

  @override
  String get qrScanButton => 'مسح رمز QR';

  @override
  String get qrScanSubtitle =>
      'تحقّق من رمز QR (ملصق، عدّاد وقوف، طرد) قبل فتحه';

  @override
  String get qrScanPrompt => 'ضع رمز QR داخل الإطار. لا يُفتح أي شيء تلقائيًا.';

  @override
  String get qrCameraTitle => 'السماح باستخدام الكاميرا؟';

  @override
  String get qrCameraText =>
      'يستخدم Sentinel الكاميرا أثناء المسح فقط، لقراءة رمز QR. لا تُحفظ الصورة ولا تُرسل: كل شيء يبقى على الهاتف.';

  @override
  String get qrOpenSettings => 'الإعدادات';

  @override
  String get qrErrorNoCamera => 'لا توجد كاميرا متاحة على هذا الهاتف.';

  @override
  String get qrErrorPermissionDenied =>
      'بدون الكاميرا، لا يستطيع Sentinel قراءة رمز QR.';

  @override
  String get qrErrorPermissionBlocked =>
      'الكاميرا مرفوضة لـ Sentinel. اسمح بها من إعدادات أندرويد.';

  @override
  String get qrErrorFailed => 'فشل المسح. أعد المحاولة.';

  @override
  String get qrResultTitle => 'رمز QR الممسوح';

  @override
  String get qrRawContent => 'المحتوى الخام';

  @override
  String get qrEmpty => '(رمز QR فارغ)';

  @override
  String get qrKindLink => 'رابط';

  @override
  String get qrKindUnsafeLink => 'رابط من نوع خطير';

  @override
  String get qrKindWifi => 'شبكة Wi-Fi';

  @override
  String get qrKindPhone => 'رقم هاتف';

  @override
  String get qrKindSms => 'رسالة SMS للإرسال';

  @override
  String get qrKindPayment => 'طلب دفع';

  @override
  String get qrKindText => 'نص';

  @override
  String get qrWifiName => 'الشبكة';

  @override
  String get qrWifiSecurity => 'الحماية';

  @override
  String get qrWifiPassword => 'كلمة المرور';

  @override
  String get qrWifiPasswordYes => 'موجودة في رمز QR';

  @override
  String get qrWifiPasswordNo => 'لا توجد';

  @override
  String get qrPhoneNumber => 'الرقم';

  @override
  String get qrSmsRecipient => 'المستلم';

  @override
  String get qrSmsText => 'نص الرسالة';

  @override
  String get qrPaymentRecipient => 'المستفيد';

  @override
  String get qrPaymentAmount => 'المبلغ';

  @override
  String get qrNotSpecified => 'غير محدد';

  @override
  String get qrWarningUnsafeLink =>
      'يحتوي رمز QR هذا على رابط قد يشغّل برمجية أو يفتح ملفًا، وليس صفحة ويب. لن يفتحه Sentinel.';

  @override
  String get qrWarningUssd =>
      'يحتوي الرقم على * أو #: إنه رمز قد يغيّر إعدادات الهاتف (تحويل المكالمات، المسح). لا تطلبه.';

  @override
  String get qrWarningShortNumber =>
      'رقم قصير: قد تكون رسالة إلى هذا النوع من الأرقام مكلفة أو تشترك بك في خدمة مدفوعة.';

  @override
  String get qrWarningPayment =>
      'غالبًا ما تُلصق رموز دفع مزيفة فوق الرموز الحقيقية (عدّادات الوقوف، الملصقات). تحقّق من المستفيد والمبلغ قبل الدفع.';

  @override
  String get qrWarningWifiOpen =>
      'شبكة مفتوحة: بدون كلمة مرور، يمكن للآخرين قراءة كل ما يُرسل دون تشفير.';

  @override
  String get qrWarningWifiWep => 'حماية WEP: يمكن كسرها في دقائق.';

  @override
  String get qrActionOpenLink => 'فتح الرابط';

  @override
  String get qrActionOpenAnyway => 'الفتح رغم ذلك';

  @override
  String get qrActionCall => 'الاتصال بهذا الرقم';

  @override
  String get qrActionSms => 'تحضير الرسالة';

  @override
  String get qrActionPayment => 'الفتح في تطبيق دفع';

  @override
  String get qrActionBlocked => 'حظره Sentinel: احتيال محتمل.';

  @override
  String get qrActionFailed =>
      'تعذّر الفتح: لا يوجد تطبيق مناسب أو المحتوى مرفوض.';

  @override
  String qrConfirmLink(String url) {
    return 'لا تُدخل أي رمز أو كلمة مرور إذا طلبتها الصفحة. الرابط الذي سيُفتح في المتصفح: $url';
  }

  @override
  String qrConfirmCall(String number) {
    return 'يفتح الهاتف شاشة الاتصال بالرقم $number. لا تبدأ المكالمة إلا إذا ضغطت على اتصال.';
  }

  @override
  String qrConfirmSms(String number) {
    return 'يُفتح تطبيق الرسائل برسالة إلى $number. لا يُرسل شيء حتى تضغط على إرسال.';
  }

  @override
  String qrConfirmPayment(String recipient) {
    return 'سيُفتح تطبيق دفع لـ: $recipient. تحقّق من المستفيد والمبلغ قبل التأكيد.';
  }
}
