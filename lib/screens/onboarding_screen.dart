import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
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
List<OnboardingPage> onboardingPages(AppLocalizations l) => [
  OnboardingPage(
    title: l.onboarding1Title,
    lines: [
      l.onboarding1Line1,
      l.onboarding1Line2,
      l.onboarding1Line3,
      l.onboarding1Line4,
      l.onboarding1Line5,
    ],
  ),
  OnboardingPage(
    title: l.onboarding2Title,
    lines: [
      l.onboarding2Line1,
      l.onboarding2Line2,
      l.onboarding2Line3,
      l.onboarding2Line4,
      l.onboarding2Line5,
    ],
  ),
  OnboardingPage(
    title: l.onboarding3Title,
    lines: [l.onboarding3Line1, l.onboarding3Line2, l.onboarding3Line3],
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

  // Toujours 3 pages, quelle que soit la langue.
  bool get _isLast => _page == _pageCount - 1;

  static const _pageCount = 3;

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
    final l = context.l10n;
    final pages = onboardingPages(l);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  for (final page in pages) _PageContent(page),
                ],
              ),
            ),
            _Dots(count: pages.length, current: _page),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.bleu,
                  ),
                  onPressed: _next,
                  child: Text(_isLast ? l.onboardingStart : l.onboardingNext),
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
