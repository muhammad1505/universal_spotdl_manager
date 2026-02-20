import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../core/constants.dart';
import '../core/spotdl_parser.dart';
import '../models/download_task.dart';
import '../providers/core_providers.dart';
import '../services/database_service.dart';
import '../services/file_service.dart';
import '../plugins/plugin_registry.dart';

class QueueState {
  const QueueState({
    this.tasks = const <DownloadTask>[],
    this.maxConcurrent = AppConstants.defaultMaxConcurrent,
    this.enginePaused = false,
    this.activeTaskIds = const <String>{},
    this.message,
  });

  final List<DownloadTask> tasks;
  final int maxConcurrent;
  final bool enginePaused;
  final Set<String> activeTaskIds;
  final String? message;

  QueueState copyWith({
    List<DownloadTask>? tasks,
    int? maxConcurrent,
    bool? enginePaused,
    Set<String>? activeTaskIds,
    String? message,
  }) {
    return QueueState(
      tasks: tasks ?? this.tasks,
      maxConcurrent: maxConcurrent ?? this.maxConcurrent,
      enginePaused: enginePaused ?? this.enginePaused,
      activeTaskIds: activeTaskIds ?? this.activeTaskIds,
      message: message,
    );
  }
}

class QueueManager extends Notifier<QueueState> {
  final Map<String, StreamSubscription<String>> _subscriptions =
      <String, StreamSubscription<String>>{};
  final Map<String, Timer> _retryTimers = <String, Timer>{};
  final Map<String, DateTime> _startTimes = <String, DateTime>{};
  bool _isProcessing = false;

  // Download log stream — Home console subscribes to this
  final StreamController<String> _downloadLogController =
      StreamController<String>.broadcast();

  Stream<String> get downloadLogStream => _downloadLogController.stream;

  void _emitDownloadLog(String line) {
    if (!_downloadLogController.isClosed) {
      _downloadLogController.add(line);
    }
  }

  @override
  QueueState build() {
    ref.onDispose(_disposeRuntime);
    unawaited(_bootstrap());
    return const QueueState();
  }

  Future<void> _bootstrap() async {
    try {
      final db = ref.read(databaseServiceProvider);
      await db.markDownloadingAsWaiting();

      final tasks = await db.getTasks();
      state = state.copyWith(tasks: _sortStable(tasks));
      await _log('bootstrap', <String, dynamic>{'count': tasks.length});
      _processQueue();
    } catch (_) {
      // Widget tests can run without sqflite initialization.
      state = state.copyWith(tasks: const <DownloadTask>[]);
    }
  }

  Future<bool> addTask(String url, {int priority = 1}) async {
    final normalized = url.trim();
    if (normalized.isEmpty) {
      return false;
    }

    final duplicated = state.tasks.any(
      (task) => task.url == normalized && !task.status.isTerminal,
    );

    if (duplicated) {
      state = state.copyWith(message: 'URL sudah ada di queue.');
      return false;
    }

    final nextOrder = state.tasks.isEmpty
        ? 0
        : state.tasks.map((task) => task.orderIndex).reduce(max) + 1;

    final task = DownloadTask(
      url: normalized,
      priority: priority,
      orderIndex: nextOrder,
      isPlaylist: SpotDLParser.isPlaylistUrl(normalized),
    );

    await ref.read(databaseServiceProvider).upsertTask(task);
    state = state.copyWith(tasks: _sortStable(<DownloadTask>[...state.tasks, task]));

    await _log('task_added', <String, dynamic>{
      'task_id': task.id,
      'priority': task.priority,
      'playlist': task.isPlaylist,
    });

    _processQueue();
    return true;
  }

  Future<int> addBatch(List<String> urls, {int priority = 1}) async {
    var inserted = 0;
    for (final raw in urls) {
      final ok = await addTask(raw, priority: priority);
      if (ok) {
        inserted += 1;
      }
    }
    return inserted;
  }

  Future<void> removeTask(String id) async {
    if (_subscriptions.containsKey(id)) {
      await cancelTask(id);
    }

    _retryTimers.remove(id)?.cancel();
    await ref.read(databaseServiceProvider).deleteTask(id);

    final tasks = state.tasks.where((task) => task.id != id).toList(growable: false);
    state = state.copyWith(tasks: _sortStable(tasks));
  }

  Future<void> cancelTask(String id) async {
    _retryTimers.remove(id)?.cancel();
    await ref.read(commandExecutorProvider).killProcess(id);
    await _subscriptions.remove(id)?.cancel();

    await _updateTask(id, (task) {
      return task.copyWith(
        status: TaskStatus.cancelled,
        outputMessage: 'Cancelled by user',
      );
    });

    _processQueue();
  }

  Future<void> cancelAll() async {
    final running = state.tasks.where((task) => !task.status.isTerminal).toList();
    for (final task in running) {
      await cancelTask(task.id);
    }
  }

  Future<void> pauseTask(String id) async {
    final task = _findTask(id);
    if (task == null) {
      return;
    }

    if (task.status == TaskStatus.downloading) {
      await _updateTask(id, (old) {
        return old.copyWith(status: TaskStatus.paused, outputMessage: 'Paused');
      });
      await ref.read(commandExecutorProvider).killProcess(id);
      await _subscriptions.remove(id)?.cancel();
    } else if (task.status == TaskStatus.waiting) {
      await _updateTask(id, (old) {
        return old.copyWith(status: TaskStatus.paused, outputMessage: 'Paused');
      });
    }

    _processQueue();
  }

  Future<void> resumeTask(String id) async {
    final task = _findTask(id);
    if (task == null || task.status != TaskStatus.paused) {
      return;
    }

    await _updateTask(id, (old) {
      return old.copyWith(status: TaskStatus.waiting, outputMessage: 'Queued');
    });

    _processQueue();
  }

  Future<void> pauseQueue() async {
    state = state.copyWith(enginePaused: true, message: 'Queue paused');
    final running = state.tasks
        .where((task) => task.status == TaskStatus.downloading)
        .toList(growable: false);

    for (final task in running) {
      await pauseTask(task.id);
    }
  }

  Future<void> resumeQueue() async {
    state = state.copyWith(enginePaused: false, message: 'Queue resumed');
    _processQueue();
  }

  Future<void> setMaxConcurrent(int maxConcurrent) async {
    state = state.copyWith(maxConcurrent: maxConcurrent.clamp(1, 8));
    _processQueue();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final tasks = <DownloadTask>[...state.tasks];
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    final moved = tasks.removeAt(oldIndex);
    tasks.insert(newIndex, moved);

    final reindexed = <DownloadTask>[];
    for (var i = 0; i < tasks.length; i++) {
      reindexed.add(tasks[i].copyWith(orderIndex: i));
    }

    state = state.copyWith(tasks: reindexed);

    final db = ref.read(databaseServiceProvider);
    for (final task in reindexed) {
      await db.upsertTask(task);
    }

    await _log('task_reordered', <String, dynamic>{
      'task_id': moved.id,
      'new_index': newIndex,
    });
  }

  Future<String> exportQueueJson() async {
    final file = await ref.read(fileServiceProvider).exportQueue(state.tasks);
    await _log('queue_exported', <String, dynamic>{'path': file.path});
    return file.path;
  }

  Future<int> importQueueJson(String path) async {
    final imported = await ref.read(fileServiceProvider).importQueue(path);
    var inserted = 0;

    for (final task in imported) {
      final ok = await addTask(task.url, priority: task.priority);
      if (ok) {
        inserted += 1;
      }
    }

    await _log('queue_imported', <String, dynamic>{
      'path': path,
      'count': inserted,
    });

    return inserted;
  }

  Future<void> _processQueue() async {
    if (_isProcessing) {
      return;
    }

    if (state.enginePaused) {
      return;
    }

    _isProcessing = true;

    try {
      while (!state.enginePaused &&
          _subscriptions.length < state.maxConcurrent) {
        final next = _nextWaitingTask();
        if (next == null) {
          break;
        }
        await _startTask(next);
      }

      state = state.copyWith(activeTaskIds: _subscriptions.keys.toSet());
    } finally {
      _isProcessing = false;
    }
  }

  DownloadTask? _nextWaitingTask() {
    final waiting = state.tasks
        .where(
          (task) =>
              task.status == TaskStatus.waiting &&
              !_subscriptions.containsKey(task.id) &&
              !_retryTimers.containsKey(task.id),
        )
        .toList(growable: false);

    if (waiting.isEmpty) {
      return null;
    }

    waiting.sort((a, b) {
      final priority = a.priority.compareTo(b.priority);
      if (priority != 0) {
        return priority;
      }
      final order = a.orderIndex.compareTo(b.orderIndex);
      if (order != 0) {
        return order;
      }
      return a.createdAt.compareTo(b.createdAt);
    });

    return waiting.first;
  }

  Future<void> _startTask(DownloadTask task) async {
    await _updateTask(task.id, (old) {
      return old.copyWith(
        status: TaskStatus.downloading,
        progress: 0,
        speed: '0',
        eta: '0',
        outputMessage: 'Starting spotdl...',
        startedAt: DateTime.now().toUtc(),
      );
    });

    _startTimes[task.id] = DateTime.now().toUtc();

    final mediaDir = await ref.read(fileServiceProvider).getMediaDirectory();
    final outputTemplate = p
        .join(mediaDir.path, '{artist} - {title}.{output-ext}')
        .replaceAll('"', '\\"');

    final plugin = ref.read(pluginRegistryProvider).resolve(task.url);
    final command = plugin.buildDownloadCommand(task.url, outputTemplate);

    _emitDownloadLog('[download] ▶ ${task.displayTitle}');
    _emitDownloadLog('[cmd] $command');

    var sawFailure = false;
    var sawSuccess = false;
    var gotExitCode = false;

    final subscription = ref
        .read(commandExecutorProvider)
        .execute(
          command,
          taskId: task.id,
          timeout: AppConstants.defaultCommandTimeout,
        )
        .listen(
      (line) async {
        if (line.startsWith('__EXIT_CODE__:')) {
          gotExitCode = true;
          final exitCode = int.tryParse(line.split(':').last) ?? 1;
          _emitDownloadLog('[exit] ${task.displayTitle} → code=$exitCode');
          await _finishTask(
            task.id,
            exitCode: exitCode,
            sawFailure: sawFailure,
            sawSuccess: sawSuccess,
          );
          return;
        }

        // Emit to console
        _emitDownloadLog(line);

        sawFailure = sawFailure || SpotDLParser.isFailure(line);
        sawSuccess = sawSuccess || SpotDLParser.isSuccess(line);

        final progress = SpotDLParser.parseProgress(line);
        final discoveredPath = _extractFilePath(line);

        await _updateTask(
          task.id,
          (old) {
            var updated = old;
            if (progress != null) {
              updated = updated.copyWith(
                progress: progress.percent,
                speed: progress.speed,
                eta: progress.eta,
              );
            }

            if (discoveredPath != null) {
              final segments = p.basenameWithoutExtension(discoveredPath).split(' - ');
              final artist = segments.length > 1 ? segments.first.trim() : old.artist;
              final title = segments.length > 1
                  ? segments.sublist(1).join(' - ').trim()
                  : p.basenameWithoutExtension(discoveredPath);

              updated = updated.copyWith(
                filePath: discoveredPath,
                artist: artist,
                title: title,
              );
            }

            return updated.copyWith(outputMessage: line);
          },
          persist: progress == null,
        );
      },
      onError: (Object error) async {
        _emitDownloadLog('[error] ${task.displayTitle}: $error');
        await _finishTask(
          task.id,
          exitCode: 1,
          sawFailure: true,
          sawSuccess: false,
          error: error.toString(),
        );
      },
      onDone: () async {
        if (!gotExitCode) {
          await _finishTask(
            task.id,
            exitCode: sawFailure && !sawSuccess ? 1 : 0,
            sawFailure: sawFailure,
            sawSuccess: sawSuccess,
          );
        }
      },
      cancelOnError: false,
    );

    _subscriptions[task.id] = subscription;
    state = state.copyWith(activeTaskIds: _subscriptions.keys.toSet());

    await _log('task_started', <String, dynamic>{
      'task_id': task.id,
      'url': task.url,
    });
  }

  Future<void> _finishTask(
    String taskId, {
    required int exitCode,
    required bool sawFailure,
    required bool sawSuccess,
    String? error,
  }) async {
    await _subscriptions.remove(taskId)?.cancel();
    state = state.copyWith(activeTaskIds: _subscriptions.keys.toSet());

    final current = _findTask(taskId);
    if (current == null) {
      _processQueue();
      return;
    }

    if (current.status == TaskStatus.paused ||
        current.status == TaskStatus.cancelled) {
      _processQueue();
      return;
    }

    final isSuccess = exitCode == 0 && !sawFailure || (sawSuccess && exitCode == 0);

    if (isSuccess) {
      final started = _startTimes.remove(taskId) ?? current.startedAt;
      final completedAt = DateTime.now().toUtc();
      final elapsed = started == null
          ? 0
          : completedAt.difference(started).inMilliseconds;

      final completed = current.copyWith(
        status: TaskStatus.completed,
        progress: 100,
        eta: '0',
        speed: '0',
        completedAt: completedAt,
        downloadDurationMs: elapsed,
        outputMessage: 'Completed',
      );

      await ref.read(databaseServiceProvider).upsertTask(completed);
      await ref.read(databaseServiceProvider).incrementSuccess(
            completedAt,
            totalBytes: completed.sizeBytes,
            downloadMs: elapsed,
          );

      _replaceTask(completed);
      _emitDownloadLog('[ok] ✓ ${current.displayTitle} selesai (${elapsed}ms)');

      await _log('task_completed', <String, dynamic>{
        'task_id': taskId,
        'duration_ms': elapsed,
        'retries': current.retries,
      });
    } else {
      _emitDownloadLog('[error] ✗ ${current.displayTitle} gagal: ${error ?? 'exit=$exitCode'}');
      await _handleFailure(current, error ?? 'Exit code $exitCode');
    }

    _processQueue();
  }

  Future<void> _handleFailure(DownloadTask task, String error) async {
    final retries = task.retries + 1;

    if (retries <= AppConstants.maxRetry) {
      final backoffSeconds = pow(2, retries).toInt();

      final waiting = task.copyWith(
        retries: retries,
        status: TaskStatus.waiting,
        outputMessage: 'Retry #$retries in ${backoffSeconds}s',
        lastError: error,
      );

      await ref.read(databaseServiceProvider).upsertTask(waiting);
      _replaceTask(waiting);

      _retryTimers[task.id]?.cancel();
      _retryTimers[task.id] = Timer(Duration(seconds: backoffSeconds), () {
        _retryTimers.remove(task.id);
        _processQueue();
      });

      await _log('task_retry_scheduled', <String, dynamic>{
        'task_id': task.id,
        'retries': retries,
        'delay_sec': backoffSeconds,
      });

      return;
    }

    final failed = task.copyWith(
      status: TaskStatus.failed,
      outputMessage: error,
      lastError: error,
    );

    await ref.read(databaseServiceProvider).upsertTask(failed);
    await ref.read(databaseServiceProvider).incrementFailure(DateTime.now().toUtc());
    _replaceTask(failed);

    await _log('task_failed', <String, dynamic>{
      'task_id': task.id,
      'error': error,
      'retries': retries,
    });
  }

  Future<void> _updateTask(
    String id,
    DownloadTask Function(DownloadTask old) mapper, {
    bool persist = true,
  }) async {
    final old = _findTask(id);
    if (old == null) {
      return;
    }

    final updated = mapper(old);
    _replaceTask(updated);

    if (persist) {
      await ref.read(databaseServiceProvider).upsertTask(updated);
    }
  }

  void _replaceTask(DownloadTask next) {
    final tasks = state.tasks.map((task) {
      if (task.id == next.id) {
        return next;
      }
      return task;
    }).toList(growable: false);

    state = state.copyWith(tasks: _sortStable(tasks));
  }

  DownloadTask? _findTask(String id) {
    for (final task in state.tasks) {
      if (task.id == id) {
        return task;
      }
    }
    return null;
  }

  List<DownloadTask> _sortStable(List<DownloadTask> tasks) {
    final sorted = <DownloadTask>[...tasks];
    sorted.sort((a, b) {
      final terminalA = a.status.isTerminal;
      final terminalB = b.status.isTerminal;
      if (terminalA != terminalB) {
        return terminalA ? 1 : -1;
      }

      final order = a.orderIndex.compareTo(b.orderIndex);
      if (order != 0) {
        return order;
      }

      return a.createdAt.compareTo(b.createdAt);
    });
    return sorted;
  }

  String? _extractFilePath(String line) {
    final regex = RegExp(
      r'([A-Za-z]:\\[^\"\n]+\.(mp3|m4a|flac|ogg|wav))|(/[^\"\n]+\.(mp3|m4a|flac|ogg|wav))',
      caseSensitive: false,
    );
    final match = regex.firstMatch(line);
    if (match == null) {
      return null;
    }
    return match.group(0);
  }

  Future<void> _log(String event, Map<String, dynamic> data) async {
    await ref.read(fileServiceProvider).appendJsonLog(
      AppConstants.queueLogFile,
      <String, dynamic>{
        'event': event,
        ...data,
      },
    );
  }

  void _disposeRuntime() {
    for (final timer in _retryTimers.values) {
      timer.cancel();
    }
    _retryTimers.clear();

    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _downloadLogController.close();
  }
}

final queueProvider = NotifierProvider<QueueManager, QueueState>(
  QueueManager.new,
);
