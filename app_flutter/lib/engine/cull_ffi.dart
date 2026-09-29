import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

class Link {
  const Link({
    required this.id,
    required this.url,
    required this.domain,
    required this.title,
    required this.excerpt,
    required this.category,
    required this.hoardScore,
    required this.actionability,
    required this.band,
    required this.bandLabel,
    required this.openCount,
    required this.duplicateCount,
    required this.ageDays,
    required this.explanation,
    required this.culled,
    required this.createdAt,
  });

  factory Link.fromJson(Map<String, dynamic> j) => Link(
    id: j['ID'] as String? ?? '',
    url: j['URL'] as String? ?? '',
    domain: j['Domain'] as String? ?? '',
    title: j['Title'] as String? ?? '',
    excerpt: j['Excerpt'] as String? ?? '',
    category: j['Category'] as String? ?? '',
    hoardScore: (j['HoardScore'] as num?)?.toDouble() ?? 0,
    actionability: (j['Actionability'] as num?)?.toDouble() ?? 0,
    band: (j['Band'] as num?)?.toInt() ?? 0,
    bandLabel: j['BandLabel'] as String? ?? '',
    openCount: (j['OpenCount'] as num?)?.toInt() ?? 0,
    duplicateCount: (j['DuplicateCount'] as num?)?.toInt() ?? 0,
    ageDays: (j['AgeDays'] as num?)?.toInt() ?? 0,
    explanation: j['Explanation'] as String? ?? '',
    culled: j['Culled'] as bool? ?? false,
    createdAt: (j['CreatedAt'] as num?)?.toInt() ?? 0,
  );

  final String id;
  final String url;
  final String domain;
  final String title;
  final String excerpt;
  final String category;
  final double hoardScore;
  final double actionability;
  final int band;
  final String bandLabel;
  final int openCount;
  final int duplicateCount;
  final int ageDays;
  final String explanation;
  final bool culled;
  final int createdAt;
}

class Proposal {
  const Proposal({
    required this.kind,
    required this.category,
    required this.count,
    required this.avgActionability,
    required this.line,
    required this.titles,
  });

  factory Proposal.fromJson(Map<String, dynamic> j) => Proposal(
    kind: (j['Kind'] as num?)?.toInt() ?? 0,
    category: j['Category'] as String? ?? '',
    count: (j['Count'] as num?)?.toInt() ?? 0,
    avgActionability: (j['AvgActionability'] as num?)?.toDouble() ?? 0,
    line: j['Line'] as String? ?? '',
    titles: (j['Titles'] as List?)?.cast<String>() ?? const [],
  );

  final int kind;
  final String category;
  final int count;
  final double avgActionability;
  final String line;
  final List<String> titles;
}

class CullReport {
  const CullReport({
    required this.week,
    required this.headline,
    required this.culled,
    required this.total,
    required this.cta,
    required this.proposals,
  });

  factory CullReport.fromJson(Map<String, dynamic> j) => CullReport(
    week: (j['Week'] as num?)?.toInt() ?? 0,
    headline: j['Headline'] as String? ?? '',
    culled: (j['Culled'] as num?)?.toInt() ?? 0,
    total: (j['Total'] as num?)?.toInt() ?? 0,
    cta: j['Cta'] as String? ?? '',
    proposals: (j['Proposals'] as List?)
            ?.map((e) => Proposal.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
  );

  final int week;
  final String headline;
  final int culled;
  final int total;
  final String cta;
  final List<Proposal> proposals;
}

class HoardStats {
  const HoardStats({
    required this.total,
    required this.culled,
    required this.duplicates,
    required this.savedToday,
    required this.opened,
    required this.tone,
    required this.averageScore,
  });

  factory HoardStats.fromJson(Map<String, dynamic> j) => HoardStats(
    total: (j['Total'] as num?)?.toInt() ?? 0,
    culled: (j['Culled'] as num?)?.toInt() ?? 0,
    duplicates: (j['Duplicates'] as num?)?.toInt() ?? 0,
    savedToday: (j['SavedToday'] as num?)?.toInt() ?? 0,
    opened: (j['Opened'] as num?)?.toInt() ?? 0,
    tone: (j['Tone'] as num?)?.toInt() ?? 1,
    averageScore: (j['AverageScore'] as num?)?.toDouble() ?? 0,
  );

  final int total;
  final int culled;
  final int duplicates;
  final int savedToday;
  final int opened;
  final int tone;
  final double averageScore;
}

class SaveOutcome {
  const SaveOutcome({
    required this.saved,
    required this.id,
    required this.category,
    required this.score,
    required this.actionability,
    required this.roast,
    required this.reason,
  });

  factory SaveOutcome.fromJson(Map<String, dynamic> j) => SaveOutcome(
    saved: j['Saved'] as bool? ?? false,
    id: j['ID'] as String? ?? '',
    category: j['Category'] as String? ?? '',
    score: (j['Score'] as num?)?.toDouble() ?? 0,
    actionability: (j['Action'] as num?)?.toDouble() ?? 0,
    roast: j['Roast'] as String? ?? '',
    reason: j['Reason'] as String? ?? '',
  );

  final bool saved;
  final String id;
  final String category;
  final double score;
  final double actionability;
  final String roast;
  final String reason;
}

class EngineException implements Exception {
  EngineException(this.message);
  final String message;

  @override
  String toString() => 'EngineException: $message';
}

typedef _OpenNative = Int32 Function(Pointer<Char>);
typedef _OpenDart = int Function(Pointer<Char>);

typedef _CloseNative = Void Function(Int32);
typedef _CloseDart = void Function(int);

typedef _SaveNative = Pointer<Char> Function(Int32, Pointer<Char>, Int32);
typedef _SaveDart = Pointer<Char> Function(int, Pointer<Char>, int);

typedef _ListNative = Pointer<Char> Function(Int32, Int32);
typedef _ListDart = Pointer<Char> Function(int, int);

typedef _SearchNative = Pointer<Char> Function(Int32, Pointer<Char>, Int32);
typedef _SearchDart = Pointer<Char> Function(int, Pointer<Char>, int);

typedef _ByIdNative = Pointer<Char> Function(Int32, Pointer<Char>);
typedef _ByIdDart = Pointer<Char> Function(int, Pointer<Char>);

typedef _StampNative = Pointer<Char> Function(Int32, Pointer<Char>, Int64);
typedef _StampDart = Pointer<Char> Function(int, Pointer<Char>, int);

typedef _ReportNative = Pointer<Char> Function(Int32, Int32, Int32);
typedef _ReportDart = Pointer<Char> Function(int, int, int);

typedef _ToneNative = Pointer<Char> Function(Int32, Int32);
typedef _ToneDart = Pointer<Char> Function(int, int);

typedef _StatsNative = Pointer<Char> Function(Int32);
typedef _StatsDart = Pointer<Char> Function(int);

typedef _ToneGetNative = Int32 Function(Int32);
typedef _ToneGetDart = int Function(int);

typedef _SchemaNative = Int32 Function(Int32);
typedef _SchemaDart = int Function(int);

typedef _FlagNative = Int32 Function(Int32);
typedef _FlagDart = int Function(int);

typedef _SettingNative = Pointer<Char> Function(Int32, Pointer<Char>, Pointer<Char>);
typedef _SettingDart = Pointer<Char> Function(int, Pointer<Char>, Pointer<Char>);

typedef _PairNative = Pointer<Char> Function(Int32, Pointer<Char>, Pointer<Char>);
typedef _PairDart = Pointer<Char> Function(int, Pointer<Char>, Pointer<Char>);

typedef _FreeNative = Void Function(Pointer<Char>);
typedef _FreeDart = void Function(Pointer<Char>);

List<Link> _links(Object? decoded) => (decoded as List)
    .map((e) => Link.fromJson(e as Map<String, dynamic>))
    .toList();

SaveOutcome _outcome(Object? decoded) =>
    SaveOutcome.fromJson(decoded as Map<String, dynamic>);

CullReport _report(Object? decoded) =>
    CullReport.fromJson(decoded as Map<String, dynamic>);

HoardStats _stats(Object? decoded) =>
    HoardStats.fromJson(decoded as Map<String, dynamic>);

class Cull {
  Cull._(this._lib, this._handle);

  final DynamicLibrary _lib;
  final int _handle;

  late final _FreeDart _free = _lib.lookupFunction<_FreeNative, _FreeDart>(
    'CULLFree',
  );

  T _decode<T>(Pointer<Char> Function() call, T Function(Object?) parse) {
    final raw = call();
    if (raw == nullptr) {
      throw EngineException('engine returned null');
    }
    final text = raw.cast<Utf8>().toDartString();
    _free(raw);
    return parse(jsonDecode(text) as Object?);
  }

  void _discard(Pointer<Char> raw) {
    if (raw == nullptr) {
      throw EngineException('engine returned null');
    }
    _free(raw);
  }

  static Cull open(String path, {String? libraryPath}) {
    final lib = DynamicLibrary.open(libraryPath ?? defaultLibraryPath());
    final openFn = lib.lookupFunction<_OpenNative, _OpenDart>('CULLOpen');
    final ptr = path.toNativeUtf8();
    final h = openFn(ptr.cast<Char>());
    calloc.free(ptr);
    if (h < 0) {
      throw EngineException('could not open $path');
    }
    return Cull._(lib, h);
  }

  static String defaultLibraryPath() {
    if (Platform.isAndroid || Platform.isLinux) return 'libcull.so';
    if (Platform.isWindows) return 'cull.dll';
    if (Platform.isMacOS) return 'cull.dylib';
    throw UnsupportedError('unsupported platform: ${Platform.operatingSystem}');
  }

  int get schemaVersion =>
      _lib.lookupFunction<_SchemaNative, _SchemaDart>('CULLSchemaVersion')(_handle);

  bool get hasOnboarded =>
      _lib.lookupFunction<_FlagNative, _FlagDart>('CULLHasOnboarded')(_handle) == 1;

  void markOnboarded() {
    final fn = _lib.lookupFunction<_StatsNative, _StatsDart>('CULLMarkOnboarded');
    _discard(fn(_handle));
  }

  bool get isPro =>
      _lib.lookupFunction<_FlagNative, _FlagDart>('CULLIsPro')(_handle) == 1;

  String getSetting(String key, {String fallback = ''}) {
    final fn =
        _lib.lookupFunction<_SettingNative, _SettingDart>('CULLGetSetting');
    final k = key.toNativeUtf8();
    final d = fallback.toNativeUtf8();
    try {
      return _decode(() => fn(_handle, k.cast<Char>(), d.cast<Char>()), (o) {
        final s = o as String;
        return s.isEmpty ? fallback : s;
      });
    } finally {
      calloc.free(k);
      calloc.free(d);
    }
  }

  void setSetting(String key, String value) {
    final fn =
        _lib.lookupFunction<_PairNative, _PairDart>('CULLSetSetting');
    final k = key.toNativeUtf8();
    final v = value.toNativeUtf8();
    try {
      _discard(fn(_handle, k.cast<Char>(), v.cast<Char>()));
    } finally {
      calloc.free(k);
      calloc.free(v);
    }
  }

  int get tone =>
      _lib.lookupFunction<_ToneGetNative, _ToneGetDart>('CULLTone')(_handle);

  void setTone(int value) {
    final fn = _lib.lookupFunction<_ToneNative, _ToneDart>('CULLSetTone');
    _discard(fn(_handle, value));
  }

  void close() {
    _lib.lookupFunction<_CloseNative, _CloseDart>('CULLClose')(_handle);
  }

  List<Link> list({int limit = 200}) {
    final fn = _lib.lookupFunction<_ListNative, _ListDart>('CULLList');
    return _decode<List<Link>>(() => fn(_handle, limit), _links);
  }

  List<Link> cullable({int limit = 50}) {
    final fn = _lib.lookupFunction<_ListNative, _ListDart>('CULLCullable');
    return _decode<List<Link>>(() => fn(_handle, limit), _links);
  }

  List<Link> graveyard({int limit = 200}) {
    final fn = _lib.lookupFunction<_ListNative, _ListDart>('CULLGraveyard');
    return _decode<List<Link>>(() => fn(_handle, limit), _links);
  }

  List<Link> search(String query, {int limit = 50}) {
    final fn = _lib.lookupFunction<_SearchNative, _SearchDart>('CULLSearch');
    final q = query.toNativeUtf8();
    try {
      return _decode<List<Link>>(() => fn(_handle, q.cast<Char>(), limit), _links);
    } finally {
      calloc.free(q);
    }
  }

  SaveOutcome save(String url, {int week = 1}) {
    final fn = _lib.lookupFunction<_SaveNative, _SaveDart>('CULLSave');
    final u = url.toNativeUtf8();
    try {
      return _decode<SaveOutcome>(() => fn(_handle, u.cast<Char>(), week), _outcome);
    } finally {
      calloc.free(u);
    }
  }

  CullReport report({int tone = 1, int week = 1}) {
    final fn = _lib.lookupFunction<_ReportNative, _ReportDart>('CULLReport');
    return _decode<CullReport>(() => fn(_handle, tone, week), _report);
  }

  HoardStats get stats {
    final fn = _lib.lookupFunction<_StatsNative, _StatsDart>('CULLStats');
    return _decode<HoardStats>(() => fn(_handle), _stats);
  }

  void cull(String id) => _byId('CULLCull', id);

  void restore(String id) => _byId('CULLRestore', id);

  void touchOpen(String id) {
    final fn = _lib.lookupFunction<_StampNative, _StampDart>('CULLTouchOpen');
    final p = id.toNativeUtf8();
    try {
      _discard(fn(_handle, p.cast<Char>(), DateTime.now().millisecondsSinceEpoch));
    } finally {
      calloc.free(p);
    }
  }

  void _byId(String symbol, String id) {
    final fn = _lib.lookupFunction<_ByIdNative, _ByIdDart>(symbol);
    final p = id.toNativeUtf8();
    try {
      _discard(fn(_handle, p.cast<Char>()));
    } finally {
      calloc.free(p);
    }
  }
}
