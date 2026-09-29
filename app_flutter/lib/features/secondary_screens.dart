import 'package:flutter/widgets.dart';

import '../data/hoard_repository.dart';
import '../design/components.dart';
import '../design/controls.dart';
import '../design/glyphs.dart';
import '../design/shell.dart';
import '../design/tokens.g.dart';
import '../design/type.dart';
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
  final TextEditingController _controller = TextEditingController();
  List<Link>? _results;
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
    setState(() => _error = null);
    try {
      final found = await widget.repository.search(q);
      if (mounted) setState(() => _results = found);
    } on Object catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return CullPage(
      eyebrow: 'Full text',
      title: 'Search',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: CullTokens.spaceLg),
            child: CullField(
              controller: _controller,
              hint: 'Search your hoard',
              onSubmitted: (_) => _run(),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CullTokens.spaceLg,
                CullTokens.spaceSm,
                CullTokens.spaceLg,
                0,
              ),
              child: Text(
                _error!,
                style: CullType.bodyS.copyWith(color: CullTokens.dangerDim),
              ),
            ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    final results = _results;
    if (results == null) {
      return const _Note(
        'Type a word you remember. Everything is searched on this device, which '
        'is the only reason it works on a plane.',
      );
    }
    if (results.isEmpty) {
      return const _Note(
        'Nothing matched. Either it was never saved, or it was saved and never '
        'read, in which case you would not have remembered it either.',
      );
    }
    return CullScroll(
      padding: const EdgeInsets.fromLTRB(
        CullTokens.spaceLg,
        CullTokens.spaceLg,
        CullTokens.spaceLg,
        96,
      ),
      child: Column(
        children: [
          for (final link in results)
            Padding(
              padding: const EdgeInsets.only(bottom: CullTokens.spaceSm),
              child: LinkCard(link: link, onTap: () => widget.onOpen(link)),
            ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

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
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Text(text, textAlign: TextAlign.center, style: CullType.bodyL),
        ),
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

  Future<void> _cull(Link link) async {
    var failed = false;
    try {
      await widget.repository.cull(link.id);
    } on Object {
      failed = true;
    }
    _reload();
    if (!mounted || !failed) return;
    CullToast.show(
      context,
      'That one would not go',
      tint: CullTokens.dangerDim,
    );
  }

  Future<void> _cullAll() async {
    final ok = await cullConfirm(
      context,
      title: 'Cull them all?',
      message:
          'Everything the engine has marked will move to the Graveyard for 30 '
          'days. You can restore any of it until then.',
      confirmLabel: 'Cull them',
    );
    if (!ok) return;
    final links = await widget.repository.cullable(limit: 50);
    var failed = 0;
    for (final link in links) {
      try {
        await widget.repository.cull(link.id);
      } on Object {
        failed++;
      }
    }
    _reload();
    if (!mounted) return;
    CullToast.show(
      context,
      failed == 0
          ? 'Culled ${links.length}'
          : 'Culled ${links.length - failed}, $failed would not go',
      tint: failed == 0 ? null : CullTokens.dangerDim,
    );
  }

  @override
  Widget build(BuildContext context) {
    return CullPage(
      eyebrow: 'Worth finishing',
      title: 'Cull inbox',
      trailing: CullGlyphButton(
        icon: CullIcon.refresh,
        label: 'Reload',
        onPressed: _reload,
      ),
      child: FutureBuilder<CullReport>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const CullLoading();
          final report = snapshot.data!;
          return CullScroll(
            padding: const EdgeInsets.fromLTRB(
              CullTokens.spaceLg,
              0,
              CullTokens.spaceLg,
              96,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RoastCard(line: report.headline, loud: true),
                const SizedBox(height: CullTokens.spaceLg),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${report.culled} of ${report.total} are past the point '
                        'of being worth keeping.',
                        style: CullType.bodyM,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: CullTokens.spaceMd),
                CullButton(
                  label: report.cta,
                  kind: CullButtonKind.danger,
                  expand: true,
                  onPressed: report.culled == 0 ? null : _cullAll,
                ),
                const SectionLabel(text: 'Waiting to be culled'),
                FutureBuilder<List<Link>>(
                  future: _candidates,
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const SizedBox(height: 80);
                    }
                    final links = snap.data!;
                    if (links.isEmpty) {
                      return Text(
                        'Nothing. Every link has been opened recently enough to '
                        'be excused.',
                        style: CullType.bodyM,
                      );
                    }
                    return Column(
                      children: [
                        for (final link in links)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: CullTokens.spaceSm,
                            ),
                            child: LinkCard(
                              link: link,
                              onCull: () => _cull(link),
                              cullLabel: 'Cull',
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
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

  Future<void> _restore(Link link) async {
    try {
      await widget.repository.restore(link.id);
      if (!mounted) return;
      CullToast.show(context, 'Back in the hoard');
    } on Object catch (e) {
      if (!mounted) return;
      CullToast.show(
        context,
        'Could not restore: $e',
        tint: CullTokens.dangerDim,
      );
    }
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return CullPage(
      eyebrow: '30 days to change your mind',
      title: 'Graveyard',
      trailing: CullGlyphButton(
        icon: CullIcon.refresh,
        label: 'Reload',
        onPressed: _reload,
      ),
      child: FutureBuilder<List<Link>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const CullLoading();
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(CullTokens.spaceXl),
                child: Text('${snapshot.error}', style: CullType.monoS),
              ),
            );
          }
          final links = snapshot.data ?? const <Link>[];
          if (links.isEmpty) {
            return const _Note(
              'Nothing culled in the last 30 days. That either means you are '
              'keeping up with what you save, or that you have not been using '
              'the app long enough for there to be evidence.',
            );
          }
          return CullScroll(
            padding: const EdgeInsets.fromLTRB(
              CullTokens.spaceLg,
              0,
              CullTokens.spaceLg,
              96,
            ),
            child: Column(
              children: [
                for (final link in links)
                  Padding(
                    padding: const EdgeInsets.only(bottom: CullTokens.spaceSm),
                    child: LinkCard(
                      link: link,
                      cullLabel: 'Restore',
                      onCull: () => _restore(link),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
