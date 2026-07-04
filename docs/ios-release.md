# iOS Release — TestFlight

How to get the Dispax iOS app onto TestFlight. The repository side (push
entitlement, fastlane, Makefile targets) is already wired; the steps below are
the account-side work only you can do, plus the commands to build and upload.

- **Bundle ID:** `de.dispax.app`
- **Apple Team ID:** `WPM9G259A4`
- **Firebase project:** `taxi-app-98671` (iOS app already registered)

> **Two ways to release, both wired:**
> - **Local** (simplest, no shared certs needed): `make ios-beta` on your Mac —
>   `flutter build ipa` with automatic signing, then fastlane uploads. Good for
>   the first release and solo work. See [Build & upload](#build--upload-every-release).
> - **CI** (headless, GitHub Actions macOS runner): a version tag or a manual
>   dispatch triggers a build signed via `fastlane match` and uploads to
>   TestFlight. Needs a one-time match seed + repository secrets. See
>   [CI via GitHub Actions](#ci-via-github-actions-fastlane-match).

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
2. Note the **Key ID** and your **Team ID** (`WPM9G259A4`).
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

## CI via GitHub Actions (fastlane match)

The `.github/workflows/ios-testflight.yml` workflow builds a signed IPA on a
macOS runner and uploads it to TestFlight, with **no Mac and no Apple login**
involved. Signing material is shared through `fastlane match`.

### How signing works here
- **`fastlane match`** keeps one App Store distribution certificate + provisioning
  profile, encrypted with `MATCH_PASSWORD`, in a **Google Cloud Storage bucket**
  (config: `web/ios/fastlane/Matchfile`). Every machine fetches the same material
  instead of minting its own.
- The committed Xcode project stays on **automatic signing** (so `make ios-beta`
  keeps working locally). The CI lane (`ci_beta`) flips *its checkout only* to
  manual signing via `update_code_signing_settings`, so the headless archive step
  finds the match profile.
- **Push on release builds:** the Release config uses `Runner.Release.entitlements`
  with `aps-environment = production` (Debug/Profile use `Runner.entitlements` =
  `development`). This is required because manual signing does **not** auto-promote
  `development → production` the way Xcode's automatic signing does — without it,
  TestFlight push would silently fail.

### One-time setup

1. **Seed the match bucket** (done once, on your Mac — needs Apple login + bucket
   write access). Create the GCS bucket first (e.g. `dispax-ios-certs`), then:
   ```bash
   export GOOGLE_APPLICATION_CREDENTIALS=/path/to/gcs-sa.json
   export MATCH_GCS_BUCKET=dispax-ios-certs
   export MATCH_PASSWORD='choose-a-strong-passphrase'
   cd web/ios && bundle exec fastlane match appstore
   ```
   This generates the cert + profile and uploads them encrypted. CI afterwards
   only runs match `readonly`, so it never touches the Apple account.

2. **Add repository secrets** (GitHub → Settings → Secrets and variables → Actions):

   | Secret | What it is |
   |--------|-----------|
   | `MATCH_PASSWORD` | the passphrase you chose above |
   | `MATCH_GCS_BUCKET` | the bucket name (e.g. `dispax-ios-certs`) |
   | `GCS_SA_KEY` | a service-account JSON key with **read** access to the bucket |
   | `ASC_KEY_ID` | App Store Connect API key id |
   | `ASC_ISSUER_ID` | App Store Connect API issuer id |
   | `ASC_KEY_CONTENT` | full `.p8` PEM contents of the ASC API key |
   | `MAPBOX_ACCESS_TOKEN` | Mapbox token compiled into the app (maps break if empty) |

### Triggering a release
- **On a version tag** — bump `version:` in `web/pubspec.yaml`, commit, then:
  ```bash
  git tag v1.0.1 && git push origin v1.0.1
  ```
- **Manually** — GitHub → Actions → *iOS TestFlight* → **Run workflow**.

---

## Verification

Neither the local nor the CI flow could be exercised end-to-end in the dev
environment (archive + upload needs your signing identity, the match bucket, and
Apple credentials). What *was* verified statically: `Info.plist`, both
entitlements files, `ExportOptions.plist`, and `project.pbxproj` pass
`plutil -lint`; Release maps to `Runner.Release.entitlements` (production) while
Debug/Profile map to `Runner.entitlements` (development); `Fastfile` and
`Matchfile` pass `ruby -c`; the workflow YAML parses; and `make ios-beta` expands
to the correct build → upload chain.

**Run the first archive through Xcode manually** (Product → Archive → Distribute App →
App Store Connect) so any signing/provisioning problems surface with Xcode's
diagnostics before relying on `make ios-beta`. For CI, the **first `Run workflow`
dispatch is the real end-to-end test** — watch it once; the likely first-run
snags are: the match profile name must be exactly `match AppStore de.dispax.app`
(as in `ExportOptions.plist`), and the GCS service account must have read access
to the bucket. After a green run, confirm the shipped IPA carries the production
push entitlement:
```bash
unzip -p build/ios/ipa/dispax.ipa 'Payload/*.app/embedded.mobileprovision' \
  | security cms -D 2>/dev/null | plutil -extract Entitlements.aps-environment raw -
# expected: production
```

To confirm push after the first TestFlight install: send a test message from
Firebase Console → Cloud Messaging to the device token and verify it arrives in
foreground and background.
