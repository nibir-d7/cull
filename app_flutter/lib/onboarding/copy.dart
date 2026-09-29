import 'package:flutter/widgets.dart';

import '../design/tokens.g.dart';

enum RoastTone {
  soft(CullTokens.success),
  blunt(CullTokens.signal),
  savage(CullTokens.danger);

  const RoastTone(this.accent);
  final Color accent;

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
      kicker: 'CULL',
      headline: 'You installed an app to manage links you never open.',
      body:
          'Not a judgement. A probability.\n\nSomewhere in that pile is a 2021 article about a framework you stopped using, a talk you meant to watch, and a tutorial for something you finished in March.',
      footnote: 'We are going to read the lot and tell you which ones were never going to be opened.',
    ),
    OnboardingPage(
      kicker: 'No account',
      headline: 'You needed an account to remember a URL.',
      body:
          'You are not getting one.\n\nAccounts are for things you care about. Money, health, other humans. Not a link you saved in a panic on a bus and forgot by Tuesday.',
    ),
    OnboardingPage(
      kicker: 'No cloud',
      headline: 'Your bookmarks are not worth backing up.',
      body:
          'If this app were uninstalled tomorrow you would lose thousands of things you were never going to open anyway.\n\nWe are not being cruel. We are being accurate, which is cheaper.',
    ),
    OnboardingPage(
      kicker: 'On this device',
      headline: 'Everything stays here.',
      body:
          'No account. No sync. No backup. No analytics, because analytics is just a slow way of uploading your data to someone else and pretending it is a feature.\n\nThere is no server holding your bookmarks, so there is nobody who could read them.',
    ),
  ];

  static const List<ToneOption> tones = [
    ToneOption(
      tone: RoastTone.soft,
      name: 'Soft',
      blurb: 'Diplomatic. It suggests, diplomatically.',
    ),
    ToneOption(
      tone: RoastTone.blunt,
      name: 'Blunt',
      blurb: 'Says the thing. Recommended, for obvious reasons.',
    ),
    ToneOption(
      tone: RoastTone.savage,
      name: 'Savage',
      blurb: 'Reads your bookmarks back to you. Reads them back.',
    ),
  ];

  static const String finalHeadline = 'Right. Let us see what you have been doing.';
  static const String finalBody =
      'We will score every link, find the duplicates, and tell you which ones have been rotting since before you installed this.';
  static const String cta = 'Show me my hoard';
  static const String skip = 'Not now';
}
