import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.g.dart';

abstract final class CullTheme {
  static const ColorScheme _scheme = ColorScheme.dark(
    primary: CullTokens.signal,
    onPrimary: CullTokens.inkOnAccent,
    secondary: CullTokens.focus,
    onSecondary: CullTokens.inkPrimary,
    error: CullTokens.danger,
    onError: CullTokens.inkPrimary,
    surface: CullTokens.canvas,
    onSurface: CullTokens.inkPrimary,
    outline: CullTokens.inkDisabled,
    outlineVariant: CullTokens.surface4,
  );

  static const SystemUiOverlayStyle overlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: CullTokens.canvas,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Colors.transparent,
  );

  static const OutlineInputBorder _field = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(CullTokens.radiusMd)),
    borderSide: BorderSide(color: CullTokens.surface4),
  );

  static const OutlineInputBorder _fieldFocused = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(CullTokens.radiusMd)),
    borderSide: BorderSide(color: CullTokens.focus, width: 2),
  );

  static TextStyle _style({
    required int weight,
    required double size,
    double height = 1.0,
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
        >= 700 => FontWeight.w700,
        >= 600 => FontWeight.w600,
        >= 500 => FontWeight.w500,
        _ => FontWeight.w400,
      },
    );
  }

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: _scheme,
      fontFamily: CullTokens.fontBody,
      fontFamilyFallback: CullTokens.fontBodyFallback,
      scaffoldBackgroundColor: CullTokens.canvas,
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displayLarge: _style(
          family: CullTokens.fontDisplay,
          fallback: CullTokens.fontDisplayFallback,
          weight: CullTokens.typeDisplayXlWeight,
          size: CullTokens.typeDisplayXlSize,
          height: CullTokens.typeDisplayXlLineHeight,
          tracking: CullTokens.typeDisplayXlTracking,
        ),
        displayMedium: _style(
          family: CullTokens.fontDisplay,
          fallback: CullTokens.fontDisplayFallback,
          weight: CullTokens.typeDisplayMWeight,
          size: CullTokens.typeDisplayMSize,
          height: CullTokens.typeDisplayMLineHeight,
          tracking: CullTokens.typeDisplayMTracking,
        ),
        displaySmall: _style(
          family: CullTokens.fontDisplay,
          fallback: CullTokens.fontDisplayFallback,
          weight: CullTokens.typeDisplaySWeight,
          size: CullTokens.typeDisplaySSize,
          height: CullTokens.typeDisplaySLineHeight,
          tracking: CullTokens.typeDisplaySTracking,
        ),
        headlineMedium: _style(
          family: CullTokens.fontDisplay,
          fallback: CullTokens.fontDisplayFallback,
          weight: CullTokens.typeTitleLWeight,
          size: CullTokens.typeTitleLSize,
          height: CullTokens.typeTitleLLineHeight,
        ),
        titleLarge: _style(
          weight: CullTokens.typeTitleMWeight,
          size: CullTokens.typeTitleMSize,
          height: CullTokens.typeTitleMLineHeight,
        ),
        titleMedium: _style(
          weight: CullTokens.typeTitleMWeight,
          size: CullTokens.typeTitleMSize,
          height: CullTokens.typeTitleMLineHeight,
        ),
        bodyLarge: _style(
          color: CullTokens.inkSecondary,
          weight: CullTokens.typeBodyLWeight,
          size: CullTokens.typeBodyLSize,
          height: CullTokens.typeBodyLLineHeight,
        ),
        bodyMedium: _style(
          color: CullTokens.inkSecondary,
          weight: CullTokens.typeBodyMWeight,
          size: CullTokens.typeBodyMSize,
          height: CullTokens.typeBodyMLineHeight,
        ),
        bodySmall: _style(
          color: CullTokens.inkTertiary,
          weight: CullTokens.typeBodySWeight,
          size: CullTokens.typeBodySSize,
          height: CullTokens.typeBodySLineHeight,
        ),
        labelLarge: _style(
          weight: CullTokens.typeLabelWeight,
          size: CullTokens.typeLabelSize,
          height: CullTokens.typeLabelLineHeight,
          tracking: CullTokens.typeLabelTracking,
        ),
        labelSmall: _style(
          family: CullTokens.fontMono,
          fallback: CullTokens.fontMonoFallback,
          color: CullTokens.inkMono,
          weight: CullTokens.typeMonoSWeight,
          size: CullTokens.typeMonoSSize,
          height: CullTokens.typeMonoSLineHeight,
          tracking: CullTokens.typeMonoSTracking,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: CullTokens.surface3,
        thickness: 1,
        space: 1,
      ),
      cardTheme: const CardThemeData(
        color: CullTokens.surface1,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(CullTokens.radiusLg)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: CullTokens.signal,
          foregroundColor: CullTokens.inkOnAccent,
          minimumSize: const Size(0, CullTokens.minTouchTarget),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(CullTokens.radiusPill)),
          ),
          textStyle: _style(
            weight: CullTokens.typeBodyMWeight,
            size: CullTokens.typeBodyMSize,
            color: CullTokens.inkOnAccent,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: CullTokens.inkPrimary,
          minimumSize: const Size(0, CullTokens.minTouchTarget),
          side: const BorderSide(color: CullTokens.inkDisabled),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(CullTokens.radiusPill)),
          ),
          textStyle: _style(
            weight: CullTokens.typeBodyMWeight,
            size: CullTokens.typeBodyMSize,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: CullTokens.inkSecondary,
          minimumSize: const Size(0, CullTokens.minTouchTarget),
          textStyle: _style(
            weight: CullTokens.typeBodyMWeight,
            size: CullTokens.typeBodyMSize,
            color: CullTokens.inkSecondary,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: CullTokens.inkSecondary,
          minimumSize: const Size(
            CullTokens.minTouchTarget,
            CullTokens.minTouchTarget,
          ),
        ),
      ),
      focusColor: CullTokens.focus,
      iconTheme: const IconThemeData(
        color: CullTokens.inkSecondary,
        size: CullTokens.spaceXl,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: CullTokens.surface1,
        contentPadding: EdgeInsets.symmetric(
          horizontal: CullTokens.spaceMd,
          vertical: CullTokens.spaceMd,
        ),
        hintStyle: TextStyle(
          color: CullTokens.inkTertiary,
          fontSize: CullTokens.typeBodyMSize,
          fontFamily: CullTokens.fontBody,
        ),
        enabledBorder: _field,
        focusedBorder: _fieldFocused,
        border: _field,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: CullTokens.surface4,
        contentTextStyle: TextStyle(
          color: CullTokens.inkPrimary,
          fontSize: CullTokens.typeBodyMSize,
          fontFamily: CullTokens.fontBody,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(CullTokens.radiusMd)),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: CullTokens.surface4,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(CullTokens.radiusMd)),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: CullTokens.surface3,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(CullTokens.radiusXl),
          ),
        ),
      ),
    );
  }
}
