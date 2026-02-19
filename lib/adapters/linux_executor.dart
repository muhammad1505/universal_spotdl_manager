import 'base_shell_executor.dart';

class LinuxShellExecutor extends BaseShellExecutor {
  @override
  String get shell => 'bash';

  @override
  List<String> shellCommandArgs(String command) => <String>['-lc', command];

  @override
  String commandExistCheck(String command) => 'command -v $command';
}
