import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'command_executor.dart';

abstract class BaseShellExecutor implements CommandExecutor {
  BaseShellExecutor({Map<String, String> environment = const {}})
      : defaultEnvironment = environment;

  final Map<String, Process> _processes = <String, Process>{};
  final Map<String, String> defaultEnvironment;

  String get shell;
  List<String> shellCommandArgs(String command);

  String commandExistCheck(String command);

  @override
  Stream<String> execute(
    String command, {
    String taskId = 'default',
    String? workingDirectory,
    Duration? timeout,
    Map<String, String>? environment,
  }) async* {
    final mergedEnvironment = <String, String>{
      ...Platform.environment,
      ...defaultEnvironment,
      ...?environment,
    };

    final process = await Process.start(
      shell,
      shellCommandArgs(command),
      workingDirectory: workingDirectory,
      runInShell: true,
      environment: mergedEnvironment,
    );

    _processes[taskId] = process;

    Timer? timeoutTimer;
    if (timeout != null) {
      timeoutTimer = Timer(timeout, () {
        if (_processes.containsKey(taskId)) {
          process.kill();
        }
      });
    }

    final controller = StreamController<String>();

    final subscriptions = <StreamSubscription<String>>[
      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(controller.add),
      process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(controller.add),
    ];

    process.exitCode.then((exitCode) async {
      timeoutTimer?.cancel();
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
      controller.add('__EXIT_CODE__:$exitCode');
      _processes.remove(taskId);
      await controller.close();
    });

    yield* controller.stream;
  }

  @override
  Future<CommandResult> executeForResult(
    String command, {
    String? workingDirectory,
    Duration? timeout,
    Map<String, String>? environment,
  }) async {
    final mergedEnvironment = <String, String>{
      ...Platform.environment,
      ...defaultEnvironment,
      ...?environment,
    };

    final stopwatch = Stopwatch()..start();

    final result = await Process.run(
      shell,
      shellCommandArgs(command),
      workingDirectory: workingDirectory,
      runInShell: true,
      environment: mergedEnvironment,
    ).timeout(timeout ?? const Duration(minutes: 5));

    stopwatch.stop();

    return CommandResult(
      exitCode: result.exitCode,
      stdout: result.stdout.toString(),
      stderr: result.stderr.toString(),
      duration: stopwatch.elapsed,
    );
  }

  @override
  Future<void> killProcess(String taskId) async {
    final process = _processes.remove(taskId);
    if (process != null) {
      process.kill();
    }
  }

  @override
  Future<bool> isCommandAvailable(String command) async {
    final result = await executeForResult(
      commandExistCheck(command),
      timeout: const Duration(seconds: 12),
    );
    return result.isSuccess;
  }
}
