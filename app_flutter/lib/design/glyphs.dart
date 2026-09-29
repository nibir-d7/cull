import 'dart:math' as math;

import 'package:flutter/widgets.dart';

enum CullIcon {
  refresh,
  search,
  trash,
  sweep,
  dot,
  dotFilled,
  open,
  forward,
  external,
  check,
  ring,
  phone,
  cloudOff,
  muted,
  inbox,
  layers,
  add,
  settings,
  flame,
  clock,
  bolt,
  close,
  share,
}

class _Glyph {
  const _Glyph(this.paint);

  final void Function(Canvas canvas, Paint paint, double s) paint;
}

const Map<CullIcon, _Glyph> _glyphs = {
  CullIcon.refresh: _Glyph(_refresh),
  CullIcon.search: _Glyph(_search),
  CullIcon.trash: _Glyph(_trash),
  CullIcon.sweep: _Glyph(_sweep),
  CullIcon.dot: _Glyph(_dot),
  CullIcon.dotFilled: _Glyph(_dotFilled),
  CullIcon.open: _Glyph(_open),
  CullIcon.forward: _Glyph(_forward),
  CullIcon.external: _Glyph(_external),
  CullIcon.check: _Glyph(_check),
  CullIcon.ring: _Glyph(_ring),
  CullIcon.phone: _Glyph(_phone),
  CullIcon.cloudOff: _Glyph(_cloudOff),
  CullIcon.muted: _Glyph(_muted),
  CullIcon.inbox: _Glyph(_inbox),
  CullIcon.layers: _Glyph(_layers),
  CullIcon.add: _Glyph(_add),
  CullIcon.settings: _Glyph(_settings),
  CullIcon.flame: _Glyph(_flame),
  CullIcon.clock: _Glyph(_clock),
  CullIcon.bolt: _Glyph(_bolt),
  CullIcon.close: _Glyph(_close),
  CullIcon.share: _Glyph(_share),
};

void _refresh(Canvas c, Paint p, double s) {
  c.drawArc(
    Rect.fromCircle(center: Offset(s / 2, s / 2), radius: s * 0.3),
    -math.pi * 0.75,
    math.pi * 1.5,
    false,
    p,
  );
  final tip = Path()
    ..moveTo(s * 0.7, s * 0.06)
    ..lineTo(s * 0.78, s * 0.24)
    ..lineTo(s * 0.6, s * 0.2)
    ..close();
  c.drawPath(tip, p);
}

void _search(Canvas c, Paint p, double s) {
  c.drawCircle(Offset(s * 0.44, s * 0.44), s * 0.28, p);
  c.drawLine(Offset(s * 0.65, s * 0.65), Offset(s * 0.9, s * 0.9), p);
}

void _trash(Canvas c, Paint p, double s) {
  c.drawLine(Offset(s * 0.24, s * 0.32), Offset(s * 0.76, s * 0.32), p);
  c.drawRRect(
    RRect.fromLTRBR(
      s * 0.3,
      s * 0.32,
      s * 0.7,
      s * 0.88,
      Radius.circular(s * 0.06),
    ),
    p,
  );
  c.drawLine(Offset(s * 0.42, s * 0.32), Offset(s * 0.42, s * 0.22), p);
  c.drawLine(Offset(s * 0.42, s * 0.22), Offset(s * 0.58, s * 0.22), p);
  c.drawLine(Offset(s * 0.58, s * 0.22), Offset(s * 0.58, s * 0.32), p);
}

void _sweep(Canvas c, Paint p, double s) {
  c.drawLine(Offset(s * 0.5, s * 0.12), Offset(s * 0.5, s * 0.6), p);
  c.drawLine(Offset(s * 0.34, s * 0.46), Offset(s * 0.5, s * 0.64), p);
  c.drawLine(Offset(s * 0.66, s * 0.46), Offset(s * 0.5, s * 0.64), p);
  c.drawRRect(
    RRect.fromLTRBR(
      s * 0.18,
      s * 0.72,
      s * 0.82,
      s * 0.88,
      Radius.circular(s * 0.07),
    ),
    p,
  );
}

void _dot(Canvas c, Paint p, double s) {
  c.drawCircle(Offset(s / 2, s / 2), s * 0.26, p);
}

void _dotFilled(Canvas c, Paint p, double s) {
  c.drawCircle(Offset(s / 2, s / 2), s * 0.26, Paint()..color = p.color);
}

void _open(Canvas c, Paint p, double s) {
  c.drawCircle(Offset(s * 0.44, s * 0.44), s * 0.3, p);
  c.drawLine(Offset(s * 0.66, s * 0.66), Offset(s * 0.92, s * 0.92), p);
}

void _forward(Canvas c, Paint p, double s) {
  c.drawLine(Offset(s * 0.16, s / 2), Offset(s * 0.78, s / 2), p);
  final head = Path()
    ..moveTo(s * 0.56, s * 0.26)
    ..lineTo(s * 0.84, s / 2)
    ..lineTo(s * 0.56, s * 0.74)
    ..close();
  c.drawPath(head, p);
}

void _external(Canvas c, Paint p, double s) {
  c.drawLine(Offset(s * 0.18, s * 0.82), Offset(s * 0.74, s * 0.26), p);
  final head = Path()
    ..moveTo(s * 0.42, s * 0.24)
    ..lineTo(s * 0.78, s * 0.24)
    ..lineTo(s * 0.78, s * 0.6);
  c.drawPath(head, p);
}

void _check(Canvas c, Paint p, double s) {
  final path = Path()
    ..moveTo(s * 0.18, s * 0.52)
    ..lineTo(s * 0.42, s * 0.74)
    ..lineTo(s * 0.84, s * 0.28);
  c.drawPath(path, p);
}

void _ring(Canvas c, Paint p, double s) {
  c.drawCircle(Offset(s / 2, s / 2), s * 0.34, p);
  c.drawCircle(Offset(s / 2, s / 2), s * 0.1, p);
}

void _phone(Canvas c, Paint p, double s) {
  c.drawRRect(
    RRect.fromLTRBR(
      s * 0.3,
      s * 0.1,
      s * 0.7,
      s * 0.9,
      Radius.circular(s * 0.08),
    ),
    p,
  );
  c.drawLine(Offset(s * 0.44, s * 0.78), Offset(s * 0.56, s * 0.78), p);
}

void _cloudOff(Canvas c, Paint p, double s) {
  final cloud = Path()
    ..moveTo(s * 0.24, s * 0.66)
    ..arcToPoint(Offset(s * 0.32, s * 0.4), radius: Radius.circular(s * 0.16))
    ..arcToPoint(Offset(s * 0.64, s * 0.4), radius: Radius.circular(s * 0.16))
    ..arcToPoint(Offset(s * 0.72, s * 0.66), radius: Radius.circular(s * 0.12))
    ..close();
  c.drawPath(cloud, p);
  c.drawLine(Offset(s * 0.14, s * 0.86), Offset(s * 0.86, s * 0.14), p);
}

void _muted(Canvas c, Paint p, double s) {
  c.drawCircle(Offset(s / 2, s / 2), s * 0.36, p);
  c.drawLine(Offset(s * 0.62, s * 0.38), Offset(s * 0.86, s * 0.14), p);
}

void _inbox(Canvas c, Paint p, double s) {
  c.drawRRect(
    RRect.fromLTRBR(
      s * 0.14,
      s * 0.24,
      s * 0.86,
      s * 0.8,
      Radius.circular(s * 0.08),
    ),
    p,
  );
  c.drawLine(Offset(s * 0.14, s * 0.56), Offset(s * 0.38, s * 0.56), p);
  c.drawLine(Offset(s * 0.62, s * 0.56), Offset(s * 0.86, s * 0.56), p);
}

void _layers(Canvas c, Paint p, double s) {
  for (var i = 0; i < 3; i++) {
    final y = s * (0.28 + i * 0.18);
    final path = Path()
      ..moveTo(s * 0.5, y - s * 0.1)
      ..lineTo(s * 0.84, y)
      ..lineTo(s * 0.5, y + s * 0.1)
      ..lineTo(s * 0.16, y)
      ..close();
    c.drawPath(path, p);
  }
}

void _add(Canvas c, Paint p, double s) {
  c.drawLine(Offset(s / 2, s * 0.2), Offset(s / 2, s * 0.8), p);
  c.drawLine(Offset(s * 0.2, s / 2), Offset(s * 0.8, s / 2), p);
}

void _settings(Canvas c, Paint p, double s) {
  c.drawCircle(Offset(s / 2, s / 2), s * 0.3, p);
  for (var i = 0; i < 6; i++) {
    final a = i * math.pi / 3;
    c.drawLine(
      Offset(s / 2 + math.cos(a) * s * 0.36, s / 2 + math.sin(a) * s * 0.36),
      Offset(s / 2 + math.cos(a) * s * 0.46, s / 2 + math.sin(a) * s * 0.46),
      p,
    );
  }
}

void _flame(Canvas c, Paint p, double s) {
  final path = Path()
    ..moveTo(s * 0.5, s * 0.12)
    ..cubicTo(s * 0.78, s * 0.4, s * 0.82, s * 0.66, s * 0.5, s * 0.86)
    ..cubicTo(s * 0.18, s * 0.66, s * 0.22, s * 0.4, s * 0.5, s * 0.12)
    ..close();
  c.drawPath(path, p);
}

void _clock(Canvas c, Paint p, double s) {
  c.drawCircle(Offset(s / 2, s / 2), s * 0.36, p);
  c.drawLine(Offset(s / 2, s * 0.5), Offset(s / 2, s * 0.3), p);
  c.drawLine(Offset(s / 2, s * 0.5), Offset(s * 0.66, s * 0.58), p);
}

void _bolt(Canvas c, Paint p, double s) {
  final path = Path()
    ..moveTo(s * 0.56, s * 0.1)
    ..lineTo(s * 0.3, s * 0.54)
    ..lineTo(s * 0.5, s * 0.54)
    ..lineTo(s * 0.44, s * 0.9)
    ..lineTo(s * 0.72, s * 0.44)
    ..lineTo(s * 0.52, s * 0.44)
    ..close();
  c.drawPath(path, p);
}

void _close(Canvas c, Paint p, double s) {
  c.drawLine(Offset(s * 0.24, s * 0.24), Offset(s * 0.76, s * 0.76), p);
  c.drawLine(Offset(s * 0.76, s * 0.24), Offset(s * 0.24, s * 0.76), p);
}

void _share(Canvas c, Paint p, double s) {
  c.drawRRect(
    RRect.fromLTRBR(
      s * 0.2,
      s * 0.14,
      s * 0.8,
      s * 0.5,
      Radius.circular(s * 0.08),
    ),
    p,
  );
  final tail = Path()
    ..moveTo(s * 0.32, s * 0.5)
    ..lineTo(s * 0.32, s * 0.88)
    ..lineTo(s * 0.68, s * 0.88)
    ..lineTo(s * 0.68, s * 0.5);
  c.drawPath(tail, p);
}

class CullGlyph extends StatelessWidget {
  const CullGlyph(
    this.icon, {
    super.key,
    this.size = 24,
    this.color = const Color(0xFF14201D),
    this.weight = 2,
  });

  final CullIcon icon;
  final double size;
  final Color color;
  final double weight;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _GlyphPainter(_glyphs[icon]!, color, weight * (size / 24)),
        isComplex: false,
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter(this.glyph, this.color, this.stroke);

  final _Glyph glyph;
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    glyph.paint(canvas, paint, size.shortestSide);
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.glyph != glyph || old.color != color || old.stroke != stroke;
}
