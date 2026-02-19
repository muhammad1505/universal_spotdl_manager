import 'base_shell_executor.dart';

class MacShellExecutor extends BaseShellExecutor {
  @override
  String get shell => 'zsh';

  @override
  List<String> shellCommandArgs(String command) => <String>['-lc', command];

  @override
  String commandExistCheck(String command) => 'command -v $command';
}
