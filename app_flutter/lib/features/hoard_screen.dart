import 'package:flutter/material.dart';

import '../data/hoard_repository.dart';
import '../design/components.dart';
import '../design/tokens.g.dart';
import '../engine/cull_ffi.dart';

class LinkCard extends StatelessWidget {
  const LinkCard({
    super.key,
    required this.link,
    this.onTap,
    this.onCull,
    this.cullLabel = 'Cull',
  });

  final Link link;
  final VoidCallback? onTap;
  final VoidCallback? onCull;
  final String cullLabel;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return GlassCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  link.title.isEmpty ? link.url : link.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: CullTokens.spaceMd),
              ScoreDial(score: link.hoardScore, band: link.band, size: 44),
            ],
          ),
          if (link.excerpt.isNotEmpty) ...[
            const SizedBox(height: CullTokens.spaceXs),
            Text(
              link.excerpt,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: CullTokens.spaceSm),
          Row(
            children: [
              Pill(
                label: link.category,
                color: categoryColor(link.category),
                surface: categorySurface(link.category),
                dense: true,
              ),
              const SizedBox(width: CullTokens.spaceXs),
              if (link.duplicateCount > 0) ...[
                Pill(
                  label: 'x${link.duplicateCount}',
                  color: CullTokens.warn,
                  dense: true,
                ),
                const SizedBox(width: CullTokens.spaceXs),
              ],
              if (link.culled)
                const Pill(
                  label: 'culled',
                  color: CullTokens.inkTertiary,
                  dense: true,
                ),
            ],
          ),
          const SizedBox(height: CullTokens.spaceSm),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${link.domain}  Ã‚Â·  ${link.ageDays}d  Ã‚Â·  ${link.bandLabel}',
                  style: t.textTheme.labelSmall,
                ),
              ),
              if (onCull != null)
                TextButton(
                  onPressed: onCull,
                  child: Text(cullLabel),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class HoardScreen extends StatefulWidget {
  const HoardScreen({super.key, required this.repository, required this.onOpen});

  final HoardRepository repository;
  final void Function(Link link) onOpen;

  @override
  State<HoardScreen> createState() => _HoardScreenState();
}

class _HoardScreenState extends State<HoardScreen> {
  late Future<List<Link>> _future;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _future = widget.repository.hoard();
  }

  void _reload() {
    setState(() {
      _future = widget.repository.hoard();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your hoard'),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload',
          ),
        ],
      ),
      body: BlobBackground(
        child: Column(
          children: [
            _FilterBar(
              value: _filter,
              onChanged: (v) => setState(() => _filter = v),
            ),
            Expanded(
              child: FutureBuilder<List<Link>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const _Loading();
                  }
                  if (snapshot.hasError) {
                    return _Error(
                      message: '${snapshot.error}',
                      onRetry: _reload,
                    );
                  }
                  final links = snapshot.data ?? const <Link>[];
                  if (links.isEmpty) {
                    return const _Empty(
                      title: 'Nothing saved yet',
                      body: 'Share a link to the app and it will land here, '
                          'be scored, and told what it is.',
                    );
                  }
                  final visible = _filter == 'all'
                      ? links
                      : links.where((l) => l.bandLabel == _filter).toList();
                  if (visible.isEmpty) {
                    return _Empty(
                      title: 'Nothing in ${_filterLabel(_filter)}',
                      body: 'The rest of your hoard is in better shape, which is '
                          'the good news.',
                      onRetry: _reload,
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async => _reload(),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(CullTokens.spaceMd),
                      itemCount: visible.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: CullTokens.spaceSm),
                      itemBuilder: (context, i) {
                        final link = visible[i];
                        return LinkCard(
                          link: link,
                          onTap: () => widget.onOpen(link),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _filterLabel(String v) => v;
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  static const _options = ['all', 'fresh', 'stale', 'rotting', 'graveyard'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: CullTokens.minTouchTarget + CullTokens.spaceMd,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: CullTokens.spaceMd),
        itemCount: _options.length,
        separatorBuilder: (_, _) => const SizedBox(width: CullTokens.spaceXs),
        itemBuilder: (context, i) {
          final option = _options[i];
          final selected = option == value;
          return Center(
            child: ChoiceChip(
              label: Text(option),
              selected: selected,
              onSelected: (_) => onChanged(option),
              labelStyle: TextStyle(
                color: selected ? CullTokens.inkOnAccent : CullTokens.inkSecondary,
                fontFamily: CullTokens.fontMono,
                fontSize: CullTokens.typeMonoSSize,
              ),
              selectedColor: CullTokens.signal,
              backgroundColor: CullTokens.surface1,
              side: BorderSide(
                color: selected ? CullTokens.signal : CullTokens.surface4,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: CullTokens.signal,
        ),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _Empty(
      title: 'That did not work',
      body: message,
      onRetry: onRetry,
      retryLabel: 'Try again',
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.title,
    required this.body,
    this.onRetry,
    this.retryLabel = 'Reload',
  });

  final String title;
  final String body;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(CullTokens.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: t.textTheme.headlineMedium,
            ),
            const SizedBox(height: CullTokens.spaceSm),
            Text(
              body,
              textAlign: TextAlign.center,
              style: t.textTheme.bodyLarge,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: CullTokens.spaceLg),
              OutlinedButton(onPressed: onRetry, child: Text(retryLabel)),
            ],
          ],
        ),
      ),
    );
  }
}
