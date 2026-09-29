import 'package:flutter/widgets.dart';

import '../data/hoard_repository.dart';
import '../design/components.dart';
import '../design/controls.dart';
import '../design/glyphs.dart';
import '../design/masonry.dart';
import '../design/shell.dart';
import '../design/tokens.g.dart';
import '../design/type.dart';
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
    return CullSurface(
      onTap: onTap,
      padding: const EdgeInsets.all(CullTokens.spaceMd),
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
                  style: CullType.titleM,
                ),
              ),
              const SizedBox(width: CullTokens.spaceSm),
              ScoreDial(score: link.hoardScore, band: link.band, size: 42),
            ],
          ),
          if (link.excerpt.isNotEmpty) ...[
            const SizedBox(height: CullTokens.spaceXs),
            Text(
              link.excerpt,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: CullType.bodyS,
            ),
          ],
          const SizedBox(height: CullTokens.spaceSm),
          Row(
            children: [
              Flexible(
                child: CategoryPill(category: link.category, dense: true),
              ),
              if (link.duplicateCount > 0) ...[
                const SizedBox(width: CullTokens.spaceXs),
                CullTag(
                  label: 'x${link.duplicateCount}',
                  foreground: CullTokens.accentDim,
                  background: CullTokens.accent.withValues(alpha: 0.18),
                  monospace: true,
                  dense: true,
                ),
              ],
              if (link.culled) ...[
                const SizedBox(width: CullTokens.spaceXs),
                CullTag(
                  label: 'culled',
                  foreground: CullTokens.inkTertiary,
                  background: CullTokens.surface3,
                  monospace: true,
                  dense: true,
                ),
              ],
            ],
          ),
          const SizedBox(height: CullTokens.spaceSm),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${link.domain}  ${link.ageDays}d  ${link.bandLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: CullType.monoXs,
                ),
              ),
              if (onCull != null)
                CullButton(
                  label: cullLabel,
                  kind: CullButtonKind.ghost,
                  dense: true,
                  onPressed: onCull,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class HoardScreen extends StatefulWidget {
  const HoardScreen({
    super.key,
    required this.repository,
    required this.onOpen,
    this.onSettings,
    this.onAdd,
  });

  final HoardRepository repository;
  final void Function(Link link) onOpen;
  final VoidCallback? onSettings;
  final VoidCallback? onAdd;

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
    return CullPage(
      eyebrow: 'Everything you saved',
      title: 'Your hoard',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.onAdd != null)
            CullGlyphButton(
              icon: CullIcon.add,
              label: 'Add a link by hand',
              onPressed: widget.onAdd,
              color: CullTokens.inkSecondary,
            ),
          if (widget.onSettings != null)
            CullGlyphButton(
              icon: CullIcon.settings,
              label: 'Settings',
              onPressed: widget.onSettings,
            ),
          CullGlyphButton(
            icon: CullIcon.refresh,
            label: 'Reload',
            onPressed: _reload,
          ),
        ],
      ),
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
                  return const CullLoading();
                }
                if (snapshot.hasError) {
                  return _Error(message: '${snapshot.error}', onRetry: _reload);
                }
                final links = snapshot.data ?? const <Link>[];
                if (links.isEmpty) {
                  return const _EmptyHoard();
                }
                final visible = _filter == 'all'
                    ? links
                    : links.where((l) => l.bandLabel == _filter).toList();
                if (visible.isEmpty) {
                  return _Empty(
                    title: 'Nothing in $_filter',
                    body:
                        'The rest of your hoard is in better shape, which is '
                        'the good news.',
                    onRetry: _reload,
                    retryLabel: 'Show everything',
                  );
                }
                return CullScroll(
                  padding: const EdgeInsets.fromLTRB(
                    CullTokens.spaceMd,
                    CullTokens.spaceSm,
                    CullTokens.spaceMd,
                    96,
                  ),
                  child: MasonryHoard(
                    itemCount: visible.length,
                    columns: 2,
                    heightFor: (_, i) => _cardHeight(visible[i]),
                    itemBuilder: (context, i) => LinkCard(
                      link: visible[i],
                      onTap: () => widget.onOpen(visible[i]),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static double _cardHeight(Link link) {
    var h = 44.0;
    h += link.title.length > 34 ? 48 : 24;
    if (link.excerpt.isNotEmpty) h += 8 + 40;
    h += 8 + 24;
    h += 8 + 24;
    return h;
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  static const _options = ['all', 'fresh', 'stale', 'rotting', 'graveyard'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: CullTokens.minTouchTarget,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: CullTokens.spaceLg),
        itemCount: _options.length,
        separatorBuilder: (_, _) => const SizedBox(width: CullTokens.spaceLg),
        itemBuilder: (context, i) {
          final option = _options[i];
          final selected = option == value;
          final color = selected
              ? CullTokens.signalDim
              : CullTokens.inkTertiary;
          return Semantics(
            button: true,
            selected: selected,
            child: GestureDetector(
              onTap: () => onChanged(option),
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Center(
                      child: Text(
                        option.toUpperCase(),
                        style: CullType.monoXs.copyWith(color: color),
                      ),
                    ),
                  ),
                  Container(
                    height: 2,
                    width: selected ? 22 : 0,
                    color: CullTokens.signalDim,
                  ),
                ],
              ),
            ),
          );
        },
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

class _EmptyHoard extends StatelessWidget {
  const _EmptyHoard();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          CullTokens.spaceXl,
          CullTokens.spaceXl,
          CullTokens.spaceXl,
          96,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nothing here yet', style: CullType.displayS),
            const SizedBox(height: CullTokens.spaceLg),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Text(
                'You are looking at the place where your saved things will go. '
                'It is empty because nothing has been sent to CULL yet.',
                style: CullType.bodyL,
              ),
            ),
            const SizedBox(height: CullTokens.spaceN2xl),
            Container(
              padding: const EdgeInsets.all(CullTokens.spaceXl),
              decoration: BoxDecoration(
                color: CullTokens.canvasDeep,
                borderRadius: BorderRadius.circular(CullTokens.radiusLg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CullGlyph(
                        CullIcon.share,
                        size: 18,
                        color: CullTokens.signalDim,
                      ),
                      const SizedBox(width: CullTokens.spaceSm),
                      Text(
                        'SHARE A LINK TO CULL',
                        style: CullType.monoXs.copyWith(
                          color: CullTokens.inkSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: CullTokens.spaceMd),
                  Text(
                    'Open anything you want to keep, tap Share, and choose '
                    'CULL. It arrives here already categorised.',
                    style: CullType.bodyM,
                  ),
                ],
              ),
            ),
            const SizedBox(height: CullTokens.spaceXl),
            Text(
              'A news article, a video, a product, a thread. The kind of thing '
              'is the same and so is the gesture.',
              style: CullType.bodyS,
            ),
          ],
        ),
      ),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          CullTokens.spaceXl,
          CullTokens.spaceXl,
          CullTokens.spaceXl,
          96,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, textAlign: TextAlign.center, style: CullType.displayS),
            const SizedBox(height: CullTokens.spaceMd),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                body,
                textAlign: TextAlign.center,
                style: CullType.bodyL,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: CullTokens.spaceXl),
              CullButton(
                label: retryLabel,
                kind: CullButtonKind.outline,
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
