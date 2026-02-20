import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/analytics_snapshot.dart';
import '../models/download_task.dart';

class DatabaseService {
  static const String _dbName = 'spotdl_manager.db';
  static const int _dbVersion = 2;

  Database? _db;

  Future<Database> get database async {
    if (_db != null) {
      return _db!;
    }

    final dir = await getDatabasesPath();
    final path = p.join(dir, _dbName);

    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    return _db!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        url TEXT NOT NULL,
        priority INTEGER NOT NULL,
        status INTEGER NOT NULL,
        progress REAL NOT NULL,
        speed TEXT NOT NULL,
        eta TEXT NOT NULL,
        retries INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        order_index INTEGER NOT NULL,
        title TEXT,
        artist TEXT,
        file_path TEXT,
        size_bytes INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        is_playlist INTEGER NOT NULL DEFAULT 0,
        started_at TEXT,
        completed_at TEXT,
        download_duration_ms INTEGER NOT NULL DEFAULT 0,
        output_message TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE analytics_daily (
        day TEXT PRIMARY KEY,
        success_count INTEGER NOT NULL DEFAULT 0,
        failed_count INTEGER NOT NULL DEFAULT 0,
        total_bytes INTEGER NOT NULL DEFAULT 0,
        total_download_ms INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE playback_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_id TEXT,
        track_name TEXT,
        artist_name TEXT,
        played_seconds INTEGER NOT NULL,
        played_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _safeAddColumn(db, 'tasks', 'updated_at TEXT');
      await _safeAddColumn(db, 'tasks', 'order_index INTEGER NOT NULL DEFAULT 0');
      await _safeAddColumn(db, 'tasks', 'title TEXT');
      await _safeAddColumn(db, 'tasks', 'artist TEXT');
      await _safeAddColumn(db, 'tasks', 'file_path TEXT');
      await _safeAddColumn(db, 'tasks', 'size_bytes INTEGER NOT NULL DEFAULT 0');
      await _safeAddColumn(db, 'tasks', 'last_error TEXT');
      await _safeAddColumn(db, 'tasks', 'is_playlist INTEGER NOT NULL DEFAULT 0');
      await _safeAddColumn(db, 'tasks', 'started_at TEXT');
      await _safeAddColumn(db, 'tasks', 'completed_at TEXT');
      await _safeAddColumn(
        db,
        'tasks',
        'download_duration_ms INTEGER NOT NULL DEFAULT 0',
      );
      await _safeAddColumn(db, 'tasks', 'output_message TEXT');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS analytics_daily (
          day TEXT PRIMARY KEY,
          success_count INTEGER NOT NULL DEFAULT 0,
          failed_count INTEGER NOT NULL DEFAULT 0,
          total_bytes INTEGER NOT NULL DEFAULT 0,
          total_download_ms INTEGER NOT NULL DEFAULT 0
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS playback_events (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          task_id TEXT,
          track_name TEXT,
          artist_name TEXT,
          played_seconds INTEGER NOT NULL,
          played_at TEXT NOT NULL
        )
      ''');
    }
  }

  Future<void> _safeAddColumn(Database db, String table, String ddl) async {
    try {
      await db.execute('ALTER TABLE $table ADD COLUMN $ddl');
    } catch (_) {
      // Ignore duplicate column errors to keep migration idempotent.
    }
  }

  Future<void> upsertTask(DownloadTask task) async {
    final db = await database;
    await db.insert(
      'tasks',
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<DownloadTask>> getTasks() async {
    final db = await database;
    final rows = await db.query(
      'tasks',
      orderBy: 'priority ASC, order_index ASC, created_at ASC',
    );

    return rows.map(DownloadTask.fromMap).toList();
  }

  Future<void> deleteTask(String id) async {
    final db = await database;
    await db.delete('tasks', where: 'id = ?', whereArgs: <Object>[id]);
  }

  Future<void> clearTasks() async {
    final db = await database;
    await db.delete('tasks');
  }

  Future<void> markDownloadingAsWaiting() async {
    final db = await database;
    await db.update(
      'tasks',
      <String, Object?>{
        'status': TaskStatus.paused.index,
        'output_message': 'Paused — recovered after app restart',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'status = ?',
      whereArgs: <Object>[TaskStatus.downloading.index],
    );
  }

  Future<void> incrementFailure(DateTime day) async {
    final db = await database;
    final key = _dayKey(day);
    await db.execute('''
      INSERT INTO analytics_daily (day, failed_count)
      VALUES (?, 1)
      ON CONFLICT(day) DO UPDATE SET
      failed_count = failed_count + 1
    ''', <Object>[key]);
  }

  Future<void> incrementSuccess(
    DateTime day, {
    required int totalBytes,
    required int downloadMs,
  }) async {
    final db = await database;
    final key = _dayKey(day);
    await db.execute('''
      INSERT INTO analytics_daily (day, success_count, total_bytes, total_download_ms)
      VALUES (?, 1, ?, ?)
      ON CONFLICT(day) DO UPDATE SET
      success_count = success_count + 1,
      total_bytes = total_bytes + excluded.total_bytes,
      total_download_ms = total_download_ms + excluded.total_download_ms
    ''', <Object>[key, totalBytes, downloadMs]);
  }

  Future<void> recordPlayback({
    required String taskId,
    required String track,
    required String artist,
    required int playedSeconds,
  }) async {
    final db = await database;
    await db.insert('playback_events', <String, Object?>{
      'task_id': taskId,
      'track_name': track,
      'artist_name': artist,
      'played_seconds': playedSeconds,
      'played_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<AnalyticsSnapshot> loadAnalytics({int days = 30}) async {
    final db = await database;

    final totalDownloadsRows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM tasks WHERE status = ?',
      <Object>[TaskStatus.completed.index],
    );
    final totalFailedRows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM tasks WHERE status = ?',
      <Object>[TaskStatus.failed.index],
    );
    final downloadsDayRows = await db.rawQuery(
      '''
      SELECT COUNT(*) AS count FROM tasks
      WHERE status = ? AND completed_at >= datetime('now', '-1 day')
      ''',
      <Object>[TaskStatus.completed.index],
    );
    final downloadsWeekRows = await db.rawQuery(
      '''
      SELECT COUNT(*) AS count FROM tasks
      WHERE status = ? AND completed_at >= datetime('now', '-7 day')
      ''',
      <Object>[TaskStatus.completed.index],
    );
    final downloadsMonthRows = await db.rawQuery(
      '''
      SELECT COUNT(*) AS count FROM tasks
      WHERE status = ? AND completed_at >= datetime('now', '-30 day')
      ''',
      <Object>[TaskStatus.completed.index],
    );
    final totalBytesRows = await db.rawQuery(
      'SELECT COALESCE(SUM(size_bytes), 0) AS total FROM tasks WHERE status = ?',
      <Object>[TaskStatus.completed.index],
    );
    final avgDownloadRows = await db.rawQuery(
      '''
      SELECT COALESCE(AVG(download_duration_ms), 0) AS avg_ms
      FROM tasks WHERE status = ? AND download_duration_ms > 0
      ''',
      <Object>[TaskStatus.completed.index],
    );
    final playbackRows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM playback_events',
    );

    final topArtistsRows = await db.rawQuery('''
      SELECT COALESCE(artist, 'Unknown') AS artist, COUNT(*) AS count
      FROM tasks
      WHERE status = ?
      GROUP BY COALESCE(artist, 'Unknown')
      ORDER BY count DESC
      LIMIT 10
    ''', <Object>[TaskStatus.completed.index]);

    final topTracksRows = await db.rawQuery('''
      SELECT COALESCE(title, url) AS track, COUNT(*) AS count
      FROM tasks
      WHERE status = ?
      GROUP BY COALESCE(title, url)
      ORDER BY count DESC
      LIMIT 10
    ''', <Object>[TaskStatus.completed.index]);

    final trendRows = await db.rawQuery('''
      SELECT day, success_count FROM analytics_daily
      ORDER BY day DESC
      LIMIT ?
    ''', <Object>[days]);

    final totalDownloads = (totalDownloadsRows.first['count'] as num?)?.toInt() ?? 0;
    final totalFailed = (totalFailedRows.first['count'] as num?)?.toInt() ?? 0;

    final ratio = (totalDownloads + totalFailed) == 0
        ? 0.0
        : totalFailed / (totalDownloads + totalFailed);

    return AnalyticsSnapshot(
      totalDownloads: totalDownloads,
      downloadsDay: (downloadsDayRows.first['count'] as num?)?.toInt() ?? 0,
      downloadsWeek: (downloadsWeekRows.first['count'] as num?)?.toInt() ?? 0,
      downloadsMonth: (downloadsMonthRows.first['count'] as num?)?.toInt() ?? 0,
      totalBytes: (totalBytesRows.first['total'] as num?)?.toInt() ?? 0,
      failureRatio: ratio,
      averageDownloadMs:
          (avgDownloadRows.first['avg_ms'] as num?)?.toDouble() ?? 0,
      playbackCount: (playbackRows.first['count'] as num?)?.toInt() ?? 0,
      topArtists: topArtistsRows
          .map(
            (row) => RankedMetric(
              name: row['artist'].toString(),
              value: (row['count'] as num).toInt(),
            ),
          )
          .toList(),
      topTracks: topTracksRows
          .map(
            (row) => RankedMetric(
              name: row['track'].toString(),
              value: (row['count'] as num).toInt(),
            ),
          )
          .toList(),
      dailyTrend: trendRows.reversed
          .map(
            (row) => MetricPoint(
              label: row['day'].toString().substring(5),
              value: (row['success_count'] as num).toDouble(),
            ),
          )
          .toList(),
    );
  }

  Future<String> exportAnalyticsCsv({int days = 30}) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT day, success_count, failed_count, total_bytes, total_download_ms
      FROM analytics_daily
      ORDER BY day DESC
      LIMIT ?
    ''', <Object>[days]);

    final buffer = StringBuffer();
    buffer.writeln(
      'day,success_count,failed_count,total_bytes,total_download_ms',
    );

    for (final row in rows.reversed) {
      buffer.writeln(
        '${row['day']},${row['success_count']},${row['failed_count']},${row['total_bytes']},${row['total_download_ms']}',
      );
    }

    return buffer.toString();
  }

  String _dayKey(DateTime dateTime) {
    final utc = dateTime.toUtc();
    final mm = utc.month.toString().padLeft(2, '0');
    final dd = utc.day.toString().padLeft(2, '0');
    return '${utc.year}-$mm-$dd';
  }
}

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});
