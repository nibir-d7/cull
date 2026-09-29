import 'package:flutter/widgets.dart';

import '../data/hoard_repository.dart';
import '../design/components.dart';
import '../design/controls.dart';
import '../design/glyphs.dart';
import '../design/shell.dart';
import '../design/tokens.g.dart';
import '../design/type.dart';
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
  bool _culling = false;

  @override
  void initState() {
    super.initState();
    _loadTone();
  }

  Future<void> _loadTone() async {
    final t = await widget.repository.tone();
    if (!mounted) return;
    setState(() => _tone = t);
  }

  Future<void> _setTone(int tone) async {
    await widget.repository.setTone(tone);
    if (!mounted) return;
    setState(() => _tone = tone);
    CullToast.show(context, 'Set to ${RoastTone.values[tone].label}');
  }

  Future<void> _cullEverything() async {
    final ok = await cullConfirm(
      context,
      title: 'Cull everything?',
      message:
          'Every link you have saved moves to the Graveyard, and is deleted '
          'after 30 days. You can restore any of it until then.',
      confirmLabel: 'Cull it all',
    );
    if (!ok || !mounted) return;
    setState(() => _culling = true);
    var failed = 0;
    try {
      final all = await widget.repository.hoard(limit: 5000);
      for (final link in all) {
        try {
          await widget.repository.cull(link.id);
        } on Object {
          failed++;
        }
      }
    } finally {
      if (mounted) setState(() => _culling = false);
    }
    if (!mounted) return;
    setState(() => _stats = widget.repository.stats());
    CullToast.show(
      context,
      failed == 0 ? 'Graveyard is full' : '$failed would not go',
      tint: failed == 0 ? null : CullTokens.dangerDim,
    );
  }

  @override
  Widget build(BuildContext context) {
    return CullPage(
      eyebrow: 'On this device',
      title: 'Settings',
      child: CullScroll(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel(text: 'How direct'),
            for (final option in OnboardingCopy.tones)
              Padding(
                padding: const EdgeInsets.only(bottom: CullTokens.spaceSm),
                child: CullSurface(
                  onTap: () => _setTone(option.tone.index),
                  selected: _tone == option.tone.index,
                  padding: const EdgeInsets.all(CullTokens.spaceLg),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(option.name, style: CullType.titleM),
                            const SizedBox(height: 2),
                            Text(option.blurb, style: CullType.bodyS),
                          ],
                        ),
                      ),
                      CullGlyph(
                        _tone == option.tone.index
                            ? CullIcon.check
                            : CullIcon.ring,
                        size: 22,
                        color: _tone == option.tone.index
                            ? option.tone.accent
                            : CullTokens.inkDisabled,
                      ),
                    ],
                  ),
                ),
              ),
            const SectionLabel(text: 'Your hoard'),
            FutureBuilder<HoardStats>(
              future: _stats,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox(height: 60);
                }
                final s = snapshot.data!;
                return CullSurface(
                  child: Column(
                    children: [
                      _row('Links saved', '${s.total}'),
                      _row('Duplicates found', '${s.duplicates}'),
                      _row('Opened at least once', '${s.opened}'),
                      _row(
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
            const SectionLabel(text: 'Where your data lives'),
            CullSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ScoreExplanation(
                    text:
                        'On this device. There is no account, no server, and no '
                        'copy anywhere else.',
                    leading: const CullGlyph(
                      CullIcon.phone,
                      size: 14,
                      color: CullTokens.signalDim,
                    ),
                  ),
                  const SizedBox(height: CullTokens.spaceMd),
                  ScoreExplanation(
                    text:
                        'Cloud backup and device-transfer backup are switched '
                        'off, so the database is not copied to your Google account.',
                    leading: const CullGlyph(
                      CullIcon.cloudOff,
                      size: 14,
                      color: CullTokens.signalDim,
                    ),
                  ),
                  const SizedBox(height: CullTokens.spaceMd),
                  ScoreExplanation(
                    text:
                        'No analytics, no crash reporting, no telemetry. The one '
                        'network request the app makes is fetching a page you just '
                        'shared, so it can work out what it is.',
                    leading: const CullGlyph(
                      CullIcon.muted,
                      size: 14,
                      color: CullTokens.signalDim,
                    ),
                  ),
                ],
              ),
            ),
            const SectionLabel(text: 'Start again'),
            CullButton(
              label: _culling ? 'Culling' : 'Cull everything',
              kind: CullButtonKind.outline,
              expand: true,
              onPressed: _culling ? null : _cullEverything,
            ),
            const SizedBox(height: CullTokens.spaceLg),
            Text(
              'Engine schema version ${widget.repository.schemaVersionSync}.',
              style: CullType.monoXs,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CullTokens.spaceXs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: CullType.bodyM)),
          Text(value, style: CullType.monoS),
        ],
      ),
    );
  }
}
