import 'package:material_ui/material_ui.dart';

import '../services/qr/qr_scanner_service.dart';
import '../theme/app_colors.dart';

/// Dessine un QR code, sombre sur clair même en thème sombre (les
/// appareils photo lisent mal un QR inversé), avec sa marge blanche.
class QrCodeView extends StatelessWidget {
  const QrCodeView({super.key, required this.matrix, required this.label});

  final QrMatrix matrix;
  final String label; // lu par TalkBack

  // Marge autour du code, en cases (4 selon la norme).
  static const quietZone = 4;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      image: true,
      child: AspectRatio(
        aspectRatio: 1,
        child: CustomPaint(painter: _QrPainter(matrix)),
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.matrix);

  final QrMatrix matrix;

  @override
  void paint(Canvas canvas, Size size) {
    const light = qrCodePalette;
    canvas.drawRect(Offset.zero & size, Paint()..color = light.chaux);
    final cells = matrix.size + 2 * QrCodeView.quietZone;
    final cell = size.shortestSide / cells;
    final dark = Paint()
      ..color = light.encre
      ..isAntiAlias = false;
    for (var y = 0; y < matrix.size; y++) {
      for (var x = 0; x < matrix.size; x++) {
        if (!matrix.isDark(x, y)) continue;
        // Un peu plus grand que la case : pas de fine ligne claire entre deux.
        canvas.drawRect(
          Rect.fromLTWH(
            (x + QrCodeView.quietZone) * cell,
            (y + QrCodeView.quietZone) * cell,
            cell + 0.5,
            cell + 0.5,
          ),
          dark,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter old) => old.matrix != matrix;
}
