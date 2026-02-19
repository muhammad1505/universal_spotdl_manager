import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../adapters/command_executor.dart';
import '../adapters/platform_adapter_factory.dart';

final environmentServiceProvider = Provider<EnvironmentService>((ref) {
  return EnvironmentService(executor: PlatformAdapterFactory.getExecutor());
});

class EnvironmentService {
  EnvironmentService({CommandExecutor? executor})
      : _executor = executor ?? PlatformAdapterFactory.getExecutor();

  final CommandExecutor _executor;

  Future<String?> checkPython() async {
    return _checkVersion(<String>['python3', 'python', 'py']);
  }

  Future<String?> checkFFmpeg() async {
    return _checkVersion(<String>['ffmpeg']);
  }

  Future<String?> checkSpotDL() async {
    return _checkVersion(<String>['spotdl']);
  }

  Future<Map<String, String?>> checkAll() async {
    return <String, String?>{
      'python': await checkPython(),
      'ffmpeg': await checkFFmpeg(),
      'spotdl': await checkSpotDL(),
    };
  }

  Future<bool> installSpotDL() async {
    if (Platform.isWindows) {
      final result =
          await _executor.executeForResult('python -m pip install -U spotdl');
      return result.isSuccess;
    }

    final result = await _executor.executeForResult('python3 -m pip install -U spotdl');
    return result.isSuccess;
  }

  Future<bool> installPython() async {
    if (Platform.isAndroid) {
      return (await _executor.executeForResult('pkg install -y python')).isSuccess;
    }

    if (Platform.isWindows) {
      final hasWinget = await _executor.isCommandAvailable('winget');
      if (!hasWinget) {
        return false;
      }
      return (await _executor.executeForResult(
        'winget install --id Python.Python.3.11 -e --silent',
      ))
          .isSuccess;
    }

    return false;
  }

  Future<bool> installFFmpeg() async {
    if (Platform.isAndroid) {
      return (await _executor.executeForResult('pkg install -y ffmpeg')).isSuccess;
    }

    if (Platform.isMacOS) {
      return (await _executor.executeForResult('brew install ffmpeg')).isSuccess;
    }

    return false;
  }

  Future<String?> _checkVersion(List<String> commands) async {
    for (final cmd in commands) {
      final available = await _executor.isCommandAvailable(cmd);
      if (!available) {
        continue;
      }

      final result = await _executor.executeForResult(
        '$cmd --version',
        timeout: const Duration(seconds: 10),
      );
      final full = '${result.stdout}\n${result.stderr}'.trim();
      if (full.isNotEmpty) {
        return full.split('\n').first;
      }
      return cmd;
    }

    return null;
  }
}
