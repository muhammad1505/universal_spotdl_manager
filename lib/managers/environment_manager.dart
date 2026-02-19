import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/environment_health.dart';
import '../providers/core_providers.dart';
import '../services/android_system_service.dart';
import '../services/file_service.dart';

class EnvironmentManager extends AsyncNotifier<EnvironmentHealthReport> {
  @override
  FutureOr<EnvironmentHealthReport> build() async {
    return _checkEnvironment();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_checkEnvironment);
  }

  Future<EnvironmentHealthReport> repairEnvironment() async {
    final executor = ref.read(commandExecutorProvider);

    if (Platform.isAndroid) {
      final androidSystem = ref.read(androidSystemServiceProvider);
      final packageName = await androidSystem.findInstalledPackage(
        AndroidSystemService.termuxPackageCandidates,
      );
      final hasTermux = packageName != null;

      if (hasTermux) {
        final started = await androidSystem.repairTermuxEnvironment();
        await ref.read(fileServiceProvider).appendJsonLog('app.jsonl', <String, dynamic>{
          'level': started ? 'info' : 'error',
          'event': 'android_termux_repair_started',
          'started': started,
          'termux_package': packageName,
        });
      }
    } else if (Platform.isWindows) {
      final hasWinget = await executor.isCommandAvailable('winget');
      final hasPython = await _isAvailable('python');
      if (!hasPython && hasWinget) {
        await executor.executeForResult(
          'winget install --id Python.Python.3.11 -e --silent',
          timeout: const Duration(minutes: 15),
        );
      }
      await executor.executeForResult('python -m pip install -U spotdl');
    } else if (Platform.isLinux) {
      await executor.executeForResult('python3 -m pip install -U spotdl');
    } else if (Platform.isMacOS) {
      await executor.executeForResult('brew install python');
      await executor.executeForResult('python3 -m pip install -U spotdl');
    }

    await ref
        .read(fileServiceProvider)
        .appendJsonLog('app.jsonl', <String, dynamic>{
      'level': 'info',
      'event': 'environment_repair_executed',
      'platform': _platformLabel(),
    });

    final report = await _checkEnvironment();
    state = AsyncValue.data(report);
    return report;
  }

  Future<void> runSetupScript() async {
    final executor = ref.read(commandExecutorProvider);
    if (Platform.isAndroid) {
      final androidSystem = ref.read(androidSystemServiceProvider);
      final packageName = await androidSystem.findInstalledPackage(
        AndroidSystemService.termuxPackageCandidates,
      );
      final hasTermux = packageName != null;
      if (hasTermux) {
        await androidSystem.repairTermuxEnvironment();
      }
    } else {
      await executor.executeForResult(
        'python3 -m pip install -U spotdl',
        timeout: const Duration(minutes: 20),
      );
    }
    await refresh();
  }

  Future<EnvironmentHealthReport> _checkEnvironment() async {
    final components = <EnvironmentComponent>[];
    var androidTermuxDetected = false;
    var androidRuntimeUnverified = false;

    if (Platform.isAndroid) {
      final androidSystem = ref.read(androidSystemServiceProvider);
      final installedTermuxPackage = await androidSystem.findInstalledPackage(
        AndroidSystemService.termuxPackageCandidates,
      );
      // Do not probe `/data/data/com.termux/...` because Android app sandbox
      // blocks cross-app directory access and throws PathAccessException.
      final hasTermux = installedTermuxPackage != null ||
          await _isAvailable('termux-info') ||
          await _isAvailable('pkg') ||
          await _isAvailable('termux-change-repo');
      androidTermuxDetected = hasTermux;
      components.add(
        EnvironmentComponent(
          name: 'Termux',
          installed: hasTermux,
          hint: hasTermux
              ? 'Detected package: ${installedTermuxPackage ?? 'shell bridge'}'
              : 'Install Termux (com.termux/com.termux.nightly) and allow app storage access.',
        ),
      );

      final python = await _checkVersioned(
        'Python',
        <String>['python', 'python3'],
        required: false,
        hint:
            'Check in Termux: python --version (sandbox app cannot always verify).',
      );
      final spotdl = await _checkVersioned(
        'spotdl',
        <String>['spotdl'],
        required: false,
        hint:
            'Check in Termux: spotdl --version (sandbox app cannot always verify).',
      );
      final ffmpeg = await _checkVersioned(
        'ffmpeg',
        <String>['ffmpeg'],
        required: false,
        hint:
            'Check in Termux: ffmpeg -version (sandbox app cannot always verify).',
      );

      components.addAll(<EnvironmentComponent>[python, spotdl, ffmpeg]);
      androidRuntimeUnverified = hasTermux &&
          (!python.installed || !spotdl.installed || !ffmpeg.installed);
    } else if (Platform.isWindows) {
      components.add(await _checkVersioned('Python', <String>['python', 'py']));
      components.add(await _checkVersioned('pip', <String>['pip', 'pip3']));
      components.add(await _checkVersioned('spotdl', <String>['spotdl']));
    } else if (Platform.isLinux) {
      components.add(await _checkVersioned('Python', <String>['python3', 'python']));
      components.add(await _checkVersioned('spotdl', <String>['spotdl']));
      components.add(
        await _checkVersioned(
          'apt',
          <String>['apt'],
          required: false,
          hint: 'Install dependencies: sudo apt install python3 ffmpeg',
        ),
      );
    } else if (Platform.isMacOS) {
      components.add(await _checkVersioned('Homebrew', <String>['brew']));
      components.add(await _checkVersioned('Python', <String>['python3', 'python']));
      components.add(await _checkVersioned('spotdl', <String>['spotdl']));
    }

    final missingRequired =
        components.where((component) => component.required && !component.installed);

    var level = missingRequired.isEmpty
        ? HealthLevel.healthy
        : (missingRequired.length >= 2 ? HealthLevel.error : HealthLevel.warning);

    var message = missingRequired.isEmpty
        ? 'Environment HEALTHY'
        : 'Missing: ${missingRequired.map((it) => it.name).join(', ')}';

    if (Platform.isAndroid && androidTermuxDetected && androidRuntimeUnverified) {
      level = HealthLevel.warning;
      message =
          'Termux terdeteksi. Jalankan di Termux: pkg update && pkg install -y python ffmpeg && pip install -U spotdl';
    }

    return EnvironmentHealthReport(
      platform: _platformLabel(),
      level: level,
      components: components,
      message: message,
      checkedAt: DateTime.now().toUtc(),
    );
  }

  Future<EnvironmentComponent> _checkVersioned(
    String name,
    List<String> candidates, {
    bool required = true,
    String? hint,
  }) async {
    final executor = ref.read(commandExecutorProvider);

    for (final candidate in candidates) {
      final installed = await executor.isCommandAvailable(candidate);
      if (!installed) {
        continue;
      }

      final result = await executor.executeForResult(
        '$candidate --version',
        timeout: const Duration(seconds: 15),
      );

      final lines = '${result.stdout}\n${result.stderr}'
          .trim()
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .toList(growable: false);
      final versionRaw = lines.isEmpty ? null : lines.first;

      return EnvironmentComponent(
        name: name,
        installed: true,
        version: versionRaw,
        required: required,
      );
    }

    return EnvironmentComponent(
      name: name,
      installed: false,
      required: required,
      hint: hint,
    );
  }

  Future<bool> _isAvailable(String command) async {
    return ref.read(commandExecutorProvider).isCommandAvailable(command);
  }

  String _platformLabel() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    if (Platform.isMacOS) return 'macos';
    return 'unknown';
  }
}

final environmentProvider =
    AsyncNotifierProvider<EnvironmentManager, EnvironmentHealthReport>(
  EnvironmentManager.new,
);
