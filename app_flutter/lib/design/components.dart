import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'controls.dart';
import 'glyphs.dart';
import 'tokens.g.dart';
import 'type.dart';

int bandColorIndex(int band) => band.clamp(0, 3);

Color bandColor(int band) => switch (bandColorIndex(band)) {
  0 => CullTokens.hoardFresh,
  1 => CullTokens.hoardStale,
  2 => CullTokens.hoardRotting,
  _ => CullTokens.hoardGraveyard,
};

Color bandGraphic(int band) => switch (bandColorIndex(band)) {
  0 => CullTokens.hoardFreshGraphic,
  1 => CullTokens.hoardStaleGraphic,
  2 => CullTokens.hoardRottingGraphic,
  _ => CullTokens.hoardGraveyardGraphic,
};

String bandName(int band) => switch (bandColorIndex(band)) {
  0 => 'fresh',
  1 => 'stale',
  2 => 'rotting',
  _ => 'graveyard',
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

Color categoryText(String category) => switch (category) {
  'to-build' => CullTokens.catToBuildText,
  'inspiration' => CullTokens.catInspirationText,
  'tool hoard' => CullTokens.catToolHoardText,
  'watch later' => CullTokens.catWatchLaterText,
  'productivity porn' => CullTokens.catProductivityPornText,
  'self-callout' => CullTokens.catSelfCalloutText,
  'rotting' => CullTokens.catRottingText,
  _ => CullTokens.catReferenceText,
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
    this.level = 1,
    this.padding = const EdgeInsets.all(CullTokens.spaceLg),
  });

  final Widget child;
  final VoidCallback? onTap;
  final int level;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return CullSurface(
      onTap: onTap,
      padding: padding,
      background: switch (level) {
        2 => CullTokens.surface2,
        3 => CullTokens.surface3,
        4 => CullTokens.surface4,
        _ => CullTokens.surface1,
      },
      child: child,
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
          horizontal: dense ? CullTokens.spaceSm : CullTokens.spaceMd,
          vertical: dense ? 3 : 5,
        ),
        decoration: BoxDecoration(
          color: surface ?? color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(CullTokens.radiusPill),
        ),
        child: Text(
          label,
          style: (dense ? CullType.monoXs : CullType.monoS).copyWith(
            color: color,
          ),
        ),
      ),
    );
  }
}

class CategoryPill extends StatelessWidget {
  const CategoryPill({super.key, required this.category, this.dense = false});

  final String category;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return CullTag(
      label: category,
      foreground: categoryText(category),
      background: categorySurface(category),
      dense: dense,
      leading: SizedBox.square(
        dimension: dense ? 5 : 6,
        child: CustomPaint(painter: _DotPainter(categoryColor(category))),
      ),
    );
  }
}

class _DotPainter extends CustomPainter {
  const _DotPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      size.center(Offset.zero),
      size.shortestSide / 2,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_DotPainter old) => old.color != color;
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
    final shown = score.roundToDouble();
    return Semantics(
      label: 'Hoard score $shown out of 100, ${bandName(band)}',
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: shown),
          duration: CullTokens.motionSettle,
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => CustomPaint(
            painter: _DialPainter(value / 100, bandGraphic(band)),
            child: Center(
              child: Text(
                value.round().toString(),
                style: CullType.monoL.copyWith(
                  color: bandGraphic(band),
                  fontSize: size * 0.3,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  const _DialPainter(this.fraction, this.color);

  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 4.0;
    final rect =
        Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);

    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = CullTokens.surface3,
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * fraction,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: CullTokens.spaceSm),
        ],
        Expanded(child: Text(text, style: CullType.bodyS)),
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
  const _BlobPainter(this.opacity);

  final double opacity;

  static const _washes = <(double, double, double, Color)>[
    (-0.15, -0.10, 0.55, CullTokens.blobA),
    (0.85, 0.05, 0.45, CullTokens.blobB),
    (0.35, 0.95, 0.50, CullTokens.blobC),
    (0.05, 0.35, 0.35, CullTokens.blobD),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));
    for (final (x, y, scale, color) in _washes) {
      final centre = Offset(size.width * x, size.height * y);
      final radius = size.shortestSide * scale;
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: 0.5 * opacity),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: centre, radius: radius)),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BlobPainter old) => old.opacity != opacity;
}

class RoastCard extends StatelessWidget {
  const RoastCard({
    super.key,
    required this.line,
    this.tone = RoastAccent.blunt,
    this.loud = false,
  });

  final String line;
  final RoastAccent tone;
  final bool loud;

  @override
  Widget build(BuildContext context) {
    final accent = switch (tone) {
      RoastAccent.soft => CullTokens.success,
      RoastAccent.savage => CullTokens.danger,
      RoastAccent.blunt => CullTokens.signalDim,
    };

    if (!loud) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 2, height: 18, child: ColoredBox(color: accent)),
          const SizedBox(width: CullTokens.spaceMd),
          Expanded(
            child: Text(
              line,
              style: CullType.bodyM.copyWith(color: CullTokens.inkSecondary),
            ),
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(CullTokens.spaceXl),
      decoration: BoxDecoration(
        color: CullTokens.signalDeep,
        borderRadius: BorderRadius.circular(CullTokens.radiusLg),
        border: Border(left: BorderSide(color: accent, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('WORTH SAYING', style: CullType.monoXs.copyWith(color: accent)),
          const SizedBox(height: CullTokens.spaceSm),
          Text(
            line,
            style: CullType.titleL.copyWith(color: CullTokens.inkInverse),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CullTokens.spaceSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 34,
            decoration: BoxDecoration(
              color: CullTokens.inkDisabled,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: CullTokens.spaceMd),
          Expanded(
            child: Text(
              text,
              style: CullType.bodyL.copyWith(color: CullTokens.inkTertiary),
            ),
          ),
        ],
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel({super.key, required this.text, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: CullTokens.spaceXl),
      child: Row(
        children: [
          Text(
            text.toUpperCase(),
            style: CullType.monoXs.copyWith(color: CullTokens.inkTertiary),
          ),
          const SizedBox(width: CullTokens.spaceMd),
          Expanded(
            child: SizedBox(
              height: 1,
              child: ColoredBox(
                color: CullTokens.inkDisabled.withValues(alpha: 0.4),
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: CullTokens.spaceMd),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class CullRow extends StatelessWidget {
  const CullRow({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.dense = false,
  });

  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return CullSurface(
      onTap: onTap,
      radius: CullTokens.radiusMd,
      padding: EdgeInsets.symmetric(
        horizontal: CullTokens.spaceLg,
        vertical: dense ? CullTokens.spaceMd : CullTokens.spaceLg,
      ),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: CullTokens.spaceMd),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: CullType.titleM),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: CullType.bodyS),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: CullTokens.spaceMd),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class CullGlyphButton extends StatelessWidget {
  const CullGlyphButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.color,
    this.size = 20,
  });

  final CullIcon icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CullIconButton(
      label: label,
      onPressed: onPressed,
      size: size,
      icon: CullGlyph(icon, color: color ?? CullTokens.inkSecondary),
    );
  }
}
