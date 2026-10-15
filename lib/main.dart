import 'package:material_ui/material_ui.dart';

import 'screens/main_shell.dart';
import 'theme/app_theme.dart';

// Le point d'entrée d'arrière-plan doit être relié à main.dart, sinon
// le compilateur (mode release) ne l'inclut pas dans l'app.
export 'background/background_analyzer.dart' show backgroundAnalyzerMain;

// Point d'entrée : Flutter démarre l'app ici.
void main() {
  runApp(const SentinelApp());
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
