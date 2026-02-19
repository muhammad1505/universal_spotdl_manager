import 'base_shell_executor.dart';

class AndroidTermuxExecutor extends BaseShellExecutor {
  AndroidTermuxExecutor()
      : super(environment: const {
          'PATH': '/data/data/com.termux/files/usr/bin:/system/bin:/system/xbin:/usr/bin:/bin',
        });

  @override
  String get shell => 'sh';

  @override
  List<String> shellCommandArgs(String command) => <String>['-c', command];

  @override
  String commandExistCheck(String command) => 'command -v $command';
}
