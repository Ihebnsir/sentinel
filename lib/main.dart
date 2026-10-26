import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

import 'l10n/l10n.dart';
import 'screens/main_shell.dart';
import 'screens/startup_gate.dart';
import 'services/language_store.dart';
import 'services/onboarding_store.dart';
import 'theme/app_theme.dart';

// Le point d'entrée d'arrière-plan doit être relié à main.dart, sinon
// le compilateur (mode release) ne l'inclut pas dans l'app.
export 'background/background_analyzer.dart' show backgroundAnalyzerMain;

// Point d'entrée : Flutter démarre l'app ici.
Future<void> main() async {
  LicenseRegistry.addLicense(readexProLicense);
  LicenseRegistry.addLicense(blocklistsLicense);
  LicenseRegistry.addLicense(stalkerwareLicense);
  LicenseRegistry.addLicense(zxingLicense);
  WidgetsFlutterBinding.ensureInitialized();
  // Noms des mois en anglais et en arabe (données dans l'app).
  await initializeDateFormatting();
  // Langue choisie dans Réglages, lue avant le premier écran.
  final language = LanguageController();
  await language.load();
  runApp(SentinelApp(language: language));
}

/// Licence OFL de la police embarquée (lue seulement si on l'affiche).
Stream<LicenseEntry> readexProLicense() async* {
  final text = await rootBundle.loadString('assets/fonts/ReadexPro-OFL.txt');
  yield LicenseEntryWithLineBreaks(['Readex Pro'], text);
}

/// Licences des listes du pare-feu DNS (un seul fichier pour toutes).
Stream<LicenseEntry> blocklistsLicense() async* {
  final text = await rootBundle.loadString('assets/blocklists/LICENSES.txt');
  yield LicenseEntryWithLineBreaks([
    // Sans mot français : la page des licences n'a pas de traduction.
    'Phishing.Database, AdGuard, AdAway, ShadowWhisperer',
  ], text);
}

/// Mention CC BY 4.0 de la liste de logiciels espions (lue dans le JSON).
Stream<LicenseEntry> stalkerwareLicense() async* {
  final json = jsonDecode(
    await rootBundle.loadString('assets/data/stalkerware_ioc.json'),
  );
  yield LicenseEntryWithLineBreaks([
    'Stalkerware Indicators (Echap)',
  ], '${json['attribution']}\n\n${json['license']} : ${json['licenseUrl']}');
}

/// Lecteur de QR code côté Android (Kotlin), absent des licences Dart.
Stream<LicenseEntry> zxingLicense() async* {
  yield const LicenseEntryWithLineBreaks(
    ['ZXing (zxing-android-embedded 4.3.0, core 3.5.3)'],
    'Copyright (C) 2008 ZXing authors, Copyright (C) 2012-2021 JourneyApps.\n\n'
    'Licensed under the Apache License, Version 2.0. '
    'You may obtain a copy of the License at '
    'https://www.apache.org/licenses/LICENSE-2.0\n\n'
    'Unless required by applicable law or agreed to in writing, software '
    'distributed under the License is distributed on an "AS IS" BASIS, '
    'WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND.',
  );
}

/// Le widget racine : il configure le thème, la langue et l'écran de départ.
class SentinelApp extends StatelessWidget {
  SentinelApp({
    super.key,
    OnboardingStore? onboardingStore,
    LanguageController? language,
  }) : onboardingStore = onboardingStore ?? OnboardingStore(),
       language = language ?? LanguageController();

  final OnboardingStore onboardingStore;

  /// Langue choisie (null : celle du téléphone, sinon le français).
  final LanguageController language;

  @override
  Widget build(BuildContext context) {
    // Au-dessus de MaterialApp : Réglages peut changer la langue.
    return LanguageScope(
      controller: language,
      child: ValueListenableBuilder<Locale?>(
        valueListenable: language,
        builder: (context, locale, _) => MaterialApp(
          onGenerateTitle: (context) => context.l10n.appTitle,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          locale: locale,
          supportedLocales: appSupportedLocales,
          localizationsDelegates: appLocalizationsDelegates,
          // Présentation au premier lancement, puis l'app.
          home: StartupGate(store: onboardingStore, home: const MainShell()),
        ),
      ),
    );
  }
}
