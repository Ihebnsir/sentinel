import 'package:material_ui/material_ui.dart';

import '../services/apps_scanner_service.dart';
import '../services/firewall_service.dart';
import '../theme/app_colors.dart';

const _divider = Divider(height: 1, thickness: 1, color: AppColors.ligne);

TextStyle get _muted =>
    TextStyle(fontSize: 13, color: AppColors.encre.withValues(alpha: 0.6));

/// Phrase discrète sous les catégories et la liste blanche.
class _CacheNote extends StatelessWidget {
  const _CacheNote();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        'Les changements peuvent prendre quelques minutes à '
        "s'appliquer (cache DNS du navigateur).",
        style: _muted,
      ),
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
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.encre,
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
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.encre,
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: _muted),
                if (warning != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    warning!,
                    style: const TextStyle(fontSize: 13, color: AppColors.ocre),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BlocklistSectionTitle('Listes de blocage'),
        for (final category in categories) ...[
          _SwitchRow(
            title: category.name,
            subtitle: category.subtitle,
            warning: switch (category.id) {
              'ads' => 'Peut empêcher certaines applications de fonctionner.',
              'impersonation' =>
                'Peut bloquer un vrai site non répertorié : '
                    'ajoutez-le alors à la liste blanche.',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BlocklistSectionTitle('Mises à jour automatiques'),
        _SwitchRow(
          title: 'Mettre à jour chaque jour',
          subtitle: config.updateSummary,
          value: config.autoUpdate,
          onChanged: onAutoUpdateChanged,
        ),
        _divider,
        const SizedBox(height: 8),
        Text(
          'Les listes sont téléchargées en HTTPS depuis GitHub, au plus une '
          "fois par jour. Aucune information vous concernant n'est envoyée.",
          style: _muted,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.bleu,
              padding: EdgeInsets.zero,
            ),
            onPressed: busy ? null : onUpdateNow,
            child: Text(busy ? 'Mise à jour en cours…' : 'Mettre à jour'),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BlocklistSectionTitle('Liste blanche'),
        Text(
          "Ces sites ne sont jamais bloqués, même s'ils figurent dans une "
          'liste. Leurs sous-domaines non plus.',
          style: _muted,
        ),
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
                style: const TextStyle(fontSize: 15, color: AppColors.encre),
                decoration: InputDecoration(
                  hintText: 'exemple.fr',
                  hintStyle: TextStyle(
                    fontSize: 15,
                    color: AppColors.encre.withValues(alpha: 0.45),
                  ),
                  errorText: error,
                  isDense: true,
                  contentPadding: const EdgeInsets.all(12),
                  enabledBorder: _border(AppColors.ligne),
                  focusedBorder: _border(AppColors.bleu),
                  errorBorder: _border(AppColors.rommen),
                  focusedErrorBorder: _border(AppColors.rommen),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: TextButton(
                style: TextButton.styleFrom(foregroundColor: AppColors.bleu),
                onPressed: onAdd,
                child: const Text('Ajouter'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (domains.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text("Aucun site pour l'instant.", style: _muted),
          ),
        for (final domain in domains) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  domain,
                  style: const TextStyle(fontSize: 15, color: AppColors.encre),
                ),
              ),
              IconButton(
                tooltip: 'Retirer $domain',
                color: AppColors.encre.withValues(alpha: 0.6),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BlocklistSectionTitle('Sources et licences'),
        for (final source in sources) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              '${source.name} · ${source.license}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.encre,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(source.attribution, style: _muted),
          if (source.homepage.startsWith('https://'))
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.bleu,
                  padding: EdgeInsets.zero,
                ),
                onPressed: () =>
                    AppsScannerService().openWebPage(source.homepage),
                child: const Text('Voir la source'),
              ),
            ),
          _divider,
        ],
      ],
    );
  }
}
