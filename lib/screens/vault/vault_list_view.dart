import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;

import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../services/breach/breach_checker.dart';
import '../../services/vault/password_health.dart';
import '../../services/vault/vault_crypto.dart';
import '../../services/vault/vault_document_platform.dart';
import '../../services/vault/vault_item.dart';
import '../../services/vault/vault_platform.dart';
import '../../services/vault/vault_session.dart';
import '../../services/weekly_report_service.dart';
import '../../theme/app_colors.dart';
import 'password_health_screen.dart';
import 'vault_document_screen.dart';
import 'vault_item_screen.dart';
import '../../widgets/ui.dart';

/// Coffre ouvert : recherche, bouton « Ajouter », liste triée par titre.
class VaultListView extends StatefulWidget {
  const VaultListView({
    super.key,
    required this.session,
    required this.clipboard,
    required this.breaches,
  });

  final VaultSession session;
  final ClipboardGuard clipboard;
  final BreachChecker breaches;

  @override
  State<VaultListView> createState() => _VaultListViewState();
}

class _VaultListViewState extends State<VaultListView> {
  final _search = TextEditingController();
  late final Listenable _healthSources;
  List<int>? _lastHealth; // évite de renvoyer les mêmes chiffres

  @override
  void initState() {
    super.initState();
    _healthSources = Listenable.merge([widget.session, widget.breaches]);
    _healthSources.addListener(_recordHealth);
    _recordHealth();
  }

  @override
  void dispose() {
    _healthSources.removeListener(_recordHealth);
    _search.dispose();
    super.dispose();
  }

  /// Bilan de la semaine : seulement trois nombres (faibles, réutilisés,
  /// trouvés dans des fuites), jamais un titre ni un mot de passe.
  void _recordHealth() {
    final items = widget.session.items;
    if (!items.any((i) => i.type == VaultItemType.motDePasse)) return;
    final report = analyzePasswordHealth(
      items,
      breachCount: widget.breaches.countFor,
    );
    final health = [
      report.weak.length,
      report.reused.length,
      report.breached.length,
    ];
    if (listEquals(health, _lastHealth)) return;
    _lastHealth = health;
    const weekly = WeeklyReportService();
    unawaited(weekly.setGauge(WeeklyGauge.passwordsWeak, health[0]));
    unawaited(weekly.setGauge(WeeklyGauge.passwordsReused, health[1]));
    unawaited(weekly.setGauge(WeeklyGauge.passwordsBreached, health[2]));
  }


  // La recherche porte sur le titre, l'identifiant et le site.
  List<VaultItem> get _visibleItems {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return widget.session.items;
    return [
      for (final item in widget.session.items)
        if ('${item.titre} ${item.identifiant} ${item.siteWeb}'
            .toLowerCase()
            .contains(query))
          item,
    ];
  }

  Future<void> _add() async {
    final type = await showModalBottomSheet<VaultItemType>(
      context: context,
      showDragHandle: true,
      backgroundColor: context.colors.chaux,
      builder: (_) => const _TypeChooser(),
    );
    if (type == null || !mounted) return;
    if (type == VaultItemType.document) return _addDocument();
    _open(type: type);
  }

  // Photo ou fichier, puis l'écran du document (pas encore enregistré).
  Future<void> _addDocument() async {
    final camera = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      backgroundColor: context.colors.chaux,
      builder: (_) => const _DocumentSourceChooser(),
    );
    if (camera == null || !mounted) return;
    final PickedDocument? picked;
    try {
      picked = camera
          ? await VaultDocumentPlatform.capturePhoto()
          : await VaultDocumentPlatform.pickFile();
    } on DocumentPickException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.error.message(context.l10n))));
      return;
    }
    if (picked == null) return;
    // Verrouillé pendant la photo (plus de 30 s dehors) : on oublie tout.
    if (!mounted || widget.session.status != VaultStatus.ouvert) {
      wipe(picked.bytes);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            VaultDocumentScreen(session: widget.session, picked: picked),
      ),
    );
  }

  void _open({VaultItem? item, VaultItemType? type}) {
    if (item != null && item.type == VaultItemType.document) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              VaultDocumentScreen(session: widget.session, item: item),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VaultItemScreen(
          session: widget.session,
          clipboard: widget.clipboard,
          breaches: widget.breaches,
          item: item,
          type: item?.type ?? type ?? VaultItemType.motDePasse,
        ),
      ),
    );
  }

  void _openHealth() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PasswordHealthScreen(
          session: widget.session,
          clipboard: widget.clipboard,
          breaches: widget.breaches,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final muted = context.colors.secondaire;
    final items = _visibleItems;
    final empty = widget.session.items.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpace.lg),
        Row(
          children: [
            Expanded(
              child: _SearchField(controller: _search, onChanged: _refresh),
            ),
            const SizedBox(width: AppSpace.md),
            FilledButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: Text(l.vaultAdd),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.sm),
        if (!empty)
          ListenableBuilder(
            listenable: widget.breaches,
            builder: (context, _) => _HealthRow(
              report: analyzePasswordHealth(
                widget.session.items,
                breachCount: widget.breaches.countFor,
              ),
              onTap: _openHealth,
            ),
          ),
        const SizedBox(height: AppSpace.sm),
        Expanded(
          child: items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: AppSpace.lg),
                  child: Text(
                    empty ? l.vaultEmptyList : l.vaultNoResults,
                    style: TextStyle(fontSize: AppText.corps, color: muted),
                  ),
                )
              : ListView(
                  children: [
                    for (final item in items) ...[
                      const AppDivider(),
                      _ItemRow(
                        item: item,
                        onTap: () => _open(item: item),
                      ),
                    ],
                    const AppDivider(),
                  ],
                ),
        ),
      ],
    );
  }

  void _refresh(String _) => setState(() {});
}

/// Ligne « Santé des mots de passe » : nombre d'éléments à corriger.
class _HealthRow extends StatelessWidget {
  const _HealthRow({required this.report, required this.onTap});

  final PasswordHealthReport report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final toFix = report.toFix;
    final level = report.breached.isNotEmpty
        ? StatusLevel.danger
        : toFix > 0
        ? StatusLevel.warning
        : StatusLevel.ok;
    return ListRow(
      icon: Icons.health_and_safety_outlined,
      iconColor: level.color(context.colors),
      title: l.vaultHealthTitle,
      trailing: StatusBadge(
        level: level,
        label: toFix == 0 ? l.vaultAllGood : l.vaultToFix(l.number(toFix)),
      ),
      onTap: onTap,
      chevron: true,
    );
  }
}

/// Champ de recherche à bordure fine.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  static OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: AppRadius.field,
    borderSide: BorderSide(color: color),
  );

  @override
  Widget build(BuildContext context) {
    final muted = context.colors.discret;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: TextStyle(fontSize: AppText.corps, color: context.colors.encre),
      decoration: InputDecoration(
        isDense: true,
        hintText: context.l10n.vaultSearch,
        hintStyle: TextStyle(fontSize: AppText.corps, color: muted),
        prefixIcon: Icon(Icons.search, color: muted),
        contentPadding: const EdgeInsets.symmetric(vertical: AppSpace.md),
        enabledBorder: _border(context.colors.ligne),
        focusedBorder: _border(context.colors.bleu),
      ),
    );
  }
}

/// Une ligne : icône du type, titre, identifiant.
class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.onTap});

  final VaultItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final subtitle = switch (item.type) {
      VaultItemType.note => item.type.label(l),
      VaultItemType.document =>
        '${documentKindLabel(l, item.mime)} · '
            '${documentSizeLabel(l, item.taille)}',
      VaultItemType.motDePasse => item.identifiant,
    };
    return ListRow(
      icon:
          item.type == VaultItemType.document && item.mime.startsWith('image/')
          ? Icons.image_outlined
          : iconFor(item.type),
      title: item.titre,
      titleMaxLines: 1,
      subtitle: subtitle.isEmpty ? null : subtitle,
      subtitleMaxLines: 1,
      onTap: onTap,
      chevron: true,
    );
  }
}

/// Icône selon le type d'élément.
IconData iconFor(VaultItemType type) => switch (type) {
  VaultItemType.motDePasse => Icons.key_outlined,
  VaultItemType.note => Icons.sticky_note_2_outlined,
  VaultItemType.document => Icons.description_outlined,
};

/// Feuille du bas : quel type d'élément ajouter ?
class _TypeChooser extends StatelessWidget {
  const _TypeChooser();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.page, 0, AppSpace.page, AppSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.vaultAdd,
              style: TextStyle(
                fontSize: AppText.titreSecondaire,
                fontWeight: FontWeight.w600,
                color: context.colors.encre,
              ),
            ),
            const SizedBox(height: AppSpace.md),
            for (final type in VaultItemType.values)
              // Documents : sélecteur et appareil photo d'Android.
              if (type != VaultItemType.document ||
                  VaultDocumentPlatform.isSupported) ...[
                const AppDivider(),
                InkWell(
                  onTap: () => Navigator.of(context).pop(type),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
                    child: Row(
                      children: [
                        Icon(iconFor(type), color: context.colors.bleu),
                        const SizedBox(width: AppSpace.lg),
                        Text(
                          type.label(context.l10n),
                          style: TextStyle(
                            fontSize: AppText.corps,
                            color: context.colors.encre,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            const AppDivider(),
          ],
        ),
      ),
    );
  }
}

/// Feuille du bas : photo (true) ou fichier (false) ?
class _DocumentSourceChooser extends StatelessWidget {
  const _DocumentSourceChooser();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget row(IconData icon, String label, bool camera) => InkWell(
      onTap: () => Navigator.of(context).pop(camera),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
        child: Row(
          children: [
            Icon(icon, color: context.colors.bleu),
            const SizedBox(width: AppSpace.lg),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: AppText.corps, color: context.colors.encre),
              ),
            ),
          ],
        ),
      ),
    );
    final line = const AppDivider();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.page, 0, AppSpace.page, AppSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.vaultNewDocument,
              style: TextStyle(
                fontSize: AppText.titreSecondaire,
                fontWeight: FontWeight.w600,
                color: context.colors.encre,
              ),
            ),
            const SizedBox(height: AppSpace.xs),
            Text(
              l.vaultDocSourceHint,
              style: TextStyle(fontSize: AppText.detail, color: context.colors.secondaire),
            ),
            const SizedBox(height: AppSpace.md),
            line,
            row(Icons.photo_camera_outlined, l.vaultDocTakePhoto, true),
            line,
            row(Icons.upload_file_outlined, l.vaultDocChooseFile, false),
            line,
          ],
        ),
      ),
    );
  }
}
