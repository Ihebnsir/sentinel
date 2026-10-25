import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sentinel/screens/firewall_screen.dart';
import 'package:sentinel/services/firewall_service.dart';
import 'package:sentinel/widgets/dns_privacy_section.dart';
import 'support/l10n.dart';

// SEN-10 (DNS chiffré, jamais de clair sans accord) et SEN-11 (DNS privé strict).
void main() {
  group('FirewallStatus.fromMap', () {
    test('lit le transport, l\'accord et le DNS privé strict', () {
      final status = FirewallStatus.fromMap({
        'active': true,
        'upstream': 'dot',
        'plainDnsAllowed': false,
        'strictPrivateDns': 'dns.google',
      });
      expect(status.upstream, UpstreamMode.dot);
      expect(status.plainDnsAllowed, isFalse);
      expect(status.strictPrivateDns, 'dns.google');
    });

    test('valeurs absentes : en attente, pas d\'accord, pas de mode strict', () {
      final status = FirewallStatus.fromMap({'upstream': 'inconnu'});
      expect(status.upstream, UpstreamMode.idle);
      expect(status.plainDnsAllowed, isFalse);
      expect(status.strictPrivateDns, isNull);
    });
  });

  group('UpstreamSection', () {
    Future<void> show(
      WidgetTester tester,
      UpstreamMode mode, {
      bool allowed = false,
      ValueChanged<bool>? onChanged,
    }) => tester.pumpWidget(
      testApp(
        home: Scaffold(
          body: UpstreamSection(
            mode: mode,
            plainAllowed: allowed,
            onPlainChanged: onChanged ?? (_) {},
          ),
        ),
      ),
    );

    testWidgets('chiffré : état affiché, aucun interrupteur', (tester) async {
      await show(tester, UpstreamMode.dot);
      expect(find.text('Chiffré (DNS-over-TLS)'), findsOneWidget);
      expect(find.byType(Switch), findsNothing);
      await show(tester, UpstreamMode.doh);
      expect(find.text('Chiffré (DNS-over-HTTPS)'), findsOneWidget);
      expect(find.byType(Switch), findsNothing);
    });

    testWidgets('échec : explication et accord désactivé par défaut', (
      tester,
    ) async {
      final changes = <bool>[];
      await show(tester, UpstreamMode.failing, onChanged: changes.add);
      expect(find.text(fr.upstreamFailingHelp), findsOneWidget);
      expect(
        find.text('Autoriser le DNS non chiffré sur ce réseau'),
        findsOneWidget,
      );
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      await tester.tap(find.byType(Switch));
      expect(changes, [true]);
    });

    testWidgets('clair autorisé : signalé, interrupteur pour revenir', (
      tester,
    ) async {
      await show(tester, UpstreamMode.plain, allowed: true);
      expect(find.text('Non chiffré : autorisé sur ce réseau'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    });
  });

  group('FirewallScreen avec un DNS privé strict', () {
    final calls = <String>[];

    setUp(() {
      calls.clear();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('com.iheb.sentinel/firewall'),
        (call) async {
          calls.add(call.method);
          return switch (call.method) {
            'status' => {
              'active': false,
              'strictPrivateDns': 'dns.google',
            },
            'reports' => <Object?>[],
            _ => null,
          };
        },
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('com.iheb.sentinel/wifi'),
        (call) async {
          calls.add('wifi:${call.method}');
          return null;
        },
      );
    });

    testWidgets('avertit, refuse d\'activer et propose les réglages', (
      tester,
    ) async {
      await tester.pumpWidget(testApp(home: FirewallScreen()));
      await tester.pumpAndSettle();

      // Avertissement visible avant même l'activation.
      expect(find.text(fr.dnsStrictMessage('dns.google')), findsOneWidget);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Ouvrir les réglages'));
      await tester.pumpAndSettle();

      expect(calls, contains('wifi:openPrivateDnsSettings'));
      expect(calls, isNot(contains('prepare'))); // pas d'activation
      expect(calls, isNot(contains('start')));

      await tester.pumpWidget(const SizedBox()); // arrête le minuteur
    });
  });
}
