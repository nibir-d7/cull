import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'tokens.g.dart';

int bandColorIndex(int band) => band.clamp(0, 3);

Color bandColor(int band) => switch (bandColorIndex(band)) {
  0 => CullTokens.hoardFresh,
  1 => CullTokens.hoardStale,
  2 => CullTokens.hoardRotting,
  _ => CullTokens.hoardGraveyard,
};

Color categoryColor(String category) => switch (category) {
  'to-build' => CullTokens.catToBuild,
  'inspiration' => CullTokens.catInspiration,
  'tool hoard' => CullTokens.catToolHoard,
  'watch later' => CullTokens.catWatchLater,
  'productivity porn' => CullTokens.catProductivityPorn,
  'self-callout' => CullTokens.catSelfCallout,
  'rotting' => CullTokens.catRotting,
  _ => CullTokens.catReference,
};

Color categorySurface(String category) => switch (category) {
  'to-build' => CullTokens.catToBuildSurface,
  'inspiration' => CullTokens.catInspirationSurface,
  'tool hoard' => CullTokens.catToolHoardSurface,
  'watch later' => CullTokens.catWatchLaterSurface,
  'productivity porn' => CullTokens.catProductivityPornSurface,
  'self-callout' => CullTokens.catSelfCalloutSurface,
  'rotting' => CullTokens.catRottingSurface,
  _ => CullTokens.catReferenceSurface,
};

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.onTap,
    this.level = 2,
    this.padding = const EdgeInsets.all(CullTokens.spaceMd),
  });

  final Widget child;
  final VoidCallback? onTap;
  final int level;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(CullTokens.radiusLg);
    final body = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: switch (level) {
          1 => CullTokens.surface1,
          3 => CullTokens.surface3,
          4 => CullTokens.surface4,
          _ => CullTokens.surface2,
        },
        borderRadius: radius,
        border: Border.all(color: CullTokens.surface4),
        boxShadow: switch (level) {
          1 => CullTokens.glassLevel1Shadow,
          3 => CullTokens.glassLevel3Shadow,
          4 => CullTokens.glassLevel4Shadow,
          _ => CullTokens.glassLevel2Shadow,
        },
      ),
      child: child,
    );

    if (onTap == null) return body;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: body,
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.label,
    required this.color,
    this.surface,
    this.dense = false,
  });

  final String label;
  final Color color;
  final Color? surface;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: dense ? CullTokens.spaceXs : CullTokens.spaceSm,
          vertical: dense ? 2 : CullTokens.spaceXs,
        ),
        decoration: BoxDecoration(
          color: surface ?? color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(CullTokens.radiusPill),
          border: Border.all(color: color.withValues(alpha: 0.55)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: dense ? CullTokens.typeMonoXsSize : CullTokens.typeMonoSSize,
            fontWeight: FontWeight.w500,
            letterSpacing: CullTokens.typeMonoSTracking,
            fontFamily: CullTokens.fontMono,
          ),
        ),
      ),
    );
  }
}

class ScoreDial extends StatelessWidget {
  const ScoreDial({
    super.key,
    required this.score,
    required this.band,
    this.size = CullTokens.spaceN3xl,
  });

  final double score;
  final int band;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = bandColor(band);
    final shown = score.roundToDouble();
    return Semantics(
      label: 'Hoard score $shown out of 100, ${_bandName(band)}',
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: shown),
          duration: CullTokens.motionSettle,
          curve: CullTokens.curveEmphasized,
          builder: (context, value, _) => CustomPaint(
            painter: _DialPainter(value / 100, color),
            child: Center(
              child: Text(
                value.round().toString(),
                style: TextStyle(
                  color: color,
                  fontSize: size * 0.32,
                  fontFamily: CullTokens.fontMono,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _bandName(int band) => switch (bandColorIndex(band)) {
    0 => 'fresh',
    1 => 'stale',
    2 => 'rotting',
    _ => 'graveyard',
  };
}

class _DialPainter extends CustomPainter {
  _DialPainter(this.fraction, this.color);

  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 4.0;
    final rect = Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = CullTokens.surface4;
    canvas.drawArc(rect, 0, math.pi * 2, false, track);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * fraction, false, arc);
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.fraction != fraction || old.color != color;
}

class ScoreExplanation extends StatelessWidget {
  const ScoreExplanation({super.key, required this.text, this.leading});

  final String text;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: CullTokens.spaceSm)],
        Expanded(
          child: Text(text, style: t.textTheme.bodySmall),
        ),
      ],
    );
  }
}

class BlobBackground extends StatelessWidget {
  const BlobBackground({super.key, this.child, this.opacity = 0.5});

  final Widget? child;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _BlobPainter(opacity)),
          ),
        ),
        if (child != null) Positioned.fill(child: child!),
      ],
    );
  }
}

class _BlobPainter extends CustomPainter {
  _BlobPainter(this.opacity);

  final double opacity;

  static const _blobs = <(double, double, double, Color)>[
    (-0.15, -0.10, 0.55, CullTokens.blobA),
    (0.85, 0.05, 0.45, CullTokens.blobB),
    (0.35, 0.95, 0.50, CullTokens.blobC),
    (0.05, 0.35, 0.35, CullTokens.blobD),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.save();
    canvas.clipRect(rect);
    for (final (x, y, scale, color) in _blobs) {
      final centre = Offset(size.width * x, size.height * y);
      final radius = size.shortestSide * scale;
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: 0.30 * opacity), color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: centre, radius: radius));
      canvas.drawCircle(centre, radius, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BlobPainter old) => old.opacity != opacity;
}

class RoastCard extends StatelessWidget {
  const RoastCard({super.key, required this.line, this.tone = RoastAccent.blunt});

  final String line;
  final RoastAccent tone;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final accent = switch (tone) {
      RoastAccent.soft => CullTokens.success,
      RoastAccent.savage => CullTokens.danger,
      RoastAccent.blunt => CullTokens.signal,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(CullTokens.spaceLg),
      decoration: BoxDecoration(
        color: CullTokens.canvasDeep,
        borderRadius: BorderRadius.circular(CullTokens.radiusLg),
        border: Border(left: BorderSide(color: accent, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WEEKLY ROAST',
            style: t.textTheme.labelLarge?.copyWith(
              color: accent,
              fontFamily: CullTokens.fontMono,
              letterSpacing: CullTokens.typeLabelTracking,
            ),
          ),
          const SizedBox(height: CullTokens.spaceSm),
          Text(
            line,
            style: t.textTheme.displaySmall?.copyWith(
              fontSize: CullTokens.typeTitleLSize,
              height: CullTokens.typeTitleLLineHeight,
            ),
          ),
        ],
      ),
    );
  }
}

enum RoastAccent { soft, blunt, savage }

class PullQuote extends StatelessWidget {
  const PullQuote({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CullTokens.spaceSm),
      child: Text(
        text,
        style: t.textTheme.bodyLarge?.copyWith(
          fontStyle: FontStyle.italic,
          color: CullTokens.inkTertiary,
        ),
      ),
    );
  }
}
