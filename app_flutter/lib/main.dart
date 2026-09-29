import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'data/hoard_repository.dart';
import 'design/components.dart';
import 'design/glyphs.dart';
import 'design/shell.dart';
import 'design/tokens.g.dart';
import 'design/type.dart';
import 'engine/cull_ffi.dart';
import 'features/add_link_sheet.dart';
import 'features/detail_screen.dart';
import 'features/hoard_screen.dart';
import 'features/secondary_screens.dart';
import 'features/settings_screen.dart';
import 'onboarding/copy.dart';
import 'onboarding/onboarding.dart';
import 'platform/app_paths.dart';
import 'platform/shared_url.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(CullApp.overlay);
  runApp(const Culling());
}

class Culling extends StatelessWidget {
  const Culling({super.key});

  @override
  Widget build(BuildContext context) {
    return CullApp(
      child: Navigator(
        onGenerateRoute: (settings) =>
            CullRoute<void>(builder: (_) => const EngineGate()),
      ),
    );
  }
}

class EngineGate extends StatefulWidget {
  const EngineGate({super.key});

  @override
  State<EngineGate> createState() => _EngineGateState();
}

class _EngineGateState extends State<EngineGate> {
  static const SharedUrl _shared = SharedUrl.android();
  static const AppPaths _paths = AppPaths.android();
  late Future<HoardRepository> _repository;
  bool _onboarded = false;
  int _tone = RoastTone.blunt.index;

  @override
  void initState() {
    super.initState();
    _repository = _open();
  }

  Future<HoardRepository> _open() async {
    final repo = await EngineHoardRepository.open(await _paths.databasePath());
    if (repo.hasOnboarded) {
      _onboarded = true;
      _tone = await repo.tone();
    }
    return repo;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HoardRepository>(
      future: _repository,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CullPage(
            child: CullLoading(label: 'Reading your links'),
          );
        }
        if (snapshot.hasError) {
          return CullPage(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(CullTokens.spaceXl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CullGlyph(
                      CullIcon.close,
                      size: 28,
                      color: CullTokens.dangerDim,
                    ),
                    const SizedBox(height: CullTokens.spaceLg),
                    Text(
                      'The engine would not start',
                      style: CullType.displayS,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: CullTokens.spaceMd),
                    Text(
                      '${snapshot.error}',
                      style: CullType.monoS,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return _onboarded
            ? HomeShell(repository: snapshot.data!, sharedUrl: _shared)
            : Onboarding(
                initialTone: RoastTone.values.firstWhere(
                  (t) => t.index == _tone,
                  orElse: () => RoastTone.blunt,
                ),
                onFinished: (t) async {
                  final repo = snapshot.data!;
                  await repo.setTone(t.index);
                  await repo.markOnboarded();
                  if (!mounted) return;
                  setState(() {
                    _onboarded = true;
                    _tone = t.index;
                  });
                },
              );
      },
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.repository, this.sharedUrl});

  final HoardRepository repository;
  final SharedUrl? sharedUrl;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  bool _handlingShare = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumeShare());
  }

  Future<void> _consumeShare() async {
    if (_handlingShare) return;
    final source = widget.sharedUrl;
    if (source == null) return;
    _handlingShare = true;
    try {
      final url = await source.take();
      if (url == null || !mounted) return;
      setState(() => _index = 0);
      await AddLinkSheet.show(
        context,
        repository: widget.repository,
        initialUrl: url,
      );
    } finally {
      _handlingShare = false;
    }
  }

  Future<void> _openAdd() async {
    final saved = await AddLinkSheet.show(
      context,
      repository: widget.repository,
    );
    if (saved == true && mounted) setState(() {});
  }

  void _open(Link link) {
    Navigator.of(context).push(
      CullRoute<void>(
        builder: (_) => DetailScreen(link: link, repository: widget.repository),
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      CullRoute<void>(
        builder: (_) => SettingsScreen(repository: widget.repository),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CullToastHost(
      child: ColoredBox(
        color: CullTokens.canvas,
        child: Stack(
          children: [
            Positioned.fill(
              child: BlobBackground(
                child: IndexedStack(
                  index: _index,
                  children: [
                    HoardScreen(
                      repository: widget.repository,
                      onOpen: _open,
                      onSettings: _openSettings,
                      onAdd: _openAdd,
                    ),
                    SearchScreen(repository: widget.repository, onOpen: _open),
                    CullInboxScreen(repository: widget.repository),
                    GraveyardScreen(repository: widget.repository),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _NavBar(
                index: _index,
                onSelect: (i) => setState(() => _index = i),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  static const _items = <(CullIcon, String)>[
    (CullIcon.layers, 'Hoard'),
    (CullIcon.search, 'Search'),
    (CullIcon.sweep, 'Cull'),
    (CullIcon.clock, 'Graveyard'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CullTokens.canvas.withValues(alpha: 0.96),
        border: Border(top: BorderSide(color: CullTokens.inkDisabled)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: _NavItem(
                    icon: _items[i].$1,
                    label: _items[i].$2,
                    selected: i == index,
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final CullIcon icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? CullTokens.signalDim : CullTokens.inkTertiary;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CullGlyph(icon, size: 21, color: color, weight: selected ? 2.4 : 2),
            const SizedBox(height: 5),
            Text(label, style: CullType.monoXs.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
