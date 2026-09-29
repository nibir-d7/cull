import 'package:flutter/material.dart';

import '../design/tokens.g.dart';
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

  int get _total => OnboardingCopy.pages.length + 1;

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
      curve: CullTokens.curveEmphasized,
    );
  }

  void _back() {
    if (_index == 0) return;
    _pages.previousPage(
      duration: CullTokens.motionSettle,
      curve: CullTokens.curveStandard,
    );
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      backgroundColor: CullTokens.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pages,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _index = i),
                children: [
                  for (final p in OnboardingCopy.pages)
                    _Page(
                      page: p,
                      index: _index,
                      total: _total,
                    ),
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
                    width: 96,
                    child: _index == 0
                        ? null
                        : TextButton(
                            onPressed: _back,
                            child: const Text(OnboardingCopy.skip),
                          ),
                  ),
                  Expanded(
                    child: _Dots(index: _index, total: _total),
                  ),
                  SizedBox(
                    width: 96,
                    child: FilledButton(
                      onPressed: _next,
                      child: Text(
                        _isLast ? OnboardingCopy.cta : 'Next',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (t.textTheme.bodySmall != null) const SizedBox(height: CullTokens.spaceSm),
          ],
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.page, required this.index, required this.total});

  final OnboardingPage page;
  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: CullTokens.spaceXl,
        vertical: CullTokens.spaceXl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            page.kicker.toUpperCase(),
            style: t.textTheme.labelLarge?.copyWith(
              color: CullTokens.signal,
              fontFamily: CullTokens.fontMono,
            ),
          ),
          const SizedBox(height: CullTokens.spaceMd),
          Text(page.headline, style: t.textTheme.displaySmall),
          const SizedBox(height: CullTokens.spaceLg),
          Text(page.body, style: t.textTheme.bodyLarge),
          if (page.footnote != null) ...[
            const SizedBox(height: CullTokens.spaceXl),
            Container(
              padding: const EdgeInsets.all(CullTokens.spaceMd),
              decoration: BoxDecoration(
                color: CullTokens.surface1,
                borderRadius: BorderRadius.circular(CullTokens.radiusMd),
                border: Border.all(color: CullTokens.surface4),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.arrow_outward,
                    size: CullTokens.spaceMd,
                    color: CullTokens.inkTertiary,
                  ),
                  const SizedBox(width: CullTokens.spaceSm),
                  Expanded(
                    child: Text(
                      page.footnote!,
                      style: t.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
    final t = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: CullTokens.spaceXl,
        vertical: CullTokens.spaceXl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'VOICE',
            style: t.textTheme.labelLarge?.copyWith(
              color: CullTokens.signal,
              fontFamily: CullTokens.fontMono,
            ),
          ),
          const SizedBox(height: CullTokens.spaceMd),
          Text('How honest do you want to be?', style: t.textTheme.displaySmall),
          const SizedBox(height: CullTokens.spaceSm),
          Text(
            'You can change this whenever you get tired of it. You will not.',
            style: t.textTheme.bodyLarge,
          ),
          const SizedBox(height: CullTokens.spaceXl),
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
    final t = Theme.of(context);
    return Semantics(
      key: ValueKey('tone-${option.tone.id}'),
      selected: isSelected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CullTokens.radiusMd),
        child: AnimatedContainer(
          duration: CullTokens.motionSettle,
          curve: CullTokens.curveEmphasized,
          padding: const EdgeInsets.all(CullTokens.spaceLg),
          decoration: BoxDecoration(
            color: isSelected ? option.tone.accent : CullTokens.surface1,
            borderRadius: BorderRadius.circular(CullTokens.radiusMd),
            border: Border.all(
              color: isSelected ? option.tone.accent : CullTokens.surface4,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.name,
                      style: t.textTheme.titleMedium?.copyWith(
                        color: isSelected
                            ? CullTokens.inkOnAccent
                            : CullTokens.inkPrimary,
                      ),
                    ),
                    const SizedBox(height: CullTokens.spaceXs),
                    Text(
                      option.blurb,
                      style: t.textTheme.bodyMedium?.copyWith(
                        color: isSelected
                            ? CullTokens.inkOnAccent
                            : CullTokens.inkSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: CullTokens.spaceMd),
              Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,
                color: isSelected ? CullTokens.inkOnAccent : CullTokens.inkDisabled,
              ),
            ],
          ),
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
    final t = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: CullTokens.spaceXl,
        vertical: CullTokens.spaceXl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tone.name.toUpperCase(),
            style: t.textTheme.labelLarge?.copyWith(
              color: tone.accent,
              fontFamily: CullTokens.fontMono,
            ),
          ),
          const SizedBox(height: CullTokens.spaceMd),
          Text(OnboardingCopy.finalHeadline, style: t.textTheme.displaySmall),
          const SizedBox(height: CullTokens.spaceLg),
          Text(OnboardingCopy.finalBody, style: t.textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.index, required this.total});

  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step ${index + 1} of $total',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < total; i++)
            AnimatedContainer(
              duration: CullTokens.motionSettle,
              curve: CullTokens.curveEmphasized,
              margin: const EdgeInsets.symmetric(horizontal: CullTokens.spaceXs),
              width: i == index ? CullTokens.spaceLg : CullTokens.spaceXs,
              height: CullTokens.spaceXs,
              decoration: BoxDecoration(
                color: i == index ? CullTokens.signal : CullTokens.surface4,
                borderRadius: BorderRadius.circular(CullTokens.radiusPill),
              ),
            ),
        ],
      ),
    );
  }
}
