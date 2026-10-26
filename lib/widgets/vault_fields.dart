import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../services/vault/password_strength.dart';
import '../theme/app_colors.dart';

/// Champ de saisie du coffre : bordure fine, bleue quand on écrit.
/// Avec [secret], le texte est masqué et un œil permet de l'afficher.
class VaultTextField extends StatefulWidget {
  const VaultTextField({
    super.key,
    required this.controller,
    required this.label,
    this.secret = false,
    this.revealed = false,
    this.autofocus = false,
    this.enabled = true,
    this.minLines = 1,
    this.maxLines = 1,
    this.keyboardType,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final bool secret;
  final bool revealed; // état de départ de l'œil
  final bool autofocus;
  final bool enabled;
  final int minLines;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<VaultTextField> createState() => _VaultTextFieldState();
}

class _VaultTextFieldState extends State<VaultTextField> {
  late bool _hidden = widget.secret && !widget.revealed;

  @override
  void didUpdateWidget(VaultTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Le générateur demande d'afficher le mot de passe qu'il vient de créer.
    if (widget.revealed && !oldWidget.revealed) _hidden = false;
  }

  static OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: color),
  );

  @override
  Widget build(BuildContext context) {
    final muted = context.colors.secondaire;
    return TextField(
      controller: widget.controller,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      obscureText: _hidden,
      // Mot de passe : ni correction, ni suggestions, ni apprentissage
      // du clavier.
      autocorrect: !widget.secret,
      enableSuggestions: !widget.secret,
      enableIMEPersonalizedLearning: !widget.secret,
      minLines: _hidden ? 1 : widget.minLines,
      maxLines: _hidden ? 1 : widget.maxLines,
      keyboardType: widget.secret
          ? TextInputType.visiblePassword
          : widget.keyboardType,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      style: TextStyle(fontSize: 15, color: context.colors.encre),
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: TextStyle(fontSize: 15, color: muted),
        floatingLabelStyle: TextStyle(color: context.colors.bleu),
        errorText: widget.errorText,
        contentPadding: const EdgeInsets.all(14),
        enabledBorder: _border(context.colors.ligne),
        disabledBorder: _border(context.colors.ligne),
        focusedBorder: _border(context.colors.bleu),
        errorBorder: _border(context.colors.rommen),
        focusedErrorBorder: _border(context.colors.rommen),
        suffixIcon: widget.secret
            ? IconButton(
                tooltip: _hidden
                    ? context.l10n.fieldShow
                    : context.l10n.fieldHide,
                color: muted,
                icon: Icon(
                  _hidden
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(() => _hidden = !_hidden),
              )
            : null,
      ),
    );
  }
}

/// Fine barre colorée et « Force : moyen », sous le mot de passe maître.
class PasswordStrengthLine extends StatelessWidget {
  const PasswordStrengthLine({super.key, required this.password});

  final String password;

  static Color _color(AppColors c, PasswordStrength strength) =>
      switch (strength) {
        PasswordStrength.faible => c.rommen,
        PasswordStrength.moyen => c.ocre,
        PasswordStrength.fort => c.zitouna,
      };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final strength = passwordStrength(password);
    final length = password.runes.length;
    final tooShort = length < masterPasswordMinLength;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: (strength.index + 1) / PasswordStrength.values.length,
          minHeight: 2,
          color: _color(context.colors, strength),
          backgroundColor: context.colors.ligne,
        ),
        const SizedBox(height: 6),
        Text(
          tooShort
              ? l.strengthLineTooShort(
                  strength.label(l),
                  '$length',
                  '$masterPasswordMinLength',
                )
              : l.strengthLine(strength.label(l)),
          style: TextStyle(
            fontSize: 13,
            color: _color(context.colors, strength),
          ),
        ),
      ],
    );
  }
}
