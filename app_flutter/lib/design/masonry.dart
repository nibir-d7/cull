import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'components.dart';
import 'tokens.g.dart';

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
    final width = MediaQuery.of(context).size.width;
    final cols = columns ?? (width >= CullTokens.spaceN4xl ? 3 : 2);
    return LayoutBuilder(
      builder: (context, constraints) {
        final total = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : width;
        final colWidth = (total - spacing * (cols - 1)) / cols;
        final lanes = List.generate(cols, (i) => <Widget>[]);
        final heights = List<double>.filled(cols, 0);

        for (var i = 0; i < itemCount; i++) {
          final lane = _shortest(heights);
          lanes[lane].add(
            Padding(
              padding: EdgeInsets.only(bottom: spacing),
              child: SizedBox(
                width: colWidth,
                child: itemBuilder(context, i),
              ),
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
    final t = Theme.of(context);
    return GlassCard(
      level: 1,
      padding: const EdgeInsets.all(CullTokens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.textTheme.displaySmall?.copyWith(
              color: accent ?? CullTokens.inkPrimary,
              fontFamily: CullTokens.fontMono,
              fontSize: CullTokens.typeTitleLSize,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: t.textTheme.bodySmall,
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
    final t = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(CullTokens.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: CullTokens.spaceN2xl,
              color: CullTokens.inkDisabled,
            ),
            const SizedBox(height: CullTokens.spaceMd),
            Text(
              title,
              textAlign: TextAlign.center,
              style: t.textTheme.headlineMedium,
            ),
            const SizedBox(height: CullTokens.spaceSm),
            Text(body, textAlign: TextAlign.center, style: t.textTheme.bodyLarge),
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
    final t = Theme.of(context);
    final pct = (value.clamp(0, 1)) * 100;
    return Semantics(
      label: '$label, ${pct.round()} percent',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: t.textTheme.bodySmall),
          const SizedBox(height: CullTokens.spaceXs),
          LayoutBuilder(
            builder: (context, c) => Stack(
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: CullTokens.surface4,
                    borderRadius: BorderRadius.circular(CullTokens.radiusPill),
                  ),
                ),
                AnimatedContainer(
                  duration: CullTokens.motionSettle,
                  curve: CullTokens.curveEmphasized,
                  height: 6,
                  width: math.max(6, c.maxWidth * (value.clamp(0, 1))),
                  decoration: BoxDecoration(
                    color: CullTokens.signal,
                    borderRadius: BorderRadius.circular(CullTokens.radiusPill),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
