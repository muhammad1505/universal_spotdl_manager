class CommandResult {
  const CommandResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.duration,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
  final Duration duration;

  bool get isSuccess => exitCode == 0;
}

abstract class CommandExecutor {
  Stream<String> execute(
    String command, {
    String taskId = 'default',
    String? workingDirectory,
    Duration? timeout,
    Map<String, String>? environment,
  });

  Future<CommandResult> executeForResult(
    String command, {
    String? workingDirectory,
    Duration? timeout,
    Map<String, String>? environment,
  });

  Future<void> killProcess(String taskId);

  Future<bool> isCommandAvailable(String command);
}
