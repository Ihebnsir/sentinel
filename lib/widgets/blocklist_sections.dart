import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../services/apps_scanner_service.dart';
import '../services/firewall_service.dart';
import '../theme/app_colors.dart';

// Couleur : celle du thème (dividerTheme, ligne fine).
const _divider = Divider(height: 1, thickness: 1);

TextStyle _muted(BuildContext context) =>
    TextStyle(fontSize: 13, color: context.colors.secondaire);

/// Phrase discrète sous les catégories et la liste blanche.
class _CacheNote extends StatelessWidget {
  const _CacheNote();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(context.l10n.blocklistCacheNote, style: _muted(context)),
    );
  }
}

/// Titre de section, même style que « Depuis l'activation ».
class BlocklistSectionTitle extends StatelessWidget {
  const BlocklistSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 32, bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: context.colors.encre,
        ),
      ),
    );
  }
}

/// Ligne « titre + sous-titre … interrupteur ».
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.warning,
  });

  final String title;
  final String subtitle;
  final String? warning;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: context.colors.encre,
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: _muted(context)),
                if (warning != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    warning!,
                    style: TextStyle(fontSize: 13, color: context.colors.ocre),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// « Listes de blocage » : une ligne par catégorie.
class BlocklistCategoriesSection extends StatelessWidget {
  const BlocklistCategoriesSection({
    super.key,
    required this.categories,
    required this.onChanged,
  });

  final List<BlocklistCategory> categories;
  final void Function(BlocklistCategory category, bool enabled)? onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BlocklistSectionTitle(l.blocklistListsTitle),
        for (final category in categories) ...[
          _SwitchRow(
            title: category.displayName(l),
            subtitle: category.subtitle(l),
            warning: switch (category.id) {
              'ads' => l.blocklistAdsWarning,
              'impersonation' => l.blocklistImpersonationWarning,
              _ => null,
            },
            value: category.enabled,
            onChanged: onChanged == null
                ? null
                : (value) => onChanged!(category, value),
          ),
          _divider,
        ],
        const _CacheNote(),
      ],
    );
  }
}

/// « Mises à jour automatiques » : interrupteur, date, bouton.
class AutoUpdateSection extends StatelessWidget {
  const AutoUpdateSection({
    super.key,
    required this.config,
    required this.busy,
    required this.onAutoUpdateChanged,
    required this.onUpdateNow,
  });

  final FirewallConfig config;
  final bool busy; // mise à jour en cours
  final ValueChanged<bool> onAutoUpdateChanged;
  final VoidCallback onUpdateNow;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BlocklistSectionTitle(l.blocklistAutoUpdateTitle),
        _SwitchRow(
          title: l.blocklistUpdateDaily,
          subtitle: config.updateSummary(l),
          value: config.autoUpdate,
          onChanged: onAutoUpdateChanged,
        ),
        _divider,
        const SizedBox(height: 8),
        Text(l.blocklistUpdateNote, style: _muted(context)),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            style: TextButton.styleFrom(
              foregroundColor: context.colors.bleu,
              padding: EdgeInsets.zero,
            ),
            onPressed: busy ? null : onUpdateNow,
            child: Text(busy ? l.blocklistUpdating : l.blocklistUpdateNow),
          ),
        ),
      ],
    );
  }
}

/// « Liste blanche » : domaines jamais bloqués.
class AllowlistSection extends StatelessWidget {
  const AllowlistSection({
    super.key,
    required this.domains,
    required this.controller,
    required this.error,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> domains;
  final TextEditingController controller;
  final String? error;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  static OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: color),
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BlocklistSectionTitle(l.allowlistTitle),
        Text(l.allowlistIntro, style: _muted(context)),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.url,
                autocorrect: false,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => onAdd(),
                style: TextStyle(fontSize: 15, color: context.colors.encre),
                decoration: InputDecoration(
                  hintText: l.allowlistHint,
                  hintStyle: TextStyle(
                    fontSize: 15,
                    color: context.colors.discret,
                  ),
                  errorText: error,
                  isDense: true,
                  contentPadding: const EdgeInsets.all(12),
                  enabledBorder: _border(context.colors.ligne),
                  focusedBorder: _border(context.colors.bleu),
                  errorBorder: _border(context.colors.rommen),
                  focusedErrorBorder: _border(context.colors.rommen),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: context.colors.bleu,
                ),
                onPressed: onAdd,
                child: Text(l.allowlistAdd),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (domains.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(l.allowlistEmpty, style: _muted(context)),
          ),
        for (final domain in domains) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  domain,
                  style: TextStyle(fontSize: 15, color: context.colors.encre),
                ),
              ),
              IconButton(
                tooltip: l.allowlistRemove(domain),
                color: context.colors.secondaire,
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => onRemove(domain),
              ),
            ],
          ),
          _divider,
        ],
        const _CacheNote(),
      ],
    );
  }
}

/// « Sources et licences » : attributions exigées par les licences.
class BlocklistSourcesSection extends StatelessWidget {
  const BlocklistSourcesSection({super.key, required this.sources});

  final List<BlocklistSourceInfo> sources;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BlocklistSectionTitle(l.sourcesTitle),
        for (final source in sources) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              '${source.name} · ${source.license}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: context.colors.encre,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(source.attribution, style: _muted(context)),
          if (source.homepage.startsWith('https://'))
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: context.colors.bleu,
                  padding: EdgeInsets.zero,
                ),
                onPressed: () =>
                    AppsScannerService().openWebPage(source.homepage),
                child: Text(l.sourcesSeeSource),
              ),
            ),
          _divider,
        ],
      ],
    );
  }
}
