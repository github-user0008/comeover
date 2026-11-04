# iOS without a Mac, without Xcode — cloud build to TestFlight

This is the zero-Mac route to get the native ComeOver app (with lock-screen
Live Activity and background location) onto an iPhone. The Mac work happens on
Codemagic's cloud build machines; you only do the account setup.

## What you need (one-time)

| Something | Cost | Time |
|---|---|---|
| Apple Developer Program account | $99/year | ~15 min to start; activation can take 1–3 days |
| Codemagic account (built by the Flutter team) | free tier is 500 build minutes/month | ~5 min |
| Your iPhone Apple ID (already have it) | — | — |

No Mac, no friend, no Xcode at any point.

## Step by step (first run)

1. **Enroll in the Apple Developer Program** — developer.apple.com → Account →
   Join. Pay the $99. Note: identity verification can take 1–3 business days
   before you can create app records.

2. **Create the app record** in App Store Connect → **My Apps → + New App**:
   - Name: `ComeOver`
   - Language: your choice, Bundle ID: `dev.comeover.comeover`, SKU:
     `comeover-001`.
   Apple reserves the bundle ID for your team here — nothing else to add.

3. **Create an App Store Connect API key** (App Store Connect → Users and
   Access → Integrations → App Store Connect API → + Team keys):
   - Name: `codemagic-ios`, role: **App Manager**.
   - Download the `.p8` once and note the **Key ID** and **Issuer ID**.

4. **Codemagic setup** — codemagic.io → sign in with GitHub →
   **Add application** → pick `github-user0008/comeover` → project type
   *Flutter App*.
   - Teams → Integrations → **App Store Connect** → add the API key with the
     Issuer ID, Key ID and `.p8` contents; name it **ASC_KEY** (exactly — the
     yaml in the repo root references that name).
   - Codemagic will show a "Connect App Store Connect" prompt; accept it.

5. **Start the workflow** — the repo ships `codemagic.yaml` with a workflow
   called *ComeOver — iOS → TestFlight*. Choose it in the Codemagic UI and
   press **Start new build**.
   - It runs on a cloud Mac mini, fetches packages, builds the ipa (Runner +
     the ComeOverLiveActivity extension), signs it with an automatically
     managed profile from your Apple account, and uploads to TestFlight.
   - First build takes ~15–20 minutes. Typical failure on the first ever run
     is signing: if it fails with a profile error, open **Codemagic →
     Workflow editor → iOS signing**, let it "fetch profiles" once, and
     rerun.

6. **Install on the iPhone**:
   - App Store Connect → your app → **TestFlight → Internal Testing → +** add
     yourself as an internal tester (internal testers need only be listed in
     your Apple account; no App Store review is required for ≤100 internal
     testers).
   - On the phone, install **TestFlight** from the App Store, accept the
     mail invite, then install ComeOver.
   - In the app you'll get the full native experience: background location
     with the Live Activity counting down on the lock screen while the phone
     is locked or in another app.

## Ongoing releases

Every push to the branch can start the same workflow (configure in the
Codemagic UI: Workflow triggers). TestFlight builds expire after 90 days —
the next build replaces them — and version-bump as usual.

## What still requires a Mac (rare)

- Changing native iOS code that needs a compile check before pushing. CI
  builds error out with logs, so you'll still know quickly.
- App **Store** (public) releases: Choose the a final review per submission
  (usually 24–48h). TestFlight needs no review for internal testers.

## Why this works at all

Apple's signing chain needs macOS tools (`xcodebuild` etc.), not *your*
Macintosh. Codemagic provides mac hardware, and with an App Store Connect API
key it can provision profiles and push to TestFlight with zero manual steps.
The only identity involved is yours.
