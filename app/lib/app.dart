import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import 'core/device.dart';
import 'core/theme.dart';
import 'data/live_status.dart';
import 'state/app_controller.dart';
import 'ui/screens/ended_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/host_lobby_screen.dart';
import 'ui/screens/join_screen.dart';
import 'ui/screens/live_screen.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/screens/welcome_screen.dart';
import 'ui/aurora_background.dart';

class AppScope extends InheritedNotifier<AppController> {
  const AppScope({super.key, required AppController controller, required super.child})
      : super(notifier: controller);

  static AppController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing from the widget tree');
    return scope!.notifier!;
  }
}

class DeviceScope extends InheritedWidget {
  const DeviceScope({super.key, required this.profile, required super.child});

  final DeviceProfile profile;

  static DeviceProfile of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<DeviceScope>();
    return scope?.profile ?? DeviceProfile.of(context);
  }

  @override
  bool updateShouldNotify(DeviceScope oldWidget) =>
      oldWidget.profile.kind != profile.kind ||
      oldWidget.profile.size != profile.size ||
      oldWidget.profile.overscan != profile.overscan;
}

class ComeOverApp extends StatefulWidget {
  const ComeOverApp({super.key, required this.controller});

  final AppController controller;

  @override
  State<ComeOverApp> createState() => _ComeOverAppState();
}

class _ComeOverAppState extends State<ComeOverApp> with WidgetsBindingObserver {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  late final AppController _controller = widget.controller;
  String? _lastError;
  String? _lastNotice;
  ThemeMode _themeMode = ThemeMode.dark;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _themeMode = _controller.themeMode;
    _controller.addListener(_onChanged);
    _controller.bootstrap();
    _listenForLinks();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(LiveStatusCoordinator.instance.sync(_controller, force: true));
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // Push one last snapshot before the OS suspends the Flutter isolate.
      unawaited(LiveStatusCoordinator.instance.sync(_controller, force: true));
    }
  }

  Future<void> _listenForLinks() async {
    try {
      final links = AppLinks();
      final initial = await links.getInitialLink();
      if (initial != null) _controller.handleDeepLink(initial);
      _linkSubscription = links.uriLinkStream.listen(
        _controller.handleDeepLink,
        onError: (Object _) {},
      );
    } catch (_) {
      // Platform without deep-link support — invite codes can still be typed.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSubscription?.cancel();
    unawaited(LiveStatusCoordinator.instance.shutdown());
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (_controller.themeMode != _themeMode) {
      setState(() => _themeMode = _controller.themeMode);
    }
    final error = _controller.errorMessage;
    if (error != null && error != _lastError) {
      _lastError = error;
      _showMessage(error, isError: true);
    } else if (error == null) {
      _lastError = null;
    }
    final notice = _controller.notice;
    if (notice != null && notice != _lastNotice) {
      _lastNotice = notice;
      _showMessage(notice, isError: false);
      _controller.clearNotice();
    } else if (notice == null) {
      _lastNotice = null;
    }
    unawaited(LiveStatusCoordinator.instance.sync(_controller));
  }

  void _showMessage(String message, {required bool isError}) {
    final messenger = _messengerKey.currentState;
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: Duration(seconds: isError ? 6 : 3),
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
              size: 20,
              color: isError ? const Color(0xFFFFB4AB) : Palette.mint,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        action: SnackBarAction(
          label: isError ? 'Dismiss' : 'OK',
          textColor: Palette.lavender,
          onPressed: () {
            if (isError) _controller.clearError();
          },
        ),
      ),
    );
    if (isError) _controller.clearError();
  }

  @override
  Widget build(BuildContext context) {
    // Keep the scopes above MaterialApp so modal sheets and dialogs, which are
    // hosted by the Navigator's overlay, can still reach them.
    return AppScope(
      controller: _controller,
      child: MaterialApp(
        title: 'ComeOver',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: _themeMode,
        scaffoldMessengerKey: _messengerKey,
        builder: (context, child) {
          final controller = AppScope.of(context);
          final profile = DeviceProfile.of(
            context,
            forceTv: controller.forceTv ?? (controller.isTelevision ? true : null),
          );
          final media = MediaQuery.of(context);
          final scaled = profile.isTv
              ? media.copyWith(
                  textScaler: TextScaler.linear(media.textScaler.scale(1) * 1.06),
                )
              : media;
          return DeviceScope(
            profile: profile,
            child: MediaQuery(
              data: scaled,
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },
        home: const AppRoot(),
      ),
    );
  }
}

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final dark = controller.themeMode != ThemeMode.light;
    final screen = switch (controller.stage) {
      AppStage.booting => const SplashScreen(),
      AppStage.welcome => const WelcomeScreen(),
      AppStage.home => const HomeScreen(),
      AppStage.joining => const JoinScreen(),
      AppStage.hosting => const HostLobbyScreen(),
      AppStage.live => const LiveScreen(),
      AppStage.ended => const EndedScreen(),
    };

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: AuroraBackground(
        dark: dark,
        intensity: controller.reduceGlass ? 0.65 : 1,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 480),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
            return FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.985, end: 1).animate(curved),
                child: child,
              ),
            );
          },
          child: KeyedSubtree(
            key: ValueKey(controller.stage),
            child: screen,
          ),
        ),
      ),
    );
  }
}
