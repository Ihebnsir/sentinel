import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../theme/app_colors.dart';
import '../../theme/tokens.dart';

/// Les petits dessins des états vides, dans l'esprit de Sidi Bou Saïd.
enum SidiBouMotif {
  porte, // porte bleue cloutée : le coffre
  fenetre, // fenêtre en moucharabieh : regarder dans les apps
  jasmin, // brin de jasmin : tout va bien
}

/// Dessin vectoriel original, aux couleurs du thème (clair ou nuit).
/// Purement décoratif : ignoré par TalkBack.
class SidiBouIllustration extends StatelessWidget {
  const SidiBouIllustration(this.motif, {super.key, this.size});

  final SidiBouMotif motif;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Pétales blancs le jour, presque blancs la nuit (texte du thème).
    final petal = Theme.of(context).brightness == Brightness.dark
        ? c.encre
        : c.surCouleur;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size ?? AppSize.illustration,
        child: CustomPaint(
          painter: _SidiBouPainter(motif: motif, colors: c, petal: petal),
        ),
      ),
    );
  }
}

class _SidiBouPainter extends CustomPainter {
  const _SidiBouPainter({
    required this.motif,
    required this.colors,
    required this.petal,
  });

  final SidiBouMotif motif;
  final AppColors colors;
  final Color petal;

  // Grille de 120 × 120.
  static const _grid = 120.0;

  /// Arche dont l'arrondi a son centre en [cy].
  static Path _archAt(double left, double right, double cy, double bottom) {
    final r = (right - left) / 2;
    return Path()
      ..moveTo(left, bottom)
      ..lineTo(left, cy)
      ..arcToPoint(Offset(right, cy), radius: Radius.circular(r))
      ..lineTo(right, bottom)
      ..close();
  }

  Paint _fill(Color color) => Paint()
    ..color = color
    ..isAntiAlias = true;

  Paint _stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / _grid, size.height / _grid);
    // Fond commun : grande arche bleue très pâle et ligne du sol.
    canvas.drawPath(
      _archAt(14, 106, 60, 112),
      _fill(colors.bleu.withValues(alpha: 0.08)),
    );
    canvas.drawLine(
      const Offset(8, 112),
      const Offset(112, 112),
      _stroke(colors.ligne, 2),
    );
    switch (motif) {
      case SidiBouMotif.porte:
        _door(canvas);
      case SidiBouMotif.fenetre:
        _window(canvas);
      case SidiBouMotif.jasmin:
        _jasmine(canvas);
    }
  }

  // Porte bleue à deux battants, cadre ocre, clous en arche.
  void _door(Canvas canvas) {
    canvas.drawPath(_archAt(32, 88, 48, 112), _stroke(colors.ocre, 3));
    canvas.drawPath(_archAt(35, 85, 48, 112), _fill(colors.bleu));
    final nail = _fill(colors.chaux);
    // Séparation des deux battants.
    canvas.drawLine(
      const Offset(60, 26),
      const Offset(60, 112),
      _stroke(colors.chaux, 1.5),
    );
    // Clous le long de l'arrondi…
    for (var a = 180; a <= 360; a += 20) {
      final t = a * math.pi / 180;
      canvas.drawCircle(
        Offset(60 + 18 * math.cos(t), 48 + 18 * math.sin(t)),
        1.6,
        nail,
      );
    }
    // … puis le long des côtés, et un losange sur chaque battant.
    for (var y = 56.0; y <= 106; y += 8) {
      canvas.drawCircle(Offset(42, y), 1.6, nail);
      canvas.drawCircle(Offset(78, y), 1.6, nail);
    }
    for (final x in [51.0, 69.0]) {
      for (final (dx, dy) in [
        (0.0, -6.0),
        (5.0, 0.0),
        (0.0, 6.0),
        (-5.0, 0.0),
      ]) {
        canvas.drawCircle(Offset(x + dx, 72 + dy), 1.4, nail);
      }
    }
    // Heurtoirs.
    final ring = _stroke(colors.ocre, 1.6);
    canvas.drawCircle(const Offset(55, 88), 2.6, ring);
    canvas.drawCircle(const Offset(65, 88), 2.6, ring);
  }

  // Fenêtre en arche fermée par un treillis de moucharabieh.
  void _window(Canvas canvas) {
    final inner = _archAt(36, 84, 52, 96);
    canvas.save();
    canvas.clipPath(inner);
    canvas.drawPath(inner, _fill(colors.bleu.withValues(alpha: 0.10)));
    final lattice = _stroke(colors.bleu, 1.6);
    for (var d = -60.0; d <= 140; d += 8) {
      canvas.drawLine(Offset(d, 20), Offset(d + 80, 100), lattice);
      canvas.drawLine(Offset(d + 80, 20), Offset(d, 100), lattice);
    }
    canvas.restore();
    canvas.drawPath(_archAt(34, 86, 52, 96), _stroke(colors.bleu, 4));
    // Rebord ocre.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(28, 96, 64, 6),
        const Radius.circular(2),
      ),
      _fill(colors.ocre),
    );
    // Brin de jasmin qui retombe sur le côté.
    final stem = Path()
      ..moveTo(86, 34)
      ..quadraticBezierTo(102, 46, 98, 74);
    canvas.drawPath(stem, _stroke(colors.zitouna, 1.8));
    _leaf(canvas, const Offset(96, 50), 0.6, 5);
    _flower(canvas, const Offset(99, 62), 7);
    _flower(canvas, const Offset(97, 77), 6);
  }

  // Brin de jasmin : tiges, feuilles et quatre fleurs.
  void _jasmine(Canvas canvas) {
    final stem = _stroke(colors.zitouna, 2);
    canvas.drawPath(
      Path()
        ..moveTo(60, 112)
        ..quadraticBezierTo(56, 80, 48, 50),
      stem,
    );
    canvas.drawPath(
      Path()
        ..moveTo(55, 76)
        ..quadraticBezierTo(70, 60, 78, 40),
      stem,
    );
    canvas.drawPath(
      Path()
        ..moveTo(57, 92)
        ..quadraticBezierTo(48, 86, 38, 80),
      stem,
    );
    canvas.drawPath(
      Path()
        ..moveTo(58, 98)
        ..quadraticBezierTo(68, 86, 76, 74),
      stem,
    );
    _leaf(canvas, const Offset(52, 66), -0.5, 7);
    _leaf(canvas, const Offset(66, 60), 0.9, 6);
    _leaf(canvas, const Offset(46, 86), -1.2, 6);
    _leaf(canvas, const Offset(64, 92), 0.7, 6);
    _flower(canvas, const Offset(48, 46), 13);
    _flower(canvas, const Offset(78, 37), 10);
    _flower(canvas, const Offset(37, 79), 9);
    _flower(canvas, const Offset(77, 72), 8);
  }

  // Feuille : ovale vert incliné de [angle] radians.
  void _leaf(Canvas canvas, Offset at, double angle, double length) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(angle);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: length * 2, height: length),
      _fill(colors.zitouna),
    );
    canvas.restore();
  }

  // Fleur de jasmin : cinq pétales et un cœur ocre.
  void _flower(Canvas canvas, Offset at, double r) {
    final fill = _fill(petal);
    final edge = _stroke(colors.secondaire, 0.8);
    for (var i = 0; i < 5; i++) {
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(i * 2 * math.pi / 5);
      final oval = Rect.fromCenter(
        center: Offset(0, -r * 0.5),
        width: r * 0.62,
        height: r,
      );
      canvas.drawOval(oval, fill);
      canvas.drawOval(oval, edge);
      canvas.restore();
    }
    canvas.drawCircle(at, r * 0.2, _fill(colors.ocre));
  }

  @override
  bool shouldRepaint(_SidiBouPainter old) =>
      old.motif != motif || old.colors != colors || old.petal != petal;
}
