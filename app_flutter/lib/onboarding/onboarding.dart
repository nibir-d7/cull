import 'package:flutter/widgets.dart';

import '../design/controls.dart';
import '../design/glyphs.dart';
import '../design/shell.dart';
import '../design/tokens.g.dart';
import '../design/type.dart';
import 'copy.dart';

class Onboarding extends StatefulWidget {
  const Onboarding({
    super.key,
    required this.onFinished,
    this.initialTone = RoastTone.blunt,
  });

  final ValueChanged<RoastTone> onFinished;
  final RoastTone initialTone;

  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  final PageController _pages = PageController();
  late RoastTone _tone = widget.initialTone;
  int _index = 0;

  int get _total => OnboardingCopy.pages.length + 2;

  bool get _isLast => _index == _total - 1;

  void _next() {
    if (_isLast) {
      widget.onFinished(_tone);
      return;
    }
    _pages.nextPage(
      duration: _tone == RoastTone.savage
          ? CullTokens.motionDramatic
          : CullTokens.motionSettle,
      curve: Curves.easeOutCubic,
    );
  }

  void _back() {
    if (_index == 0) return;
    _pages.previousPage(
      duration: CullTokens.motionSettle,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CullApp(
      child: ColoredBox(
        color: CullTokens.canvas,
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pages,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _index = i),
                  children: [
                    for (final p in OnboardingCopy.pages)
                      _Statement(page: p, index: _index, total: _total),
                    _TonePage(
                      selected: _tone,
                      onSelect: (v) => setState(() => _tone = v),
                    ),
                    _FinalPage(tone: _tone),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  CullTokens.spaceLg,
                  CullTokens.spaceMd,
                  CullTokens.spaceLg,
                  CullTokens.spaceLg,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 84,
                      child: _index == 0
                          ? null
                          : CullButton(
                              label: 'Back',
                              kind: CullButtonKind.ghost,
                              dense: true,
                              onPressed: _back,
                            ),
                    ),
                    Expanded(
                      child: _Progress(index: _index, total: _total),
                    ),
                    SizedBox(
                      width: 84,
                      child: CullButton(
                        label: _isLast ? OnboardingCopy.cta : 'Next',
                        onPressed: _next,
                        dense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Statement extends StatelessWidget {
  const _Statement({
    required this.page,
    required this.index,
    required this.total,
  });

  final OnboardingPage page;
  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        CullTokens.spaceLg,
        CullTokens.spaceN2xl,
        CullTokens.spaceLg,
        CullTokens.spaceXl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 28, height: 3, color: CullTokens.signalDim),
              const SizedBox(width: CullTokens.spaceSm),
              Flexible(
                child: Text(
                  page.kicker.toUpperCase(),
                  style: CullType.monoXs.copyWith(
                    color: CullTokens.inkSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: CullTokens.spaceLg),
          Text(page.headline, style: CullType.displayL),
          const SizedBox(height: CullTokens.spaceXl),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Text(page.body, style: CullType.bodyL),
          ),
          if (page.footnote != null) ...[
            const SizedBox(height: CullTokens.spaceN2xl),
            _Footnote(text: page.footnote!),
          ],
        ],
      ),
    );
  }
}

class _Footnote extends StatelessWidget {
  const _Footnote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(CullTokens.spaceLg),
      decoration: BoxDecoration(
        color: CullTokens.canvasDeep,
        borderRadius: BorderRadius.circular(CullTokens.radiusMd),
        border: Border(left: BorderSide(color: CullTokens.accentDim, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CullGlyph(CullIcon.forward, size: 14, color: CullTokens.accentDim),
          const SizedBox(width: CullTokens.spaceMd),
          Expanded(
            child: Text(
              text,
              style: CullType.bodyS.copyWith(color: CullTokens.inkSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _TonePage extends StatelessWidget {
  const _TonePage({required this.selected, required this.onSelect});

  final RoastTone selected;
  final ValueChanged<RoastTone> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        CullTokens.spaceLg,
        CullTokens.spaceN2xl,
        CullTokens.spaceLg,
        CullTokens.spaceXl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 28, height: 3, color: CullTokens.signalDim),
              const SizedBox(width: CullTokens.spaceSm),
              Text(
                'HOW PLAIN',
                style: CullType.monoXs.copyWith(color: CullTokens.inkSecondary),
              ),
            ],
          ),
          const SizedBox(height: CullTokens.spaceLg),
          Text('How direct should it be?', style: CullType.displayL),
          const SizedBox(height: CullTokens.spaceLg),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Text(
              'Every option is honest. They differ in how much room they take. '
              'Change it any time in Settings.',
              style: CullType.bodyL,
            ),
          ),
          const SizedBox(height: CullTokens.spaceN2xl),
          for (final option in OnboardingCopy.tones)
            Padding(
              padding: const EdgeInsets.only(bottom: CullTokens.spaceMd),
              child: _ToneCard(
                option: option,
                isSelected: option.tone == selected,
                onTap: () => onSelect(option.tone),
              ),
            ),
        ],
      ),
    );
  }
}

class _ToneCard extends StatelessWidget {
  const _ToneCard({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final ToneOption option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: ValueKey('tone-${option.tone.id}'),
      selected: isSelected,
      button: true,
      child: CullSurface(
        onTap: onTap,
        selected: isSelected,
        padding: const EdgeInsets.all(CullTokens.spaceLg),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(option.name, style: CullType.titleM),
                  const SizedBox(height: CullTokens.spaceXs),
                  Text(option.blurb, style: CullType.bodyS),
                ],
              ),
            ),
            const SizedBox(width: CullTokens.spaceMd),
            CullGlyph(
              isSelected ? CullIcon.check : CullIcon.ring,
              size: 22,
              color: isSelected ? option.tone.accent : CullTokens.inkDisabled,
            ),
          ],
        ),
      ),
    );
  }
}

class _FinalPage extends StatelessWidget {
  const _FinalPage({required this.tone});

  final RoastTone tone;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        CullTokens.spaceLg,
        CullTokens.spaceN2xl,
        CullTokens.spaceLg,
        CullTokens.spaceXl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 28, height: 3, color: tone.accent),
              const SizedBox(width: CullTokens.spaceSm),
              Text(
                'READY',
                style: CullType.monoXs.copyWith(color: tone.accent),
              ),
            ],
          ),
          const SizedBox(height: CullTokens.spaceLg),
          Text(OnboardingCopy.finalHeadline, style: CullType.displayL),
          const SizedBox(height: CullTokens.spaceXl),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Text(OnboardingCopy.finalBody, style: CullType.bodyL),
          ),
        ],
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.index, required this.total});

  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    final done = total > 1 ? index / (total - 1) : 0.0;
    return Semantics(
      label: 'Step ${index + 1} of $total',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: CullTokens.spaceMd),
        child: SizedBox(
          height: 3,
          child: LayoutBuilder(
            builder: (context, c) => Stack(
              children: [
                ColoredBox(
                  color: CullTokens.inkDisabled.withValues(alpha: 0.4),
                ),
                AnimatedContainer(
                  duration: CullTokens.motionSettle,
                  curve: Curves.easeOutCubic,
                  width: c.maxWidth * done,
                  color: CullTokens.signalDim,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
