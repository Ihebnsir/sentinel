import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';

/// L'arche de Sentinel avec son trou de serrure, dessinée comme une icône.
/// [filled] : arche pleine (serrure découpée) ou simple contour.
/// Taille et couleur par défaut : celles de l'IconTheme, comme une Icon.
class ArchIcon extends StatelessWidget {
  const ArchIcon({super.key, this.filled = false, this.size, this.color});

  final bool filled;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final side = size ?? theme.size ?? 24;
    return SizedBox.square(
      dimension: side,
      child: CustomPaint(
        painter: _ArchPainter(
          filled: filled,
          color: color ?? theme.color ?? context.colors.encre,
        ),
      ),
    );
  }
}

class _ArchPainter extends CustomPainter {
  const _ArchPainter({required this.filled, required this.color});

  final bool filled;
  final Color color;

  // Arche sur une grille de 24, comme ic_stat_arch.xml.
  static Path _arch({double inset = 0}) => Path()
    ..moveTo(4 + inset, 22 - inset)
    ..lineTo(4 + inset, 10)
    ..arcToPoint(Offset(20 - inset, 10), radius: Radius.circular(8 - inset))
    ..lineTo(20 - inset, 22 - inset)
    ..close();

  // Trou de serrure : cercle + pied qui s'élargit vers le bas.
  static Path _keyhole() => Path()
    ..moveTo(10.2, 19.4)
    ..lineTo(10.79, 15.42)
    ..arcToPoint(
      const Offset(13.21, 15.42),
      radius: const Radius.circular(2.1),
      largeArc: true,
    )
    ..lineTo(13.8, 19.4)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true;

    if (filled) {
      // evenOdd : la serrure, dans l'arche, devient un trou.
      final path = _arch()
        ..addPath(_keyhole(), Offset.zero)
        ..fillType = PathFillType.evenOdd;
      canvas.drawPath(path, paint);
    } else {
      // Contour de 2 (comme les icônes Material), tracé vers l'intérieur.
      canvas.drawPath(
        _arch(inset: 1),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.miter,
      );
      // Serrure remontée pour ne pas toucher le bas du contour.
      canvas.drawPath(_keyhole().shift(const Offset(0, -1)), paint);
    }
  }

  @override
  bool shouldRepaint(_ArchPainter old) =>
      old.filled != filled || old.color != color;
}
