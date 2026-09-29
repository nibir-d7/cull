import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/hoard_repository.dart';
import 'design/components.dart';
import 'design/theme.dart';
import 'design/tokens.g.dart';
import 'engine/cull_ffi.dart';
import 'features/detail_screen.dart';
import 'features/add_link_sheet.dart';
import 'features/hoard_screen.dart';
import 'features/secondary_screens.dart';
import 'onboarding/copy.dart';
import 'onboarding/onboarding.dart';
import 'platform/shared_url.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(CullTheme.overlay);
  runApp(const CullApp());
}

class CullApp extends StatefulWidget {
  const CullApp({super.key});

  @override
  State<CullApp> createState() => _CullAppState();
}

class _CullAppState extends State<CullApp> {
  RoastTone _tone = RoastTone.blunt;
  bool _onboarded = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CULL',
      debugShowCheckedModeBanner: false,
      theme: CullTheme.dark(),
      home: _onboarded
          ? const EngineGate()
          : Onboarding(
              initialTone: _tone,
              onFinished: (t) => setState(() {
                _tone = t;
                _onboarded = true;
              }),
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
  late Future<HoardRepository> _repository;

  @override
  void initState() {
    super.initState();
    _repository = _open();
  }

  Future<HoardRepository> _open() async {
    const name = 'cull.db';
    const dir = 'data';
    return EngineHoardRepository.open('$dir${Platform.pathSeparator}$name');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HoardRepository>(
      future: _repository,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: CullTokens.signal),
            ),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(CullTokens.spaceXl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'The engine would not start',
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: CullTokens.spaceSm),
                    Text(
                      '${snapshot.error}',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return HomeShell(repository: snapshot.data!, sharedUrl: _shared);
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
      MaterialPageRoute<void>(
        builder: (_) => DetailScreen(link: link, repository: widget.repository),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HoardScreen(repository: widget.repository, onOpen: _open),
      SearchScreen(repository: widget.repository, onOpen: _open),
      CullInboxScreen(repository: widget.repository),
      GraveyardScreen(repository: widget.repository),
    ];

    return Scaffold(
      floatingActionButton: _index == 0
          ? FloatingActionButton.extended(
              onPressed: _openAdd,
              backgroundColor: CullTokens.signal,
              foregroundColor: CullTokens.inkOnAccent,
              icon: const Icon(Icons.add),
              label: const Text('Save a link'),
            )
          : null,
      body: BlobBackground(
        child: IndexedStack(index: _index, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: CullTokens.canvasDeep,
        indicatorColor: CullTokens.signal.withValues(alpha: 0.18),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.layers_outlined),
            selectedIcon: Icon(Icons.layers),
            label: 'Hoard',
          ),
          NavigationDestination(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.delete_sweep_outlined),
            selectedIcon: Icon(Icons.delete_sweep),
            label: 'Cull',
          ),
          NavigationDestination(
            icon: Icon(Icons.inbox_outlined),
            selectedIcon: Icon(Icons.inbox),
            label: 'Graveyard',
          ),
        ],
      ),
    );
  }
}
