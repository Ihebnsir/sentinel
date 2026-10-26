// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Sentinel';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonLater => 'Later';

  @override
  String get commonAccept => 'Accept';

  @override
  String get commonClose => 'Close';

  @override
  String get commonDetails => 'Details';

  @override
  String get commonOn => 'On';

  @override
  String get commonOff => 'Off';

  @override
  String get commonOffFeminine => 'Off';

  @override
  String get commonUnknown => 'Unknown';

  @override
  String get commonUnknownFeminine => 'Unknown';

  @override
  String get commonYes => 'Yes';

  @override
  String get commonNo => 'No';

  @override
  String get commonAndroidOnly => 'Available on Android';

  @override
  String get commonOpenSettings => 'Open settings';

  @override
  String get commonComingSoon => 'Coming soon';

  @override
  String get commonAnalysisFailedPull =>
      'The analysis failed. Pull down to try again.';

  @override
  String commonDateAtTime(String date, String time) {
    return '$date at $time';
  }

  @override
  String get commonOutOf100 => 'out of 100';

  @override
  String get commonLoading => 'Loading';

  @override
  String scoreSemantics(int score) {
    return 'Security score: $score out of 100';
  }

  @override
  String get navHome => 'Home';

  @override
  String get navApps => 'Apps';

  @override
  String get navMessages => 'Messages';

  @override
  String get navVault => 'Vault';

  @override
  String get homeGreeting => 'Hello';

  @override
  String get homeTitleFailed => 'Analysis failed';

  @override
  String get homeTitleDefault => 'Phone security';

  @override
  String get homeTitleProtected => 'Your phone is well protected';

  @override
  String get homeTitleToImprove => 'A few things to improve';

  @override
  String get homeTitleExposed => 'Your phone is at risk';

  @override
  String homeAndroidVersion(String version) {
    return 'Android $version';
  }

  @override
  String homeAndroidVersionPatch(String version, String date) {
    return 'Android $version · security patch of $date';
  }

  @override
  String get homeAnalyzing => 'Analyzing…';

  @override
  String get homeAndroidOnly => 'Phone analysis is available on Android.';

  @override
  String get homeToGainPoints => 'To earn points';

  @override
  String get homeNothingToFix => 'Nothing to fix for now.';

  @override
  String homeWifiAlert(String title) {
    return '$title: avoid banking and shopping.';
  }

  @override
  String get scoreLockTitle => 'Set up a screen lock';

  @override
  String get scoreLockDesc =>
      'A PIN or pattern protects your data if you lose your phone';

  @override
  String get scoreRootTitle => 'Your phone seems to be rooted';

  @override
  String get scoreRootDesc =>
      'Root bypasses Android\'s protections. It can\'t be removed from the settings';

  @override
  String get scoreUpdateTitle => 'Install the security update';

  @override
  String get scoreUpdateUnknown =>
      'The date of the last security patch is unknown';

  @override
  String get scoreUpdateOld =>
      'The last security patch is more than 3 months old';

  @override
  String get scoreBiometricTitle => 'Turn on biometric unlock';

  @override
  String get scoreBiometricDesc => 'Fingerprint or face to unlock the phone';

  @override
  String get scoreDevOptionsTitle => 'Turn off developer options';

  @override
  String get scoreDevOptionsDesc =>
      'They give access to sensitive system settings';

  @override
  String get scoreUsbTitle => 'Turn off USB debugging';

  @override
  String get scoreUsbDesc => 'A connected computer could access your data';

  @override
  String get scoreEncryptTitle => 'Encrypt storage';

  @override
  String get scoreEncryptDesc => 'Your files stay unreadable without your PIN';

  @override
  String get settingsTitle => 'Settings';

  @override
  String settingsAppVersion(String version) {
    return 'Sentinel $version';
  }

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'Phone language';

  @override
  String get settingsTheme => 'Appearance';

  @override
  String get settingsThemeSystem => 'Same as the phone';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsReplayOnboarding => 'View the introduction again';

  @override
  String get settingsPrivacy => 'Privacy policy';

  @override
  String get settingsLicenses => 'Licenses';

  @override
  String get settingsLicensesDetail => 'Libraries, font, blocklists, spyware';

  @override
  String get settingsLicenseLegalese => 'MIT License';

  @override
  String get settingsAudit => 'Security audit report';

  @override
  String get settingsReportFlaw => 'Report a vulnerability';

  @override
  String get settingsReportFlawDetail =>
      'Privately, via GitHub (opens the browser)';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingStart => 'Get started';

  @override
  String get onboarding1Title => 'Sentinel watches over your phone';

  @override
  String get onboarding1Line1 => 'A security score and the settings to fix.';

  @override
  String get onboarding1Line2 => 'Suspicious apps: fake apps, spyware.';

  @override
  String get onboarding1Line3 => 'Scam messages, analyzed on the phone.';

  @override
  String get onboarding1Line4 => 'An encrypted vault for your passwords.';

  @override
  String get onboarding1Line5 =>
      'A firewall that blocks dangerous sites and trackers.';

  @override
  String get onboarding2Title => 'Everything stays on your phone';

  @override
  String get onboarding2Line1 =>
      'No account, no ads, no analytics. Your messages, your passwords and your list of apps never leave the phone.';

  @override
  String get onboarding2Line2 =>
      'There are only three network exchanges, all optional, and only if you turn them on:';

  @override
  String get onboarding2Line3 =>
      '• Checking for leaked passwords (Have I Been Pwned): 5 characters of a hash, never the password.';

  @override
  String get onboarding2Line4 =>
      '• DNS firewall: the names of allowed sites are sent, encrypted, to the Quad9 resolver.';

  @override
  String get onboarding2Line5 =>
      '• Blocklist updates: a simple download from GitHub.';

  @override
  String get onboarding3Title => 'Permissions, at the right time';

  @override
  String get onboarding3Line1 => 'Sentinel doesn\'t ask for anything now.';

  @override
  String get onboarding3Line2 =>
      'Each permission (notifications, notification access, VPN, biometrics) is requested only when you turn on the feature that needs it, with an explanation.';

  @override
  String get onboarding3Line3 => 'You can turn everything off at any time.';

  @override
  String get privacyBriefTitle => 'In short';

  @override
  String get privacyBrief1 =>
      'Sentinel has no server, no account, no ads, no usage analytics and no crash reports. All analyses run on the phone.';

  @override
  String get privacyBrief2 =>
      'Sentinel only connects to the Internet for the three optional features below, and only after you agree.';

  @override
  String get privacyNetworkTitle => 'The only network exchanges (optional)';

  @override
  String get privacyNetwork1 =>
      '1. Leaked password check (vault). After you agree, Sentinel computes the SHA-1 hash of each password and sends only its first 5 characters to Have I Been Pwned (api.pwnedpasswords.com), over HTTPS. The password and its full hash never leave the phone. The service sees your IP address. You can withdraw your consent; the results are then erased.';

  @override
  String get privacyNetwork2 =>
      '2. DNS firewall. When you turn it on, the names of the sites requested by your apps go through Sentinel. Blocked sites get an answer on the phone; the other names are sent to the Quad9 resolver, encrypted (DNS over TLS or over HTTPS). Quad9 sees these names and your IP address, under its own privacy policy. If a network blocks encrypted DNS, nothing is sent unencrypted unless you allow it for that network.';

  @override
  String get privacyNetwork3 =>
      '3. Blocklist updates. Off by default. If you start one or turn on automatic updates (at most once a day), Sentinel downloads the lists from GitHub (raw.githubusercontent.com), without cookies or any information about you. GitHub sees your IP address.';

  @override
  String get privacyNetwork4 =>
      '\"Open the website\" links (advice, sources, audit report) open in your browser, only when you tap them.';

  @override
  String get privacyLocalTitle => 'What stays on the phone';

  @override
  String get privacyLocal1 =>
      'The vault (passwords, notes): encrypted with your master password (Argon2id, AES-256-GCM).';

  @override
  String get privacyLocal2 =>
      'Your choices: consent to the leak check, firewall settings and list of allowed sites, automatic protection on or off, introduction already seen, language, theme.';

  @override
  String get privacyLocal3 => 'The blocklists and their updates.';

  @override
  String get privacyLocal4 =>
      '\"Analyze an app\" reports: the list of sites contacted by the chosen app, erased at the latest 24 hours after the analysis.';

  @override
  String get privacyLocal5 =>
      'Android backup is turned off: nothing goes to the cloud. A vault backup (encrypted .sentinel file) is only created if you ask for it, in the place you choose.';

  @override
  String get privacyNeverTitle => 'What Sentinel never records';

  @override
  String get privacyNever1 =>
      'The text of analyzed messages and QR codes (pasted, shared, scanned or read from notifications): it is analyzed in memory and then forgotten. The camera image is never saved.';

  @override
  String get privacyNever2 =>
      'Your browsing history: the firewall only keeps counters, never a site name (except during an app analysis that you start).';

  @override
  String get privacyNever3 =>
      'The Wi-Fi name and your location: Sentinel doesn\'t ask for location access.';

  @override
  String get privacyPermissionsTitle => 'Permissions';

  @override
  String get privacyPermissions1 =>
      'List of installed apps: to spot fake apps and spyware. It is never sent anywhere.';

  @override
  String get privacyPermissions2 =>
      'Notifications: requested when you turn on automatic protection or the firewall, to show alerts.';

  @override
  String get privacyPermissions3 =>
      'Notification access: an Android setting you open yourself for automatic protection; Sentinel reads incoming messages to look for scams.';

  @override
  String get privacyPermissions4 =>
      'VPN: requested when you turn on the firewall. It only captures DNS, not the rest of the traffic.';

  @override
  String get privacyPermissions5 =>
      'Biometrics: only if you choose to unlock the vault without typing your master password.';

  @override
  String get privacyPermissions6 =>
      'Camera: requested when you tap “Scan a QR code”, only to read the QR code, on the phone.';

  @override
  String get privacyEraseTitle => 'Erasing your data';

  @override
  String get privacyErase1 =>
      'Uninstalling Sentinel erases everything it saved on the phone. There is no copy anywhere else.';

  @override
  String get auditFrameTitle => 'Scope';

  @override
  String get auditFrame1 =>
      'Security audit based on the OWASP MASVS v2 standard, from October 21 to 24, 2026, on Sentinel 1.0.0: review of the code, network traffic, storage and Android components.';

  @override
  String get auditFrame2 =>
      'It was carried out for the app\'s owner, on their own code: it is not an independent audit.';

  @override
  String get auditResultsTitle => 'Results';

  @override
  String get auditResults1 =>
      '17 findings, including one of high severity and four medium.';

  @override
  String get auditResults2 =>
      '14 are fixed, each with an automated test. 3 are knowingly accepted (readable anti-scam model since the app is open source, no certificate pinning, one finding already compliant).';

  @override
  String get auditResults3 =>
      'Since then, the firewall encrypts all its requests and the app no longer contacts anything without consent.';

  @override
  String get auditLimitsTitle => 'Limits';

  @override
  String get auditLimits1 =>
      'No app is 100% safe. The main remaining risks depend on the phone: an Android version that is too old, or spyware that was given accessibility or root access.';

  @override
  String get auditReadFull => 'Read the full report on GitHub';

  @override
  String get verdictScam => 'Likely scam';

  @override
  String get verdictSuspect => 'Suspicious';

  @override
  String get verdictNothing => 'Nothing suspicious';

  @override
  String get adviceScam =>
      'Don\'t click the link and don\'t share any code. Your bank or the post office will never ask you to pay by SMS. Delete this message.';

  @override
  String get adviceSuspect =>
      'Be careful: don\'t open the link and don\'t give any information. If in doubt, call the organization on the number shown on its official website.';

  @override
  String get adviceNothing =>
      'No sign of a scam found. Stay alert anyway: never share your codes or passwords.';

  @override
  String get reasonHiddenCharacters =>
      'Invisible or text-reversing characters (a scam technique)';

  @override
  String reasonScamWords(String words) {
    return 'Words typical of scams: $words';
  }

  @override
  String reasonQuotedWord(String word) {
    return '\"$word\"';
  }

  @override
  String get listSeparator => ', ';

  @override
  String reasonLinkImpersonation(String host, String brand) {
    return '\"$host\" imitates $brand but is not its official website';
  }

  @override
  String reasonLinkIp(String host) {
    return 'The link uses an IP address ($host) instead of a site name';
  }

  @override
  String reasonLinkPunycode(String host) {
    return '\"$host\" contains disguised letters (punycode) to look like a real site';
  }

  @override
  String reasonLinkAt(String host) {
    return 'The link contains \"@\": the real destination is \"$host\"';
  }

  @override
  String reasonLinkShortener(String host) {
    return 'Shortened link ($host): the real address is hidden';
  }

  @override
  String reasonLinkTld(String tld) {
    return 'The \".$tld\" extension is often used by scams';
  }

  @override
  String reasonLinkSubdomains(String host) {
    return '\"$host\" has many subdomains, a trick to deceive';
  }

  @override
  String get reasonLinkHttp => 'The link is not secure (http instead of https)';

  @override
  String get messagesHint => 'Paste an SMS, a WhatsApp message or a link';

  @override
  String get messagesPaste => 'Paste';

  @override
  String get messagesClear => 'Clear';

  @override
  String get messagesAnalyze => 'Analyze';

  @override
  String get messagesFailed => 'The analysis failed. Try again.';

  @override
  String get messagesLocalNote =>
      'The analysis runs on your phone. The message is not sent anywhere.';

  @override
  String messagesProbability(String percent) {
    return 'Scam probability: $percent%';
  }

  @override
  String get alertDefaultReason =>
      'This message looks like known scams. Do not click any link.';

  @override
  String get alertTitleSms => 'Likely scam in an SMS';

  @override
  String get alertTitleMessage => 'Likely scam in a message';

  @override
  String alertTitleApp(String app) {
    return 'Likely scam on $app';
  }

  @override
  String get autoProtectionTitle => 'Automatic protection';

  @override
  String get autoProtectionOn =>
      'Analyzes incoming messages and warns you about scams.';

  @override
  String get autoProtectionNotificationsBlocked =>
      'Sentinel\'s notifications are blocked: you won\'t be warned about scams.';

  @override
  String get autoProtectionAllowNotifications =>
      'Allow Sentinel\'s notifications';

  @override
  String get autoProtectionRemoveAccess =>
      'Also remove access in Android settings';

  @override
  String get autoProtectionDoesTitle => 'What Sentinel does';

  @override
  String get autoProtectionDoes1 =>
      'Reads the text of notifications from your messaging apps.';

  @override
  String get autoProtectionDoes2 => 'Analyzes it on your phone.';

  @override
  String get autoProtectionDoes3 => 'Warns you if it\'s a scam.';

  @override
  String get autoProtectionNeverTitle => 'What Sentinel never does';

  @override
  String get autoProtectionNever1 => 'Send your messages over the Internet.';

  @override
  String get autoProtectionNever2 => 'Save them.';

  @override
  String get autoProtectionNever3 => 'Read notifications from other apps.';

  @override
  String get wifiLevelDanger => 'Danger';

  @override
  String get wifiLevelWeak => 'Weak';

  @override
  String get wifiLevelOk => 'Good';

  @override
  String get wifiLevelExcellent => 'Excellent';

  @override
  String get wifiLevelNone => 'None';

  @override
  String get wifiLevelUnknown => 'Unknown';

  @override
  String get wifiSecurityOpen => 'None (open network)';

  @override
  String get wifiSecurityWpa2 => 'WPA2 or WPA';

  @override
  String get wifiSecurityEnterprise => 'Enterprise (WPA2 / WPA3)';

  @override
  String get wifiAdviceNoBanking =>
      'Avoid banking and shopping on this network';

  @override
  String get wifiAdviceUseMobile => 'Use mobile data instead';

  @override
  String get wifiAdviceUpgradeBox =>
      'If it\'s your router, choose WPA2 or WPA3 in its settings';

  @override
  String get wifiAdvicePublicUnknown =>
      'On public Wi-Fi, avoid banking and shopping';

  @override
  String get wifiNoneTitle => 'No Wi-Fi';

  @override
  String get wifiNoneSummary => 'You\'re not connected to any Wi-Fi.';

  @override
  String get wifiNoneExplanation =>
      'You\'re not connected to any Wi-Fi: nothing to check for now.';

  @override
  String get wifiPublicTitle => 'Public Wi-Fi';

  @override
  String get wifiPublicSummary => 'Shared network with a login page.';

  @override
  String get wifiCaptiveExplanation =>
      'This network asks you to sign in on a page (hotel, station, café…). Many people share it.';

  @override
  String get wifiCaptiveAdvice =>
      'Never use your usual passwords on the login page';

  @override
  String get wifiDnsOffExplanation =>
      'Private DNS is off: the network can see the names of the sites you visit.';

  @override
  String get wifiDnsOffAdvice =>
      'Turn on Private DNS (automatic mode) in the settings';

  @override
  String get wifiOpenTitle => 'Open Wi-Fi';

  @override
  String get wifiOpenSummary => 'This Wi-Fi isn\'t protected.';

  @override
  String get wifiOpenExplanation =>
      'This Wi-Fi isn\'t protected. People connected to the same network can see what you send.';

  @override
  String get wifiWepTitle => 'Outdated WEP protection';

  @override
  String get wifiWepSummary => 'Its protection can be cracked in minutes.';

  @override
  String get wifiWepExplanation =>
      'This Wi-Fi uses WEP, a protection from 1999 that can be cracked in minutes. It is almost like an open network.';

  @override
  String get wifiWpaTitle => 'Old WPA protection';

  @override
  String get wifiWpaSummary => 'Old and weak protection.';

  @override
  String get wifiWpaExplanation =>
      'This Wi-Fi uses WPA, an old protection with known flaws.';

  @override
  String get wifiOweTitle => 'Encrypted public Wi-Fi';

  @override
  String get wifiOweSummary => 'Encrypted, but open to everyone.';

  @override
  String get wifiOweExplanation =>
      'This public Wi-Fi encrypts your traffic (Enhanced Open): others can\'t read it. But anyone can connect to it, and a fake network can imitate the real one.';

  @override
  String get wifiWpa2Title => 'Protected Wi-Fi (WPA2)';

  @override
  String get wifiWpa2Summary => 'Protected by a password.';

  @override
  String get wifiWpa2Explanation =>
      'This Wi-Fi is protected by a password (WPA2). People who don\'t know it can\'t read what you send.';

  @override
  String get wifiWpa3Title => 'Highly protected Wi-Fi (WPA3)';

  @override
  String get wifiWpa3Summary => 'The best Wi-Fi protection available today.';

  @override
  String get wifiWpa3Explanation =>
      'This Wi-Fi uses WPA3, the most recent protection. Even someone who knows the password cannot read your traffic.';

  @override
  String get wifiEnterpriseTitle => 'Enterprise Wi-Fi';

  @override
  String get wifiEnterpriseSummary =>
      'Everyone signs in with their own credentials.';

  @override
  String get wifiEnterpriseExplanation =>
      'This enterprise Wi-Fi (WPA2 / WPA3-Enterprise) gives each person their own credentials and key.';

  @override
  String get wifiUnknownTitle => 'Unknown security';

  @override
  String get wifiUnknownSummary => 'The type of protection is not available.';

  @override
  String get wifiUnknownOldAndroid =>
      'On Android 11 and earlier, knowing a Wi-Fi\'s protection requires location permission, which Sentinel doesn\'t ask for.';

  @override
  String get wifiUnknownExplanation =>
      'Android didn\'t report this Wi-Fi\'s type of protection.';

  @override
  String get wifiSectionTitle => 'Wi-Fi network';

  @override
  String get wifiUnavailableTitle => 'Information unavailable';

  @override
  String get wifiUnavailableSummary =>
      'Android couldn\'t read the Wi-Fi status.';

  @override
  String get wifiDetailProtection => 'Protection';

  @override
  String get wifiDetailCaptive => 'Login page';

  @override
  String get wifiDetailPrivateDns => 'Private DNS';

  @override
  String get wifiOurAdvice => 'Our advice';

  @override
  String get wifiEnablePrivateDns => 'Turn on Private DNS';

  @override
  String get wifiPrivateDnsHelp =>
      'Opens \"Network & internet\". Private DNS is sometimes under \"Advanced\" or \"More connection settings\".';

  @override
  String get riskLevelSystem => 'System';

  @override
  String get riskLevelLow => 'Low';

  @override
  String get riskLevelModerate => 'Moderate';

  @override
  String get riskLevelHigh => 'High';

  @override
  String get riskStalkerware => 'Known spyware (stalkerware)';

  @override
  String riskModifiedCopy(String brand) {
    return 'Modified copy of $brand (signature differs from the official publisher)';
  }

  @override
  String riskImpersonation(String brand) {
    return 'Pretends to be $brand, but is not the official app';
  }

  @override
  String riskKnownMod(String brand) {
    return 'Unofficial modified version of $brand: it can read your messages';
  }

  @override
  String get riskSpyProfile => 'Hidden icon and access typical of spyware';

  @override
  String get riskBankingCombo =>
      'Combination typical of apps that steal bank accounts';

  @override
  String get riskAccessibility =>
      'Can read everything on the screen and act on your behalf';

  @override
  String get riskUnknownSource => 'Installed outside the Play Store';

  @override
  String get riskDeviceAdmin =>
      'Is a device administrator and can make uninstalling it harder';

  @override
  String get riskDebugCert => 'Signed with a test certificate';

  @override
  String get riskSms => 'Can read your SMS, including bank verification codes';

  @override
  String get riskNotifications =>
      'Can read all your notifications, including your messages';

  @override
  String get riskMicrophone => 'Can use the microphone';

  @override
  String get riskCallLog => 'Can see your call history';

  @override
  String get riskOverlay => 'Can appear on top of other apps';

  @override
  String get riskBackgroundLocation =>
      'Can know your location even when you\'re not using it';

  @override
  String get riskOldTarget =>
      'Built for an old version of Android, with fewer protections';

  @override
  String get riskOtherStore =>
      'Installed from a store other than the Play Store (different checks)';

  @override
  String get riskContacts => 'Can read your contacts';

  @override
  String get riskCamera => 'Can use the camera';

  @override
  String appsAnalyzed(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n apps analyzed',
      one: '$n app analyzed',
    );
    return '$_temp0';
  }

  @override
  String appsSummaryNoneToReview(String analyzed) {
    return '$analyzed, none to review.';
  }

  @override
  String appsSummaryToReview(String analyzed, String count) {
    return '$analyzed, $count to review.';
  }

  @override
  String get appsEmptyTitle => 'Analyze your apps';

  @override
  String get appsEmptyMessage =>
      'Sentinel checks the permissions of each installed app and flags those that ask for too much.';

  @override
  String get appsStartScan => 'Start the analysis';

  @override
  String get appsAndroidOnly => 'App analysis is available on Android.';

  @override
  String get appsShowSystem => 'Show system apps';

  @override
  String get appsSpywareFound => 'Possible spyware was found';

  @override
  String get appsSpywareReadAdvice => 'Read the advice before removing it.';

  @override
  String get appsSeeAdvice => 'See advice';

  @override
  String get appsScanning => 'Analyzing your apps…';

  @override
  String get appsSystemApp => 'Android system app';

  @override
  String get appsNoWorry => 'No worrying signs';

  @override
  String get detailPreinstalled => 'Preinstalled';

  @override
  String get detailUnknownSource => 'Unknown source';

  @override
  String detailKnownSpyware(String name) {
    return 'Known spyware: $name';
  }

  @override
  String detailSignatureVerified(String brand) {
    return 'Signature verified for $brand';
  }

  @override
  String detailSignatureDifferent(String brand) {
    return 'Signature differs from the official publisher of $brand';
  }

  @override
  String detailNotOfficial(String brand) {
    return 'This is not the official $brand app';
  }

  @override
  String detailKnownMod(String brand) {
    return 'Unofficial modified version of $brand';
  }

  @override
  String detailUnchecked(String brand) {
    return 'The official fingerprint of $brand is not yet recorded in Sentinel';
  }

  @override
  String get detailSignatureUnreadable => 'Unreadable signature';

  @override
  String get detailSha256 => 'SHA-256 fingerprint';

  @override
  String get detailCertificate => 'Certificate';

  @override
  String get detailPublisherMissing => 'Publisher not specified';

  @override
  String detailOtherCertificates(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'And $n other certificates (old or multiple)',
      one: 'And 1 other certificate (old or multiple)',
    );
    return '$_temp0';
  }

  @override
  String get detailWhatToDo => 'What should I do?';

  @override
  String get detailManagePermissions => 'Manage permissions';

  @override
  String get detailUninstall => 'Uninstall';

  @override
  String get detailRiskLevel => 'Risk level';

  @override
  String get detailSource => 'Source';

  @override
  String get detailInstalledOn => 'Installed on';

  @override
  String get detailUpdatedOn => 'Updated on';

  @override
  String get detailWhyLevel => 'Why this level';

  @override
  String get detailSystemExplanation =>
      'This app is part of Android or comes from your phone\'s maker. Its extended permissions are normal for how it works.';

  @override
  String get detailSignature => 'Signature';

  @override
  String get detailGrantedPermissions => 'Granted permissions';

  @override
  String get detailNoPermissions => 'No permissions granted';

  @override
  String detailOtherPermissions(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'And $n other technical permissions',
      one: 'And 1 other technical permission',
    );
    return '$_temp0';
  }

  @override
  String get spywareTitle => 'Before you touch this app';

  @override
  String get spywareParagraph1 =>
      'If you think someone close to you installed this app, removing it may alert them. If you are in danger, first contact a support organization or the police.';

  @override
  String get spywareParagraph2 =>
      'Before acting, you can write down the app\'s name and take a screenshot: it can serve as evidence.';

  @override
  String get spywareParagraph3 =>
      'Sentinel doesn\'t alert anyone and sends no notification about this.';

  @override
  String get spywareGetHelp => 'Get help';

  @override
  String get spywareCoalition =>
      'Coalition Against Stalkerware: advice for people who are being monitored and contacts for support organizations.';

  @override
  String get spywareBrowserNote =>
      'The site opens in your browser and will stay in its history. You can also copy the address and open it in private browsing, or from another device.';

  @override
  String get spywareOpenSite => 'Open the website';

  @override
  String get spywareCopyAddress => 'Copy the address';

  @override
  String get spywareAddressCopied => 'Address copied';

  @override
  String get spywareIocCredit =>
      'Spyware list: Stalkerware Indicators project (Echap), CC BY 4.0 license.';

  @override
  String get permReadSms => 'Read your SMS';

  @override
  String get permReceiveSms => 'Receive your SMS';

  @override
  String get permSendSms => 'Send SMS (sometimes paid)';

  @override
  String get permReceiveMms => 'Receive MMS';

  @override
  String get permReadCallLog => 'See the call history';

  @override
  String get permWriteCallLog => 'Change the call history';

  @override
  String get permCallPhone => 'Make phone calls';

  @override
  String get permAnswerPhoneCalls => 'Answer phone calls';

  @override
  String get permReadPhoneState => 'See phone and call status';

  @override
  String get permReadPhoneNumbers => 'Know your phone number';

  @override
  String get permReadContacts => 'Read your contacts';

  @override
  String get permWriteContacts => 'Change your contacts';

  @override
  String get permGetAccounts => 'See the accounts saved on the phone';

  @override
  String get permReadCalendar => 'Read your calendar';

  @override
  String get permWriteCalendar => 'Change your calendar';

  @override
  String get permRecordAudio => 'Use the microphone';

  @override
  String get permCamera => 'Use the camera';

  @override
  String get permBodySensors => 'Read body sensors (heart rate…)';

  @override
  String get permBodySensorsBackground => 'Read body sensors in the background';

  @override
  String get permActivityRecognition => 'Detect your physical activity';

  @override
  String get permAccessFineLocation => 'Know your precise location';

  @override
  String get permAccessCoarseLocation => 'Know your approximate location';

  @override
  String get permAccessBackgroundLocation =>
      'Know your location even when the app is closed';

  @override
  String get permAccessMediaLocation => 'Read where your photos were taken';

  @override
  String get permReadExternalStorage => 'Read your files';

  @override
  String get permWriteExternalStorage => 'Change your files';

  @override
  String get permManageExternalStorage => 'Access all your files';

  @override
  String get permReadMediaImages => 'See your photos';

  @override
  String get permReadMediaVideo => 'See your videos';

  @override
  String get permReadMediaAudio => 'Access your audio files';

  @override
  String get permReadMediaVisualUserSelected => 'See the photos you choose';

  @override
  String get permBluetooth => 'Use Bluetooth';

  @override
  String get permBluetoothConnect => 'Connect to Bluetooth devices';

  @override
  String get permBluetoothScan => 'Search for Bluetooth devices';

  @override
  String get permNearbyWifiDevices => 'Find nearby Wi-Fi devices';

  @override
  String get permNfc => 'Use NFC (contactless payment…)';

  @override
  String get permInternet => 'Access the Internet';

  @override
  String get permAccessNetworkState => 'See the connection status';

  @override
  String get permAccessWifiState => 'See Wi-Fi networks';

  @override
  String get permChangeWifiState => 'Turn Wi-Fi on or off';

  @override
  String get permSystemAlertWindow => 'Appear on top of other apps';

  @override
  String get permPostNotifications => 'Show notifications';

  @override
  String get permRequestInstallPackages => 'Offer to install other apps';

  @override
  String get permRequestDeletePackages => 'Offer to uninstall apps';

  @override
  String get permQueryAllPackages => 'See the list of your apps';

  @override
  String get permPackageUsageStats => 'See which apps you use';

  @override
  String get permReceiveBootCompleted => 'Start when the phone starts';

  @override
  String get permForegroundService => 'Keep running in the background';

  @override
  String get permWakeLock => 'Prevent the phone from sleeping';

  @override
  String get permVibrate => 'Make the phone vibrate';

  @override
  String get permUseBiometric => 'Use fingerprint or face';

  @override
  String get permUseFingerprint => 'Use the fingerprint';

  @override
  String get permScheduleExactAlarm => 'Schedule exact alarms';

  @override
  String get permUseFullScreenIntent => 'Show full-screen alerts';

  @override
  String get firewallTitle => 'DNS firewall';

  @override
  String firewallOnBlocked(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'On · $n requests blocked',
      one: 'On · $n request blocked',
    );
    return '$_temp0';
  }

  @override
  String get categoryMalware => 'Malware and phishing';

  @override
  String get categoryImpersonation => 'Brand impersonation';

  @override
  String get categoryTrackers => 'Trackers';

  @override
  String get categoryAds => 'Ads';

  @override
  String get categoryOther => 'Other domains';

  @override
  String categoryBrandsWatched(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n brands watched · sites imitating them',
      one: '$n brand watched · sites imitating it',
    );
    return '$_temp0';
  }

  @override
  String domainsCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n domains',
      one: '$n domain',
    );
    return '$_temp0';
  }

  @override
  String get firewallListsBundled => 'Lists shipped with the app';

  @override
  String firewallLastUpdate(String date) {
    return 'Last update: $date';
  }

  @override
  String get firewallLastAttemptFailed => 'last attempt failed';

  @override
  String get analysisErrorFirewallOff => 'Turn on the DNS firewall first.';

  @override
  String get analysisErrorRunning => 'An analysis is already running.';

  @override
  String get analysisErrorUnknownApp => 'This app is no longer installed.';

  @override
  String get analysisErrorFailed => 'Couldn\'t start the analysis.';

  @override
  String durationMinutes(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n min',
    );
    return '$_temp0';
  }

  @override
  String durationMinutesLong(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n minutes',
      one: '$n minute',
    );
    return '$_temp0';
  }

  @override
  String durationSeconds(String n) {
    return '$n s';
  }

  @override
  String durationMinutesSeconds(String minutes, String seconds) {
    return '$minutes min $seconds s';
  }

  @override
  String durationMinutesOnly(String minutes) {
    return '$minutes min';
  }

  @override
  String get durationLessThanSecond => 'less than 1 s';

  @override
  String reportStoppedEarly(String duration, String planned) {
    return '$duration (stopped before the planned $planned)';
  }

  @override
  String reportNoDomain(String app) {
    return '$app contacted no domains during the analysis.';
  }

  @override
  String reportContacted(String app, String domains) {
    return '$app contacted $domains';
  }

  @override
  String reportNothingKnown(String start) {
    return '$start, none known as a tracker, ad or dangerous site.';
  }

  @override
  String reportIncluding(String start, String parts) {
    return '$start, including $parts.';
  }

  @override
  String reportDangerousCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n dangerous sites',
      one: '$n dangerous site',
    );
    return '$_temp0';
  }

  @override
  String reportTrackersCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n trackers',
      one: '$n tracker',
    );
    return '$_temp0';
  }

  @override
  String reportAdsCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n ads',
      one: '$n ad',
    );
    return '$_temp0';
  }

  @override
  String get listLastSeparator => ' and ';

  @override
  String get analysisLessThanMinuteLeft => 'Less than 1 min left';

  @override
  String analysisMinutesLeft(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n min left',
    );
    return '$_temp0';
  }

  @override
  String analysisDomainsSeen(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n domains seen',
      one: '$n domain seen',
    );
    return '$_temp0';
  }

  @override
  String get analysisSectionTitle => 'Analyze an app';

  @override
  String analysisRunning(String app) {
    return 'Analyzing $app';
  }

  @override
  String get analysisUnprotectedWarning =>
      'Other apps are not protected by the firewall until the analysis ends.';

  @override
  String get analysisStop => 'Stop the analysis';

  @override
  String get analysisIntroActive =>
      'Find out which sites an app contacts over a few minutes: trackers, ads, dangerous sites.';

  @override
  String get analysisIntroInactive => 'Turn on the firewall to analyze an app.';

  @override
  String get analysisChooseApp => 'Choose an app';

  @override
  String get analysisRecentReports => 'Reports from the last 24 hours';

  @override
  String get analysisScreenIntro =>
      'Choose the app to observe. For a few minutes, Sentinel records the sites (domains) it contacts.';

  @override
  String get analysisListFailed => 'Couldn\'t list the apps.';

  @override
  String get analysisNoApps => 'No apps to analyze.';

  @override
  String analysisSheetTitle(String app) {
    return 'Analyze $app';
  }

  @override
  String analysisSheetLine1(String duration, String app) {
    return 'For $duration, only requests from $app go through the firewall: every domain seen belongs to it.';
  }

  @override
  String get analysisSheetLine2 =>
      'Other apps are NOT protected during this time: no blocking, no alerts. Avoid opening unknown links.';

  @override
  String get analysisSheetLine3 =>
      'At the end, the normal firewall comes back on its own. You can stop earlier, from Sentinel or the notification.';

  @override
  String get analysisSheetLine4 =>
      'The report stays on this phone for 24 hours at most, then it is deleted. It is never sent.';

  @override
  String analysisSheetLine5(String app) {
    return '$app will open: use it as usual.';
  }

  @override
  String reportDateLine(String date, String duration) {
    return 'Analysis of $date · $duration';
  }

  @override
  String get reportDomainsContacted => 'Domains contacted';

  @override
  String get reportDangerousSites => 'Dangerous sites';

  @override
  String get reportTruncated =>
      'Incomplete list: the app contacted too many different domains.';

  @override
  String get reportSeeApp => 'See the app';

  @override
  String get reportDelete => 'Delete this report';

  @override
  String reportLocalOnly(String date) {
    return 'This report stays only on this phone until $date, then it is deleted automatically. It is never sent.';
  }

  @override
  String get reportApproximate =>
      'The number of requests is approximate: Android keeps some answers in memory for a few minutes.';

  @override
  String reportRequests(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n requests',
      one: '$n request',
    );
    return '$_temp0';
  }

  @override
  String reportImitates(String brand) {
    return 'Imitates $brand';
  }

  @override
  String get reportBlocked => 'Blocked';

  @override
  String get firewallIntro =>
      'Blocks dangerous sites and trackers before an app even connects to them. Everything happens on your phone.';

  @override
  String get firewallSinceActivation => 'Since activation';

  @override
  String get firewallQueriesAnalyzed => 'Requests analyzed';

  @override
  String get firewallQueriesBlocked => 'Requests blocked';

  @override
  String get firewallListsLoading => 'Loading lists…';

  @override
  String get firewallOneVpn =>
      'Android allows only one VPN at a time: if you turn on another one, the firewall stops.';

  @override
  String get firewallUpdated => 'Lists updated.';

  @override
  String get firewallUpdateFailed =>
      'Update failed: the current lists are kept.';

  @override
  String get firewallInvalidDomain =>
      'Invalid domain, for example: example.com';

  @override
  String get firewallDomainRefused =>
      'Domain refused (invalid format or list full)';

  @override
  String get firewallExplain1 =>
      'Android will ask you to allow a \"VPN connection\": this is how Sentinel sees the names of the requested sites.';

  @override
  String get firewallExplain2 =>
      'Only site name requests (DNS) go through Sentinel; the rest of your traffic does not change.';

  @override
  String get firewallExplain3 =>
      'Allowed sites are looked up with Quad9 (a Swiss resolver), encrypted: your network no longer sees the site names.';

  @override
  String get firewallExplain4 =>
      'No visited site is recorded: only counters exist (except during an app analysis that you start yourself).';

  @override
  String get firewallExplain5 =>
      'A discreet notification stays visible while the firewall is on.';

  @override
  String get firewallUpdateTitle => 'Updating the lists';

  @override
  String get firewallConsent1 =>
      'Sentinel downloads the blocklists from GitHub (raw.githubusercontent.com), over HTTPS, at most once a day.';

  @override
  String get firewallConsent2 =>
      'No information about you is sent: no visited sites, no identifier. As with any connection, GitHub sees your phone\'s IP address.';

  @override
  String get firewallConsent3 =>
      'Each list is checked (size, format, consistency) before use. If there is a problem, the previous version is kept.';

  @override
  String get blocklistCacheNote =>
      'Changes may take a few minutes to apply (browser DNS cache).';

  @override
  String get blocklistListsTitle => 'Blocklists';

  @override
  String get blocklistAdsWarning => 'May stop some apps from working.';

  @override
  String get blocklistImpersonationWarning =>
      'May block a real site that is not listed: if so, add it to the allowlist.';

  @override
  String get blocklistAutoUpdateTitle => 'Automatic updates';

  @override
  String get blocklistUpdateDaily => 'Update every day';

  @override
  String get blocklistUpdateNote =>
      'The lists are downloaded over HTTPS from GitHub, at most once a day. No information about you is sent.';

  @override
  String get blocklistUpdating => 'Updating…';

  @override
  String get blocklistUpdateNow => 'Update';

  @override
  String get allowlistTitle => 'Allowlist';

  @override
  String get allowlistIntro =>
      'These sites are never blocked, even if they appear in a list. Neither are their subdomains.';

  @override
  String get allowlistHint => 'example.com';

  @override
  String get allowlistAdd => 'Add';

  @override
  String get allowlistEmpty => 'No sites yet.';

  @override
  String allowlistRemove(String domain) {
    return 'Remove $domain';
  }

  @override
  String get sourcesTitle => 'Sources and licenses';

  @override
  String get sourcesSeeSource => 'See the source';

  @override
  String get upstreamIdle => 'Waiting for the first request';

  @override
  String get upstreamDot => 'Encrypted (DNS-over-TLS)';

  @override
  String get upstreamDoh => 'Encrypted (DNS-over-HTTPS)';

  @override
  String get upstreamPlain => 'Unencrypted: allowed on this network';

  @override
  String get upstreamFailing => 'Quad9 can\'t be reached with encryption';

  @override
  String get upstreamFailingHelp =>
      'This network blocks encrypted DNS: sites won\'t open. Sentinel never sends your requests unencrypted without your consent. If you trust this network, you can allow it below: the names of the sites you visit will then be visible on the network.';

  @override
  String get upstreamLabel => 'Requests to Quad9';

  @override
  String get upstreamAllowPlain => 'Allow unencrypted DNS on this network';

  @override
  String get dnsStrictTitle => 'Incompatible Private DNS';

  @override
  String dnsStrictMessage(String server) {
    return 'Your Private DNS is set to \"$server\" (strict mode). With the firewall, no site would open anymore. Choose \"Automatic\" in the settings: Sentinel already encrypts your DNS requests.';
  }

  @override
  String get dnsStrictOpenSettings => 'Open Private DNS settings';

  @override
  String get networkProtectionTitle => 'Network protection';

  @override
  String get vaultSettingsTitle => 'Vault settings';

  @override
  String get vaultLock => 'Lock';

  @override
  String get vaultEmptyTitle => 'Your passwords, encrypted';

  @override
  String get vaultEmptyMessage =>
      'Store your passwords and secret notes. They are encrypted on your phone and no one else can read them.';

  @override
  String get vaultCreate => 'Create my vault';

  @override
  String get vaultUnreadableTitle => 'Unreadable vault';

  @override
  String get vaultUnreadableMessage =>
      'The vault file seems damaged or modified. Sentinel cannot open it.';

  @override
  String get vaultCreateFailed => 'Creating the vault failed.';

  @override
  String get vaultCreateIntro =>
      'Choose a master password: it opens the vault and encrypts everything in it.';

  @override
  String get vaultCreateWarning =>
      'No one, not even Sentinel, can recover this password. You will then get a recovery key: write it down, it\'s the only way to open the vault if you forget it.';

  @override
  String get vaultMasterPassword => 'Master password';

  @override
  String get vaultConfirmation => 'Confirmation';

  @override
  String get vaultPasswordsDiffer => 'The two passwords don\'t match';

  @override
  String get vaultUnderstood =>
      'I understand that this password cannot be recovered';

  @override
  String get vaultCreating => 'Creating…';

  @override
  String get vaultRestoreBackup => 'Restore a backup';

  @override
  String get vaultFingerprintsChanged =>
      'The phone\'s fingerprints have changed. Open the vault with your password, then turn the fingerprint back on.';

  @override
  String get vaultTooManyTries => 'Too many attempts. Use your password.';

  @override
  String get vaultFingerprintFailed =>
      'The fingerprint couldn\'t open the vault. Use your password.';

  @override
  String get vaultWeeklyPassword =>
      'For your security, the master password is required at least once every 7 days.';

  @override
  String get vaultLockedTitle => 'Vault locked';

  @override
  String get vaultUseFingerprintOrPassword =>
      'Use your fingerprint or your master password.';

  @override
  String get vaultEnterMasterPassword => 'Enter your master password.';

  @override
  String get vaultOpenWithFingerprint => 'Open with fingerprint';

  @override
  String get vaultOrWithPassword => 'Or with the password:';

  @override
  String get vaultWrongPassword => 'Wrong password.';

  @override
  String vaultRetryIn(String seconds) {
    return 'Try again in $seconds s.';
  }

  @override
  String get vaultOpening => 'Opening…';

  @override
  String get vaultOpen => 'Open the vault';

  @override
  String get vaultForgotPassword => 'Forgot your password?';

  @override
  String get vaultSaveFailed => 'Saving failed.';

  @override
  String get vaultForgotTitle => 'Forgotten password';

  @override
  String get vaultKeyAccepted => 'Key accepted. Choose a new master password.';

  @override
  String get vaultEnterRecoveryKey =>
      'Enter the recovery key you wrote down when you created the vault. Dashes and lowercase letters are accepted.';

  @override
  String get vaultRecoveryKeyLabel => 'Recovery key';

  @override
  String get vaultWrongRecoveryKey => 'Wrong recovery key';

  @override
  String get vaultNewMasterPassword => 'New master password';

  @override
  String get vaultNewKeyWillBeCreated =>
      'A new recovery key will be created; the old one will no longer work.';

  @override
  String get vaultSaving => 'Saving…';

  @override
  String get vaultSave => 'Save';

  @override
  String vaultKeyCopied(String seconds) {
    return 'Key copied. It will be cleared from the clipboard in $seconds s.';
  }

  @override
  String get vaultYourRecoveryKey => 'Your recovery key';

  @override
  String get vaultWriteKeyDown =>
      'Write it on paper and keep it somewhere safe. It\'s the only way to open the vault if you forget your password.';

  @override
  String get vaultKeyShownOnce => 'It will never be shown again.';

  @override
  String get vaultCopy => 'Copy';

  @override
  String get vaultRetypeLast4 =>
      'To check that you wrote it down, type its last 4 characters again.';

  @override
  String get vaultLast4Label => 'Last 4 characters';

  @override
  String get vaultKeyNoted => 'I\'ve written down my key';

  @override
  String get vaultKeyCreateFailed => 'Creating the key failed.';

  @override
  String get vaultKeyOfferTitle => 'New: the recovery key';

  @override
  String get vaultKeyOfferText =>
      'If you forget your master password, a recovery key is the only way to open the vault. Create it now and write it down on paper.';

  @override
  String get vaultCreateKey => 'Create my key';

  @override
  String get backupEmpty => 'This file is empty.';

  @override
  String get backupUnreadable =>
      'This file is not a Sentinel backup, or it is damaged.';

  @override
  String get backupNewerVersion =>
      'This backup comes from a newer version of Sentinel. Update the app, then try again.';

  @override
  String get backupTooBig => 'This file is too large to be a Sentinel backup.';

  @override
  String get backupCannotReadFile => 'Can\'t read this file.';

  @override
  String get backupWrongPassword =>
      'Wrong password, or the file was modified after the export.';

  @override
  String get backupCannotRead => 'Can\'t read this backup.';

  @override
  String get backupRestoreFailed => 'Restoring failed.';

  @override
  String get backupIntroFile =>
      'Choose the .sentinel file created with \"Export an encrypted backup\" on your old phone.';

  @override
  String get backupIntroPassword =>
      'Enter the password you chose when exporting.';

  @override
  String backupIntroNewPassword(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n items',
      one: '$n item',
    );
    return 'Backup opened: $_temp0. Choose the master password for this phone.';
  }

  @override
  String get backupPasswordLabel => 'Backup password';

  @override
  String get backupNewKeyNote =>
      'A new recovery key will be created for this phone.';

  @override
  String get backupChooseFile => 'Choose the file';

  @override
  String get backupRestoring => 'Restoring…';

  @override
  String get backupRestore => 'Restore';

  @override
  String get vaultAdd => 'Add';

  @override
  String get vaultEmptyList =>
      'Your vault is empty. Add a first password or a secret note.';

  @override
  String get vaultNoResults => 'No results.';

  @override
  String get vaultHealthTitle => 'Password health';

  @override
  String get vaultAllGood => 'All good';

  @override
  String vaultToFix(String count) {
    return '$count to fix';
  }

  @override
  String get vaultSearch => 'Search';

  @override
  String get vaultTypePassword => 'Password';

  @override
  String get vaultTypeNote => 'Secret note';

  @override
  String vaultPasswordCopied(String seconds) {
    return 'Password copied. It will be cleared from the clipboard in $seconds s.';
  }

  @override
  String get vaultNeedTitle => 'Give this item a title.';

  @override
  String vaultDeleteItemTitle(String title) {
    return 'Delete \"$title\"?';
  }

  @override
  String get vaultDeleteItemText =>
      'This item will be permanently erased from the vault.';

  @override
  String get vaultDelete => 'Delete';

  @override
  String get vaultNewPassword => 'New password';

  @override
  String get vaultNewNote => 'New secret note';

  @override
  String get vaultFieldTitle => 'Title';

  @override
  String get vaultFieldNote => 'Note';

  @override
  String get vaultFieldUsername => 'Username';

  @override
  String get vaultFieldWebsite => 'Website';

  @override
  String get vaultHideGenerator => 'Hide the generator';

  @override
  String get vaultGenerate => 'Generate';

  @override
  String generatorLength(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Length: $n characters',
      one: 'Length: $n character',
    );
    return '$_temp0';
  }

  @override
  String get generatorUppercase => 'Uppercase (A-Z)';

  @override
  String get generatorDigits => 'Digits (0-9)';

  @override
  String get generatorSymbols => 'Symbols (!#\$…)';

  @override
  String get generatorNewPassword => 'New password';

  @override
  String healthToFix(String count) {
    return '$count to fix. Tap an item to change its password.';
  }

  @override
  String get healthBreached => 'Found in leaks';

  @override
  String get healthNoBreach => 'No password found in a leak.';

  @override
  String get healthReused => 'Used more than once';

  @override
  String get healthAllUnique => 'Every password is unique.';

  @override
  String healthAlsoUsedFor(String titles) {
    return 'Also used for: $titles';
  }

  @override
  String get healthWeak => 'Too weak';

  @override
  String get healthNoWeak => 'No password is too weak.';

  @override
  String get healthEasyToGuess => 'Easy to guess';

  @override
  String get healthCheckIntro =>
      'Check whether your passwords appear in known leaks (Have I Been Pwned).';

  @override
  String get healthCheckButton => 'Check for leaks';

  @override
  String healthChecking(String done, String total) {
    return 'Checking… $done / $total';
  }

  @override
  String get healthRetry => 'Try again';

  @override
  String breachMessage(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'This password has been seen $n times in data leaks. Change it.',
      one: 'This password has been seen once in data leaks. Change it.',
    );
    return '$_temp0';
  }

  @override
  String breachShort(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Seen $n times in leaks',
      one: 'Seen once in leaks',
    );
    return '$_temp0';
  }

  @override
  String get breachConsentTitle => 'Check for leaks?';

  @override
  String get breachConsentText =>
      'Sentinel only sends the first 5 characters of a hash of each password to Have I Been Pwned. Your password never leaves the phone.';

  @override
  String get breachConsentDetail =>
      'The service replies with a list of known leaks, and the comparison happens on your phone. You can withdraw this consent in the vault settings.';

  @override
  String get breachConsentCheck => 'Check';

  @override
  String get breachErrorTimeout =>
      'The service is not responding. Try again later.';

  @override
  String get breachErrorOffline =>
      'No Internet connection. Check Wi-Fi or mobile data.';

  @override
  String get breachErrorTooMany => 'Too many requests. Try again in a moment.';

  @override
  String breachErrorUnavailable(String code) {
    return 'The Have I Been Pwned service is unavailable (error $code).';
  }

  @override
  String get clipboardSharedTitle => 'Shared clipboard';

  @override
  String get clipboardSharedWarning =>
      'On this version of Android, all apps can read what you copy. The clipboard will be cleared after 10 seconds.';

  @override
  String get clipboardCopyAnyway => 'Copy anyway';

  @override
  String get fieldShow => 'Show';

  @override
  String get fieldHide => 'Hide';

  @override
  String get strengthWeak => 'weak';

  @override
  String get strengthMedium => 'medium';

  @override
  String get strengthStrong => 'strong';

  @override
  String strengthLine(String strength) {
    return 'Strength: $strength';
  }

  @override
  String strengthLineTooShort(String strength, String length, String min) {
    return 'Strength: $strength · $length / $min characters minimum';
  }

  @override
  String get vaultFingerprintEnabled => 'Fingerprint unlock turned on.';

  @override
  String get vaultBiometricTooManyTries =>
      'Too many attempts. Try again in a few moments.';

  @override
  String get vaultNoFingerprint =>
      'No fingerprint is registered on this phone.';

  @override
  String get vaultFingerprintActivationFailed =>
      'Turning on the fingerprint failed.';

  @override
  String get vaultNewKeyTitle => 'New recovery key?';

  @override
  String get vaultNewKeyText =>
      'The old key will no longer work. Remember to write down the new one.';

  @override
  String get vaultDeleteFailed => 'Deleting failed.';

  @override
  String get vaultFingerprintWeekly =>
      'The password is still required at least once every 7 days.';

  @override
  String get vaultBreachSettingDetail =>
      'Have I Been Pwned. Only the start of a hash is sent, never the password.';

  @override
  String get vaultChangeMaster => 'Change the master password';

  @override
  String get vaultNewRecoveryKey => 'Generate a new recovery key';

  @override
  String get vaultExport => 'Export an encrypted backup';

  @override
  String get vaultDeleteVault => 'Delete the vault';

  @override
  String get vaultDeleteVaultTitle => 'Delete the vault?';

  @override
  String vaultDeleteVaultText(String word) {
    return 'All passwords and notes will be permanently erased. Type $word to confirm.';
  }

  @override
  String get vaultDeleteWord => 'DELETE';

  @override
  String get vaultMasterChanged => 'Master password changed.';

  @override
  String get vaultCurrentPassword => 'Current password';

  @override
  String get vaultWrongPasswordShort => 'Wrong password';

  @override
  String get vaultChange => 'Change';

  @override
  String get exportSaved => 'Backup saved. Keep its password somewhere safe.';

  @override
  String get exportCancelled => 'Export cancelled.';

  @override
  String get exportFileFailed => 'Saving the file failed.';

  @override
  String get exportFailed => 'The export failed.';

  @override
  String get exportIntro =>
      'To move to a new phone: a .sentinel file, encrypted with the password chosen here. Without this password, no one can read it, not even Sentinel.';

  @override
  String get exportStore =>
      'Store the file wherever you like (Drive, USB stick, computer) and don\'t lose it or its password.';

  @override
  String get exportPasswordLabel => 'Export password';

  @override
  String get exportEncrypting => 'Encrypting…';

  @override
  String get exportButton => 'Export';

  @override
  String get qrScanButton => 'Scan a QR code';

  @override
  String get qrScanSubtitle =>
      'Check a QR code (poster, parking meter, parcel) before opening it';

  @override
  String get qrScanPrompt =>
      'Place the QR code inside the frame. Nothing opens on its own.';

  @override
  String get qrCameraTitle => 'Allow the camera?';

  @override
  String get qrCameraText =>
      'Sentinel only uses the camera during the scan, to read the QR code. The image is neither saved nor sent: everything stays on the phone.';

  @override
  String get qrOpenSettings => 'Settings';

  @override
  String get qrErrorNoCamera => 'No camera available on this phone.';

  @override
  String get qrErrorPermissionDenied =>
      'Without the camera, Sentinel cannot read the QR code.';

  @override
  String get qrErrorPermissionBlocked =>
      'Camera access is denied for Sentinel. Allow it in the Android settings.';

  @override
  String get qrErrorFailed => 'The scan failed. Try again.';

  @override
  String get qrResultTitle => 'Scanned QR code';

  @override
  String get qrRawContent => 'Raw content';

  @override
  String get qrEmpty => '(empty QR code)';

  @override
  String get qrKindLink => 'Link';

  @override
  String get qrKindUnsafeLink => 'Dangerous type of link';

  @override
  String get qrKindWifi => 'Wi-Fi network';

  @override
  String get qrKindPhone => 'Phone number';

  @override
  String get qrKindSms => 'Text message to send';

  @override
  String get qrKindPayment => 'Payment request';

  @override
  String get qrKindText => 'Text';

  @override
  String get qrWifiName => 'Network';

  @override
  String get qrWifiSecurity => 'Protection';

  @override
  String get qrWifiPassword => 'Password';

  @override
  String get qrWifiPasswordYes => 'Included in the QR code';

  @override
  String get qrWifiPasswordNo => 'None';

  @override
  String get qrPhoneNumber => 'Number';

  @override
  String get qrSmsRecipient => 'Recipient';

  @override
  String get qrSmsText => 'Message text';

  @override
  String get qrPaymentRecipient => 'Payee';

  @override
  String get qrPaymentAmount => 'Amount';

  @override
  String get qrNotSpecified => 'Not specified';

  @override
  String get qrWarningUnsafeLink =>
      'This QR code contains a link that can run code or open a file, not a web page. Sentinel will not open it.';

  @override
  String get qrWarningUssd =>
      'The number contains * or #: it is a code that can change phone settings (call forwarding, wiping). Do not dial it.';

  @override
  String get qrWarningShortNumber =>
      'Short number: a text to this kind of number may be charged extra or subscribe you to a paid service.';

  @override
  String get qrWarningPayment =>
      'Fake payment QR codes are often stuck over real ones (parking meters, posters). Check the payee and the amount before paying.';

  @override
  String get qrWarningWifiOpen =>
      'Open network: without a password, anything sent unencrypted can be read by others.';

  @override
  String get qrWarningWifiWep =>
      'WEP protection: it can be broken in a few minutes.';

  @override
  String get qrActionOpenLink => 'Open the link';

  @override
  String get qrActionOpenAnyway => 'Open anyway';

  @override
  String get qrActionCall => 'Call this number';

  @override
  String get qrActionSms => 'Prepare the text message';

  @override
  String get qrActionPayment => 'Open in a payment app';

  @override
  String get qrActionBlocked => 'Blocked by Sentinel: likely scam.';

  @override
  String get qrActionFailed =>
      'Cannot open: no compatible app, or content refused.';

  @override
  String qrConfirmLink(String url) {
    return 'Do not enter any code or password if the page asks for one. Link that will open in your browser: $url';
  }

  @override
  String qrConfirmCall(String number) {
    return 'The phone opens the call screen with $number. The call only starts if you press Call.';
  }

  @override
  String qrConfirmSms(String number) {
    return 'Your messaging app opens with a message to $number. Nothing is sent until you press Send.';
  }

  @override
  String qrConfirmPayment(String recipient) {
    return 'A payment app will open for: $recipient. Check the payee and the amount before confirming.';
  }
}
