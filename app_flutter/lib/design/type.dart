import 'package:flutter/widgets.dart';

import 'tokens.g.dart';

abstract final class CullType {
  static TextStyle _s({
    required int weight,
    required double size,
    required double height,
    double tracking = 0,
    Color color = CullTokens.inkPrimary,
    String family = CullTokens.fontBody,
    List<String> fallback = const [],
  }) {
    return TextStyle(
      fontFamily: family,
      fontFamilyFallback: fallback,
      fontSize: size,
      height: height,
      letterSpacing: tracking,
      color: color,
      fontWeight: switch (weight) {
        >= 800 => FontWeight.w800,
        >= 700 => FontWeight.w700,
        >= 600 => FontWeight.w600,
        >= 500 => FontWeight.w500,
        _ => FontWeight.w400,
      },
    );
  }

  static final TextStyle displayXl = _s(
    family: CullTokens.fontDisplay,
    fallback: CullTokens.fontDisplayFallback,
    weight: CullTokens.typeDisplayXlWeight,
    size: CullTokens.typeDisplayXlSize,
    height: CullTokens.typeDisplayXlLineHeight,
    tracking: CullTokens.typeDisplayXlTracking,
  );

  static final TextStyle displayL = _s(
    family: CullTokens.fontDisplay,
    fallback: CullTokens.fontDisplayFallback,
    weight: CullTokens.typeDisplayLWeight,
    size: CullTokens.typeDisplayLSize,
    height: CullTokens.typeDisplayLLineHeight,
    tracking: CullTokens.typeDisplayLTracking,
  );

  static final TextStyle displayM = _s(
    family: CullTokens.fontDisplay,
    fallback: CullTokens.fontDisplayFallback,
    weight: CullTokens.typeDisplayMWeight,
    size: CullTokens.typeDisplayMSize,
    height: CullTokens.typeDisplayMLineHeight,
    tracking: CullTokens.typeDisplayMTracking,
  );

  static final TextStyle displayS = _s(
    family: CullTokens.fontDisplay,
    fallback: CullTokens.fontDisplayFallback,
    weight: CullTokens.typeDisplaySWeight,
    size: CullTokens.typeDisplaySSize,
    height: CullTokens.typeDisplaySLineHeight,
    tracking: CullTokens.typeDisplaySTracking,
  );

  static final TextStyle titleL = _s(
    family: CullTokens.fontDisplay,
    fallback: CullTokens.fontDisplayFallback,
    weight: CullTokens.typeTitleLWeight,
    size: CullTokens.typeTitleLSize,
    height: CullTokens.typeTitleLLineHeight,
    tracking: CullTokens.typeTitleLTracking,
  );

  static final TextStyle titleM = _s(
    weight: CullTokens.typeTitleMWeight,
    size: CullTokens.typeTitleMSize,
    height: CullTokens.typeTitleMLineHeight,
    tracking: CullTokens.typeTitleMTracking,
  );

  static final TextStyle bodyL = _s(
    color: CullTokens.inkSecondary,
    weight: CullTokens.typeBodyLWeight,
    size: CullTokens.typeBodyLSize,
    height: CullTokens.typeBodyLLineHeight,
  );

  static final TextStyle bodyM = _s(
    color: CullTokens.inkSecondary,
    weight: CullTokens.typeBodyMWeight,
    size: CullTokens.typeBodyMSize,
    height: CullTokens.typeBodyMLineHeight,
  );

  static final TextStyle bodyS = _s(
    color: CullTokens.inkTertiary,
    weight: CullTokens.typeBodySWeight,
    size: CullTokens.typeBodySSize,
    height: CullTokens.typeBodySLineHeight,
  );

  static final TextStyle label = _s(
    weight: CullTokens.typeLabelWeight,
    size: CullTokens.typeLabelSize,
    height: CullTokens.typeLabelLineHeight,
    tracking: CullTokens.typeLabelTracking,
  );

  static final TextStyle monoL = _s(
    family: CullTokens.fontMono,
    fallback: CullTokens.fontMonoFallback,
    color: CullTokens.inkMono,
    weight: CullTokens.typeMonoLWeight,
    size: CullTokens.typeMonoLSize,
    height: CullTokens.typeMonoLLineHeight,
    tracking: CullTokens.typeMonoLTracking,
  );

  static final TextStyle monoS = _s(
    family: CullTokens.fontMono,
    fallback: CullTokens.fontMonoFallback,
    color: CullTokens.inkMono,
    weight: CullTokens.typeMonoSWeight,
    size: CullTokens.typeMonoSSize,
    height: CullTokens.typeMonoSLineHeight,
    tracking: CullTokens.typeMonoSTracking,
  );

  static final TextStyle monoXs = _s(
    family: CullTokens.fontMono,
    fallback: CullTokens.fontMonoFallback,
    color: CullTokens.inkTertiary,
    weight: CullTokens.typeMonoXsWeight,
    size: CullTokens.typeMonoXsSize,
    height: CullTokens.typeMonoXsLineHeight,
    tracking: CullTokens.typeMonoXsTracking,
  );

  static TextStyle withColor(TextStyle base, Color color) =>
      base.copyWith(color: color);
}
