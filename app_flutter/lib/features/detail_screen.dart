import 'package:flutter/widgets.dart';

import '../data/hoard_repository.dart';
import '../design/components.dart';
import '../design/controls.dart';
import '../design/glyphs.dart';
import '../design/shell.dart';
import '../design/tokens.g.dart';
import '../design/type.dart';
import '../engine/cull_ffi.dart';

class DetailScreen extends StatefulWidget {
  const DetailScreen({super.key, required this.link, required this.repository});

  final Link link;
  final HoardRepository repository;

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late String _category = widget.link.category;
  late List<String> _categories = const [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  void _loadCategories() {
    try {
      _categories = widget.repository.categories();
    } on Object {
      _categories = const [];
    }
  }

  Future<void> _recategorise(String next) async {
    if (next == _category || _saving) return;
    final previous = _category;
    setState(() {
      _saving = true;
      _category = next;
    });
    try {
      await widget.repository.setCategory(widget.link.id, next);
      if (!mounted) return;
      CullToast.show(context, 'Filed under $_category');
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _category = previous);
      CullToast.show(
        context,
        'Could not change that: $e',
        tint: CullTokens.dangerDim,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _cull() async {
    final ok = await cullConfirm(
      context,
      title: 'Cull this one?',
      message:
          'It moves to the Graveyard for 30 days, then it is gone. You can '
          'restore it from there until then.',
      confirmLabel: 'Cull it',
    );
    if (!ok || !mounted) return;
    await widget.repository.cull(widget.link.id);
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final link = widget.link;
    return CullPage(
      eyebrow: link.domain,
      title: link.title.isEmpty ? link.url : link.title,
      trailing: CullGlyphButton(
        icon: CullIcon.trash,
        label: 'Cull this link',
        color: CullTokens.dangerDim,
        onPressed: _cull,
      ),
      child: CullScroll(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(link.url, style: CullType.monoS),
                      const SizedBox(height: CullTokens.spaceMd),
                      ScoreDial(
                        score: link.hoardScore,
                        band: link.band,
                        size: 64,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SectionLabel(text: 'Filed under'),
            _CategoryPicker(
              current: _category,
              options: _categories.isEmpty ? [_category] : _categories,
              busy: _saving,
              onSelect: _recategorise,
            ),
            const SectionLabel(text: 'What the numbers say'),
            CullSurface(
              padding: const EdgeInsets.all(CullTokens.spaceLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ScoreExplanation(
                    text: link.explanation,
                    leading: const CullGlyph(
                      CullIcon.clock,
                      size: 14,
                      color: CullTokens.inkTertiary,
                    ),
                  ),
                  const SizedBox(height: CullTokens.spaceMd),
                  ScoreExplanation(
                    text:
                        'Actionability ${link.actionability.toStringAsFixed(2)} '
                        'on a 0 to 1 scale. Near zero means nothing here tells you '
                        'what to do next.',
                    leading: const CullGlyph(
                      CullIcon.bolt,
                      size: 14,
                      color: CullTokens.inkTertiary,
                    ),
                  ),
                  const SizedBox(height: CullTokens.spaceMd),
                  Row(
                    children: [
                      Expanded(
                        child: _Fact(label: 'age', value: '${link.ageDays}d'),
                      ),
                      Expanded(
                        child: _Fact(
                          label: 'opens',
                          value: '${link.openCount}',
                        ),
                      ),
                      Expanded(
                        child: _Fact(
                          label: 'saves',
                          value: '${link.duplicateCount + 1}',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (link.excerpt.isNotEmpty) ...[
              const SectionLabel(text: 'From the page'),
              Text(link.excerpt, style: CullType.bodyL),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({
    required this.current,
    required this.options,
    required this.busy,
    required this.onSelect,
  });

  final String current;
  final List<String> options;
  final bool busy;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: busy ? 0.5 : 1,
      child: Wrap(
        spacing: CullTokens.spaceSm,
        runSpacing: CullTokens.spaceSm,
        children: [
          for (final c in options)
            _CategoryOption(
              category: c,
              selected: c == current,
              onTap: () => onSelect(c),
            ),
        ],
      ),
    );
  }
}

class _CategoryOption extends StatelessWidget {
  const _CategoryOption({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final String category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: category,
      child: CullSurface(
        onTap: onTap,
        selected: selected,
        padding: const EdgeInsets.symmetric(
          horizontal: CullTokens.spaceMd,
          vertical: CullTokens.spaceSm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 7,
              child: CustomPaint(
                painter: _MarkPainter(categoryColor(category)),
              ),
            ),
            const SizedBox(width: CullTokens.spaceSm),
            Text(
              category.toUpperCase(),
              style: CullType.label.copyWith(
                color: selected
                    ? CullTokens.signalDim
                    : CullTokens.inkSecondary,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: CullTokens.spaceSm),
              const CullGlyph(
                CullIcon.check,
                size: 13,
                color: CullTokens.signalDim,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      size.center(Offset.zero),
      size.shortestSide / 2,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.color != color;
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: CullType.monoXs.copyWith(color: CullTokens.inkTertiary),
        ),
        const SizedBox(height: 2),
        Text(value, style: CullType.monoL),
      ],
    );
  }
}
