import 'package:flutter/material.dart';

import '../data/hoard_repository.dart';
import '../design/components.dart';
import '../design/tokens.g.dart';
import '../engine/cull_ffi.dart';

class DetailScreen extends StatelessWidget {
  const DetailScreen({
    super.key,
    required this.link,
    required this.repository,
  });

  final Link link;
  final HoardRepository repository;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Link'),
        actions: [
          IconButton(
            tooltip: 'Cull this link',
            onPressed: () async {
              await repository.cull(link.id);
              if (context.mounted) Navigator.of(context).maybePop();
            },
            icon: const Icon(Icons.delete_outline, color: CullTokens.danger),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(CullTokens.spaceMd),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  link.title.isEmpty ? link.url : link.title,
                  style: t.textTheme.headlineMedium,
                ),
              ),
              const SizedBox(width: CullTokens.spaceMd),
              ScoreDial(score: link.hoardScore, band: link.band),
            ],
          ),
          const SizedBox(height: CullTokens.spaceSm),
          Text(link.url, style: t.textTheme.labelSmall),
          const SizedBox(height: CullTokens.spaceMd),
          Wrap(
            spacing: CullTokens.spaceXs,
            runSpacing: CullTokens.spaceXs,
            children: [
              Pill(
                label: link.category,
                color: categoryColor(link.category),
                surface: categorySurface(link.category),
              ),
              Pill(
                label: link.bandLabel,
                color: bandColor(link.band),
              ),
              Pill(
                label: '${link.ageDays} days old',
                color: CullTokens.inkTertiary,
              ),
              if (link.duplicateCount > 0)
                Pill(
                  label: 'saved ${link.duplicateCount + 1} times',
                  color: CullTokens.warn,
                ),
              if (link.openCount > 0)
                Pill(
                  label: 'opened ${link.openCount}x',
                  color: CullTokens.inkTertiary,
                ),
            ],
          ),
          const SizedBox(height: CullTokens.spaceLg),
          Text('Why it scored that', style: t.textTheme.titleMedium),
          const SizedBox(height: CullTokens.spaceSm),
          GlassCard(
            level: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ScoreExplanation(
                  text: link.explanation,
                  leading: const Icon(
                    Icons.schedule,
                    size: CullTokens.spaceMd,
                    color: CullTokens.inkTertiary,
                  ),
                ),
                const SizedBox(height: CullTokens.spaceSm),
                ScoreExplanation(
                  text: 'Actionability ${link.actionability.toStringAsFixed(2)} '
                      'on a 0 to 1 scale. Near zero means nothing here tells you '
                      'what to do next.',
                  leading: const Icon(
                    Icons.bolt_outlined,
                    size: CullTokens.spaceMd,
                    color: CullTokens.inkTertiary,
                  ),
                ),
              ],
            ),
          ),
          if (link.excerpt.isNotEmpty) ...[
            const SizedBox(height: CullTokens.spaceLg),
            Text('Excerpt', style: t.textTheme.titleMedium),
            const SizedBox(height: CullTokens.spaceSm),
            Text(link.excerpt, style: t.textTheme.bodyLarge),
          ],
          const SizedBox(height: CullTokens.spaceXl),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open the link'),
          ),
        ],
      ),
    );
  }
}
