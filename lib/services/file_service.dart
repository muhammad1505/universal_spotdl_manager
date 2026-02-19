import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/constants.dart';
import '../models/download_task.dart';

class FileService {
  Future<Directory> getAppDirectory() async {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> getLogDirectory() async {
    final appDir = await getAppDirectory();
    final logDir = Directory(p.join(appDir.path, 'logs'));
    await logDir.create(recursive: true);
    return logDir;
  }

  Future<Directory> getExportDirectory() async {
    final downloadsDir = await getDownloadsDirectory();
    if (downloadsDir != null) {
      await downloadsDir.create(recursive: true);
      return downloadsDir;
    }

    final appDir = await getAppDirectory();
    final exportDir = Directory(p.join(appDir.path, 'exports'));
    await exportDir.create(recursive: true);
    return exportDir;
  }

  Future<Directory> getMediaDirectory() async {
    final downloadsDir = await getDownloadsDirectory();
    if (downloadsDir != null) {
      return downloadsDir;
    }
    return getAppDirectory();
  }

  Future<File> appendJsonLog(String fileName, Map<String, dynamic> payload) async {
    final logDir = await getLogDirectory();
    final file = File(p.join(logDir.path, fileName));
    final entry = <String, dynamic>{
      'ts': DateTime.now().toUtc().toIso8601String(),
      ...payload,
    };
    await file.writeAsString('${jsonEncode(entry)}\n', mode: FileMode.append);
    return file;
  }

  Future<File> exportQueue(List<DownloadTask> tasks) async {
    final exportDir = await getExportDirectory();
    final fileName =
        'queue_${DateTime.now().toUtc().millisecondsSinceEpoch}.json';
    final file = File(p.join(exportDir.path, fileName));
    final json = tasks.map((task) => task.toMap()).toList(growable: false);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(json));
    return file;
  }

  Future<List<DownloadTask>> importQueue(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return <DownloadTask>[];
    }

    final raw = await file.readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return <DownloadTask>[];
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(DownloadTask.fromMap)
        .toList();
  }

  Future<File> exportAnalyticsCsv(String csvContent) async {
    final exportDir = await getExportDirectory();
    final file = File(
      p.join(
        exportDir.path,
        'analytics_${DateTime.now().toUtc().millisecondsSinceEpoch}.csv',
      ),
    );
    await file.writeAsString(csvContent);
    return file;
  }

  Future<File> exportLogs() async {
    final logDir = await getLogDirectory();
    final exportDir = await getExportDirectory();
    final output = File(
      p.join(
        exportDir.path,
        'logs_${DateTime.now().toUtc().millisecondsSinceEpoch}.json',
      ),
    );

    final queueLog = File(p.join(logDir.path, AppConstants.queueLogFile));
    final appLog = File(p.join(logDir.path, AppConstants.appLogFile));

    final outputJson = <String, dynamic>{
      'generated_at': DateTime.now().toUtc().toIso8601String(),
      'queue_log': await _readLines(queueLog),
      'app_log': await _readLines(appLog),
    };

    await output.writeAsString(const JsonEncoder.withIndent('  ').convert(outputJson));
    return output;
  }

  Future<List<String>> _readLines(File file) async {
    if (!await file.exists()) {
      return <String>[];
    }
    return file.readAsLines();
  }
}

final fileServiceProvider = Provider<FileService>((ref) {
  return FileService();
});
