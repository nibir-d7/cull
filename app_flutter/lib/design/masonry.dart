import 'package:flutter/widgets.dart';

import 'components.dart';
import 'controls.dart';
import 'glyphs.dart';
import 'tokens.g.dart';
import 'type.dart';

class MasonryHoard extends StatelessWidget {
  const MasonryHoard({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.heightFor,
    this.columns,
    this.spacing = CullTokens.spaceSm,
  });

  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final double Function(BuildContext context, int index)? heightFor;
  final int? columns;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final total = constraints.maxWidth;
        final cols = columns ?? (total >= CullTokens.spaceN5xl ? 3 : 2);
        final colWidth = (total - spacing * (cols - 1)) / cols;
        final lanes = List.generate(cols, (i) => <Widget>[]);
        final heights = List<double>.filled(cols, 0);

        for (var i = 0; i < itemCount; i++) {
          final lane = _shortest(heights);
          lanes[lane].add(
            Padding(
              padding: EdgeInsets.only(bottom: spacing),
              child: SizedBox(width: colWidth, child: itemBuilder(context, i)),
            ),
          );
          heights[lane] += heightFor?.call(context, i) ?? 190.0;
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < cols; i++) ...[
              if (i > 0) SizedBox(width: spacing),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: lanes[i],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  static int _shortest(List<double> heights) {
    var best = 0;
    for (var i = 1; i < heights.length; i++) {
      if (heights[i] < heights[best]) best = i;
    }
    return best;
  }
}

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.accent,
  });

  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(CullTokens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: CullType.titleL.copyWith(
              color: accent ?? CullTokens.inkPrimary,
              fontFamily: CullTokens.fontMono,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: CullType.bodyS,
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.body,
    this.action,
  });

  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(CullTokens.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CullGlyph(
              CullIcon.inbox,
              size: 32,
              color: CullTokens.inkDisabled,
            ),
            const SizedBox(height: CullTokens.spaceMd),
            Text(title, textAlign: TextAlign.center, style: CullType.displayS),
            const SizedBox(height: CullTokens.spaceSm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                body,
                textAlign: TextAlign.center,
                style: CullType.bodyL,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: CullTokens.spaceLg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class HaulMeter extends StatelessWidget {
  const HaulMeter({super.key, required this.value, required this.label});

  final double value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final pct = value.clamp(0, 1) * 100;
    return Semantics(
      label: '$label, ${pct.round()} percent',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: CullType.bodyS),
          const SizedBox(height: CullTokens.spaceXs),
          CullBar(value: value, color: CullTokens.signalDim),
        ],
      ),
    );
  }
}
