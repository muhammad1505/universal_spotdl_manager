import 'dart:io';

import 'command_executor.dart';
import 'linux_executor.dart';
import 'mac_executor.dart';
import 'windows_executor.dart';

@Deprecated('Use LinuxShellExecutor/WindowsShellExecutor/MacShellExecutor directly.')
class DesktopExecutor implements CommandExecutor {
  DesktopExecutor()
      : _delegate = Platform.isWindows
            ? WindowsShellExecutor()
            : (Platform.isMacOS ? MacShellExecutor() : LinuxShellExecutor());

  final CommandExecutor _delegate;

  @override
  Stream<String> execute(
    String command, {
    String taskId = 'default',
    String? workingDirectory,
    Duration? timeout,
    Map<String, String>? environment,
  }) {
    return _delegate.execute(
      command,
      taskId: taskId,
      workingDirectory: workingDirectory,
      timeout: timeout,
      environment: environment,
    );
  }

  @override
  Future<CommandResult> executeForResult(
    String command, {
    String? workingDirectory,
    Duration? timeout,
    Map<String, String>? environment,
  }) {
    return _delegate.executeForResult(
      command,
      workingDirectory: workingDirectory,
      timeout: timeout,
      environment: environment,
    );
  }

  @override
  Future<void> killProcess(String taskId) => _delegate.killProcess(taskId);

  @override
  Future<bool> isCommandAvailable(String command) =>
      _delegate.isCommandAvailable(command);
}
