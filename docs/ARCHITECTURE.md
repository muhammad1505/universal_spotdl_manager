# Universal SpotDL Manager Architecture

## High Level

Flutter UI Layer
- Screens and Widgets
- Riverpod State Management

Core Engines
- Queue Engine (`lib/managers/queue_manager.dart`)
- Analytics Engine (`lib/managers/analytics_manager.dart`)
- Player Engine (`lib/managers/player_manager.dart`)
- Environment Manager (`lib/managers/environment_manager.dart`)

Platform Adapter Layer
- `AndroidTermuxExecutor`
- `WindowsShellExecutor`
- `LinuxShellExecutor`
- `MacShellExecutor`

CLI Execution
- spotdl command orchestration through platform adapter
- progress parsing (`lib/core/spotdl_parser.dart`)

Persistence
- SQLite (`lib/services/database_service.dart`)
- JSON logs / queue import-export (`lib/services/file_service.dart`)

## Queue Engine

Implemented capabilities:
- FIFO + Priority scheduling
- Configurable max concurrent workers
- Pause / Resume queue and per-task
- Cancel individual / Cancel all
- Drag reorder
- Crash-safe resume (downloading -> waiting on startup)
- Persistent queue storage
- Exponential retry policy
- Auto deduplicate URL input
- Track vs playlist detection

## Environment Manager

Per platform checks:
- Android: Termux, Python, spotdl, ffmpeg
- Windows: Python, pip, spotdl, optional winget repair
- Linux: Python, spotdl, apt availability hint
- macOS: Homebrew, Python, spotdl

Status model:
- `HEALTHY`
- `WARNING`
- `ERROR`

## Analytics Engine

Tracked metrics:
- Total downloads
- Downloads per day/week/month
- Total bytes
- Failure ratio
- Average download duration
- Playback count
- Top 10 artist
- Top 10 track

Visualized in app:
- Bar chart
- Pie chart
- Line trend

Export:
- CSV export from analytics database

## Player Engine

Built with:
- `just_audio`
- `audio_session`

Features:
- Mini player
- Full-screen player
- Seekbar
- Playlist queue
- Resume last position
- Playback speed control
- Background-ready initialization (`just_audio_background`)

## Future Plugin Extension

Plugin contract:
- `lib/plugins/cli_plugin.dart`

Current implementation:
- `SpotdlPlugin`

Future-ready stubs:
- YouTube CLI
- Instagram CLI
- Torrent CLI
- SoundCloud CLI
