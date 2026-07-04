# iOS Release — TestFlight

How to get the Dispax iOS app onto TestFlight. The repository side (push
entitlement, fastlane, Makefile targets) is already wired; the steps below are
the account-side work only you can do, plus the commands to build and upload.

- **Bundle ID:** `de.dispax.app`
- **Apple Team ID:** `D74H38HXXR`
- **Firebase project:** `taxi-app-98671` (iOS app already registered)

> **CI status — read this.** The current pipeline is a **local build + automated
> upload**: `flutter build ipa` runs on your Mac with `CODE_SIGN_STYLE = Automatic`,
> and fastlane uploads the result to TestFlight without an Apple ID password (API
> key). This is *not* yet a fully headless CI pipeline: automatic signing does not
> work on a GitHub Actions runner without `fastlane match` (shared signing certs) or
> an exported provisioning profile, plus a macOS runner. Wiring that is a separate,
> not-yet-done step. For now, run the upload from your Mac.

---

## One-time setup (account side — do once)

### 1. App ID + Push capability (Apple Developer)
At <https://developer.apple.com/account> → **Certificates, Identifiers & Profiles → Identifiers**:
1. Confirm the App ID **`de.dispax.app`** exists (create it if not).
2. Open it and enable the **Push Notifications** capability. Save.

The repo already ships the matching entitlement (`web/ios/Runner/Runner.entitlements`,
`aps-environment`), so no Xcode change is needed — it flips to `production`
automatically when the archive is exported for the App Store.

### 2. APNs key for Firebase (so FCM push actually delivers)
At **Certificates, Identifiers & Profiles → Keys**:
1. **+** → enable **Apple Push Notifications service (APNs)** → download the `.p8` (offered once).
2. Note the **Key ID** and your **Team ID** (`D74H38HXXR`).
3. Firebase Console → project `taxi-app-98671` → **Project Settings → Cloud Messaging →
   Apple app configuration** → upload that `.p8` with the Key ID + Team ID.

Without this, TestFlight builds install fine but push notifications never arrive.

### 3. App record in App Store Connect
At <https://appstoreconnect.apple.com> → **Apps → +** → **New App**:
- Platform **iOS**, Bundle ID **`de.dispax.app`**, an SKU (e.g. `dispax-ios`), primary language.
- You do **not** need screenshots, description, or App Store review to use TestFlight.

### 4. App Store Connect API key (so fastlane can upload)
At **App Store Connect → Users and Access → Integrations → App Store Connect API**:
1. **+** → role **App Manager** → generate → download `AuthKey_XXXXXXXXXX.p8` (offered once).
2. Copy the **Key ID** and the **Issuer ID** (UUID at the top of the page).
3. Create `web/ios/.env` from the template and fill it in (this file is gitignored):
   ```bash
   cp web/ios/fastlane/.env.example web/ios/.env
   ```
   Set `ASC_KEY_ID`, `ASC_ISSUER_ID`, and `ASC_KEY_CONTENT` (the full `.p8` PEM text,
   including the `-----BEGIN/END PRIVATE KEY-----` lines).

### 5. Install fastlane (once, on your Mac)
```bash
cd web/ios && bundle install    # installs fastlane from the Gemfile
```

---

## Build & upload (every release)

The Flutter build number is derived from the git commit count, so each build gets
a unique, increasing number automatically. The **marketing version** (`1.0.0`)
lives in `web/pubspec.yaml` — bump the `version:` line when you want a new user-facing
version; a duplicate build number for the same version is rejected by Apple.

```bash
# 1. Build the signed IPA and upload to TestFlight in one step:
make ios-beta

# — or run the two halves separately —
make flutter-prod-ios          # builds web/build/ios/ipa/dispax.ipa
make ios-testflight-upload     # fastlane beta → uploads that IPA
```

After upload:
- App Store Connect → your app → **TestFlight** tab.
- **Internal Testing**: add up to 100 testers from your team — available immediately,
  no review.
- **External Testing**: create a group + public link for up to 10 000 testers —
  requires a quick **Beta App Review** (lighter than full App Store review).
- Export compliance is pre-answered in `Info.plist`
  (`ITSAppUsesNonExemptEncryption = false`), so builds are not held on a manual
  encryption question.

---

## Verification

This flow was **not** exercised end-to-end in the repository (an archive + upload
needs your signing identity and Apple credentials, which aren't available in the
dev environment). What *was* verified here: `Info.plist`, `Runner.entitlements`,
and `project.pbxproj` pass `plutil -lint`; the `CODE_SIGN_ENTITLEMENTS` setting is
present in all three Runner build configs; the Fastfile passes `ruby -c`; and
`make ios-beta` expands to the correct build → upload chain.

**Run the first archive through Xcode manually** (Product → Archive → Distribute App →
App Store Connect) so any signing/provisioning problems surface with Xcode's
diagnostics before you rely on `make ios-beta`. Once one archive succeeds, the
Makefile path is the repeatable route.

To confirm push after the first TestFlight install: send a test message from
Firebase Console → Cloud Messaging to the device token and verify it arrives in
foreground and background.
