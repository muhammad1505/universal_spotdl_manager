# Universal SpotDL Manager

Universal Cross-Platform CLI Media Orchestrator built with Flutter for:
- Android
- Windows
- Linux
- macOS

CLI engine: `spotdl` (no embedded Python, no Chaquopy, no external server dependency).

## Core Features

- Smart multi-download queue (FIFO + priority)
- Max concurrent worker control
- Pause/resume/cancel/reorder
- Crash-safe queue recovery
- Persistent queue storage (SQLite)
- Built-in audio player (just_audio + audio_session)
- Analytics dashboard + CSV export
- Environment health manager per platform
- Structured JSON logging + export
- Queue JSON import/export

## Project Structure

```text
lib/
 ├── main.dart
 ├── core/
 │   ├── constants.dart
 │   ├── spotdl_parser.dart
 │   └── theme.dart
 ├── adapters/
 │   ├── command_executor.dart
 │   ├── android_termux_executor.dart
 │   ├── windows_executor.dart
 │   ├── linux_executor.dart
 │   ├── mac_executor.dart
 │   └── platform_adapter_factory.dart
 ├── managers/
 │   ├── queue_manager.dart
 │   ├── analytics_manager.dart
 │   ├── environment_manager.dart
 │   └── player_manager.dart
 ├── services/
 │   ├── database_service.dart
 │   ├── audio_service.dart
 │   ├── file_service.dart
 │   └── environment_service.dart
 ├── models/
 ├── screens/
 ├── widgets/
 └── plugins/
```

## CI/CD

Workflow: `.github/workflows/build.yml`

- Setup Flutter
- Cache pub
- `flutter analyze`
- `flutter test`
- Matrix desktop build: Windows, Linux, macOS
- Android APK build
- Artifact upload per OS
- Auto release + changelog on tag `v*`

## Docs

- `docs/ARCHITECTURE.md`
- `docs/DISTRIBUTION.md`
- `docs/SCALING.md`
