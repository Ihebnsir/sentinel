import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../widgets/arch_icon.dart';

/// Une page de la présentation : titre et paragraphes courts.
class OnboardingPage {
  const OnboardingPage({required this.title, required this.lines});

  final String title;
  final List<String> lines;
}

/// Les 3 pages : ce que fait Sentinel, la vie privée, les autorisations.
/// La liste des appels réseau doit rester celle de la politique de
/// confidentialité (privacy_policy_screen.dart).
const onboardingPages = [
  OnboardingPage(
    title: 'Sentinel veille sur votre téléphone',
    lines: [
      'Un score de sécurité et les réglages à corriger.',
      'Les applications suspectes : fausses apps, logiciels espions.',
      "Les messages d'arnaque, analysés sur le téléphone.",
      'Un coffre chiffré pour vos mots de passe.',
      'Un pare-feu qui bloque les sites dangereux et les traqueurs.',
    ],
  ),
  OnboardingPage(
    title: 'Tout reste sur votre téléphone',
    lines: [
      'Pas de compte, pas de publicité, pas de statistiques. '
          'Vos messages, vos mots de passe et la liste de vos '
          'applications ne quittent jamais le téléphone.',
      'Seuls trois échanges réseau existent, tous facultatifs, '
          'et seulement si vous les activez :',
      '• Vérifier les fuites de mots de passe (Have I Been Pwned) : '
          "5 caractères d'une empreinte, jamais le mot de passe.",
      '• Pare-feu DNS : les noms des sites autorisés sont transmis, '
          'chiffrés, au résolveur Quad9.',
      '• Mise à jour des listes de blocage : un simple '
          'téléchargement depuis GitHub.',
    ],
  ),
  OnboardingPage(
    title: 'Les autorisations, au bon moment',
    lines: [
      'Sentinel ne demande rien maintenant.',
      'Chaque autorisation (notifications, accès aux notifications, '
          'VPN, biométrie) est demandée seulement quand vous '
          'activez la fonction qui en a besoin, avec une explication.',
      'Vous pouvez tout désactiver à tout moment.',
    ],
  ),
];

/// Présentation du premier lancement (relançable depuis Réglages).
/// [onDone] : appelé par le bouton « Commencer ».
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  bool get _isLast => _page == onboardingPages.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_isLast) {
      widget.onDone();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  for (final page in onboardingPages) _PageContent(page),
                ],
              ),
            ),
            _Dots(count: onboardingPages.length, current: _page),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.bleu,
                  ),
                  onPressed: _next,
                  child: Text(_isLast ? 'Commencer' : 'Suivant'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageContent extends StatelessWidget {
  const _PageContent(this.page);

  final OnboardingPage page;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 48, 28, 24),
      children: [
        const Center(
          child: ArchIcon(filled: true, size: 72, color: AppColors.bleu),
        ),
        const SizedBox(height: 32),
        Text(
          page.title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: AppColors.encre,
          ),
        ),
        const SizedBox(height: 20),
        for (final line in page.lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              line,
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: AppColors.encre.withValues(alpha: 0.8),
              ),
            ),
          ),
      ],
    );
  }
}

/// Petits points sous les pages : la page affichée est en bleu.
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == current ? AppColors.bleu : AppColors.ligne,
            ),
          ),
      ],
    );
  }
}
