import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_color_utilities/material_color_utilities.dart' as mcu;

import 'core/device.dart';
import 'core/motion.dart';
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
  const AppScope({
    super.key,
    required AppController controller,
    required super.child,
  }) : super(notifier: controller);

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
  // Last TV verdict from the MaterialApp builder's DeviceProfile, so notices
  // can use the same switch the rest of the UI uses (covers the manual
  // "TV layout: On" override on devices where autodetect fails).
  bool _profileTv = false;

  // TVs get a non-interactive, auto-dismissing flash banner instead of a
  // SnackBar: the d-pad cannot reliably reach a SnackBar's action, and a
  // banner that sits there blinking with an unusable OK is worse than no
  // banner at all.
  String? _flash;
  bool _flashIsError = false;
  Timer? _flashTimer;
  int _flashSeq = 0;

  /// Wallpaper-derived hue on Android 12+ (Material You). Null means the
  /// device could not provide dynamic colours and the app falls back to its
  /// own violet expressive seed — TVs and Fire OS do this too.
  /// Wallpaper-derived scheme on Android 12+ (Material You). Null means the
  /// device could not provide dynamic colours and the app falls back to its
  /// own violet expressive seed — TVs and Fire OS do this too.
  ColorScheme? _systemLightScheme;
  ColorScheme? _systemDarkScheme;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _themeMode = _controller.themeMode;
    _controller.addListener(_onChanged);
    _controller.bootstrap();
    unawaited(_loadSystemScheme());
    _listenForLinks();
  }

  /// Material You: use the tonal palette the OS derived from the wallpaper in
  /// the light of whatever wallpaper style the user picked (Android 16 ships
  /// expressive styles, so the palette already reflects their choice). The
  /// dynamic_color plugin hands back material_ui scheme objects, which the
  /// Flutter [ThemeData] API cannot consume yet, so the roles are resolved
  /// here with the same tone recipe the OS uses.
  Future<void> _loadSystemScheme() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final palette = await DynamicColorPlugin.getCorePalette();
      if (palette == null || !mounted) return;
      final dark = _youScheme(palette, Brightness.dark);
      final light = _youScheme(palette, Brightness.light);
      setState(() {
        _systemDarkScheme = dark;
        _systemLightScheme = light;
        AppTheme.deviceColoursActive = true;
      });
    } catch (_) {
      // No dynamic colour support on this build — brand palette stays.
    }
  }

  /// Maps the five OS tonal palettes onto Flutter's [ColorScheme] using the
  /// legacy tone recipe (the same one `dynamic_color`'s scheme converter
  /// applies). A `fromSeed` baseline fills the newer surface-container roles
  /// from the wallpaper hue in between the overrides.
  static ColorScheme _youScheme(
    mcu.CorePalette palette, // ignore: deprecated_member_use
    Brightness brightness,
  ) {
    final dark = brightness == Brightness.dark;
    Color c(mcu.TonalPalette p, int tone) => Color(p.get(tone) | 0xFF000000);
    final (p, s, t, n, nv) = (
      palette.primary,
      palette.secondary,
      palette.tertiary,
      palette.neutral,
      palette.neutralVariant,
    );
    final seed = c(p, dark ? 80 : 40);
    final base = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
    );
    return base.copyWith(
      primary: seed,
      onPrimary: c(p, dark ? 20 : 100),
      primaryContainer: c(p, dark ? 30 : 90),
      onPrimaryContainer: c(p, dark ? 90 : 10),
      secondary: c(s, dark ? 80 : 40),
      onSecondary: c(s, dark ? 20 : 100),
      secondaryContainer: c(s, dark ? 30 : 90),
      onSecondaryContainer: c(s, dark ? 90 : 10),
      tertiary: c(t, dark ? 80 : 40),
      onTertiary: c(t, dark ? 20 : 100),
      tertiaryContainer: c(t, dark ? 30 : 90),
      onTertiaryContainer: c(t, dark ? 90 : 10),
      error: c(palette.error, dark ? 80 : 40),
      onError: c(palette.error, dark ? 20 : 100),
      errorContainer: c(palette.error, dark ? 30 : 90),
      onErrorContainer: c(palette.error, dark ? 90 : 10),
      outline: c(nv, dark ? 60 : 50),
      outlineVariant: c(nv, dark ? 30 : 80),
      onSurfaceVariant: c(nv, dark ? 80 : 30),
      surface: c(n, dark ? 6 : 98),
      onSurface: c(n, dark ? 90 : 10),
      inverseSurface: c(n, dark ? 90 : 20),
      onInverseSurface: c(n, dark ? 20 : 95),
      inversePrimary: c(p, dark ? 40 : 80),
      shadow: c(n, 0),
      scrim: c(n, 0),
      surfaceTint: seed,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(LiveStatusCoordinator.instance.sync(_controller, force: true));
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
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
    _flashTimer?.cancel();
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
    final isTv =
        _controller.forceTv ?? (_controller.isTelevision || _profileTv);
    if (isTv) {
      _flashTimer?.cancel();
      setState(() {
        _flashSeq++;
        _flash = message;
        _flashIsError = isError;
      });
      _flashTimer = Timer(const Duration(seconds: 4), () {
        if (!mounted) return;
        setState(() => _flash = null);
      });
      return;
    }
    final messenger = _messengerKey.currentState;
    if (messenger == null) return;
    final scheme = Theme.of(messenger.context).colorScheme;
    final style = AppStyle.of(messenger.context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: Duration(seconds: isError ? 6 : 3),
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.info_outline_rounded,
              size: 20,
              color: isError ? scheme.error : style.live,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        action: SnackBarAction(
          label: isError ? 'Dismiss' : 'OK',
          textColor: scheme.primary,
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
        theme: AppTheme.light(systemScheme: _systemLightScheme),
        darkTheme: AppTheme.dark(systemScheme: _systemDarkScheme),
        themeMode: _themeMode,
        scaffoldMessengerKey: _messengerKey,
        builder: (context, child) {
          final controller = AppScope.of(context);
          final profile = DeviceProfile.of(
            context,
            forceTv:
                controller.forceTv ?? (controller.isTelevision ? true : null),
          );
          if (profile.isTv != _profileTv) {
            _profileTv = profile.isTv;
          }
          final media = MediaQuery.of(context);
          final scaled = profile.isTv
              ? media.copyWith(
                  textScaler: TextScaler.linear(
                    media.textScaler.scale(1) * 1.06,
                  ),
                )
              : media;
          final content = DeviceScope(
            profile: profile,
            child: MediaQuery(
              data: scaled,
              child: child ?? const SizedBox.shrink(),
            ),
          );
          if (!profile.isTv || _flash == null) return content;
          // TV flash banner: sits inside the overscan trim at the top,
          // ignores pointer/focus (the d-pad navigates underneath it), and
          // dismisses itself after a few seconds.
          final scheme = Theme.of(context).colorScheme;
          return Stack(
            children: [
              content,
              Positioned(
                top: profile.overscan.top,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: Container(
                        key: ValueKey('$_flashSeq:$_flash'),
                        margin: const EdgeInsets.symmetric(horizontal: 48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        constraints: const BoxConstraints(maxWidth: 720),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: _flashIsError
                                ? scheme.error
                                : scheme.primary,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.45),
                              blurRadius: 18,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _flashIsError
                                  ? Icons.error_outline_rounded
                                  : Icons.info_outline_rounded,
                              size: 22,
                              color: _flashIsError
                                  ? scheme.error
                                  : scheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                _flash!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
    final springy = AppStyle.of(context).isMaterial;
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
          switchInCurve: springy ? Motion.springy : Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: springy ? Motion.springy : Curves.easeOutCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween<double>(
                  begin: springy ? 0.93 : 0.985,
                  end: 1,
                ).animate(curved),
                child: child,
              ),
            );
          },
          child: KeyedSubtree(key: ValueKey(controller.stage), child: screen),
        ),
      ),
    );
  }
}
