import 'package:cupertino_ui/cupertino_ui.dart'
    show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../utils/french_date.dart';
import '../utils/french_number.dart';
import 'app_localizations.dart';

export 'app_localizations.dart';

/// Les langues de l'app. Le français d'abord : c'est la langue choisie
/// quand celle du téléphone n'est pas proposée.
const appSupportedLocales = [Locale('fr'), Locale('ar'), Locale('en')];

/// Textes de l'app, puis ceux de material_ui (pas ceux de
/// flutter_localizations : autre type) et le sens d'écriture (RTL).
const appLocalizationsDelegates = <LocalizationsDelegate<Object>>[
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
];

/// Textes hors écran (arrière-plan, tests) : langue proposée, sinon français.
AppLocalizations l10nFor(String? languageCode) => lookupAppLocalizations(
  appSupportedLocales.firstWhere(
    (l) => l.languageCode == languageCode,
    orElse: () => appSupportedLocales.first,
  ),
);

/// Raccourci : `context.l10n.homeTitle`.
extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Nombres et dates dans la langue des textes.
/// Le français garde ses formats maison (« 1er mars », « 14 h 05 »).
extension AppFormats on AppLocalizations {
  bool get _fr => localeName == 'fr';

  /// « 3 861 » en français, « 3,861 » en anglais et en arabe.
  String number(int value) => _fr
      ? formatFrenchNumber(value)
      : NumberFormat.decimalPattern(localeName).format(value);

  /// « 5 août 2026 », « August 5, 2026 », « 5 أغسطس 2026 ».
  String date(DateTime date) =>
      _fr ? formatFrenchDate(date) : _format(DateFormat.yMMMMd, date);

  /// « 14 h 05 », « 2:05 PM ».
  String time(DateTime date) => _fr
      ? '${date.hour} h ${date.minute.toString().padLeft(2, '0')}'
      : _format(DateFormat.jm, date);

  /// « 19 octobre 2026 à 14 h 05 ».
  String dateTime(DateTime date) =>
      commonDateAtTime(this.date(date), time(date));

  // Données de dates absentes (rare : chargées par les délégués) :
  // format numérique, toujours lisible.
  String _format(DateFormat Function(String) pattern, DateTime date) {
    try {
      return pattern(localeName).format(date);
    } on Object {
      return DateFormat('y-MM-dd HH:mm').format(date);
    }
  }
}
