import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AndroidSystemService {
  static const MethodChannel _channel = MethodChannel('usm/android_system');
  static const EventChannel _repairLogsChannel =
      EventChannel('usm/termux_repair_logs');
  static const List<String> termuxPackageCandidates = <String>[
    'com.termux',
    'com.termux.nightly',
  ];

  Future<bool> isPackageInstalled(String packageName) async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod<bool>(
        'isPackageInstalled',
        <String, dynamic>{'packageName': packageName},
      );
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> openPackage(String packageName) async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod<bool>(
        'openPackage',
        <String, dynamic>{'packageName': packageName},
      );
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> repairTermuxEnvironment() async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod<bool>('repairTermuxEnvironment');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<String?> findInstalledPackage(List<String> packageNames) async {
    for (final packageName in packageNames) {
      final installed = await isPackageInstalled(packageName);
      if (installed) {
        return packageName;
      }
    }
    return null;
  }

  Stream<String> repairLogs() {
    if (!Platform.isAndroid) {
      return const Stream<String>.empty();
    }
    return _repairLogsChannel
        .receiveBroadcastStream()
        .map((event) => event?.toString() ?? '')
        .where((line) => line.isNotEmpty);
  }
}

final androidSystemServiceProvider = Provider<AndroidSystemService>((ref) {
  return AndroidSystemService();
});
