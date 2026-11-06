import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'motion.dart';

/// Legacy brand range. New UI code should read tokens from [AppStyle] so the
/// same screen can render as Material 3 Expressive on Android and as quieter
/// Liquid Glass on Apple platforms.
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

/// The two visual languages the app ships with.
///
/// Android (phones, tablets, TV and Fire OS) gets Material 3 Expressive:
/// vivid generated colour roles, tonal surfaces, heavier type and springy
/// motion. iOS and macOS get a restrained Liquid Glass treatment: graphite
/// surfaces, hairline rims, deep blur and native SF type.
enum VisualLanguage { materialExpressive, liquidGlass }

VisualLanguage visualLanguageFor(TargetPlatform platform) {
  return switch (platform) {
    TargetPlatform.iOS || TargetPlatform.macOS => VisualLanguage.liquidGlass,
    _ => VisualLanguage.materialExpressive,
  };
}

/// Platform-specific design tokens exposed through [ThemeData.extensions].
///
/// Reading these instead of [Palette] constants is what keeps the Android and
/// iOS builds from looking like the same skin with a different accent.
@immutable
class AppStyle extends ThemeExtension<AppStyle> {
  const AppStyle({
    required this.visual,
    required this.background,
    required this.ink,
    required this.scrim,
    required this.live,
    required this.warm,
    required this.caution,
    required this.accent,
    required this.brand,
    required this.auroraPrimary,
    required this.auroraSecondary,
    required this.auroraTertiary,
    required this.auroraStrength,
    required this.backgroundPeriod,
    required this.glassBlur,
    required this.glassSaturation,
    required this.glassTintAlpha,
    required this.glassBorderAlpha,
    required this.glassBorderWidth,
    required this.glassHighlightAlpha,
    required this.glassShadowAlpha,
    required this.useBlur,
    required this.useGlow,
    required this.cardRadius,
    required this.inputRadius,
    required this.buttonRadius,
    required this.pressScale,
    required this.chipFill,
    required this.chipBorder,
    required this.mapTint,
    required this.mapTintBlend,
  });

  final VisualLanguage visual;

  /// Opaque page background behind the aurora blobs.
  final Color background;

  /// Scrim used over maps and video-like surfaces.
  final Color ink;
  final Color scrim;

  /// Signal colours. These stay semantic rather than brand-specific.
  final Color live;
  final Color warm;
  final Color caution;
  final Color accent;
  final Color brand;

  final Color auroraPrimary;
  final Color auroraSecondary;
  final Color auroraTertiary;
  final double auroraStrength;
  final Duration backgroundPeriod;

  final double glassBlur;
  final double glassSaturation;
  final double glassTintAlpha;
  final double glassBorderAlpha;
  final double glassBorderWidth;
  final double glassHighlightAlpha;
  final double glassShadowAlpha;
  final bool useBlur;
  final bool useGlow;

  final double cardRadius;
  final double inputRadius;
  final double buttonRadius;
  final double pressScale;

  final Color chipFill;
  final Color chipBorder;

  final Color mapTint;
  final BlendMode mapTintBlend;

  bool get isMaterial => visual == VisualLanguage.materialExpressive;
  bool get isLiquid => visual == VisualLanguage.liquidGlass;

  static AppStyle of(BuildContext context) {
    return Theme.of(context).extension<AppStyle>() ?? fallback;
  }

  /// Used by unit tests and the rare widget built without a [Theme].
  static const fallback = AppStyle(
    visual: VisualLanguage.materialExpressive,
    background: Palette.ink,
    ink: Palette.ink,
    scrim: Color(0xC40A0712),
    live: Palette.mint,
    warm: Palette.peach,
    caution: Palette.lemon,
    accent: Palette.lavender,
    brand: Palette.violet,
    auroraPrimary: Palette.violet,
    auroraSecondary: Color(0xFF16C7DA),
    auroraTertiary: Color(0xFFFF7E5F),
    auroraStrength: 1,
    backgroundPeriod: Duration(seconds: 26),
    glassBlur: 18,
    glassSaturation: 1.6,
    glassTintAlpha: 0.10,
    glassBorderAlpha: 0.28,
    glassBorderWidth: 1,
    glassHighlightAlpha: 0.14,
    glassShadowAlpha: 0.18,
    useBlur: true,
    useGlow: true,
    cardRadius: 28,
    inputRadius: 24,
    buttonRadius: 999,
    pressScale: 0.96,
    chipFill: Color(0x14FFFFFF),
    chipBorder: Color(0x24FFFFFF),
    mapTint: Palette.violet,
    mapTintBlend: BlendMode.softLight,
  );

  @override
  AppStyle copyWith({
    VisualLanguage? visual,
    Color? background,
    Color? ink,
    Color? scrim,
    Color? live,
    Color? warm,
    Color? caution,
    Color? accent,
    Color? brand,
    Color? auroraPrimary,
    Color? auroraSecondary,
    Color? auroraTertiary,
    double? auroraStrength,
    Duration? backgroundPeriod,
    double? glassBlur,
    double? glassSaturation,
    double? glassTintAlpha,
    double? glassBorderAlpha,
    double? glassBorderWidth,
    double? glassHighlightAlpha,
    double? glassShadowAlpha,
    bool? useBlur,
    bool? useGlow,
    double? cardRadius,
    double? inputRadius,
    double? buttonRadius,
    double? pressScale,
    Color? chipFill,
    Color? chipBorder,
    Color? mapTint,
    BlendMode? mapTintBlend,
  }) {
    return AppStyle(
      visual: visual ?? this.visual,
      background: background ?? this.background,
      ink: ink ?? this.ink,
      scrim: scrim ?? this.scrim,
      live: live ?? this.live,
      warm: warm ?? this.warm,
      caution: caution ?? this.caution,
      accent: accent ?? this.accent,
      brand: brand ?? this.brand,
      auroraPrimary: auroraPrimary ?? this.auroraPrimary,
      auroraSecondary: auroraSecondary ?? this.auroraSecondary,
      auroraTertiary: auroraTertiary ?? this.auroraTertiary,
      auroraStrength: auroraStrength ?? this.auroraStrength,
      backgroundPeriod: backgroundPeriod ?? this.backgroundPeriod,
      glassBlur: glassBlur ?? this.glassBlur,
      glassSaturation: glassSaturation ?? this.glassSaturation,
      glassTintAlpha: glassTintAlpha ?? this.glassTintAlpha,
      glassBorderAlpha: glassBorderAlpha ?? this.glassBorderAlpha,
      glassBorderWidth: glassBorderWidth ?? this.glassBorderWidth,
      glassHighlightAlpha: glassHighlightAlpha ?? this.glassHighlightAlpha,
      glassShadowAlpha: glassShadowAlpha ?? this.glassShadowAlpha,
      useBlur: useBlur ?? this.useBlur,
      useGlow: useGlow ?? this.useGlow,
      cardRadius: cardRadius ?? this.cardRadius,
      inputRadius: inputRadius ?? this.inputRadius,
      buttonRadius: buttonRadius ?? this.buttonRadius,
      pressScale: pressScale ?? this.pressScale,
      chipFill: chipFill ?? this.chipFill,
      chipBorder: chipBorder ?? this.chipBorder,
      mapTint: mapTint ?? this.mapTint,
      mapTintBlend: mapTintBlend ?? this.mapTintBlend,
    );
  }

  @override
  AppStyle lerp(AppStyle? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    double d(double a, double b) => a + (b - a) * t;
    return AppStyle(
      visual: t < 0.5 ? visual : other.visual,
      background: c(background, other.background),
      ink: c(ink, other.ink),
      scrim: c(scrim, other.scrim),
      live: c(live, other.live),
      warm: c(warm, other.warm),
      caution: c(caution, other.caution),
      accent: c(accent, other.accent),
      brand: c(brand, other.brand),
      auroraPrimary: c(auroraPrimary, other.auroraPrimary),
      auroraSecondary: c(auroraSecondary, other.auroraSecondary),
      auroraTertiary: c(auroraTertiary, other.auroraTertiary),
      auroraStrength: d(auroraStrength, other.auroraStrength),
      backgroundPeriod: t < 0.5 ? backgroundPeriod : other.backgroundPeriod,
      glassBlur: d(glassBlur, other.glassBlur),
      glassSaturation: d(glassSaturation, other.glassSaturation),
      glassTintAlpha: d(glassTintAlpha, other.glassTintAlpha),
      glassBorderAlpha: d(glassBorderAlpha, other.glassBorderAlpha),
      glassBorderWidth: d(glassBorderWidth, other.glassBorderWidth),
      glassHighlightAlpha: d(glassHighlightAlpha, other.glassHighlightAlpha),
      glassShadowAlpha: d(glassShadowAlpha, other.glassShadowAlpha),
      useBlur: t < 0.5 ? useBlur : other.useBlur,
      useGlow: t < 0.5 ? useGlow : other.useGlow,
      cardRadius: d(cardRadius, other.cardRadius),
      inputRadius: d(inputRadius, other.inputRadius),
      buttonRadius: d(buttonRadius, other.buttonRadius),
      pressScale: d(pressScale, other.pressScale),
      chipFill: c(chipFill, other.chipFill),
      chipBorder: c(chipBorder, other.chipBorder),
      mapTint: c(mapTint, other.mapTint),
      mapTintBlend: t < 0.5 ? mapTintBlend : other.mapTintBlend,
    );
  }
}

class AppTheme {
  /// Fallback violet seed, used when the device cannot supply wallpaper
  /// colours (web, TVs, Fire OS, Android < 12). On Android 12+ the scheme
  /// Material You computed from the user's wallpaper is passed in as
  /// [systemScheme] instead and is used verbatim.
  static const _materialSeed = Color(0xFF6D4AFF);

  /// Set by the app once the wallpaper palette resolves. Exposed in Settings
  /// so it is obvious whether the build is running the Material You engine or
  /// the fallback seed.
  static bool deviceColoursActive = false;

  static ThemeData dark({
    bool highContrast = false,
    VisualLanguage? visual,
    TargetPlatform? platform,
    bool? web,
    ColorScheme? systemScheme,
  }) {
    return _theme(
      brightness: Brightness.dark,
      highContrast: highContrast,
      visual: visual,
      platform: platform,
      web: web,
      systemScheme: systemScheme,
    );
  }

  static ThemeData light({
    bool highContrast = false,
    VisualLanguage? visual,
    TargetPlatform? platform,
    bool? web,
    ColorScheme? systemScheme,
  }) {
    return _theme(
      brightness: Brightness.light,
      highContrast: highContrast,
      visual: visual,
      platform: platform,
      web: web,
      systemScheme: systemScheme,
    );
  }

  static ThemeData _theme({
    required Brightness brightness,
    required bool highContrast,
    VisualLanguage? visual,
    TargetPlatform? platform,
    bool? web,
    ColorScheme? systemScheme,
  }) {
    final target = platform ?? defaultTargetPlatform;
    final language = visual ?? visualLanguageFor(target);
    final isWeb = web ?? kIsWeb;
    final scheme =
        language == VisualLanguage.materialExpressive && systemScheme != null
        ? systemScheme
        : _scheme(brightness, language, highContrast);
    final style = _style(scheme, language, brightness, highContrast);

    final base = Typography.material2021(platform: target, colorScheme: scheme);
    final baseText = brightness == Brightness.dark ? base.white : base.black;
    final text = _textTheme(baseText, language, isWeb);
    final onSurface = scheme.onSurface;

    final transitions = language == VisualLanguage.liquidGlass
        ? const <TargetPlatform, PageTransitionsBuilder>{
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
            TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
            TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
          }
        : const <TargetPlatform, PageTransitionsBuilder>{
            TargetPlatform.android: _ExpressivePageTransitionsBuilder(),
            TargetPlatform.iOS: _ExpressivePageTransitionsBuilder(),
            TargetPlatform.macOS: _ExpressivePageTransitionsBuilder(),
            TargetPlatform.windows: _ExpressivePageTransitionsBuilder(),
            TargetPlatform.linux: _ExpressivePageTransitionsBuilder(),
            TargetPlatform.fuchsia: _ExpressivePageTransitionsBuilder(),
          };

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      platform: target,
      colorScheme: scheme,
      textTheme: text,
      extensions: <ThemeExtension<dynamic>>[style],
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: scheme.surface,
      splashFactory: language == VisualLanguage.liquidGlass
          ? NoSplash.splashFactory
          : InkSparkle.splashFactory,
      visualDensity: language == VisualLanguage.liquidGlass
          ? VisualDensity.standard
          : VisualDensity.comfortable,
      pageTransitionsTheme: PageTransitionsTheme(builders: transitions),
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
          side: BorderSide(color: style.chipBorder),
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
        fillColor: language == VisualLanguage.liquidGlass
            ? scheme.surfaceContainerHigh.withValues(alpha: 0.55)
            : scheme.surfaceContainerHigh,
        hintStyle: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 22,
          vertical: 19,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(style.inputRadius),
          borderSide: BorderSide(color: style.chipBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(style.inputRadius),
          borderSide: BorderSide(color: style.chipBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(style.inputRadius),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            language == VisualLanguage.liquidGlass ? 26 : 32,
          ),
        ),
        // Bottom-heavy dialog insets: on TVs the bezel crops the bottom
        // ~5%, and every dialog opens before the app can know its device —
        // so keep all dialogs inside the common safe area by default.
        insetPadding: const EdgeInsets.fromLTRB(48, 36, 48, 56),
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(
              language == VisualLanguage.liquidGlass ? 30 : 38,
            ),
          ),
        ),
        showDragHandle: false,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(
            language == VisualLanguage.liquidGlass ? 10 : 14,
          ),
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
        color: style.live,
        linearTrackColor: scheme.surfaceContainerHighest,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.onSurfaceVariant,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHighest,
        ),
      ),
    );
  }

  static ColorScheme _scheme(
    Brightness brightness,
    VisualLanguage visual,
    bool highContrast,
  ) {
    if (visual == VisualLanguage.materialExpressive) {
      return ColorScheme.fromSeed(
        seedColor: _materialSeed,
        brightness: brightness,
        dynamicSchemeVariant: DynamicSchemeVariant.expressive,
        contrastLevel: highContrast ? 0.5 : 0.0,
      );
    }

    final base = ColorScheme.fromSeed(
      seedColor: const Color(0xFF7C8AE8),
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.neutral,
      contrastLevel: highContrast ? 0.4 : 0.0,
    );

    if (brightness == Brightness.dark) {
      return base.copyWith(
        primary: const Color(0xFFC7D3FF),
        onPrimary: const Color(0xFF1A2542),
        primaryContainer: const Color(0xFF2A3556),
        onPrimaryContainer: const Color(0xFFE4E9FF),
        secondary: const Color(0xFFA9D9D2),
        onSecondary: const Color(0xFF0E2E2B),
        secondaryContainer: const Color(0xFF1F3B38),
        onSecondaryContainer: const Color(0xFFD6F4EF),
        tertiary: const Color(0xFFE6C1B8),
        onTertiary: const Color(0xFF3A211C),
        tertiaryContainer: const Color(0xFF49302A),
        onTertiaryContainer: const Color(0xFFFFE2DB),
        surface: const Color(0xFF0B0C0F),
        onSurface: const Color(0xFFEDEDF2),
        surfaceContainerLowest: const Color(0xFF050608),
        surfaceContainerLow: const Color(0xFF101114),
        surfaceContainer: const Color(0xFF15161A),
        surfaceContainerHigh: const Color(0xFF1B1C21),
        surfaceContainerHighest: const Color(0xFF23242A),
        onSurfaceVariant: const Color(0xFFA3A5B0),
        outline: const Color(0xFF5C5E68),
        outlineVariant: const Color(0xFF2C2E36),
        error: const Color(0xFFFFB4AB),
        onError: const Color(0xFF690005),
      );
    }

    return base.copyWith(
      primary: const Color(0xFF3D5AA8),
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFDCE3FF),
      onPrimaryContainer: const Color(0xFF0E1B3D),
      secondary: const Color(0xFF2F6B64),
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFCFE9E4),
      onSecondaryContainer: const Color(0xFF10322E),
      tertiary: const Color(0xFF7A4F45),
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFFF4DDD6),
      onTertiaryContainer: const Color(0xFF341B15),
      surface: const Color(0xFFF6F6F8),
      onSurface: const Color(0xFF15161A),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFF1F1F4),
      surfaceContainer: const Color(0xFFEBEBEF),
      surfaceContainerHigh: const Color(0xFFE5E5EA),
      surfaceContainerHighest: const Color(0xFFDEDEE5),
      onSurfaceVariant: const Color(0xFF5E606B),
      outline: const Color(0xFF8B8D98),
      outlineVariant: const Color(0xFFD4D5DC),
      error: const Color(0xFFB3261E),
      onError: Colors.white,
    );
  }

  static AppStyle _style(
    ColorScheme scheme,
    VisualLanguage visual,
    Brightness brightness,
    bool highContrast,
  ) {
    final dark = brightness == Brightness.dark;

    if (visual == VisualLanguage.materialExpressive) {
      return AppStyle(
        visual: visual,
        background: scheme.surfaceContainerLowest,
        ink: scheme.surfaceContainerLowest,
        scrim: scheme.scrim.withValues(alpha: 0.80),
        live: scheme.primary,
        warm: dark ? const Color(0xFFFFB59E) : const Color(0xFF9A4B34),
        caution: dark ? const Color(0xFFFFD98A) : const Color(0xFF8A5A00),
        accent: scheme.tertiary,
        brand: scheme.primary,
        auroraPrimary: scheme.primary,
        auroraSecondary: scheme.secondary,
        auroraTertiary: scheme.tertiary,
        auroraStrength: dark ? 0.80 : 0.50,
        backgroundPeriod: const Duration(seconds: 22),
        glassBlur: 0,
        glassSaturation: 1.0,
        glassTintAlpha: 0.14,
        glassBorderAlpha: 0.65,
        glassBorderWidth: 1,
        glassHighlightAlpha: 0.06,
        glassShadowAlpha: 0.26,
        useBlur: false,
        useGlow: false,
        cardRadius: 30,
        inputRadius: 26,
        buttonRadius: 999,
        pressScale: 0.94,
        chipFill: Color.alphaBlend(
          scheme.primary.withValues(alpha: 0.14),
          scheme.surfaceContainerHigh,
        ),
        chipBorder: scheme.outlineVariant.withValues(
          alpha: highContrast ? 1 : 0.75,
        ),
        mapTint: scheme.primary,
        mapTintBlend: BlendMode.softLight,
      );
    }

    final live = dark ? const Color(0xFF8FE3D1) : const Color(0xFF1F6F66);
    final warm = dark ? const Color(0xFFFFB59E) : const Color(0xFF9A4B34);
    final caution = dark ? const Color(0xFFFFD89A) : const Color(0xFF8A5A00);

    return AppStyle(
      visual: visual,
      background: scheme.surface,
      ink: scheme.surfaceContainerLowest,
      scrim: scheme.surfaceContainerLowest.withValues(alpha: 0.78),
      live: live,
      warm: warm,
      caution: caution,
      accent: scheme.primary,
      brand: scheme.primary,
      auroraPrimary: scheme.primary,
      auroraSecondary: live,
      auroraTertiary: warm,
      auroraStrength: dark ? 0.30 : 0.26,
      backgroundPeriod: const Duration(seconds: 40),
      glassBlur: 28,
      glassSaturation: 1.08,
      glassTintAlpha: 0.09,
      glassBorderAlpha: dark ? 0.22 : 0.10,
      glassBorderWidth: 0.75,
      glassHighlightAlpha: 0.16,
      glassShadowAlpha: 0.18,
      useBlur: true,
      useGlow: true,
      cardRadius: 26,
      inputRadius: 16,
      buttonRadius: 999,
      pressScale: 0.97,
      chipFill: scheme.surfaceContainerHigh.withValues(alpha: 0.55),
      chipBorder: scheme.outlineVariant.withValues(alpha: 0.55),
      mapTint: const Color(0xFF7C8AE8),
      mapTintBlend: BlendMode.softLight,
    );
  }

  static TextTheme _textTheme(TextTheme base, VisualLanguage visual, bool web) {
    final material = visual == VisualLanguage.materialExpressive;
    final family = !material
        ? null
        : web
        ? 'Figtree'
        : 'RobotoFlex';
    final vary = material && !web;

    TextStyle style(
      TextStyle? source,
      double size,
      FontWeight weight,
      double height,
      double tracking, [
      int width = 100,
    ]) {
      return (source ?? const TextStyle()).copyWith(
        fontFamily: family,
        fontSize: size,
        height: height,
        fontWeight: weight,
        letterSpacing: tracking,
        fontVariations: vary
            ? <FontVariation>[
                FontVariation('wght', weight.value.toDouble()),
                FontVariation('wdth', width.toDouble()),
                FontVariation('opsz', size.clamp(14, 48).toDouble()),
              ]
            : null,
      );
    }

    if (material) {
      // Expressive display type runs wide — the signature Roboto Flex move
      // that keeps the voice consistent across every wallpaper palette.
      return base.copyWith(
        displayLarge: style(
          base.displayLarge,
          66,
          FontWeight.w800,
          0.98,
          -2.2,
          125,
        ),
        displayMedium: style(
          base.displayMedium,
          54,
          FontWeight.w800,
          1.0,
          -1.8,
          120,
        ),
        displaySmall: style(
          base.displaySmall,
          44,
          FontWeight.w800,
          1.02,
          -1.2,
          115,
        ),
        headlineLarge: style(
          base.headlineLarge,
          36,
          FontWeight.w800,
          1.08,
          -0.8,
          112,
        ),
        headlineMedium: style(
          base.headlineMedium,
          30,
          FontWeight.w700,
          1.12,
          -0.5,
          108,
        ),
        headlineSmall: style(
          base.headlineSmall,
          25,
          FontWeight.w700,
          1.18,
          -0.2,
          105,
        ),
        titleLarge: style(base.titleLarge, 22, FontWeight.w700, 1.22, -0.1),
        titleMedium: style(base.titleMedium, 17, FontWeight.w600, 1.30, 0),
        titleSmall: style(base.titleSmall, 15, FontWeight.w600, 1.30, 0),
        bodyLarge: style(base.bodyLarge, 16, FontWeight.w400, 1.50, 0),
        bodyMedium: style(base.bodyMedium, 14.5, FontWeight.w400, 1.50, 0.1),
        bodySmall: style(base.bodySmall, 12.5, FontWeight.w400, 1.45, 0.15),
        labelLarge: style(base.labelLarge, 15, FontWeight.w700, 1.20, 0.1),
        labelMedium: style(base.labelMedium, 12.5, FontWeight.w600, 1.20, 0.4),
        labelSmall: style(base.labelSmall, 11, FontWeight.w600, 1.20, 0.6),
      );
    }

    return base.copyWith(
      displayLarge: style(base.displayLarge, 58, FontWeight.w700, 1.0, -1.8),
      displayMedium: style(base.displayMedium, 48, FontWeight.w700, 1.02, -1.4),
      displaySmall: style(base.displaySmall, 38, FontWeight.w700, 1.05, -1.0),
      headlineLarge: style(base.headlineLarge, 32, FontWeight.w700, 1.12, -0.6),
      headlineMedium: style(
        base.headlineMedium,
        27,
        FontWeight.w600,
        1.15,
        -0.4,
      ),
      headlineSmall: style(base.headlineSmall, 23, FontWeight.w600, 1.20, -0.2),
      titleLarge: style(base.titleLarge, 20, FontWeight.w600, 1.26, 0),
      titleMedium: style(base.titleMedium, 17, FontWeight.w600, 1.30, 0),
      titleSmall: style(base.titleSmall, 15, FontWeight.w600, 1.30, 0),
      bodyLarge: style(base.bodyLarge, 17, FontWeight.w400, 1.45, 0),
      bodyMedium: style(base.bodyMedium, 15, FontWeight.w400, 1.45, 0),
      bodySmall: style(base.bodySmall, 13, FontWeight.w400, 1.40, 0.05),
      labelLarge: style(base.labelLarge, 15, FontWeight.w600, 1.20, 0.1),
      labelMedium: style(base.labelMedium, 13, FontWeight.w500, 1.20, 0.2),
      labelSmall: style(base.labelSmall, 11.5, FontWeight.w500, 1.20, 0.4),
    );
  }
}

/// Android's expressive transition: a quick fade-through with a springy scale
/// and a small upward drift. iOS uses the native Cupertino slide instead.
class _ExpressivePageTransitionsBuilder extends PageTransitionsBuilder {
  const _ExpressivePageTransitionsBuilder();

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
    final springy = CurvedAnimation(
      parent: animation,
      curve: Motion.springy,
      reverseCurve: Motion.emphasizedAccelerate,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.025),
          end: Offset.zero,
        ).animate(curved),
        child: ScaleTransition(
          // The scale rides the springy curve and grows a touch past 1 before
          // settling — the M3 Expressive "stop arriving abruptly" feel.
          scale: Tween<double>(begin: 0.92, end: 1).animate(springy),
          child: child,
        ),
      ),
    );
  }
}
