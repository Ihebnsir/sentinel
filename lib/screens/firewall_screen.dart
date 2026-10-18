import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../services/firewall_service.dart';
import '../services/protection_service.dart';
import '../theme/app_colors.dart';
import '../utils/french_number.dart';
import '../widgets/blocklist_sections.dart';

/// Écran du pare-feu DNS : interrupteur, compteurs, listes de blocage,
/// mises à jour, liste blanche et sources.
class FirewallScreen extends StatefulWidget {
  const FirewallScreen({super.key});

  @override
  State<FirewallScreen> createState() => _FirewallScreenState();
}

class _FirewallScreenState extends State<FirewallScreen> {
  final _service = FirewallService();
  late final AppLifecycleListener _lifecycle;
  Timer? _timer;

  FirewallStatus? _status;
  FirewallConfig? _config;
  bool _busy = false; // démarrage ou arrêt en cours
  bool _updating = false; // téléchargement des listes en cours
  final _allowController = TextEditingController();
  String? _allowError;

  @override
  void initState() {
    super.initState();
    // Le pare-feu peut s'arrêter seul (bouton « Arrêter », autre VPN) :
    // on relit l'état au retour dans l'app et toutes les 2 secondes.
    _lifecycle = AppLifecycleListener(onResume: _refresh);
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
    _refresh();
    _loadConfig();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lifecycle.dispose();
    _allowController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final config = await _service.getConfig();
    if (!mounted) return;
    setState(() => _config = config);
  }

  // Appliqué tout de suite par Android, sans redémarrer le VPN.
  Future<void> _onCategoryChanged(
    BlocklistCategory category,
    bool enabled,
  ) async {
    final config = await _service.setCategoryEnabled(category.id, enabled);
    if (!mounted || config == null) return;
    setState(() => _config = config);
  }

  Future<void> _onAutoUpdateChanged(bool enabled) async {
    if (enabled && !await _askUpdateConsent()) return;
    await _service.setAutoUpdate(enabled);
    await _loadConfig();
  }

  Future<void> _onUpdateNow() async {
    // Sans l'option automatique, on redemande l'accord à chaque fois.
    if (_config?.autoUpdate != true && !await _askUpdateConsent()) return;
    setState(() => _updating = true);
    final ok = await _service.updateNow();
    if (!mounted) return;
    setState(() => _updating = false);
    await _loadConfig();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Listes mises à jour.' : 'Mise à jour impossible : les listes actuelles sont conservées.',
        ),
      ),
    );
  }

  Future<bool> _askUpdateConsent() async {
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.chaux,
      builder: (_) => const _UpdateConsentSheet(),
    );
    return accepted == true && mounted;
  }

  Future<void> _onAddAllowed() async {
    final domain = normalizeDomainInput(_allowController.text);
    if (domain == null) {
      setState(
        () => _allowError = 'Domaine invalide, par exemple : exemple.fr',
      );
      return;
    }
    final saved = await _service.addAllowed(domain);
    if (!mounted) return;
    if (saved == null) {
      setState(
        () => _allowError = 'Domaine refusé (format invalide ou liste pleine)',
      );
      return;
    }
    _allowController.clear();
    setState(() => _allowError = null);
    await _loadConfig();
  }

  Future<void> _onRemoveAllowed(String domain) async {
    await _service.removeAllowed(domain);
    await _loadConfig();
  }

  Future<void> _refresh() async {
    final status = await _service.getStatus();
    if (!mounted) return;
    setState(() => _status = status);
  }

  Future<void> _onSwitch(bool value) async {
    if (_busy) return;
    if (value) {
      final accepted = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: AppColors.chaux,
        builder: (_) => const _ExplanationSheet(),
      );
      if (accepted != true || !mounted) return;
      setState(() => _busy = true);
      // Écran « Demande de connexion » d'Android (la première fois).
      if (await _service.prepare()) {
        // Android 13+ : sans cette autorisation, la notification
        // (et son bouton « Arrêter ») reste invisible.
        await ProtectionService().requestNotificationPermission();
        await _service.start();
      }
    } else {
      setState(() => _busy = true);
      await _service.stop();
    }
    // Le service démarre ou s'arrête en quelques instants.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await _refresh();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final config = _config;
    final muted = AppColors.encre.withValues(alpha: 0.6);
    final active = status?.active ?? false;

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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
          children: [
            const Text(
              'Pare-feu DNS',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: AppColors.encre,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Bloque les sites dangereux et les traqueurs avant même qu'une "
              "application ne s'y connecte. Tout se passe sur votre téléphone.",
              style: TextStyle(fontSize: 15, color: AppColors.encre),
            ),
            const SizedBox(height: 24),
            const Divider(height: 1, thickness: 1, color: AppColors.ligne),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pare-feu DNS',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppColors.encre,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          status == null
                              ? 'Disponible sur Android'
                              : (active ? 'Activé' : 'Désactivé'),
                          style: TextStyle(fontSize: 13, color: muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Switch(
                    value: active,
                    onChanged: status == null || _busy ? null : _onSwitch,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: AppColors.ligne),
            if (active && status != null) ...[
              const SizedBox(height: 24),
              const Text(
                "Depuis l'activation",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.encre,
                ),
              ),
              const SizedBox(height: 4),
              _CountRow(
                label: 'Requêtes analysées',
                value: status.totalQueries,
              ),
              const Divider(height: 1, thickness: 1, color: AppColors.ligne),
              _CountRow(
                label: 'Requêtes bloquées',
                value: status.blockedQueries,
              ),
              // Détail par catégorie (une requête compte pour une seule).
              for (final category
                  in config?.categories ?? const <BlocklistCategory>[])
                if (category.enabled ||
                    (status.blockedByCategory[category.id] ?? 0) > 0) ...[
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.ligne,
                  ),
                  _CountRow(
                    label: category.name,
                    value: status.blockedByCategory[category.id] ?? 0,
                  ),
                ],
              if (status.listsLoading)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Chargement des listes…',
                    style: TextStyle(fontSize: 13, color: muted),
                  ),
                ),
            ],
            if (config != null) ...[
              BlocklistCategoriesSection(
                categories: config.categories,
                onChanged: _onCategoryChanged,
              ),
              AutoUpdateSection(
                config: config,
                busy: _updating || config.updating,
                onAutoUpdateChanged: _onAutoUpdateChanged,
                onUpdateNow: _onUpdateNow,
              ),
              AllowlistSection(
                domains: config.allowlist,
                controller: _allowController,
                error: _allowError,
                onAdd: _onAddAllowed,
                onRemove: _onRemoveAllowed,
              ),
            ],
            const SizedBox(height: 24),
            Text(
              "Android n'autorise qu'un seul VPN à la fois : si vous en "
              "activez un autre, le pare-feu s'arrête.",
              style: TextStyle(fontSize: 13, color: muted),
            ),
            if (config != null && config.sources.isNotEmpty)
              BlocklistSourcesSection(sources: config.sources),
          ],
        ),
      ),
    );
  }
}

/// Ligne « libellé … nombre ».
class _CountRow extends StatelessWidget {
  const _CountRow({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.encre.withValues(alpha: 0.6),
              ),
            ),
          ),
          Text(
            formatFrenchNumber(value),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.encre,
            ),
          ),
        ],
      ),
    );
  }
}

/// Explication avant l'écran de consentement VPN d'Android.
/// Retourne true (Continuer) ou false / null (Plus tard).
class _ExplanationSheet extends StatelessWidget {
  const _ExplanationSheet();

  static const _lines = [
    "Android va vous demander d'autoriser une « connexion VPN » : "
        "c'est ainsi que Sentinel voit les noms de sites demandés.",
    'Seules les demandes de noms de sites (DNS) passent par Sentinel, '
        'le reste de votre trafic ne change pas.',
    "Aucun site visité n'est enregistré : seuls des compteurs existent.",
    'Une notification discrète reste affichée tant que le pare-feu est actif.',
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Pare-feu DNS',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.encre,
              ),
            ),
            const SizedBox(height: 12),
            for (final line in _lines) ...[
              const Divider(height: 1, thickness: 1, color: AppColors.ligne),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  line,
                  style: const TextStyle(fontSize: 15, color: AppColors.encre),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.encre.withValues(alpha: 0.6),
                  ),
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Plus tard'),
                ),
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.bleu,
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Continuer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Accord avant de télécharger les listes. Retourne true (Accepter).
class _UpdateConsentSheet extends StatelessWidget {
  const _UpdateConsentSheet();

  static const _lines = [
    'Sentinel télécharge les listes de blocage depuis GitHub '
        '(raw.githubusercontent.com), en HTTPS, au plus une fois par jour.',
    "Aucune information vous concernant n'est envoyée : ni sites visités, "
        'ni identifiant. Comme pour toute connexion, GitHub voit '
        "l'adresse IP de votre téléphone.",
    'Chaque liste est vérifiée (taille, format, cohérence) avant usage. '
        "En cas de problème, l'ancienne version est conservée.",
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Mise à jour des listes',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.encre,
              ),
            ),
            const SizedBox(height: 12),
            for (final line in _lines) ...[
              const Divider(height: 1, thickness: 1, color: AppColors.ligne),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  line,
                  style: const TextStyle(fontSize: 15, color: AppColors.encre),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.encre.withValues(alpha: 0.6),
                  ),
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Plus tard'),
                ),
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.bleu,
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Accepter'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
