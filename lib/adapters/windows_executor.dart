import 'base_shell_executor.dart';

class WindowsShellExecutor extends BaseShellExecutor {
  @override
  String get shell => 'cmd';

  @override
  List<String> shellCommandArgs(String command) => <String>['/c', command];

  @override
  String commandExistCheck(String command) => 'where $command';
}
