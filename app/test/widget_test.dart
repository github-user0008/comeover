import 'package:comeover/app.dart';
import 'package:comeover/core/config.dart';
import 'package:comeover/core/device.dart';
import 'package:comeover/core/theme.dart';
import 'package:comeover/data/prefs.dart';
import 'package:comeover/models/member.dart';
import 'package:comeover/state/app_controller.dart';
import 'package:comeover/ui/screens/ended_screen.dart';
import 'package:comeover/ui/screens/home_screen.dart';
import 'package:comeover/ui/screens/join_screen.dart';
import 'package:comeover/ui/screens/welcome_screen.dart';
import 'package:flutter/material.dart';
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

Future<AppController> makeController() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await Prefs.load();
  final controller = AppController(baseConfig: testConfig, prefs: prefs);
  addTearDown(controller.dispose);
  return controller;
}

Widget wrap(
  AppController controller,
  Widget child, {
  DeviceClass kind = DeviceClass.phone,
}) {
  final size = kind == DeviceClass.tv
      ? const Size(1280, 720)
      : const Size(430, 900);
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.dark(),
    home: Scaffold(
      backgroundColor: Palette.ink,
      body: AppScope(
        controller: controller,
        child: DeviceScope(
          profile: DeviceProfile(
            kind: kind,
            size: size,
            overscan: EdgeInsets.zero,
            textScale: 1,
          ),
          child: child,
        ),
      ),
    ),
  );
}

void setScreenSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('welcome asks for a name and stores it', (tester) async {
    final controller = await makeController();
    controller.stage = AppStage.welcome;
    setScreenSize(tester, const Size(1200, 1000));
    await tester.pumpWidget(wrap(controller, const WelcomeScreen()));
    await tester.pump();

    expect(find.text('WHO ARE YOU'), findsOneWidget);
    expect(find.text('PICK AN AVATAR'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Maya');
    await tester.tap(find.text('Let me in'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(controller.profile.name, 'Maya');
    expect(controller.stage, AppStage.home);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a blank name keeps you on the welcome screen', (tester) async {
    final controller = await makeController();
    controller.stage = AppStage.welcome;
    setScreenSize(tester, const Size(1200, 1000));
    await tester.pumpWidget(wrap(controller, const WelcomeScreen()));
    await tester.pump();

    await tester.tap(find.text('Let me in'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(controller.stage, AppStage.welcome);
    expect(find.text('Tell people what to call you.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('join screen starts empty and explains the code', (tester) async {
    final controller = await makeController();
    controller.stage = AppStage.joining;
    setScreenSize(tester, const Size(1100, 900));
    await tester.pumpWidget(wrap(controller, const JoinScreen()));
    await tester.pump();

    expect(find.text('Type the code'), findsOneWidget);
    expect(find.text('Join room'), findsOneWidget);
    expect(find.text('Paste'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('TV home offers the room buttons and remote hints', (
    tester,
  ) async {
    final controller = await makeController();
    controller.stage = AppStage.home;
    controller.profile = const AppProfile(name: 'Maya', avatar: '🐼');
    setScreenSize(tester, const Size(1280, 720));
    await tester.pumpWidget(
      wrap(controller, const HomeScreen(), kind: DeviceClass.tv),
    );
    await tester.pump();

    expect(find.text('Start a room'), findsOneWidget);
    expect(find.text('Join with a code'), findsOneWidget);
    expect(find.text('Watch a live demo'), findsOneWidget);
    expect(find.text('TV friendly'), findsOneWidget);
    expect(find.textContaining('OK select'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('ended screen summarises the room and returns home', (
    tester,
  ) async {
    final controller = await makeController();
    controller
      ..stage = AppStage.ended
      ..endedReason = 'You closed the room.'
      ..room = RoomModel(
        id: 'room-1',
        code: 'ABC123',
        hostId: 'host-1',
        createdAt: DateTime(2026, 1, 1, 12),
        expiresAt: DateTime(2026, 1, 1, 18),
      )
      ..me = const Member(
        id: 'host-1',
        name: 'Maya',
        avatar: '🐼',
        colorHex: '#9BF6FF',
        isHost: true,
        online: true,
      )
      ..members = const [
        Member(
          id: 'host-1',
          name: 'Maya',
          avatar: '🐼',
          colorHex: '#9BF6FF',
          isHost: true,
          online: true,
        ),
        Member(
          id: 'guest-1',
          name: 'Sam',
          avatar: '🦊',
          colorHex: '#CDBDFF',
          isHost: false,
          online: false,
        ),
      ];
    // Keep the fixture deterministic without depending on the wall clock.
    setScreenSize(tester, const Size(1200, 900));
    await tester.pumpWidget(wrap(controller, const EndedScreen()));
    await tester.pump();

    expect(find.text('That’s a wrap'), findsOneWidget);
    expect(find.text('ABC123'), findsOneWidget);
    expect(find.text('Sam'), findsOneWidget);

    await tester.tap(find.text('Back home'));
    await tester.pump();
    expect(controller.stage, AppStage.home);
  });
}
