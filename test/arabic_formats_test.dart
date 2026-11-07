import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sentinel/l10n/l10n.dart';
import 'package:sentinel/models/security_action.dart';
import 'package:sentinel/utils/maghreb_format.dart';
import 'package:sentinel/widgets/action_tile.dart';

import 'support/l10n.dart';

// Aucun chiffre arabe-indien (٠١٢… ou ۰۱۲…).
final _easternDigit = RegExp('[٠-٩۰-۹]');

/// Abscisse gauche du caractère [index] dans le texte affiché.
double _charLeft(WidgetTester tester, Finder text, int index) {
  final paragraph = tester.renderObject<RenderParagraph>(text);
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: index, extentOffset: index + 1),
  );
  return boxes.first.left;
}

void main() {
  // Données de dates de l'anglais (chargées par main.dart dans l'app).
  setUpAll(initializeDateFormatting);

  group('chiffres occidentaux en arabe', () {
    test('dates, heures et nombres', () {
      final date = DateTime(2026, 9, 5, 14, 5);
      expect(ar.date(date), '5 سبتمبر 2026');
      expect(ar.time(date), '14:05');
      expect(ar.dateTime(date), '5 سبتمبر 2026 على الساعة 14:05');
      expect(ar.number(3861), '3,861');
      for (final text in [
        ar.date(date),
        ar.dateTime(date),
        ar.number(1234567),
      ]) {
        expect(text.contains(_easternDigit), isFalse, reason: text);
      }
    });

    test('conversion des chiffres arabes-indiens', () {
      expect(westernDigits('٥ سبتمبر ٢٠٢٦'), '5 سبتمبر 2026');
      expect(westernDigits('۰۱۲۳۴۵۶۷۸۹'), '0123456789');
      expect(westernDigits('abc 42'), 'abc 42');
    });
  });

  test('mois tunisiens pour toute l\'année', () {
    const months = [
      'جانفي', 'فيفري', 'مارس', 'أفريل', 'ماي', 'جوان', //
      'جويلية', 'أوت', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
    ];
    for (var m = 1; m <= 12; m++) {
      expect(ar.date(DateTime(2026, m, 1)), '1 ${months[m - 1]} 2026');
    }
    // Plus de noms du Machrek.
    expect(ar.date(DateTime(2026, 1, 1)).contains('يناير'), isFalse);
    expect(ar.date(DateTime(2026, 8, 1)).contains('أغسطس'), isFalse);
  });

  test('français et anglais inchangés', () {
    final date = DateTime(2026, 8, 5, 14, 5);
    expect(fr.date(date), '5 août 2026');
    expect(fr.time(date), '14 h 05');
    expect(en.date(date), 'August 5, 2026');
    expect(en.number(3861), '3,861');
  });

  group('nombres dans un texte de droite à gauche', () {
    testWidgets('« +10 » garde le signe à gauche', (tester) async {
      await tester.pumpWidget(
        testApp(
          locale: const Locale('ar'),
          home: Scaffold(
            body: ActionTile(
              action: SecurityAction(
                icon: Icons.usb,
                title: ar.scoreLockTitle,
                description: ar.scoreDevOptionsDesc,
                points: 10,
              ),
            ),
          ),
        ),
      );
      final points = find.text('+10');
      expect(points, findsOneWidget);
      // « + » avant « 1 » à l'écran, pas « 10+ ».
      expect(
        _charLeft(tester, points, 0),
        lessThan(_charLeft(tester, points, 1)),
      );
    });

    testWidgets('pourcentage et durée lisibles', (tester) async {
      final percent = ar.messagesProbability('87');
      final duration = ar.durationMinutesSeconds('3', '20');
      await tester.pumpWidget(
        testApp(
          locale: const Locale('ar'),
          home: Scaffold(
            body: Column(children: [Text(percent), Text(duration)]),
          ),
        ),
      );
      // « 87% » : le 8 avant le 7, puis le signe % à droite.
      final p = find.text(percent);
      final eight = percent.indexOf('8');
      expect(
        _charLeft(tester, p, eight),
        lessThan(_charLeft(tester, p, eight + 1)),
      );
      expect(
        _charLeft(tester, p, eight + 1),
        lessThan(_charLeft(tester, p, percent.indexOf('%'))),
      );
      // « 20 » reste « 20 » (pas « 02 »).
      final d = find.text(duration);
      final two = duration.indexOf('2');
      expect(
        _charLeft(tester, d, two),
        lessThan(_charLeft(tester, d, two + 1)),
      );
    });
  });
}
