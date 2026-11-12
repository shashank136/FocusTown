# Release notes

Everything needed to ship Focus Town, except the secrets (which are never committed).

## Identity

- Display name: `Focus Town`.
- Version: `1.0.0+1` (`pubspec.yaml`).
- Bundle id / application id: `com.shashank.focusTown` (iOS, iOS tests as
  `.RunnerTests`, Android `applicationId` and package). Chosen by the user on
  2026-11-11. The signing team is `5RLKRL9U6T` (the user's own team; not a
  secret, every signed app carries it).

## Icon and launch screens

- `flutter test tool/generate_icon_test.dart` redraws the icons with the town's
  own painter: iOS `AppIcon` (1024 px, opaque), Android legacy `mipmap-*`, the
  adaptive foreground (`drawable-nodpi/ic_launcher_foreground.png`) and the
  launch pictures. The adaptive background is `#8CC9EA` (`values/colors.xml`).
- iOS launch screen: sky colour plus `LaunchImage`. Android: `launch_background`
  and, on Android 12+, `values-v31/styles.xml`.

## Privacy

- No network permission, no accounts, no analytics. Everything stays on the
  device.
- iOS `PrivacyInfo.xcprivacy`: no tracking, no collected data; required-reason
  APIs: system boot time `35F9.1` (the uptime clock), file timestamp `C617.1`
  (SQLite files), user defaults `CA92.1`. After the first archive, run Product >
  Archive > Generate Privacy Report in Xcode and add any extra reasons it lists.
- App Store privacy label: **Data Not Collected**.
- Play Console data safety: no data collected, no data shared; no encryption in
  transit is needed because the app makes no network calls.
- Permissions: notifications (to warn before builders stop). Android
  `READ_PHONE_STATE` is optional, only for phone-call detection, with the
  reason: "so a phone call does not count as leaving the app".

## Signing

### Android

1. Create an upload key (once):

   ```
   keytool -genkey -v -keystore ~/focus-town-upload.jks -keyalg RSA \
     -keysize 2048 -validity 10000 -alias upload
   ```

2. Create `android/key.properties` (git-ignored; placeholders shown):

   ```
   storePassword=<store password>
   keyPassword=<key password>
   keyAlias=upload
   storeFile=/Users/<you>/focus-town-upload.jks
   ```

3. `flutter build appbundle --release` signs with it. Without `key.properties`
   the release build falls back to the debug key and Gradle prints a warning;
   such a build cannot be uploaded to the Play Store.

Keep the keystore and both passwords in a password manager, plus an offline
encrypted copy in a second place. Losing the upload key is recoverable only
through Play App Signing key reset, so enrol in **Play App Signing** when
creating the app.

### iOS

- Apple Developer Program membership ($99/year).
- In Xcode, Runner target > Signing & Capabilities: tick "Automatically manage
  signing" and pick the Team. The App ID needs no extra capabilities.
- Build with `flutter build ipa --release`, or Product > Archive.

## Checks run for T-22.10 and T-22.11

- `flutter build ios --no-codesign --release` builds and bundles
  `PrivacyInfo.xcprivacy`.
- The Android release build could not be run on the dev machine (no Android SDK).
  `build.gradle.kts` and the resource files are written but unverified; run
  `flutter build apk --release` once the SDK is installed.

## Store name (decided 2026-11-12)

App Store limits: name 30 characters, subtitle 30 characters. Another app, "Focustown: Pomodoro Timer", exists, so the exact name may be taken.

- Name: `Focus Town`
- Subtitle: `Build While You Focus`
- If the name is taken, try in order: `Focus Town Builder`, `Focus Town: Block Builder`, `Focus Town: Build & Focus` (keep the subtitle).
- The home screen name (`CFBundleDisplayName`) stays `Focus Town`; it need not match the store name.
- Keep the icon and screenshots clearly different from the other app (isometric block town).
