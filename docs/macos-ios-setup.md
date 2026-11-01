# Building ComeOver for iOS on a Mac

Everything here takes about **30–45 minutes** the first time (mostly downloads).
You only need to repeat steps 3–6 to ship updates.

## 1. Install Xcode

Install Xcode from the Mac App Store (any Xcode 16+ is fine). It is a large
download (~12 GB), so start it early.

While it installs, continue with step 2.

## 2. Install Flutter and CocoaPods

Open **Terminal** and paste:

```bash
# Xcode command line tools
xcode-select --install

# Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# CocoaPods (needed to build the iOS runner) + git
brew install cocoapods git
```

Then install Flutter:

```bash
# Download and unpack Flutter (silicon Mac)
cd /dev
curl -o flutter.tar.xz https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_arm64_3.47.9-stable.zip
unzip flutter.tar.xz
rm flutter.tar.xz

# Add it to your PATH for this and future shells
echo 'export PATH="/dev/flutter/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

flutter --version   # should print Flutter 3.47.9
```

(If the Mac and this readme disagree on the Flutter version, use the version
the readme pins: 3.47.9.)

## 3. Clone the project and run the doctor

```bash
git clone https://github.com/github-user0008/comeover.git
cd comeover/app

flutter doctor
```

`flutter doctor` should show green ticks for Flutter, Xcode and CocoaPods
(Android tooling and Chrome warnings can be ignored for this task).

Then fetch the app's dependencies:

```bash
flutter pub get
```

## 4. Open the iOS project and set signing

```bash
open ios/Runner.xcworkspace
```

In Xcode:

1. In the left project navigator, click the blue **Runner** project.
2. Select the **Runner** target → **Signing & Capabilities** tab.
3. Tick **Automatically manage signing**.
4. Under **Team**, pick the Apple ID account (Xcode may tell you it has no
   accounts — click *Add Account* and sign in with an Apple ID. A free account
   is enough to run the app on one device; a paid Apple Developer account is
   required for TestFlight/App Store).
5. Change the **Bundle Identifier** from `dev.comeover.comeover` to
   something unique, e.g. `com.<friendname>.comeover` — Apple only allows a
   custom identifier per Apple ID.
6. Repeat the exact same steps for the **ComeOverLiveActivity** target
   (the lock-screen Live Activity widget): same team, same automatic signing,
   bundle identifier `<yours>.comeover.LiveActivity` — it must stay
   *different* from the Runner's, ideally `<yours>.comeover.LiveActivity`.
7. Do the same for the **RunnerTests** target if Xcode complains.

Leave every other capability as-is. Note: the lock-screen Live Activity only
runs on iOS 16.1+; free-account builds expire every 7 days and must be
re-installed via Xcode Run.

## 5. Run it on the iPhone

1. Plug the iPhone into the Mac with a cable.
2. On the device, allow the "Trust this computer?" prompt.
3. (iOS 16+ only, one time) On the phone: **Settings → Privacy & Security →
   Developer Mode → on**, then reboot when asked.
4. Back in Xcode, pick the iPhone from the device dropdown at the top
   (do not pick "Any iOS Device").
5. Press **▶ Run** and wait for the build to finish (~2 min the first time).
6. First launch will fail to open with *"Untrusted developer"* — on the phone
   go to **Settings → General → VPN & Device Management**, tap the developer
   profile for your Apple ID, and tap **Trust**. Launch the app again.

## 6. (Optional) TestFlight — 90-day installs without a Mac

If the Apple ID is enrolled in the **Apple Developer Program** ($99/yr):

1. In Xcode pick **Product → Build**, then **Product → Archive**.
2. In the **Organizer** window press **Distribute App → App Store Connect**.
3. Sign into [appstoreconnect.apple.com](https://appstoreconnect.apple.com) →
   **My Apps → ComeOver** → the version you archived appears in *TestFlight*.
4. Add your phone's Apple ID as a tester in TestFlight.
5. On the phone, install **TestFlight** from the App Store and accept the
   beta invite. Builds last 90 days.

## Troubleshooting

- **"could not find or compute absolute path to CocoaPods"** → run
  `brew install cocoapods`, restart Terminal, Xcode.
- **Signing errors mentioning "capability"** → make sure the Live Activity
  target has *no* extra capabilities ticked; only automatic signing and a team.
- **`flutter bus` errors on library update** → re-run `flutter pub get`, then
  in Xcode: *Product → Clean Build Folder* (⇧⌘K) and Run again.
- Both targets must use **the same team** but **different bundle
  identifiers**, or the Live Activity extension won't sign.
