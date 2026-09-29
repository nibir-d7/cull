import 'package:flutter/material.dart';

import '../data/hoard_repository.dart';
import '../design/components.dart';
import '../design/tokens.g.dart';
import '../engine/cull_ffi.dart';

class RoastScreen extends StatefulWidget {
  const RoastScreen({super.key, required this.repository});

  final HoardRepository repository;

  @override
  State<RoastScreen> createState() => _RoastScreenState();
}

class _RoastScreenState extends State<RoastScreen> {
  late Future<CullReport> _report = widget.repository.report();

  void _reload() {
    setState(() => _report = widget.repository.report());
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('The roast'),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload',
          ),
        ],
      ),
      body: FutureBuilder<CullReport>(
        future: _report,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: CullTokens.signal),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(CullTokens.spaceXl),
                child: Text(
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: t.textTheme.bodyLarge,
                ),
              ),
            );
          }
          final report = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(CullTokens.spaceMd),
            children: [
              RoastCard(line: report.headline),
              const SizedBox(height: CullTokens.spaceMd),
              Text(
                'Week ${report.week}',
                style: t.textTheme.labelSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: CullTokens.spaceLg),
              Row(
                children: [
                  Expanded(
                    child: _Stat(
                      label: 'Links',
                      value: '${report.total}',
                    ),
                  ),
                  const SizedBox(width: CullTokens.spaceSm),
                  Expanded(
                    child: _Stat(
                      label: 'Rotting',
                      value: '${report.culled}',
                      accent: CullTokens.warn,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: CullTokens.spaceLg),
              if (report.proposals.isEmpty) ...[
                Text(
                  'Nothing to propose this week. Either you are reading things, '
                  'or you saved very little. Both are worth celebrating, briefly.',
                  style: t.textTheme.bodyLarge,
                ),
              ] else ...[
                Text('What we are proposing', style: t.textTheme.titleMedium),
                const SizedBox(height: CullTokens.spaceSm),
                for (final p in report.proposals)
                  Padding(
                    padding: const EdgeInsets.only(bottom: CullTokens.spaceMd),
                    child: _ProposalCard(proposal: p),
                  ),
                const SizedBox(height: CullTokens.spaceMd),
                FilledButton(
                  onPressed: report.culled == 0 ? null : () {},
                  child: Text(report.cta),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.accent});

  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final color = accent ?? CullTokens.inkPrimary;
    return GlassCard(
      level: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: t.textTheme.displaySmall?.copyWith(
              color: color,
              fontFamily: CullTokens.fontMono,
              fontSize: CullTokens.typeDisplayMSize,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: t.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ProposalCard extends StatelessWidget {
  const _ProposalCard({required this.proposal});

  final Proposal proposal;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Pill(
                label: proposal.category.isEmpty
                    ? 'group'
                    : proposal.category,
                color: proposal.category.isEmpty
                    ? CullTokens.inkSecondary
                    : categoryColor(proposal.category),
              ),
              const Spacer(),
              Text(
                '${proposal.count} link${proposal.count == 1 ? '' : 's'}',
                style: t.textTheme.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: CullTokens.spaceSm),
          Text(
            proposal.line,
            style: t.textTheme.titleLarge?.copyWith(
              fontFamily: CullTokens.fontDisplay,
              fontFamilyFallback: CullTokens.fontDisplayFallback,
            ),
          ),
          if (proposal.titles.isNotEmpty) ...[
            const SizedBox(height: CullTokens.spaceSm),
            for (final title in proposal.titles.take(5))
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.textTheme.bodySmall,
                ),
              ),
            if (proposal.titles.length > 5)
              Text(
                'and ${proposal.titles.length - 5} more',
                style: t.textTheme.labelSmall,
              ),
          ],
        ],
      ),
    );
  }
}

class ForgeScreen extends StatelessWidget {
  const ForgeScreen({super.key, required this.repository, this.onUnlocked});

  final HoardRepository repository;
  final VoidCallback? onUnlocked;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Forge')),
      body: ListView(
        padding: const EdgeInsets.all(CullTokens.spaceMd),
        children: [
          Text('Everything is free.', style: t.textTheme.headlineMedium),
          const SizedBox(height: CullTokens.spaceSm),
          Text(
            'Scoring, categorising, duplicates, search, the graveyard and the '
            'weekly roast. All of it. There is nothing locked and nothing to buy.',
            style: t.textTheme.bodyLarge,
          ),
          const SizedBox(height: CullTokens.spaceLg),
          const RoastCard(
            line: 'Paying us money would not make you read more links.',
            tone: RoastAccent.blunt,
          ),
          const SizedBox(height: CullTokens.spaceLg),
          Text('Savage, for people who want it', style: t.textTheme.titleMedium),
          const SizedBox(height: CullTokens.spaceSm),
          GlassCard(
            level: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ScoreExplanation(
                  text: 'The harshest tone available. It names the number, the '
                      'age, and the pattern, and it does not apologise.',
                  leading: const Icon(
                    Icons.local_fire_department_outlined,
                    size: CullTokens.spaceMd,
                    color: CullTokens.danger,
                  ),
                ),
                const SizedBox(height: CullTokens.spaceSm),
                ScoreExplanation(
                  text: 'Soft and Blunt are the free tiers and are not '
                      'watered down. Savage is just more of the same, louder.',
                  leading: const Icon(
                    Icons.volume_up_outlined,
                    size: CullTokens.spaceMd,
                    color: CullTokens.inkTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: CullTokens.spaceLg),
          OutlinedButton.icon(
            onPressed: () async {
              await repository.setTone(2);
              onUnlocked?.call();
            },
            icon: const Icon(Icons.lock_open),
            label: const Text('Unlock Savage'),
          ),
        ],
      ),
    );
  }
}
