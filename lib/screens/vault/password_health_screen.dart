import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../services/breach/breach_checker.dart';
import '../../services/vault/password_health.dart';
import '../../services/vault/vault_item.dart';
import '../../services/vault/vault_platform.dart';
import '../../services/vault/vault_session.dart';
import '../../theme/app_colors.dart';
import '../../widgets/breach_consent_sheet.dart';
import 'vault_item_screen.dart';
import '../../utils/bidi.dart';
import '../../widgets/ui.dart';

// Couleur : celle du thème (dividerTheme, ligne fine).
const _divider = Divider(height: 1, thickness: 1);

/// « Santé des mots de passe » : fuites, réutilisés, trop faibles.
/// Se ferme tout seul si le coffre se verrouille.
class PasswordHealthScreen extends StatefulWidget {
  const PasswordHealthScreen({
    super.key,
    required this.session,
    required this.clipboard,
    required this.breaches,
  });

  final VaultSession session;
  final ClipboardGuard clipboard;
  final BreachChecker breaches;

  @override
  State<PasswordHealthScreen> createState() => _PasswordHealthScreenState();
}

class _PasswordHealthScreenState extends State<PasswordHealthScreen> {
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSession);
    // Déjà accepté : on vérifie ce qui ne l'a pas encore été.
    widget.breaches.check(widget.session.items);
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSession);
    super.dispose();
  }

  void _onSession() {
    if (_closing || !mounted) return;
    if (widget.session.status == VaultStatus.ouvert) {
      // Un élément a pu changer : on vérifie le nouveau mot de passe.
      widget.breaches.check(widget.session.items);
      return;
    }
    _closing = true;
    final route = ModalRoute.of(context);
    final navigator = Navigator.of(context);
    navigator.popUntil((r) => r == route);
    navigator.pop();
  }

  Future<void> _askAndCheck() async {
    if (!await askBreachConsent(context)) return;
    await widget.breaches.setConsent(true);
    await widget.breaches.check(widget.session.items);
  }

  void _open(VaultItem item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VaultItemScreen(
          session: widget.session,
          clipboard: widget.clipboard,
          breaches: widget.breaches,
          item: item,
          type: item.type,
          showGenerator: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.colors.chaux,
        foregroundColor: context.colors.encre,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        // Redessine quand le coffre ou la vérification changent.
        child: ListenableBuilder(
          listenable: Listenable.merge([widget.session, widget.breaches]),
          builder: (context, _) => _content(),
        ),
      ),
    );
  }

  Widget _content() {
    final l = context.l10n;
    final breaches = widget.breaches;
    final report = analyzePasswordHealth(
      widget.session.items,
      breachCount: breaches.countFor,
    );
    final muted = context.colors.secondaire;
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpace.page, AppSpace.sm, AppSpace.page, AppSpace.xl),
      children: [
        Text(
          l.vaultHealthTitle,
          style: TextStyle(
            fontSize: AppText.titreSecondaire,
            fontWeight: FontWeight.w600,
            color: context.colors.encre,
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        Text(
          report.toFix == 0
              ? l.homeNothingToFix
              : l.healthToFix(l.number(report.toFix)),
          style: TextStyle(fontSize: AppText.corps, color: muted),
        ),
        const SizedBox(height: AppSpace.xl),
        _Section(
          title: l.healthBreached,
          header: _breachStatus(l, muted),
          emptyText:
              breaches.consent && breaches.isUpToDate(widget.session.items)
              ? l.healthNoBreach
              : null,
          items: report.breached,
          subtitle: (item) => breachShort(l, report.breachCounts[item.id]!),
          color: context.colors.rommen,
          onTap: _open,
        ),
        _Section(
          title: l.healthReused,
          emptyText: l.healthAllUnique,
          items: report.reused,
          subtitle: (item) => l.healthAlsoUsedFor(
            // Chaque titre isolé : l'ordre tient en arabe.
            report.reusedWith[item.id]!.map(bidiIsolate).join(l.listSeparator),
          ),
          color: context.colors.ocre,
          onTap: _open,
        ),
        _Section(
          title: l.healthWeak,
          emptyText: l.healthNoWeak,
          items: report.weak,
          subtitle: (_) => l.healthEasyToGuess,
          color: context.colors.ocre,
          onTap: _open,
        ),
      ],
    );
  }

  /// Sous le titre « fuites » : accord, progression ou erreur.
  Widget? _breachStatus(AppLocalizations l, Color muted) {
    final breaches = widget.breaches;
    if (!breaches.consent) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.healthCheckIntro,
            style: TextStyle(fontSize: AppText.detail, color: muted),
          ),
          TextButton(
            style: inlineButtonStyle(context),
            onPressed: _askAndCheck,
            child: Text(l.healthCheckButton),
          ),
        ],
      );
    }
    if (breaches.checking) {
      final (done, total) = breaches.progress;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.healthChecking('$done', '$total'),
              style: TextStyle(fontSize: AppText.detail, color: muted),
            ),
            const SizedBox(height: AppSpace.sm),
            LinearProgressIndicator(
              minHeight: AppSize.progress,
              value: total == 0 ? null : done / total,
              color: context.colors.bleu,
              backgroundColor: context.colors.ligne,
            ),
          ],
        ),
      );
    }
    final error = breaches.error;
    if (error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            error.message(l),
            style: TextStyle(fontSize: AppText.detail, color: context.colors.rommen),
          ),
          TextButton(
            style: inlineButtonStyle(context),
            onPressed: () => breaches.check(widget.session.items),
            child: Text(l.healthRetry),
          ),
        ],
      );
    }
    return null;
  }
}

/// Une section : titre, nombre, puis une ligne par élément.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.items,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.header,
    this.emptyText,
  });

  final String title;
  final List<VaultItem> items;
  final String Function(VaultItem) subtitle;
  final Color color;
  final ValueChanged<VaultItem> onTap;
  final Widget? header; // texte ou bouton sous le titre
  final String? emptyText; // null : rien à dire quand c'est vide

  @override
  Widget build(BuildContext context) {
    final muted = context.colors.secondaire;
    final header = this.header;
    final emptyText = this.emptyText;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: AppText.section,
                    fontWeight: FontWeight.w600,
                    color: context.colors.encre,
                  ),
                ),
              ),
              if (items.isNotEmpty)
                Text(
                  '${items.length}',
                  style: TextStyle(fontWeight: FontWeight.w600, color: color),
                ),
            ],
          ),
          if (header != null) ...[const SizedBox(height: AppSpace.xs), header],
          if (items.isEmpty && emptyText != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.sm),
              child: Text(
                emptyText,
                style: TextStyle(fontSize: AppText.corps, color: muted),
              ),
            ),
          if (items.isNotEmpty) const SizedBox(height: AppSpace.sm),
          for (final item in items) ...[
            _divider,
            InkWell(
              onTap: () => onTap(item),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
                child: Row(
                  children: [
                    Icon(Icons.key_outlined, color: color),
                    const SizedBox(width: AppSpace.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.titre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: AppText.corps,
                              fontWeight: FontWeight.w500,
                              color: context.colors.encre,
                            ),
                          ),
                          Text(
                            subtitle(item),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: AppText.detail, color: muted),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: context.colors.discret),
                  ],
                ),
              ),
            ),
          ],
          if (items.isNotEmpty) _divider,
        ],
      ),
    );
  }
}
