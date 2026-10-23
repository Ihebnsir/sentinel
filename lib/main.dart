import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'screens/main_shell.dart';
import 'theme/app_theme.dart';

// Le point d'entrée d'arrière-plan doit être relié à main.dart, sinon
// le compilateur (mode release) ne l'inclut pas dans l'app.
export 'background/background_analyzer.dart' show backgroundAnalyzerMain;

// Point d'entrée : Flutter démarre l'app ici.
void main() {
  LicenseRegistry.addLicense(readexProLicense);
  runApp(const SentinelApp());
}

/// Licence OFL de la police embarquée (lue seulement si on l'affiche).
Stream<LicenseEntry> readexProLicense() async* {
  final text = await rootBundle.loadString('assets/fonts/ReadexPro-OFL.txt');
  yield LicenseEntryWithLineBreaks(['Readex Pro'], text);
}

/// Le widget racine : il configure le thème et l'écran de départ.
class SentinelApp extends StatelessWidget {
  const SentinelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sentinel',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const MainShell(),
    );
  }
}
