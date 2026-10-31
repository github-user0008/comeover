# ComeOver app

Flutter client for ComeOver. It talks to the relay in `../server` over REST + Socket.IO and keeps
all user preferences (name, avatar, units, theme, relay URL) on the device.

```
lib/
├── core/       config, device/TV profile, geo math, formatting, theme
├── data/       REST client, Socket.IO client, geolocation, local prefs
├── models/     room, member, room settings, travel estimate
├── state/      AppController (single source of truth)
└── ui/         screens + Liquid Glass / Expressive components
```

## Run

```bash
flutter pub get
flutter run --dart-define=COMEOVER_SERVER=http://192.168.1.20:8787
```

See the [root README](../README.md) for TV, Android, iOS and web builds, invite-link handling and
the full relay API.

## Layout notes

- `DeviceProfile` treats TVs as a 10-foot UI: overscan padding, larger type and d-pad focus
  traversal. The app also detects directional navigation automatically; **Settings → TV layout**
  forces it on a phone for testing.
- `LiveScreen` renders a full-bleed map plus a glass HUD on compact screens and a right-hand rail
  on wide screens/TVs.
- `LocationService` forces Android's `LocationManager` (Fire OS has no Play Services) and supports
  `COMEOVER_DEMO_LOCATION` for emulators and TVs without GPS.
- `AppController` measures distance/ETA from the host's position for TV viewers that do not share
  their own location, so the big screen still has useful numbers.

## Lock-screen live status

`lib/data/live_status.dart` turns the current HUD into a `LiveStatusSnapshot` and pushes it over the
`dev.comeover/live_status` channel. The native side only renders that snapshot.

- **Android** (`LiveStatusBridge.kt`) posts an ongoing notification. On Android 16 it uses
  `Notification.ProgressStyle`, a short critical text chip and the `android.requestPromotedOngoing`
  extra to request a Live Update. Pixel, Samsung Now Bar and other Android 16 skins share this path;
  older releases fall back to a progress/BigText notification. A foreground location service keeps
  updates flowing while the phone is locked.
- **iOS** (`LiveStatusBridge.swift` + `ComeOverLiveActivity/`) starts an ActivityKit activity and
  renders it on the Lock Screen and in the Dynamic Island. `ComeOverActivityAttributes.swift` is
  shared by the app and the widget extension. All ActivityKit calls branch between the iOS 16.1
  `contentState` API and the iOS 16.2 `ActivityContent` API. When a room starts, the bridge also
  asks to upgrade location access to **Always** so background updates continue with the screen off.

The `ComeOverLiveActivity` app-extension target is part of `Runner.xcodeproj`, so open the workspace
in Xcode on macOS, pick a team for both targets, then run on a device. On Linux the Swift code can
only be type-checked by review, not compiled.
