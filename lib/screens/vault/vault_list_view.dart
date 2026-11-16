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
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _SearchField(controller: _search, onChanged: _refresh),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: context.colors.bleu,
              ),
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: Text(l.vaultAdd),
            ),
          ],
        ),
        const SizedBox(height: 8),
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
        const SizedBox(height: 8),
        Expanded(
          child: items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    empty ? l.vaultEmptyList : l.vaultNoResults,
                    style: TextStyle(fontSize: 15, color: muted),
                  ),
                )
              : ListView(
                  children: [
                    for (final item in items) ...[
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: context.colors.ligne,
                      ),
                      _ItemRow(
                        item: item,
                        onTap: () => _open(item: item),
                      ),
                    ],
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: context.colors.ligne,
                    ),
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
    final color = report.breached.isNotEmpty
        ? context.colors.rommen
        : toFix > 0
        ? context.colors.ocre
        : context.colors.zitouna;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(Icons.health_and_safety_outlined, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                l.vaultHealthTitle,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: context.colors.encre,
                ),
              ),
            ),
            Text(
              toFix == 0 ? l.vaultAllGood : l.vaultToFix(l.number(toFix)),
              style: TextStyle(fontWeight: FontWeight.w600, color: color),
            ),
            Icon(Icons.chevron_right, color: context.colors.discret),
          ],
        ),
      ),
    );
  }
}

/// Champ de recherche à bordure fine.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  static OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: color),
  );

  @override
  Widget build(BuildContext context) {
    final muted = context.colors.discret;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: TextStyle(fontSize: 15, color: context.colors.encre),
      decoration: InputDecoration(
        isDense: true,
        hintText: context.l10n.vaultSearch,
        hintStyle: TextStyle(fontSize: 15, color: muted),
        prefixIcon: Icon(Icons.search, color: muted),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(
              item.type == VaultItemType.document &&
                      item.mime.startsWith('image/')
                  ? Icons.image_outlined
                  : iconFor(item.type),
              color: context.colors.bleu,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.titre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: context.colors.encre,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.colors.secondaire,
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: context.colors.discret),
          ],
        ),
      ),
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
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.vaultAdd,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: context.colors.encre,
              ),
            ),
            const SizedBox(height: 12),
            for (final type in VaultItemType.values)
              // Documents : sélecteur et appareil photo d'Android.
              if (type != VaultItemType.document ||
                  VaultDocumentPlatform.isSupported) ...[
                Divider(height: 1, thickness: 1, color: context.colors.ligne),
                InkWell(
                  onTap: () => Navigator.of(context).pop(type),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      children: [
                        Icon(iconFor(type), color: context.colors.bleu),
                        const SizedBox(width: 16),
                        Text(
                          type.label(context.l10n),
                          style: TextStyle(
                            fontSize: 15,
                            color: context.colors.encre,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            Divider(height: 1, thickness: 1, color: context.colors.ligne),
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
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: context.colors.bleu),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 15, color: context.colors.encre),
              ),
            ),
          ],
        ),
      ),
    );
    final line = Divider(height: 1, thickness: 1, color: context.colors.ligne);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.vaultNewDocument,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: context.colors.encre,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l.vaultDocSourceHint,
              style: TextStyle(fontSize: 13, color: context.colors.secondaire),
            ),
            const SizedBox(height: 12),
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
