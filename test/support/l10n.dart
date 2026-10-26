import 'package:material_ui/material_ui.dart';
import 'package:sentinel/l10n/l10n.dart';

/// Textes de l'app dans chaque langue, pour les tests sans écran.
final fr = l10nFor('fr');
final en = l10nFor('en');
final ar = l10nFor('ar');

/// Comme MaterialApp(home: …), avec les traductions (français par défaut).
/// [theme] : AppTheme.dark pour vérifier un écran en sombre.
Widget testApp({
  required Widget home,
  Locale locale = const Locale('fr'),
  ThemeData? theme,
}) => MaterialApp(
  theme: theme,
  locale: locale,
  supportedLocales: appSupportedLocales,
  localizationsDelegates: appLocalizationsDelegates,
  home: home,
);
