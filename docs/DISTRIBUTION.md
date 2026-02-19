# Distribution Guide

## Android

1. Build APK:
```bash
flutter build apk --release
```
2. Output: `build/app/outputs/flutter-apk/app-release.apk`
3. Runtime requirement: Termux installed and environment prepared.

## Windows

1. Build EXE bundle:
```bash
flutter build windows --release
```
2. Portable ZIP: compress `build/windows/x64/runner/Release/`.
3. Installer: package with Inno Setup or WiX from release folder.

## Linux

1. Build Linux bundle:
```bash
flutter build linux --release
```
2. AppImage strategy:
- Use `appimagetool` against `build/linux/x64/release/bundle/`.

## macOS

1. Build app bundle:
```bash
flutter build macos --release
```
2. DMG strategy:
- Package `build/macos/Build/Products/Release/*.app` using `create-dmg`.

## CI/CD

Workflow file: `.github/workflows/build.yml`

Includes:
- Flutter setup
- pub cache
- `flutter analyze`
- unit tests
- matrix desktop build (`windows-latest`, `ubuntu-latest`, `macos-latest`)
- Android APK build
- artifact upload per OS
- automatic release + changelog on `v*` tag
