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
