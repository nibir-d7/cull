import 'package:flutter/material.dart';

import '../data/hoard_repository.dart';
import '../design/components.dart';
import '../design/tokens.g.dart';
import '../engine/cull_ffi.dart';
import 'hoard_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.repository,
    required this.onOpen,
  });

  final HoardRepository repository;
  final void Function(Link link) onOpen;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<Link>? _results;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final q = _controller.text.trim();
    if (q.isEmpty) {
      setState(() => _results = null);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final found = await widget.repository.search(q);
      if (mounted) setState(() => _results = found);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(CullTokens.spaceMd),
            child: TextField(
              controller: _controller,
              onSubmitted: (_) => _run(),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search your hoard',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _busy
                    ? const Padding(
                        padding: EdgeInsets.all(CullTokens.spaceMd),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: CullTokens.signal,
                          ),
                        ),
                      )
                    : IconButton(
                        onPressed: _run,
                        icon: const Icon(Icons.arrow_forward),
                        tooltip: 'Search',
                      ),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: CullTokens.spaceMd),
              child: Text(_error!, style: t.textTheme.bodyMedium),
            ),
          Expanded(child: _body(t)),
        ],
      ),
    );
  }

  Widget _body(ThemeData t) {
    final results = _results;
    if (results == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(CullTokens.spaceXl),
          child: Text(
            'Full text search, ranked. It runs on the device, which is why it '
            'works on a plane.',
            textAlign: TextAlign.center,
            style: t.textTheme.bodyLarge,
          ),
        ),
      );
    }
    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(CullTokens.spaceXl),
          child: Text(
            'Nothing matched. Either you have not saved it, or you saved it and '
            'never read it, in which case you would not remember it anyway.',
            textAlign: TextAlign.center,
            style: t.textTheme.bodyLarge,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: CullTokens.spaceMd),
      itemCount: results.length,
      separatorBuilder: (_, _) => const SizedBox(height: CullTokens.spaceSm),
      itemBuilder: (context, i) => LinkCard(
        link: results[i],
        onTap: () => widget.onOpen(results[i]),
      ),
    );
  }
}

class CullInboxScreen extends StatefulWidget {
  const CullInboxScreen({super.key, required this.repository});

  final HoardRepository repository;

  @override
  State<CullInboxScreen> createState() => _CullInboxScreenState();
}

class _CullInboxScreenState extends State<CullInboxScreen> {
  late Future<CullReport> _future;
  late Future<List<Link>> _candidates;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.report();
    _candidates = widget.repository.cullable();
  }

  void _reload() {
    setState(() {
      _future = widget.repository.report();
      _candidates = widget.repository.cullable();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cull inbox'),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: ListView(
          padding: const EdgeInsets.all(CullTokens.spaceMd),
          children: [
            FutureBuilder<CullReport>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox(height: 120);
                final report = snapshot.data!;
                return Column(
                  children: [
                    RoastCard(
                      line: report.headline,
                      tone: RoastAccent.blunt,
                    ),
                    const SizedBox(height: CullTokens.spaceMd),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${report.culled} of ${report.total} links are rotting.',
                            style: t.textTheme.bodyMedium,
                          ),
                        ),
                        FilledButton(
                          onPressed: report.culled == 0 ? null : _cullAll,
                          child: Text(report.cta),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: CullTokens.spaceLg),
            Text('Waiting to be culled', style: t.textTheme.titleMedium),
            const SizedBox(height: CullTokens.spaceSm),
            FutureBuilder<List<Link>>(
              future: _candidates,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox(height: 80);
                }
                final links = snapshot.data!;
                if (links.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: CullTokens.spaceLg,
                    ),
                    child: Text(
                      'Nothing. Every link has been opened recently enough to be '
                      'excused. Enjoy it while it lasts.',
                      style: t.textTheme.bodyLarge,
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final link in links)
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: CullTokens.spaceSm,
                        ),
                        child: Dismissible(
                          key: ValueKey(link.id),
                          direction: DismissDirection.endToStart,
                          background: _cullBackground(),
                          onDismissed: (_) => _cull(link),
                          child: LinkCard(link: link),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _cullBackground() => Container(
    alignment: Alignment.centerRight,
    padding: const EdgeInsets.only(right: CullTokens.spaceLg),
    decoration: BoxDecoration(
      color: CullTokens.danger.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(CullTokens.radiusLg),
    ),
    child: const Icon(Icons.delete_outline, color: CullTokens.danger),
  );

  Future<void> _cull(Link link) async {
    try {
      await widget.repository.cull(link.id);
    } catch (_) {}
    _reload();
  }

  Future<void> _cullAll() async {
    final links = await widget.repository.cullable(limit: 50);
    for (final link in links) {
      try {
        await widget.repository.cull(link.id);
      } catch (_) {}
    }
    _reload();
  }
}

class GraveyardScreen extends StatefulWidget {
  const GraveyardScreen({super.key, required this.repository});

  final HoardRepository repository;

  @override
  State<GraveyardScreen> createState() => _GraveyardScreenState();
}

class _GraveyardScreenState extends State<GraveyardScreen> {
  late Future<List<Link>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.graveyard();
  }

  void _reload() {
    setState(() {
      _future = widget.repository.graveyard();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Graveyard'),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload',
          ),
        ],
      ),
      body: FutureBuilder<List<Link>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          final links = snapshot.data ?? const <Link>[];
          if (links.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(CullTokens.spaceXl),
                child: Text(
                  'Empty. Nothing culled in the last 30 days, which means you '
                  'are either disciplined or have not been using the app long '
                  'enough to have any evidence.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(CullTokens.spaceMd),
            itemCount: links.length,
            separatorBuilder: (_, _) => const SizedBox(height: CullTokens.spaceSm),
            itemBuilder: (context, i) {
              final link = links[i];
              return LinkCard(
                link: link,
                cullLabel: 'Restore',
                onCull: () async {
                  try {
                    await widget.repository.restore(link.id);
                  } catch (_) {}
                  _reload();
                },
              );
            },
          );
        },
      ),
    );
  }
}
