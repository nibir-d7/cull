import '../engine/cull_ffi.dart';

abstract class HoardRepository {
  Future<List<Link>> hoard({int limit});

  Future<List<Link>> cullable({int limit});

  Future<List<Link>> graveyard({int limit});

  Future<List<Link>> search(String query, {int limit});

  Future<SaveOutcome> save(String url, {int week});

  Future<HoardStats> stats();

  Future<CullReport> report({int tone, int week});

  Future<void> cull(String id);

  Future<void> restore(String id);

  Future<void> markOpened(String id);

  Future<int> tone();

  Future<void> setTone(int tone);

  bool get hasOnboarded;

  Future<void> markOnboarded();

  bool get isPro;

  String getSetting(String key, {String fallback});

  Future<void> setSetting(String key, String value);

  int get week;

  int get schemaVersionSync;

  void close();
}

class EngineHoardRepository implements HoardRepository {
  EngineHoardRepository(this._engine);

  final Cull _engine;

  static Future<HoardRepository> open(
    String dbPath, {
    String? libraryPath,
  }) async {
    return EngineHoardRepository(
      Cull.open(dbPath, libraryPath: libraryPath),
    );
  }

  @override
  Future<List<Link>> hoard({int limit = 200}) async =>
      _engine.list(limit: limit);

  @override
  Future<List<Link>> cullable({int limit = 50}) async =>
      _engine.cullable(limit: limit);

  @override
  Future<List<Link>> graveyard({int limit = 200}) async =>
      _engine.graveyard(limit: limit);

  @override
  Future<List<Link>> search(String query, {int limit = 50}) async {
    if (query.trim().isEmpty) return const [];
    return _engine.search(query, limit: limit);
  }

  @override
  Future<SaveOutcome> save(String url, {int? week}) async {
    final outcome = _engine.save(url, week: week ?? _engine.week);
    if (!outcome.saved && outcome.reason.isNotEmpty) {
      throw EngineException(outcome.reason);
    }
    return outcome;
  }

  @override
  Future<HoardStats> stats() async => _engine.stats;

  @override
  Future<CullReport> report({int? tone, int? week}) async => _engine.report(
    tone: tone ?? _engine.tone,
    week: week ?? _engine.week,
  );

  @override
  Future<void> cull(String id) async => _engine.cull(id);

  @override
  Future<void> restore(String id) async => _engine.restore(id);

  @override
  Future<void> markOpened(String id) async => _engine.touchOpen(id);

  @override
  Future<int> tone() async => _engine.tone;

  @override
  Future<void> setTone(int tone) async => _engine.setTone(tone);

  @override
  bool get hasOnboarded => _engine.hasOnboarded;

  @override
  Future<void> markOnboarded() async => _engine.markOnboarded();

  @override
  bool get isPro => _engine.isPro;

  @override
  String getSetting(String key, {String fallback = ''}) =>
      _engine.getSetting(key, fallback: fallback);

  @override
  Future<void> setSetting(String key, String value) async =>
      _engine.setSetting(key, value);

  @override
  @override
  int get week => _engine.week;

  @override
  int get schemaVersionSync => _engine.schemaVersion;

  @override
  void close() => _engine.close();

}
