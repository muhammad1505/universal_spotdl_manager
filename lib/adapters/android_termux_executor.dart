import 'dart:async';

import 'package:flutter/services.dart';

import 'command_executor.dart';

/// Executes commands in the Termux environment via the Android native
/// RUN_COMMAND bridge (MethodChannel).
///
/// Important: Termux's RUN_COMMAND is batch-mode (no streaming).
/// The entire command runs, then stdout/stderr are returned at once.
/// This executor tracks active tasks and supports cancellation.
class AndroidTermuxExecutor implements CommandExecutor {
  static const MethodChannel _channel = MethodChannel('usm/android_system');

  /// Tracks active task IDs → cancelled flag.
  final Set<String> _cancelled = <String>{};

  @override
  Stream<String> execute(
    String command, {
    String taskId = 'default',
    String? workingDirectory,
    Duration? timeout,
    Map<String, String>? environment,
  }) async* {
    final timeoutSeconds = timeout?.inSeconds ?? 300;
    _cancelled.remove(taskId);

    yield '[info] Mengirim command ke Termux...';
    yield '[info] Menunggu Termux menyelesaikan proses (batch mode)...';

    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'executeTermuxCommand',
        <String, dynamic>{
          'command': command,
          'timeoutSeconds': timeoutSeconds,
        },
      );

      // Check if task was cancelled while waiting
      if (_cancelled.contains(taskId)) {
        _cancelled.remove(taskId);
        yield '[info] Task dibatalkan.';
        yield '__EXIT_CODE__:130';
        return;
      }

      if (result == null) {
        yield '[error] Tidak ada hasil dari Termux bridge';
        yield '__EXIT_CODE__:1';
        return;
      }

      final stdout = (result['stdout'] as String?) ?? '';
      final stderr = (result['stderr'] as String?) ?? '';
      final rawExitCode = (result['exitCode'] as int?) ?? -1;
      final errCode = (result['errCode'] as int?) ?? -1;
      final errMsg = (result['errMsg'] as String?) ?? '';
      final success = (result['success'] as bool?) ?? false;

      // Normalize exit code: Termux sometimes returns exitCode=-1 on
      // successful commands (minimal callback). Use the 'success' flag
      // from Kotlin-side rescue logic as the source of truth.
      final exitCode = (rawExitCode == -1 && success) ? 0 : rawExitCode;

      // Emit diagnostic info if there are issues
      if (exitCode != 0) {
        if (errMsg.isNotEmpty) {
          yield '[debug] errMsg: $errMsg';
        }
        if (errCode != -1 && errCode != 0) {
          yield '[debug] errCode: $errCode';
        }
      }

      // Yield stdout lines
      if (stdout.isNotEmpty) {
        for (final line in stdout.split('\n')) {
          if (line.isNotEmpty) {
            yield line;
          }
        }
      }

      // Yield stderr lines
      if (stderr.isNotEmpty) {
        for (final line in stderr.split('\n')) {
          if (line.isNotEmpty) {
            yield '[stderr] $line';
          }
        }
      }

      // If no output at all and success, emit info
      if (stdout.isEmpty && stderr.isEmpty && exitCode == 0) {
        yield '[info] Command selesai tanpa output (normal untuk beberapa command)';
      }

      yield '__EXIT_CODE__:$exitCode';
    } on PlatformException catch (e) {
      yield '[error] ${e.code}: ${e.message}';
      yield '__EXIT_CODE__:1';
    } catch (e) {
      yield '[error] $e';
      yield '__EXIT_CODE__:1';
    } finally {
      _cancelled.remove(taskId);
    }
  }

  @override
  Future<CommandResult> executeForResult(
    String command, {
    String? workingDirectory,
    Duration? timeout,
    Map<String, String>? environment,
  }) async {
    final timeoutSeconds = timeout?.inSeconds ?? 300;
    final stopwatch = Stopwatch()..start();

    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'executeTermuxCommand',
        <String, dynamic>{
          'command': command,
          'timeoutSeconds': timeoutSeconds,
        },
      );

      stopwatch.stop();

      if (result == null) {
        return CommandResult(
          exitCode: 1,
          stdout: '',
          stderr: 'No result from Termux bridge',
          duration: stopwatch.elapsed,
        );
      }

      final rawExitCode = (result['exitCode'] as int?) ?? -1;
      final success = (result['success'] as bool?) ?? false;
      final exitCode = (rawExitCode == -1 && success) ? 0 : rawExitCode;

      return CommandResult(
        exitCode: exitCode,
        stdout: (result['stdout'] as String?) ?? '',
        stderr: (result['stderr'] as String?) ?? '',
        duration: stopwatch.elapsed,
      );
    } on PlatformException catch (e) {
      stopwatch.stop();
      return CommandResult(
        exitCode: 1,
        stdout: '',
        stderr: e.message ?? 'Platform error',
        duration: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<void> killProcess(String taskId) async {
    _cancelled.add(taskId);
  }

  @override
  Future<bool> isCommandAvailable(String command) async {
    final result = await executeForResult(
      'command -v $command',
      timeout: const Duration(seconds: 15),
    );
    return result.isSuccess && result.stdout.trim().isNotEmpty;
  }
}
