import 'package:comeover/core/theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android theme uses Material 3 Expressive tokens', () {
    final theme = AppTheme.dark(platform: TargetPlatform.android);
    final style = theme.extension<AppStyle>();

    expect(style, isNotNull);
    expect(style!.visual, VisualLanguage.materialExpressive);
    expect(style.isMaterial, isTrue);
    expect(style.useBlur, isFalse);
    expect(style.backgroundPeriod, const Duration(seconds: 22));
    expect(style.cardRadius, 30);
    expect(style.pressScale, lessThan(0.96));

    // Expressive typography uses the bundled Roboto Flex variable font.
    expect(theme.textTheme.displayLarge?.fontFamily, 'RobotoFlex');
    expect(theme.textTheme.displayLarge?.fontVariations, isNotEmpty);
    expect(theme.textTheme.bodyLarge?.fontVariations, isNotEmpty);

    // Android gets a custom expressive transition, not the Cupertino slide.
    expect(
      theme.pageTransitionsTheme.builders[TargetPlatform.android],
      isNot(isA<CupertinoPageTransitionsBuilder>()),
    );
  });

  test('iOS theme uses restrained Liquid Glass tokens', () {
    final theme = AppTheme.dark(platform: TargetPlatform.iOS);
    final style = theme.extension<AppStyle>();

    expect(style, isNotNull);
    expect(style!.visual, VisualLanguage.liquidGlass);
    expect(style.isLiquid, isTrue);
    expect(style.useBlur, isTrue);
    expect(style.glassBlur, greaterThan(20));
    expect(style.glassBorderWidth, lessThan(1));
    expect(style.backgroundPeriod, const Duration(seconds: 40));
    expect(style.pressScale, greaterThan(0.96));

    // iOS keeps the native SF type stack and skips Roboto Flex.
    expect(theme.textTheme.displayLarge?.fontFamily, isNot('RobotoFlex'));
    expect(theme.textTheme.displayLarge?.fontVariations, isNull);
    expect(theme.platform, TargetPlatform.iOS);
    expect(
      theme.pageTransitionsTheme.builders[TargetPlatform.iOS],
      isA<CupertinoPageTransitionsBuilder>(),
    );
  });

  test('light and dark themes carry the style extension', () {
    for (final theme in [
      AppTheme.light(platform: TargetPlatform.android),
      AppTheme.dark(platform: TargetPlatform.android),
      AppTheme.light(platform: TargetPlatform.iOS),
      AppTheme.dark(platform: TargetPlatform.iOS),
    ]) {
      expect(theme.extension<AppStyle>(), isNotNull);
      expect(theme.useMaterial3, isTrue);
    }
  });

  test('the two visual languages do not share the same palette', () {
    final android = AppTheme.dark(platform: TargetPlatform.android);
    final ios = AppTheme.dark(platform: TargetPlatform.iOS);

    expect(android.colorScheme.primary, isNot(ios.colorScheme.primary));
    expect(
      android.extension<AppStyle>()!.live,
      isNot(ios.extension<AppStyle>()!.live),
    );
  });
}
