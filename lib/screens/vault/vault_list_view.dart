import 'package:material_ui/material_ui.dart';

import '../../services/vault/vault_item.dart';
import '../../services/vault/vault_platform.dart';
import '../../services/vault/vault_session.dart';
import '../../theme/app_colors.dart';
import 'vault_item_screen.dart';

/// Coffre ouvert : recherche, bouton « Ajouter », liste triée par titre.
class VaultListView extends StatefulWidget {
  const VaultListView({
    super.key,
    required this.session,
    required this.clipboard,
  });

  final VaultSession session;
  final ClipboardGuard clipboard;

  @override
  State<VaultListView> createState() => _VaultListViewState();
}

class _VaultListViewState extends State<VaultListView> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
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
      backgroundColor: AppColors.chaux,
      builder: (_) => const _TypeChooser(),
    );
    if (type == null || !mounted) return;
    _open(type: type);
  }

  void _open({VaultItem? item, VaultItemType? type}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VaultItemScreen(
          session: widget.session,
          clipboard: widget.clipboard,
          item: item,
          type: item?.type ?? type ?? VaultItemType.motDePasse,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.encre.withValues(alpha: 0.6);
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
              style: FilledButton.styleFrom(backgroundColor: AppColors.bleu),
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    empty
                        ? 'Votre coffre est vide. Ajoutez un premier mot de '
                              'passe ou une note secrète.'
                        : 'Aucun résultat.',
                    style: TextStyle(fontSize: 15, color: muted),
                  ),
                )
              : ListView(
                  children: [
                    for (final item in items) ...[
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: AppColors.ligne,
                      ),
                      _ItemRow(
                        item: item,
                        onTap: () => _open(item: item),
                      ),
                    ],
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.ligne,
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  void _refresh(String _) => setState(() {});
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
    final muted = AppColors.encre.withValues(alpha: 0.45);
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 15, color: AppColors.encre),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Rechercher',
        hintStyle: TextStyle(fontSize: 15, color: muted),
        prefixIcon: Icon(Icons.search, color: muted),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        enabledBorder: _border(AppColors.ligne),
        focusedBorder: _border(AppColors.bleu),
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
    final subtitle = item.type == VaultItemType.note
        ? item.type.label
        : item.identifiant;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(iconFor(item.type), color: AppColors.bleu),
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
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.encre.withValues(alpha: 0.6),
                      ),
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
    );
  }
}

/// Icône selon le type d'élément.
IconData iconFor(VaultItemType type) => switch (type) {
  VaultItemType.motDePasse => Icons.key_outlined,
  VaultItemType.note => Icons.sticky_note_2_outlined,
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
            const Text(
              'Ajouter',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.encre,
              ),
            ),
            const SizedBox(height: 12),
            for (final type in VaultItemType.values) ...[
              const Divider(height: 1, thickness: 1, color: AppColors.ligne),
              InkWell(
                onTap: () => Navigator.of(context).pop(type),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    children: [
                      Icon(iconFor(type), color: AppColors.bleu),
                      const SizedBox(width: 16),
                      Text(
                        type.label,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.encre,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const Divider(height: 1, thickness: 1, color: AppColors.ligne),
          ],
        ),
      ),
    );
  }
}
