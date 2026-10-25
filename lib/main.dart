import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'screens/main_shell.dart';
import 'screens/startup_gate.dart';
import 'services/onboarding_store.dart';
import 'theme/app_theme.dart';

// Le point d'entrée d'arrière-plan doit être relié à main.dart, sinon
// le compilateur (mode release) ne l'inclut pas dans l'app.
export 'background/background_analyzer.dart' show backgroundAnalyzerMain;

// Point d'entrée : Flutter démarre l'app ici.
void main() {
  LicenseRegistry.addLicense(readexProLicense);
  LicenseRegistry.addLicense(blocklistsLicense);
  LicenseRegistry.addLicense(stalkerwareLicense);
  runApp(SentinelApp());
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
    'Listes de blocage (Phishing.Database, AdGuard, AdAway, ShadowWhisperer)',
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

/// Le widget racine : il configure le thème et l'écran de départ.
class SentinelApp extends StatelessWidget {
  SentinelApp({super.key, OnboardingStore? onboardingStore})
    : onboardingStore = onboardingStore ?? OnboardingStore();

  final OnboardingStore onboardingStore;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sentinel',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // Présentation au premier lancement, puis l'app.
      home: StartupGate(store: onboardingStore, home: const MainShell()),
    );
  }
}
