import 'package:comeover/core/config.dart';
import 'package:comeover/core/theme.dart';
import 'package:comeover/data/prefs.dart';
import 'package:comeover/state/app_controller.dart';
import 'package:comeover/ui/screens/live_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _testConfig = AppConfig(
  serverUrl: 'http://localhost:8787',
  publicUrl: 'http://localhost:8787',
  isWeb: false,
  isAndroid: false,
  isIOS: false,
  demoLocation: null,
  previewMode: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('keep-alive availability is gated to web guests in a live room', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await Prefs.load();
    final controller = AppController(baseConfig: _testConfig, prefs: prefs);
    addTearDown(controller.dispose);

    // Hosts never get it, whatever the stage.
    controller.stage = AppStage.live;
    expect(controller.travellerKeepAliveActive, isFalse);

    // Guests outside a room don't either.
    controller.stage = AppStage.home;
    await controller.setTravellerKeepAlive(true);
    expect(controller.travellerKeepAliveActive, isFalse);

    // A web guest in a live room does.
    controller.stage = AppStage.live;
    expect(controller.travellerKeepAliveActive, isTrue);
    expect(prefs.travellerKeepAlive, isTrue);

    await controller.setTravellerKeepAlive(false);
    expect(controller.travellerKeepAliveActive, isFalse);
    expect(prefs.travellerKeepAlive, isFalse);
  });

  testWidgets('traveller toggle shows the experimental disclosure, then opts in', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await Prefs.load();
    final controller = AppController(baseConfig: _testConfig, prefs: prefs)
      ..stage = AppStage.live;
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(web: true),
        home: Scaffold(
          body: Center(
            child: ListenableBuilder(
              listenable: controller,
              builder: (_, _) => KeepAliveToggle(app: controller),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Background off'), findsOneWidget);

    await tester.tap(find.text('Background off'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Keep tracking in the background?'), findsOneWidget);
    expect(find.textContaining('near-silent audio loop'), findsOneWidget);

    await tester.tap(find.text('Enable'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Keep tracking in the background?'), findsNothing);
    expect(prefs.travellerKeepAlive, isTrue);
    expect(find.text('Background on'), findsOneWidget);
    expect(find.textContaining('near-silent audio loop'), findsNothing);

    // Switching back off needs no second dialog.
    await tester.tap(find.text('Background on'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(prefs.travellerKeepAlive, isFalse);
    expect(find.text('Background off'), findsOneWidget);
  });
}
