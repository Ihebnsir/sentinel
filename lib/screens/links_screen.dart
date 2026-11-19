import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../app_info.dart';
import '../l10n/l10n.dart';
import '../services/apps_scanner_service.dart';
import '../services/firewall_service.dart';
import '../services/links/link_checker.dart';
import '../services/notification_permission.dart';
import '../services/phishing/known_brands.dart';
import '../services/qr/qr_scanner_service.dart';
import '../services/share_service.dart';
import '../services/weekly_report_service.dart';
import '../theme/app_colors.dart';
import '../utils/bidi.dart';
import '../widgets/actions_row.dart';
import '../widgets/loading_bar.dart';
import '../widgets/verdict_section.dart';
import 'firewall_screen.dart';
import 'qr_result_screen.dart';
import '../widgets/ui.dart';

/// Onglet « Liens » : l'utilisateur colle, partage ou scanne un lien ;
/// Sentinel dit où il mène vraiment et s'il est dangereux. Tout se passe
/// sur le téléphone : rien n'est envoyé, rien n'est enregistré.
class LinksScreen extends StatefulWidget {
  const LinksScreen({
    super.key,
    this.sharedText,
    this.checkDomain,
    this.firewall,
    this.qr,
  });

  /// Texte reçu d'une autre app : on y cherche le premier lien.
  final ValueListenable<SharedText?>? sharedText;

  /// Remplacés dans les tests.
  final DomainChecker? checkDomain;
  final FirewallService? firewall;
  final QrScannerService? qr;

  @override
  State<LinksScreen> createState() => _LinksScreenState();
}

class _LinksScreenState extends State<LinksScreen> {
  final _controller = TextEditingController();
  late final FirewallService _firewall = widget.firewall ?? FirewallService();
  late final QrScannerService _qr = widget.qr ?? QrScannerService();

  bool _scanning = false;
  bool _checking = false;
  bool _noLink = false; // aucun lien dans le texte
  bool _failed = false; // marques connues illisibles
  LinkCheck? _result;

  bool get _hasText => _controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    widget.sharedText?.addListener(_onShared);
  }

  @override
  void didUpdateWidget(LinksScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sharedText != widget.sharedText) {
      oldWidget.sharedText?.removeListener(_onShared);
      widget.sharedText?.addListener(_onShared);
    }
  }

  @override
  void dispose() {
    widget.sharedText?.removeListener(_onShared);
    _controller.dispose();
    super.dispose();
  }

  // Un texte arrive d'une autre app : on le met dans le champ et on vérifie.
  void _onShared() {
    final shared = widget.sharedText?.value;
    if (shared == null) return;
    _controller.text = shared.text;
    _onTextChanged(shared.text);
    _check();
  }

  // Le texte a changé : l'ancien résultat ne correspond plus.
  void _onTextChanged(String _) {
    setState(() {
      _result = null;
      _noLink = false;
      _failed = false;
    });
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty || !mounted) return;
    _controller.text = text;
    _onTextChanged(text);
  }

  void _clear() {
    _controller.clear();
    _onTextChanged('');
  }

  /// Règles du lien + listes du pare-feu. Aucune requête réseau : un lien
  /// raccourci n'est jamais ouvert pour découvrir sa destination.
  Future<void> _check() async {
    FocusScope.of(context).unfocus(); // ferme le clavier
    final text = _controller.text;
    setState(() => _checking = true);
    try {
      await loadKnownBrands();
      final link = extractFirstLink(text);
      DomainCheck? lists;
      if (link != null) {
        final check = widget.checkDomain ?? _firewall.checkDomain;
        lists = await check(link.host);
        // Bilan de la semaine : un compteur, jamais le lien.
        unawaited(
          const WeeklyReportService().count(WeeklyCounter.linksChecked),
        );
      }
      // Le texte a changé entre-temps (nouveau partage) : résultat périmé.
      if (!mounted || _controller.text != text) return;
      setState(() {
        _result = checkText(text, lists: lists);
        _noLink = _result == null;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  // Confirmation, puis navigateur. Jamais d'ouverture automatique.
  Future<void> _open(LinkCheck result) async {
    final l = context.l10n;
    final url = result.link.openableUrl;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_openLabel(l, result)),
        content: Text(l.qrConfirmLink(url)),
        actions: [
          TextButton(
            style: mutedButtonStyle(context),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.commonContinue),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (!await _qr.openLink(url) && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.qrActionFailed)));
    }
  }

  /// Scan d'un QR code : explication avant la première demande de caméra,
  /// puis écran de résultat. Rien n'est ouvert sans l'utilisateur.
  Future<void> _scanQr() async {
    final l = context.l10n;
    if (!await _qr.hasCameraPermission()) {
      if (!mounted || !await _explainCamera()) return;
    }
    setState(() => _scanning = true);
    final result = await _qr.scan(l.qrScanPrompt);
    if (!mounted) return;
    setState(() => _scanning = false);
    final error = result.error;
    final text = result.text;
    if (error != null) {
      _showScanError(error);
    } else if (text != null) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              QrResultScreen(raw: text, checkDomain: widget.checkDomain),
        ),
      );
    }
  }

  // Pourquoi la caméra, avant la demande d'Android. true : continuer.
  Future<bool> _explainCamera() async {
    final l = context.l10n;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.qrCameraTitle),
        content: Text(l.qrCameraText),
        actions: [
          TextButton(
            style: mutedButtonStyle(context),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.commonContinue),
          ),
        ],
      ),
    );
    return accepted == true;
  }

  void _showScanError(QrScanError error) {
    final l = context.l10n;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.message(l)),
        // Refus définitif : seuls les réglages d'Android peuvent le changer.
        action: error == QrScanError.permissionBlocked
            ? SnackBarAction(
                label: l.qrOpenSettings,
                onPressed: () =>
                    AppsScannerService().openAppSettings(ownPackageName),
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final result = _result;
    final muted = context.colors.secondaire;
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppSpace.page, AppSpace.xl, AppSpace.page, AppSpace.lg),
              children: [
                Text(
                  l.navLinks,
                  style: TextStyle(
                    fontSize: AppText.titre,
                    fontWeight: FontWeight.w600,
                    color: context.colors.encre,
                  ),
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  l.linksIntro,
                  style: TextStyle(fontSize: AppText.corps, color: muted),
                ),
                const SizedBox(height: AppSpace.lg),
                _LinkField(controller: _controller, onChanged: _onTextChanged),
                const SizedBox(height: AppSpace.sm),
                _actions(l),
                if (_checking)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpace.xl),
                    child: LoadingBar(label: l.linksChecking),
                  ),
                if (_noLink || _failed)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpace.xl),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _noLink ? l.linksNoLink : l.linksFailed,
                        style: TextStyle(fontSize: AppText.corps, color: muted),
                      ),
                    ),
                  ),
                if (result != null && !_checking) ..._resultWidgets(l, result),
                const SizedBox(height: AppSpace.xl),
                _QrScanRow(onTap: _scanning ? null : _scanQr),
                AutoProtectionRow(firewall: _firewall),
              ],
            ),
          ),
          // Rappel discret, toujours visible.
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.page, 0, AppSpace.page, AppSpace.lg),
            child: Text(
              l.linksLocalNote,
              style: TextStyle(fontSize: AppText.detail, color: context.colors.secondaire),
            ),
          ),
        ],
      ),
    );
  }

  // Verdict, destination réelle, raisons, conseil, bouton « Ouvrir ».
  List<Widget> _resultWidgets(AppLocalizations l, LinkCheck result) {
    final verdict = result.verdict;
    final blocked = verdict == Verdict.dangereux;
    return [
      VerdictSection(
        verdict: verdict,
        subtitle: l.linksRealDestination(result.realDestination),
        reasons: [
          ...result.reasons(l),
          if (result.isShortener) l.linksShortenerHelp,
        ],
        advice: verdict.advice(l),
      ),
      const SizedBox(height: AppSpace.xl),
      // Le lien tel qu'il sera ouvert, de gauche à droite même en arabe.
      Text(
        result.link.openableUrl,
        textDirection: TextDirection.ltr,
        textAlign: pageStart(context),
        style: TextStyle(fontSize: AppText.detail, color: context.colors.secondaire),
      ),
      const SizedBox(height: AppSpace.md),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: OutlinedButton(
          // null : désactivé (lien dangereux).
          onPressed: blocked ? null : () => _open(result),
          child: Text(_openLabel(l, result)),
        ),
      ),
      if (blocked)
        Padding(
          padding: const EdgeInsets.only(top: AppSpace.sm),
          child: Text(
            l.linksOpenBlocked,
            style: TextStyle(fontSize: AppText.detail, color: context.colors.secondaire),
          ),
        ),
    ];
  }

  /// « Coller » à gauche ; « Effacer » et « Vérifier » à droite.
  Widget _actions(AppLocalizations l) {
    return ActionsRow(
      children: [
        TextButton(
          onPressed: _paste,
          child: Text(l.linksPaste),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_controller.text.isNotEmpty)
              TextButton(
                style: mutedButtonStyle(context),
                onPressed: _clear,
                child: Text(l.linksClear),
              ),
            const SizedBox(width: AppSpace.sm),
            FilledButton(
              // null = bouton désactivé (champ vide ou vérification en cours).
              onPressed: _hasText && !_checking ? _check : null,
              child: Text(l.linksCheck),
            ),
          ],
        ),
      ],
    );
  }
}

/// « Ouvrir le lien » si rien n'est connu, sinon « Ouvrir quand même ».
String _openLabel(AppLocalizations l, LinkCheck result) =>
    result.verdict == Verdict.rien ? l.qrActionOpenLink : l.qrActionOpenAnyway;

/// Champ du lien, bordure fine, bleue quand on écrit dedans.
class _LinkField extends StatelessWidget {
  const _LinkField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  static OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: AppRadius.field,
    borderSide: BorderSide(color: color),
  );

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      minLines: 1,
      maxLines: 4,
      keyboardType: TextInputType.url,
      autocorrect: false,
      style: TextStyle(fontSize: AppText.corps, color: context.colors.encre),
      decoration: InputDecoration(
        hintText: context.l10n.linksHint,
        hintStyle: TextStyle(fontSize: AppText.corps, color: context.colors.discret),
        contentPadding: const EdgeInsets.all(AppSpace.lg),
        enabledBorder: _border(context.colors.ligne),
        focusedBorder: _border(context.colors.bleu),
      ),
    );
  }
}

/// Ligne « Scanner un QR code », entre deux traits fins.
class _QrScanRow extends StatelessWidget {
  const _QrScanRow({required this.onTap});

  final VoidCallback? onTap; // null pendant un scan

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      children: [
        const AppDivider(),
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
            child: Row(
              children: [
                Icon(Icons.qr_code_scanner, color: context.colors.bleu),
                const SizedBox(width: AppSpace.lg),
                Expanded(
                  child: _TwoLines(
                    title: l.qrScanButton,
                    subtitle: l.qrScanSubtitle,
                    titleColor: context.colors.bleu,
                  ),
                ),
              ],
            ),
          ),
        ),
        const AppDivider(),
      ],
    );
  }
}

/// « Protection automatique quand vous cliquez » : l'état du pare-feu DNS,
/// qui bloque les sites dangereux connus même sans passer par cet onglet.
/// Activable en un appui. Rien hors Android.
class AutoProtectionRow extends StatefulWidget {
  const AutoProtectionRow({super.key, required this.firewall});

  final FirewallService firewall;

  @override
  State<AutoProtectionRow> createState() => _AutoProtectionRowState();
}

class _AutoProtectionRowState extends State<AutoProtectionRow> {
  late final AppLifecycleListener _lifecycle;
  FirewallStatus? _status;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Au retour dans l'app (ex : arrêt depuis la notification).
    _lifecycle = AppLifecycleListener(onResume: _refresh);
    _refresh();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final status = await widget.firewall.getStatus();
    if (mounted) setState(() => _status = status);
  }

  // Un appui : autorisation VPN d'Android (la première fois), puis départ.
  // DNS privé strict : l'écran du pare-feu explique quoi faire.
  Future<void> _enable() async {
    if (_status?.strictPrivateDns != null) return _openFirewall();
    setState(() => _busy = true);
    if (await widget.firewall.prepare()) {
      // Android 13+ : sans elle, les alertes du pare-feu restent invisibles.
      await const NotificationPermission().request();
      await widget.firewall.start();
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    await _refresh();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _openFirewall() async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const FirewallScreen()));
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final status = _status;
    if (status == null) return const SizedBox.shrink();
    final active = status.active;
    return Column(
      children: [
        InkWell(
          onTap: active ? _openFirewall : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
            child: Row(
              children: [
                Icon(
                  Icons.shield_outlined,
                  color: active
                      ? context.colors.zitouna
                      : context.colors.discret,
                ),
                const SizedBox(width: AppSpace.lg),
                Expanded(
                  child: _TwoLines(
                    title: l.linksAutoTitle,
                    subtitle: active ? l.linksAutoOn : l.linksAutoOff,
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                if (active)
                  Icon(Icons.chevron_right, color: context.colors.discret)
                else
                  TextButton(
                    onPressed: _busy ? null : _enable,
                    child: Text(l.linksAutoEnable),
                  ),
              ],
            ),
          ),
        ),
        const AppDivider(),
      ],
    );
  }
}

/// Titre et sous-titre d'une ligne.
class _TwoLines extends StatelessWidget {
  const _TwoLines({
    required this.title,
    required this.subtitle,
    this.titleColor,
  });

  final String title;
  final String subtitle;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: AppText.intitule,
            fontWeight: FontWeight.w500,
            color: titleColor ?? context.colors.encre,
          ),
        ),
        const SizedBox(height: AppSpace.xs),
        Text(
          subtitle,
          style: TextStyle(fontSize: AppText.detail, color: context.colors.secondaire),
        ),
      ],
    );
  }
}
