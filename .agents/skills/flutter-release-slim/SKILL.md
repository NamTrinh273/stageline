---
name: flutter-release-slim
description: >-
  Use when configuring Android/iOS permissions, file associations (.concert),
  R8/ProGuard shrinking, APK/IPA size audits, or GitHub Actions CI/CD builds
  (including cloud iOS builds without a local Mac).
---

# Flutter Release Slim & Cross-Platform Build Checklist

## 1. Platform Permissions & File Associations
- **Android (`android/app/src/main/AndroidManifest.xml`)**:
  - `android.permission.CAMERA` (QR scanner only; mark `<uses-feature android:name="android.hardware.camera" android:required="false" />`).
  - Do NOT request `INTERNET` permission in release manifest if strictly offline (double-check debug vs main manifest).
  - Register `ACTION_VIEW` intent-filter for `.concert` / `application/json` / `application/octet-stream` so tapping a shared `.concert` file in Zalo/Files opens StageLine directly.
- **iOS (`ios/Runner/Info.plist`)**:
  - `NSCameraUsageDescription`: explain QR song import clearly.
  - `UIFileSharingEnabled` (`true`) + `LSSupportsOpeningDocumentsInPlace` (`true`) + custom `UTExportedTypeDeclarations` / `CFBundleDocumentTypes` for `.concert` extension.

## 2. Android Slim Build Configuration (`android/app/build.gradle.kts` or `.gradle`)
- Enable release shrinking:
  - `isMinifyEnabled = true`
  - `isShrinkResources = true`
- Build split APKs (primary distribution target is `app-arm64-v8a-release.apk`):
```powershell
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols
```
- Audit binary footprint whenever adding or updating a package:
```powershell
flutter build apk --release --target-platform android-arm64 --analyze-size
```
- **Target Budget**: `app-arm64-v8a-release.apk` MUST stay **< 18 MB**. Flag any dependency adding > 2 MB.

## 3. Cloud iOS Build (No Local Mac)
- Provide `.github/workflows/build.yml` with two jobs:
  1. `android-release` (`ubuntu-latest`): runs `flutter analyze`, `flutter test`, builds split APKs, uploads `app-arm64-v8a-release.apk` artifact.
  2. `ios-unsigned-or-signed` (`macos-latest`): runs `flutter build ios --release --no-codesign` (or signed `.ipa` when Apple certificates/provisioning secrets are supplied) and packages `.ipa` artifact for AltStore/SideStore/TestFlight.

## 4. Pre-Release Audit Gate (Neon Review)
1. Confirm zero `print()` statements and zero unused assets in `pubspec.yaml`.
2. Confirm `WakelockPlus` and `MobileScannerController` release properly on backgrounding.
3. Confirm APK size `< 18 MB` via file size check on `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.
