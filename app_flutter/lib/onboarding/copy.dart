import 'package:flutter/widgets.dart';

import '../design/tokens.g.dart';

enum RoastTone {
  soft(CullTokens.signalDim, 'Quiet'),
  blunt(CullTokens.signal, 'Plain'),
  savage(CullTokens.danger, 'Direct');

  const RoastTone(this.accent, this.label);

  final Color accent;
  final String label;

  String get id => name;

  static RoastTone fromId(String? id) => RoastTone.values.firstWhere(
    (t) => t.id == id,
    orElse: () => RoastTone.blunt,
  );
}

@immutable
class OnboardingPage {
  const OnboardingPage({
    required this.kicker,
    required this.headline,
    required this.body,
    this.footnote,
  });

  final String kicker;

  final String headline;

  final String body;
  final String? footnote;
}

@immutable
class ToneOption {
  const ToneOption({
    required this.tone,
    required this.name,
    required this.blurb,
  });

  final RoastTone tone;
  final String name;
  final String blurb;
}

abstract final class OnboardingCopy {
  static const List<OnboardingPage> pages = [
    OnboardingPage(
      kicker: 'The problem',
      headline: 'Saved is not the same as read.',
      body: 'The gap between the two is where the time actually goes.\n\nMost of what you keep is not lost. It is just not being worked through, and it will keep not being worked through for a very long time, comfortably, without ever bothering you.',
      footnote: 'This app is only interested in that gap.',
    ),
    OnboardingPage(
      kicker: 'What it does',
      headline: 'Everything in, one place, already sorted.',
      body: 'Share a link to CULL from anywhere — an article, a video, a product, a thread — and it lands here already categorised.\n\nOr put it in a category yourself. Both work. The point is that you should not have to think about where something goes at the moment you are reading it.',
    ),
    OnboardingPage(
      kicker: 'Share it over',
      headline: 'Sharing a link is the whole interaction.',
      body: 'CULL is in your share sheet. You are already in the habit of sending things to yourself; this is the same gesture pointed somewhere useful.\n\nOpen the app when you want to look at what you have kept. Not to feed it.',
    ),
    OnboardingPage(
      kicker: 'Where it lives',
      headline: 'On your phone. That is the whole address.',
      body: 'No account to create, because an account is for something you intend to return to. No sync, no backup, no analytics, no leaderboard, nothing to sign into and nothing watching.\n\nThe list is a file on this device. If you delete CULL, it is gone, and that is the deal.',
    ),
  ];

  static const List<ToneOption> tones = [
    ToneOption(
      tone: RoastTone.soft,
      name: 'Quiet',
      blurb: 'States the number and leaves it there.',
    ),
    ToneOption(
      tone: RoastTone.blunt,
      name: 'Plain',
      blurb: 'Says the pattern in one sentence. Recommended.',
    ),
    ToneOption(
      tone: RoastTone.savage,
      name: 'Direct',
      blurb: 'Says the pattern and the reason, when there is one.',
    ),
  ];

  static const String finalHeadline = 'Look at what you kept.';
  static const String finalBody =
      'CULL will read what is already here, sort it, and mark what has been sitting unopened for long enough that it is probably not going to happen. Then it gets out of the way.';

  static const String cta = 'Open my links';
  static const String skip = 'Later';
}
