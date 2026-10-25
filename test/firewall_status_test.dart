import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel/services/firewall_service.dart';
import 'support/l10n.dart';

void main() {
  group('FirewallStatus.fromMap', () {
    test('lit la Map envoyée par FirewallChannel.kt', () {
      final status = FirewallStatus.fromMap({
        'active': true,
        'totalQueries': 1520,
        'blockedQueries': 37,
      });
      expect(status.active, isTrue);
      expect(status.totalQueries, 1520);
      expect(status.blockedQueries, 37);
    });

    test('valeurs absentes ou invalides : inactif, compteurs à zéro', () {
      final status = FirewallStatus.fromMap({'totalQueries': 'x'});
      expect(status.active, isFalse);
      expect(status.totalQueries, 0);
      expect(status.blockedQueries, 0);
    });
  });

  group('FirewallStatus.summary(fr)', () {
    FirewallStatus status(bool active, int blocked) => FirewallStatus(
      active: active,
      totalQueries: 5000,
      blockedQueries: blocked,
    );

    test('désactivé', () {
      expect(status(false, 12).summary(fr), 'Désactivé');
    });

    test('singulier pour 0 et 1, pluriel au-delà', () {
      expect(status(true, 0).summary(fr), 'Activé · 0 requête bloquée');
      expect(status(true, 1).summary(fr), 'Activé · 1 requête bloquée');
      // Espace insécable entre les milliers.
      expect(status(true, 1234).summary(fr), 'Activé · 1 234 requêtes bloquées');
    });
  });
}
