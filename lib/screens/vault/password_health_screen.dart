import 'package:material_ui/material_ui.dart';

import '../../services/breach/breach_checker.dart';
import '../../services/vault/password_health.dart';
import '../../services/vault/vault_item.dart';
import '../../services/vault/vault_platform.dart';
import '../../services/vault/vault_session.dart';
import '../../theme/app_colors.dart';
import '../../widgets/breach_consent_sheet.dart';
import 'vault_item_screen.dart';

const _divider = Divider(height: 1, thickness: 1, color: AppColors.ligne);

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
        backgroundColor: AppColors.chaux,
        foregroundColor: AppColors.encre,
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
    final breaches = widget.breaches;
    final report = analyzePasswordHealth(
      widget.session.items,
      breachCount: breaches.countFor,
    );
    final muted = AppColors.encre.withValues(alpha: 0.6);
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
      children: [
        const Text(
          'Santé des mots de passe',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: AppColors.encre,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          report.toFix == 0
              ? 'Rien à corriger pour le moment.'
              : '${report.toFix} à corriger. Touchez un élément pour '
                    'changer son mot de passe.',
          style: TextStyle(fontSize: 15, color: muted),
        ),
        const SizedBox(height: 24),
        _Section(
          title: 'Trouvés dans des fuites',
          header: _breachStatus(muted),
          emptyText:
              breaches.consent && breaches.isUpToDate(widget.session.items)
              ? 'Aucun mot de passe trouvé dans une fuite.'
              : null,
          items: report.breached,
          subtitle: (item) => breachShort(report.breachCounts[item.id]!),
          color: AppColors.rommen,
          onTap: _open,
        ),
        _Section(
          title: 'Utilisés plusieurs fois',
          emptyText: 'Chaque mot de passe est unique.',
          items: report.reused,
          subtitle: (item) =>
              'Aussi utilisé pour : ${report.reusedWith[item.id]!.join(', ')}',
          color: AppColors.ocre,
          onTap: _open,
        ),
        _Section(
          title: 'Trop faibles',
          emptyText: 'Aucun mot de passe trop faible.',
          items: report.weak,
          subtitle: (_) => 'Facile à deviner',
          color: AppColors.ocre,
          onTap: _open,
        ),
      ],
    );
  }

  /// Sous le titre « fuites » : accord, progression ou erreur.
  Widget? _breachStatus(Color muted) {
    final breaches = widget.breaches;
    if (!breaches.consent) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vérifiez si vos mots de passe apparaissent dans des fuites '
            'connues (Have I Been Pwned).',
            style: TextStyle(fontSize: 13, color: muted),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.bleu,
              padding: EdgeInsets.zero,
            ),
            onPressed: _askAndCheck,
            child: const Text('Vérifier les fuites'),
          ),
        ],
      );
    }
    if (breaches.checking) {
      final (done, total) = breaches.progress;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vérification… $done / $total',
              style: TextStyle(fontSize: 13, color: muted),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              minHeight: 2,
              value: total == 0 ? null : done / total,
              color: AppColors.bleu,
              backgroundColor: AppColors.ligne,
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
            error,
            style: const TextStyle(fontSize: 13, color: AppColors.rommen),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.bleu,
              padding: EdgeInsets.zero,
            ),
            onPressed: () => breaches.check(widget.session.items),
            child: const Text('Réessayer'),
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
    final muted = AppColors.encre.withValues(alpha: 0.6);
    final header = this.header;
    final emptyText = this.emptyText;
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.encre,
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
          if (header != null) ...[const SizedBox(height: 4), header],
          if (items.isEmpty && emptyText != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                emptyText,
                style: TextStyle(fontSize: 14, color: muted),
              ),
            ),
          if (items.isNotEmpty) const SizedBox(height: 8),
          for (final item in items) ...[
            _divider,
            InkWell(
              onTap: () => onTap(item),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: [
                    Icon(Icons.key_outlined, color: color),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.titre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppColors.encre,
                            ),
                          ),
                          Text(
                            subtitle(item),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, color: muted),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: AppColors.encre.withValues(alpha: 0.3),
                    ),
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
