import 'package:material_ui/material_ui.dart';

/// Rangée de boutons « Annuler … Valider », un à chaque bout. Si les
/// textes ne tiennent pas sur une ligne (police agrandie), les boutons
/// passent l'un sous l'autre, alignés à droite, au lieu de déborder.
class ActionsRow extends StatelessWidget {
  const ActionsRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return OverflowBar(
      spacing: 8,
      overflowSpacing: 8,
      alignment: MainAxisAlignment.spaceBetween,
      overflowAlignment: OverflowBarAlignment.end,
      children: children,
    );
  }
}
