# Scaling Strategy

## 1. Runtime scaling
- Queue workers are configurable (`maxConcurrent`) and can be tuned by device capacity.
- Long-running command execution is stream-based, avoiding UI thread blocking.

## 2. Fault tolerance
- Queue state is persisted in SQLite.
- In-flight downloads are recovered after crash/restart.
- Exponential retry handles intermittent failures.

## 3. Observability
- Structured JSON logs for queue and app events.
- Export logs for production diagnostics.
- Analytics dashboard fed by persisted daily and playback metrics.

## 4. Data growth handling
- UI uses builder/reorderable builder lists for large collections.
- Aggregated daily analytics minimizes heavy read paths.
- Can archive old playback rows periodically for long-term performance.

## 5. Extensibility
- Platform adapter pattern isolates OS process semantics.
- Plugin contract allows adding new CLI engines without changing queue core.
- Suggested future plugins: YouTube, Instagram, Torrent, SoundCloud, AI metadata correction.
