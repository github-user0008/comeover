import 'keepalive_none.dart'
    if (dart.library.js_interop) 'keepalive_web.dart'
    as impl;

/// Experimental inaudible-audio keep-alive for web travellers.
///
/// A page with actively playing audio is treated as "in use" by mobile
/// WebKit and is never suspended, so the loop below lets the geolocation
/// watcher keep ticking while the screen is locked or another app is in
/// front. Only has an effect in browsers; the stub returns `false`
/// everywhere else. Started from a user gesture (the toggle tap) because
/// browsers reject non-gesture playback.
abstract final class BackgroundKeepAlive {
  /// Starts (or resumes) the loop. `false` means the browser refused it —
  /// usually a missing user gesture or an unsupported environment.
  static bool start() => impl.keepAliveStart();

  /// Pauses the loop. Safe to call any time.
  static bool stop() => impl.keepAliveStop();

  /// `true` while the browser reports the loop as actually playing.
  static bool playing() => impl.keepAlivePlaying();
}
