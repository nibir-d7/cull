import 'package:flutter/material.dart';

import '../data/hoard_repository.dart';
import '../design/components.dart';
import '../design/tokens.g.dart';
import '../engine/cull_ffi.dart';
import '../onboarding/copy.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.repository});

  final HoardRepository repository;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<HoardStats> _stats = widget.repository.stats();
  late int _tone = RoastTone.blunt.index;
  bool _loaded = false;
  bool _culling = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final t = await widget.repository.tone();
    if (!mounted) return;
    setState(() {
      _tone = t;
      _loaded = true;
    });
    _stats = widget.repository.stats();
  }

  Future<void> _setTone(int tone) async {
    await widget.repository.setTone(tone);
    if (!mounted) return;
    setState(() => _tone = tone);
  }

  Future<void> _confirmCullEverything() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cull everything?'),
        content: const Text(
          'Every link you have saved goes to the Graveyard, then is deleted '
          'after 30 days. You can restore from the Graveyard until then.\n\n'
          'This is the app doing what it exists to do.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep them'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cull it all'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _culling = true);
    try {
      final all = await widget.repository.hoard(limit: 5000);
      for (final link in all) {
        try {
          await widget.repository.cull(link.id);
        } catch (_) {
          continue;
        }
      }
    } finally {
      if (mounted) setState(() => _culling = false);
      setState(() {
        _stats = widget.repository.stats();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(CullTokens.spaceMd),
        children: [
          Text('Voice', style: t.textTheme.titleMedium),
          const SizedBox(height: CullTokens.spaceSm),
          for (final option in [
            (RoastTone.soft, 'Diplomatic. It suggests.'),
            (RoastTone.blunt, 'Says the thing. Recommended.'),
            (RoastTone.savage, 'Reads your bookmarks back to you.'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: CullTokens.spaceSm),
              child: GlassCard(
                onTap: () => _setTone(option.$1.index),
                level: _tone == option.$1.index ? 3 : 1,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(option.$1.label, style: t.textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text(option.$2, style: t.textTheme.bodyMedium),
                        ],
                      ),
                    ),
                    Icon(
                      _tone == option.$1.index
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: _tone == option.$1.index
                          ? CullTokens.signal
                          : CullTokens.inkDisabled,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: CullTokens.spaceLg),
          Text('Your hoard', style: t.textTheme.titleMedium),
          const SizedBox(height: CullTokens.spaceSm),
          FutureBuilder<HoardStats>(
            future: _stats,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox(height: 60);
              }
              final s = snapshot.data!;
              return GlassCard(
                level: 1,
                child: Column(
                  children: [
                    _row(t, 'Links saved', '${s.total}'),
                    _row(t, 'Duplicates found', '${s.duplicates}'),
                    _row(t, 'Opened at least once', '${s.opened}'),
                    _row(
                      t,
                      'Average hoard score',
                      s.total == 0
                          ? 'n/a'
                          : s.averageScore.toStringAsFixed(1),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: CullTokens.spaceLg),
          Text('Where your data lives', style: t.textTheme.titleMedium),
          const SizedBox(height: CullTokens.spaceSm),
          GlassCard(
            level: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ScoreExplanation(
                  text: 'On this device. There is no account, no server, and '
                      'no copy anywhere else.',
                  leading: const Icon(
                    Icons.phone_android,
                    size: CullTokens.spaceMd,
                    color: CullTokens.success,
                  ),
                ),
                const SizedBox(height: CullTokens.spaceSm),
                ScoreExplanation(
                  text: 'Cloud backup and device-transfer backup are switched '
                      'off, so the database is not copied to your Google account.',
                  leading: const Icon(
                    Icons.cloud_off,
                    size: CullTokens.spaceMd,
                    color: CullTokens.success,
                  ),
                ),
                const SizedBox(height: CullTokens.spaceSm),
                ScoreExplanation(
                  text: 'No analytics, no crash reporting, no telemetry. The one '
                      'network request the app makes is fetching a page you just '
                      'shared, so it can work out what it is.',
                  leading: const Icon(
                    Icons.notifications_off_outlined,
                    size: CullTokens.spaceMd,
                    color: CullTokens.success,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: CullTokens.spaceLg),
          OutlinedButton.icon(
            onPressed: _culling ? null : _confirmCullEverything,
            icon: _culling
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: CullTokens.danger,
                    ),
                  )
                : const Icon(Icons.delete_sweep_outlined),
            label: Text(_culling ? 'Culling' : 'Cull everything'),
          ),
          const SizedBox(height: CullTokens.spaceSm),
          Text(
            'Engine schema version ${_schema()}.',
            style: t.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  String _schema() {
    if (!_loaded) return 'unknown';
    return '';
  }

  Widget _row(ThemeData t, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CullTokens.spaceXs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: t.textTheme.bodyLarge)),
          Text(value, style: t.textTheme.labelSmall),
        ],
      ),
    );
  }
}
