import 'dart:js_interop';

/// Web implementation: binds to the `window.ComeOverKeepAlive` helper
/// installed by web/index.html. That script owns a hidden looped
/// <audio> element fed with assets/keepalive.wav — near-silent, ~2 s,
/// so it can loop forever without being noticed in a pocket.
@JS('ComeOverKeepAlive.start')
external JSBoolean _start();

@JS('ComeOverKeepAlive.stop')
external JSBoolean _stop();

@JS('ComeOverKeepAlive.playing')
external JSBoolean _playing();

bool keepAliveStart() {
  try {
    return _start().toDart;
  } catch (_) {
    // The helper is missing (stale cached index.html) or playback was
    // refused (no user gesture): report failure so the UI stays honest.
    return false;
  }
}

bool keepAliveStop() {
  try {
    return _stop().toDart;
  } catch (_) {
    return false;
  }
}

bool keepAlivePlaying() {
  try {
    return _playing().toDart;
  } catch (_) {
    return false;
  }
}
