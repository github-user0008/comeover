import 'package:flutter/material.dart';

import 'motion.dart';

/// Hand-tuned expressive palette: deep plum night, lavender light, mint signal.
abstract final class Palette {
  static const ink = Color(0xFF0A0712);
  static const plum = Color(0xFF140F20);
  static const violet = Color(0xFF7C5CFF);
  static const lavender = Color(0xFFCDBDFF);
  static const mint = Color(0xFF9BF6FF);
  static const peach = Color(0xFFFFB4A2);
  static const lemon = Color(0xFFFFE08A);
  static const fog = Color(0xFFB9B2CC);
  static const glass = Color(0x22FFFFFF);
  static const glassStrong = Color(0x33FFFFFF);
}

class AppTheme {
  static ThemeData dark({bool highContrast = false}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: Palette.violet,
      brightness: Brightness.dark,
      dynamicSchemeVariant: DynamicSchemeVariant.expressive,
      contrastLevel: highContrast ? 0.6 : 0.0,
    ).copyWith(
      primary: Palette.lavender,
      onPrimary: const Color(0xFF241247),
      primaryContainer: const Color(0xFF45307F),
      onPrimaryContainer: const Color(0xFFE9DFFF),
      secondary: Palette.mint,
      onSecondary: const Color(0xFF00363C),
      secondaryContainer: const Color(0xFF0E4B52),
      onSecondaryContainer: const Color(0xFFC7FBFF),
      tertiary: Palette.peach,
      onTertiary: const Color(0xFF4B1F16),
      tertiaryContainer: const Color(0xFF6B3225),
      onTertiaryContainer: const Color(0xFFFFDBD2),
      surface: Palette.plum,
      onSurface: const Color(0xFFF8F4FF),
      surfaceContainerLowest: const Color(0xFF08050F),
      surfaceContainerLow: const Color(0xFF120D1D),
      surfaceContainer: const Color(0xFF181226),
      surfaceContainerHigh: const Color(0xFF211A30),
      surfaceContainerHighest: const Color(0xFF2B233C),
      onSurfaceVariant: Palette.fog,
      outline: const Color(0xFF5A5270),
      outlineVariant: const Color(0xFF3A3350),
      error: const Color(0xFFFFB4AB),
      onError: const Color(0xFF690005),
      inverseSurface: const Color(0xFFEAE0F5),
      onInverseSurface: const Color(0xFF1B1526),
    );
    return _build(scheme, Typography.blackMountainView, Brightness.dark);
  }

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: Palette.violet,
      brightness: Brightness.light,
      dynamicSchemeVariant: DynamicSchemeVariant.expressive,
    ).copyWith(
      primary: const Color(0xFF5B3FD1),
      onPrimary: Colors.white,
      secondary: const Color(0xFF006B75),
      tertiary: const Color(0xFF9B4231),
      surface: const Color(0xFFFDF8FF),
      onSurface: const Color(0xFF1B1526),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFF7F1FF),
      surfaceContainer: const Color(0xFFF1EAFB),
      surfaceContainerHigh: const Color(0xFFEBE2F7),
      surfaceContainerHighest: const Color(0xFFE4DAF2),
      onSurfaceVariant: const Color(0xFF5F5675),
      outline: const Color(0xFF958CA9),
    );
    return _build(scheme, Typography.blackMountainView, Brightness.light);
  }

  static ThemeData _build(ColorScheme scheme, TextTheme base, Brightness brightness) {
    final text = _textTheme(base, brightness);
    final onSurface = scheme.onSurface;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: 'Figtree',
      textTheme: text,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: scheme.surface,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _FadeThroughBuilder(),
          TargetPlatform.iOS: _FadeThroughBuilder(),
          TargetPlatform.macOS: _FadeThroughBuilder(),
          TargetPlatform.windows: _FadeThroughBuilder(),
          TargetPlatform.linux: _FadeThroughBuilder(),
          TargetPlatform.fuchsia: _FadeThroughBuilder(),
        },
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(56, 56),
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
          shape: const StadiumBorder(),
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(56, 56),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          side: BorderSide(color: scheme.outlineVariant),
          shape: const StadiumBorder(),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: const StadiumBorder(),
          textStyle: text.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: onSurface,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh.withValues(alpha: 0.6),
        hintStyle: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.surfaceContainerHighest,
        contentTextStyle: text.bodyMedium?.copyWith(color: onSurface),
        shape: const StadiumBorder(),
        insetPadding: const EdgeInsets.all(20),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
        ),
        showDragHandle: false,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: text.bodySmall?.copyWith(color: scheme.onInverseSurface),
      ),
      dividerColor: scheme.outlineVariant.withValues(alpha: 0.5),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        iconColor: scheme.onSurfaceVariant,
        textColor: onSurface,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.secondary,
        linearTrackColor: scheme.surfaceContainerHighest,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? scheme.onPrimary : scheme.onSurfaceVariant,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? scheme.primary : scheme.surfaceContainerHighest,
        ),
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base, Brightness brightness) {
    final ink = brightness == Brightness.dark ? const Color(0xFFF8F4FF) : const Color(0xFF1B1526);
    TextStyle style(double size, FontWeight weight, double height, double tracking) => TextStyle(
          fontFamily: 'Figtree',
          fontSize: size,
          height: height,
          fontWeight: weight,
          letterSpacing: tracking,
          color: ink,
        );
    return base.copyWith(
      displayLarge: style(64, FontWeight.w800, 0.98, -2.4),
      displayMedium: style(52, FontWeight.w800, 1.0, -1.8),
      displaySmall: style(42, FontWeight.w700, 1.04, -1.2),
      headlineLarge: style(34, FontWeight.w700, 1.1, -0.8),
      headlineMedium: style(28, FontWeight.w700, 1.14, -0.5),
      headlineSmall: style(24, FontWeight.w700, 1.2, -0.3),
      titleLarge: style(21, FontWeight.w700, 1.24, -0.2),
      titleMedium: style(17, FontWeight.w600, 1.3, 0),
      titleSmall: style(15, FontWeight.w600, 1.3, 0),
      bodyLarge: style(16, FontWeight.w400, 1.5, 0),
      bodyMedium: style(14.5, FontWeight.w400, 1.5, 0.1),
      bodySmall: style(12.5, FontWeight.w400, 1.45, 0.15),
      labelLarge: style(15, FontWeight.w700, 1.2, 0.1),
      labelMedium: style(12.5, FontWeight.w600, 1.2, 0.4),
      labelSmall: style(11, FontWeight.w600, 1.2, 0.6),
    ).apply(displayColor: ink, bodyColor: ink);
  }
}

class _FadeThroughBuilder extends PageTransitionsBuilder {
  const _FadeThroughBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Motion.emphasizedDecelerate,
      reverseCurve: Motion.emphasizedAccelerate,
    );
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
        child: child,
      ),
    );
  }
}
