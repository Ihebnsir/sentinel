import 'package:material_ui/material_ui.dart';

import '../models/security_action.dart';
import '../theme/app_colors.dart';
import '../widgets/action_tile.dart';
import '../widgets/score_arch.dart';

/// L'écran d'accueil : salutation, score et actions conseillées.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // Score de démonstration (plus tard, il sera calculé par l'app).
  static const _score = 72;

  // Les actions proposées pour gagner des points.
  static const _actions = [
    SecurityAction(
      icon: Icons.fingerprint,
      title: 'Activer le déverrouillage biométrique',
      description: 'Empreinte ou visage pour ouvrir le téléphone',
      points: 12,
    ),
    SecurityAction(
      icon: Icons.system_update_outlined,
      title: 'Installer la mise à jour Android',
      description: 'Elle corrige 3 failles de sécurité connues',
      points: 9,
    ),
    SecurityAction(
      icon: Icons.wifi_lock_outlined,
      title: 'Vérifier le réseau Wi-Fi',
      description: "Le réseau actuel n'est pas chiffré",
      points: 7,
    ),
  ];

  /// Titre principal selon le score.
  String _titleFor(int score) {
    if (score >= 70) return 'Votre téléphone est bien protégé';
    if (score >= 45) return 'Quelques points à renforcer';
    return 'Votre téléphone est exposé';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        // SingleChildScrollView permet de faire défiler l'écran
        // si le contenu est plus haut que le téléphone.
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bonjour, Iheb',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.encre.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _titleFor(_score),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: AppColors.encre,
                ),
              ),
              const SizedBox(height: 40),
              const Center(child: ScoreArch(score: _score)),
              const SizedBox(height: 40),
              const Text(
                'Pour gagner des points',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.encre,
                ),
              ),
              const SizedBox(height: 8),
              // Boucle for dans la liste : on crée une ligne par action,
              // avec un séparateur fin entre deux lignes (pas avant la première).
              for (var i = 0; i < _actions.length; i++) ...[
                if (i > 0)
                  const Divider(height: 1, thickness: 1, color: AppColors.ligne),
                ActionTile(action: _actions[i]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
