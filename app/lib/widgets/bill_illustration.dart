import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/motion/motion_access.dart';
import '../core/theme/split_colors.dart';
import 'avatar.dart';
import 'split_icon.dart';

/// Home's empty-state picture, drawn in the app icon's style: one receipt,
/// its lines in four friends' colours, each friend tied to the line they had.
/// The signature idea (a person's colour follows their items) in one image.
class BillIllustration extends StatefulWidget {
  const BillIllustration({super.key});

  static const size = Size(300, 220);

  /// Each friend: name, colour index, avatar top-left, and which receipt
  /// row is theirs.
  static const _friends = [
    ('Amaka', 0, Offset(26, 26), 0),
    ('Josh', 1, Offset(22, 146), 2),
    ('Dan', 2, Offset(238, 20), 1),
    ('Sam', 3, Offset(242, 142), 3),
  ];

  @override
  State<BillIllustration> createState() => _BillIllustrationState();
}

class _BillIllustrationState extends State<BillIllustration> with SingleTickerProviderStateMixin {
  static const _friends = BillIllustration._friends;

  /// Friends pop in one after another, once. A one-off, not a loop: Home is
  /// where the organiser comes back to, and a picture that never stops
  /// moving pulls the eye off the card above it. One controller, so nothing
  /// waits on a timer.
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: SplitDurations.long + SplitDurations.beat * (_friends.length - 1),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _pop.value = 1;
    } else if (!_pop.isAnimating && _pop.value == 0) {
      _pop.forward();
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  Widget _popIn(int i, Widget child) {
    final total = _pop.duration!.inMicroseconds;
    final start = (SplitDurations.beat * i).inMicroseconds / total;
    final end = start + SplitDurations.long.inMicroseconds / total;
    final t = CurvedAnimation(parent: _pop, curve: Interval(start, end.clamp(0, 1), curve: SplitSprings.gentle));
    return AnimatedBuilder(
      animation: t,
      builder: (_, child) => Opacity(
        opacity: t.value.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.6 + 0.4 * t.value, child: child),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = SplitColors.of(context);
    return Semantics(
      image: true,
      label: 'A receipt with each line tied to the friend who had it',
      excludeSemantics: true,
      child: SizedBox.fromSize(
        size: BillIllustration.size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _ReceiptPainter(
                  colours: c,
                  links: [for (final f in _friends) (f.$3 + const Offset(18, 18), f.$4, f.$2)],
                ),
              ),
            ),
            for (final (i, f) in _friends.indexed)
              Positioned(
                left: f.$3.dx,
                top: f.$3.dy,
                child: _popIn(
                  i,
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: c.surface, width: 3),
                          boxShadow: [BoxShadow(color: c.ink.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 3))],
                        ),
                        child: Avatar(name: f.$1, colourIndex: f.$2, size: 36),
                      ),
                      // Dan has paid: the moment the whole app builds to.
                      if (f.$1 == 'Dan')
                        Positioned(
                          right: -6,
                          bottom: -4,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: c.success,
                              shape: BoxShape.circle,
                              border: Border.all(color: c.surface, width: 2),
                            ),
                            alignment: Alignment.center,
                            child: SplitIcon(SplitIcons.check, size: 11, color: c.surface),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

}

class _ReceiptPainter extends CustomPainter {
  _ReceiptPainter({required this.colours, required this.links});

  final SplitColors colours;

  /// Avatar centre, receipt row, colour index.
  final List<(Offset, int, int)> links;

  static const _receipt = Size(118, 156);
  static const _tilt = -5 * math.pi / 180;
  static const _rowTop = 46.0;
  static const _rowGap = 22.0;
  static const _dotX = 16.0;

  @override
  void paint(Canvas canvas, Size size) {
    final c = colours;
    final centre = Offset(size.width / 2, size.height / 2);

    // The soft disc behind everything, as on the icon's blue.
    canvas.drawCircle(centre, 98, Paint()..color = c.primaryTint);

    // Sparkles.
    _sparkle(canvas, const Offset(280, 100), 7, c.highlight);
    _sparkle(canvas, const Offset(14, 104), 6, c.accentCyan);
    _sparkle(canvas, const Offset(196, 206), 5, c.primary);
    _sparkle(canvas, const Offset(104, 8), 4, c.highlight);

    // Receipt-space to canvas-space, so the strings land on the dots.
    final origin = centre - Offset(_receipt.width / 2, _receipt.height / 2);
    Offset toCanvas(Offset p) {
      final d = p + origin - centre;
      return centre +
          Offset(
            d.dx * math.cos(_tilt) - d.dy * math.sin(_tilt),
            d.dx * math.sin(_tilt) + d.dy * math.cos(_tilt),
          );
    }

    // Strings from each friend to their line, under the receipt's edge.
    for (final (from, row, colourIndex) in links) {
      final rowY = _rowTop + row * _rowGap;
      final onLeft = from.dx < centre.dx;
      final to = toCanvas(Offset(onLeft ? _dotX : _receipt.width - 14, rowY));
      final mid = Offset((from.dx + to.dx) / 2, from.dy + (to.dy - from.dy) * 0.8);
      final path = Path()
        ..moveTo(from.dx, from.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, to.dx, to.dy);
      _dashed(canvas, path, Paint()
        ..color = c.participant(colourIndex).fill
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round);
    }

    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.rotate(_tilt);
    canvas.translate(-_receipt.width / 2, -_receipt.height / 2);

    final w = _receipt.width;
    final h = _receipt.height;
    const tooth = 8.0;
    final paper = Path()
      ..moveTo(0, 12)
      ..quadraticBezierTo(0, 0, 12, 0)
      ..lineTo(w - 12, 0)
      ..quadraticBezierTo(w, 0, w, 12)
      ..lineTo(w, h);
    // Torn bottom edge.
    for (var x = w; x > 0; x -= tooth * 2) {
      paper
        ..lineTo(math.max(x - tooth, 0), h - tooth)
        ..lineTo(math.max(x - tooth * 2, 0), h);
    }
    paper.close();

    canvas.drawShadow(paper, c.ink.withValues(alpha: 0.35), 6, false);
    canvas.drawPath(paper, Paint()..color = c.surface);

    final bar = Paint()..strokeCap = StrokeCap.round..strokeWidth = 7;
    void line(double x1, double x2, double y, Color colour, {double width = 7}) {
      canvas.drawLine(Offset(x1, y), Offset(x2, y), bar..color = colour..strokeWidth = width);
    }

    // Header: the restaurant's name.
    line(w / 2 - 26, w / 2 + 26, 22, c.ink, width: 8);

    // Four lines, each in a friend's colour, each with a price.
    const lengths = [44.0, 58.0, 36.0, 50.0];
    for (var row = 0; row < 4; row++) {
      final y = _rowTop + row * _rowGap;
      final fill = c.participant(links.firstWhere((l) => l.$2 == row).$3).fill;
      canvas.drawCircle(Offset(_dotX, y), 4.5, Paint()..color = fill);
      line(28, 28 + lengths[row], y, c.line);
      line(w - 30, w - 14, y, fill);
    }

    // Dashed rule, then the total, which adds up.
    final rule = Paint()..color = c.line..strokeWidth = 1.5;
    for (var x = 12.0; x < w - 12; x += 8) {
      canvas.drawLine(Offset(x, 132), Offset(x + 4, 132), rule);
    }
    line(14, 44, 146, c.ink, width: 8);
    line(w - 40, w - 14, 146, c.success, width: 8);

    canvas.restore();
  }

  void _sparkle(Canvas canvas, Offset at, double r, Color colour) {
    final p = Path()
      ..moveTo(at.dx, at.dy - r)
      ..quadraticBezierTo(at.dx, at.dy, at.dx + r, at.dy)
      ..quadraticBezierTo(at.dx, at.dy, at.dx, at.dy + r)
      ..quadraticBezierTo(at.dx, at.dy, at.dx - r, at.dy)
      ..quadraticBezierTo(at.dx, at.dy, at.dx, at.dy - r)
      ..close();
    canvas.drawPath(p, Paint()..color = colour);
  }

  void _dashed(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 9) {
        canvas.drawPath(metric.extractPath(d, math.min(d + 5, metric.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_ReceiptPainter old) => old.colours != colours;
}
