import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../services/qr/qr_scanner_service.dart';
import '../services/qr/wifi_share.dart';
import '../services/vault/vault_platform.dart';
import '../theme/app_colors.dart';
import '../widgets/qr_code_view.dart';
import '../widgets/ui.dart';

/// « Partager mon Wi-Fi » : nom du réseau et mot de passe saisis (ou
/// collés), QR code WIFI: affiché à l'écran pour les invités.
/// Captures d'écran bloquées pendant l'affichage (FLAG_SECURE), rien
/// n'est enregistré, tout est effacé en quittant l'écran.
class WifiShareScreen extends StatefulWidget {
  const WifiShareScreen({super.key, this.service});

  final QrScannerService? service; // remplacé dans les tests

  @override
  State<WifiShareScreen> createState() => _WifiShareScreenState();
}

class _WifiShareScreenState extends State<WifiShareScreen> {
  late final QrScannerService _service = widget.service ?? QrScannerService();
  final _ssid = TextEditingController();
  final _password = TextEditingController();
  WifiShareSecurity _security = WifiShareSecurity.wpa;
  bool _hidden = false;
  bool _showPassword = false;
  bool _busy = false;
  WifiShareProblem? _problem;
  bool _failed = false;
  QrMatrix? _matrix; // QR code affiché, en mémoire seulement

  @override
  void initState() {
    super.initState();
    // Pas de capture d'écran ni d'aperçu dans les apps récentes.
    VaultPlatform.setSecure(true);
  }

  @override
  void dispose() {
    // Effacé en quittant : champs vidés, QR code oublié.
    _ssid.clear();
    _password.clear();
    _ssid.dispose();
    _password.dispose();
    _matrix = null;
    VaultPlatform.setSecure(false);
    super.dispose();
  }

  Future<void> _paste(TextEditingController controller) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty || !mounted) return;
    setState(() {
      controller.text = text;
      _problem = null;
    });
  }

  Future<void> _create() async {
    FocusScope.of(context).unfocus();
    final ssid = _ssid.text;
    final password = _security == WifiShareSecurity.none ? '' : _password.text;
    final problem = checkWifiShare(ssid, password, _security);
    setState(() {
      _problem = problem;
      _failed = false;
    });
    if (problem != null) return;
    setState(() => _busy = true);
    final matrix = await _service.encode(
      buildWifiQr(
        ssid: ssid,
        password: password,
        security: _security,
        hidden: _hidden,
      ),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _matrix = matrix;
      _failed = matrix == null;
    });
  }

  void _edit() => setState(() => _matrix = null);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final matrix = _matrix;
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.page,
            AppSpace.sm,
            AppSpace.page,
            AppSpace.xxl,
          ),
          children: [
            PageHeader(
              title: l.qrWifiShareButton,
              subtitle: l.qrWifiShareIntro,
            ),
            const SizedBox(height: AppSpace.xl),
            if (matrix == null) ..._form(l) else ..._code(l, matrix),
          ],
        ),
      ),
    );
  }

  List<Widget> _form(AppLocalizations l) {
    final c = context.colors;
    final problem = _problem;
    return [
      _Field(
        controller: _ssid,
        label: l.qrWifiShareName,
        error: problem == WifiShareProblem.missingName
            ? l.qrWifiShareErrorName
            : null,
        onPaste: () => _paste(_ssid),
        pasteTooltip: l.linksPaste,
      ),
      const SizedBox(height: AppSpace.lg),
      Text(
        l.qrWifiShareSecurity,
        style: TextStyle(fontSize: AppText.detail, color: c.secondaire),
      ),
      const SizedBox(height: AppSpace.sm),
      RadioGroup<WifiShareSecurity>(
        groupValue: _security,
        onChanged: (v) => setState(() {
          _security = v ?? WifiShareSecurity.wpa;
          _problem = null;
        }),
        child: Column(
          children: [
            for (final (value, label) in [
              (WifiShareSecurity.wpa, l.qrWifiShareSecurityWpa),
              (WifiShareSecurity.wep, l.qrWifiShareSecurityWep),
              (WifiShareSecurity.none, l.qrWifiShareSecurityNone),
            ])
              RadioListTile<WifiShareSecurity>(
                value: value,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  label,
                  style: TextStyle(fontSize: AppText.corps, color: c.encre),
                ),
              ),
          ],
        ),
      ),
      if (_security != WifiShareSecurity.none) ...[
        const SizedBox(height: AppSpace.sm),
        _Field(
          controller: _password,
          label: l.qrWifiSharePassword,
          obscure: !_showPassword,
          error: switch (problem) {
            WifiShareProblem.wpaPassword => l.qrWifiShareErrorWpa,
            WifiShareProblem.wepPassword => l.qrWifiShareErrorWep,
            _ => null,
          },
          onPaste: () => _paste(_password),
          pasteTooltip: l.linksPaste,
          onToggle: () => setState(() => _showPassword = !_showPassword),
          toggleTooltip: _showPassword
              ? l.qrWifiShareHidePassword
              : l.qrWifiShareShowPassword,
        ),
      ],
      SwitchListTile(
        value: _hidden,
        contentPadding: EdgeInsets.zero,
        title: Text(
          l.qrWifiShareHidden,
          style: TextStyle(fontSize: AppText.corps, color: c.encre),
        ),
        onChanged: (v) => setState(() => _hidden = v),
      ),
      const SizedBox(height: AppSpace.lg),
      PrimaryButton(
        label: l.qrWifiShareCreate,
        icon: Icons.qr_code_2,
        busy: _busy,
        expand: true,
        onPressed: _create,
      ),
      if (_failed)
        Padding(
          padding: const EdgeInsets.only(top: AppSpace.md),
          child: Text(
            l.qrWifiShareFailed,
            style: TextStyle(fontSize: AppText.corps, color: c.rommen),
          ),
        ),
    ];
  }

  List<Widget> _code(AppLocalizations l, QrMatrix matrix) {
    final c = context.colors;
    return [
      Center(
        child: FractionallySizedBox(
          widthFactor: 0.85,
          child: QrCodeView(
            matrix: matrix,
            label: l.qrWifiShareCodeLabel(_ssid.text),
          ),
        ),
      ),
      const SizedBox(height: AppSpace.lg),
      Text(
        _ssid.text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: AppText.section,
          fontWeight: FontWeight.w600,
          color: c.encre,
        ),
      ),
      const SizedBox(height: AppSpace.sm),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.screenshot_monitor,
            size: AppSize.iconSmall,
            color: c.secondaire,
          ),
          const SizedBox(width: AppSpace.sm),
          Flexible(
            child: Text(
              l.qrWifiShareShow,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: AppText.detail, color: c.secondaire),
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpace.xl),
      Center(
        child: SecondaryButton(
          label: l.qrWifiShareEdit,
          icon: Icons.edit_outlined,
          onPressed: _edit,
        ),
      ),
    ];
  }
}

/// Champ fin, sans suggestions du clavier ni apprentissage (mot de passe).
class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.onPaste,
    required this.pasteTooltip,
    this.error,
    this.obscure = false,
    this.onToggle,
    this.toggleTooltip,
  });

  final TextEditingController controller;
  final String label;
  final String? error;
  final bool obscure;
  final VoidCallback onPaste;
  final String pasteTooltip;
  final VoidCallback? onToggle; // afficher / masquer le mot de passe
  final String? toggleTooltip;

  static OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: AppRadius.field,
    borderSide: BorderSide(color: color),
  );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return TextField(
      controller: controller,
      obscureText: obscure,
      autocorrect: false,
      enableSuggestions: false,
      enableIMEPersonalizedLearning: false,
      keyboardType: onToggle == null
          ? TextInputType.text
          : TextInputType.visiblePassword,
      style: TextStyle(fontSize: AppText.corps, color: c.encre),
      decoration: InputDecoration(
        labelText: label,
        errorText: error,
        contentPadding: const EdgeInsets.all(AppSpace.lg),
        enabledBorder: _border(c.ligne),
        focusedBorder: _border(c.bleu),
        errorBorder: _border(c.rommen),
        focusedErrorBorder: _border(c.rommen),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onToggle != null)
              IconButton(
                tooltip: toggleTooltip,
                icon: Icon(
                  obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: onToggle,
              ),
            IconButton(
              tooltip: pasteTooltip,
              icon: const Icon(Icons.content_paste),
              onPressed: onPaste,
            ),
          ],
        ),
      ),
    );
  }
}
