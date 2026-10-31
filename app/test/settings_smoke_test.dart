import 'package:comeover/app.dart';
import 'package:comeover/core/config.dart';
import 'package:comeover/data/prefs.dart';
import 'package:comeover/state/app_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const testConfig = AppConfig(
  serverUrl: 'http://localhost:8787',
  publicUrl: 'http://localhost:8787',
  isWeb: false,
  isAndroid: false,
  isIOS: false,
  demoLocation: null,
  previewMode: true,
);

void main() {
  testWidgets('settings sheet opens from home without throwing', (tester) async {
    SharedPreferences.setMockInitialValues({
      'profile.name': 'Maya',
      'profile.avatar': '🐼',
    });
    final fontLoader = FontLoader('Figtree')
      ..addFont(rootBundle.load('assets/fonts/Figtree.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Figtree-Italic.ttf'));
    await fontLoader.load();

    final prefs = await Prefs.load();
    final controller = AppController(baseConfig: testConfig, prefs: prefs);

    const deviceChannel = MethodChannel('dev.comeover/device');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(deviceChannel, (call) async => false);
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(deviceChannel, null));

    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ComeOverApp(controller: controller));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Maya'), findsOneWidget);

    await tester.tap(find.text('Maya'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final error = tester.takeException();
    expect(error, isNull, reason: 'settings sheet build threw: $error');
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Relay'), findsWidgets);
  });
}
