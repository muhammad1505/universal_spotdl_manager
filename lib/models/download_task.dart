import 'dart:convert';

import 'package:uuid/uuid.dart';

enum TaskStatus {
  waiting,
  downloading,
  paused,
  completed,
  failed,
  cancelled,
}

extension TaskStatusX on TaskStatus {
  bool get isTerminal {
    return this == TaskStatus.completed ||
        this == TaskStatus.failed ||
        this == TaskStatus.cancelled;
  }
}

class DownloadTask {
  DownloadTask({
    String? id,
    required this.url,
    this.priority = 1,
    this.status = TaskStatus.waiting,
    this.progress = 0,
    this.speed = '0',
    this.eta = '0',
    this.retries = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.orderIndex = 0,
    this.title,
    this.artist,
    this.filePath,
    this.sizeBytes = 0,
    this.lastError,
    this.isPlaylist = false,
    this.startedAt,
    this.completedAt,
    this.downloadDurationMs = 0,
    this.outputMessage,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now().toUtc(),
        updatedAt = updatedAt ?? DateTime.now().toUtc();

  final String id;
  final String url;
  final int priority;
  final TaskStatus status;
  final double progress;
  final String speed;
  final String eta;
  final int retries;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int orderIndex;
  final String? title;
  final String? artist;
  final String? filePath;
  final int sizeBytes;
  final String? lastError;
  final bool isPlaylist;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int downloadDurationMs;
  final String? outputMessage;

  DownloadTask copyWith({
    String? id,
    String? url,
    int? priority,
    TaskStatus? status,
    double? progress,
    String? speed,
    String? eta,
    int? retries,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? orderIndex,
    String? title,
    String? artist,
    String? filePath,
    int? sizeBytes,
    String? lastError,
    bool? isPlaylist,
    DateTime? startedAt,
    DateTime? completedAt,
    int? downloadDurationMs,
    String? outputMessage,
  }) {
    return DownloadTask(
      id: id ?? this.id,
      url: url ?? this.url,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      speed: speed ?? this.speed,
      eta: eta ?? this.eta,
      retries: retries ?? this.retries,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
      orderIndex: orderIndex ?? this.orderIndex,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      filePath: filePath ?? this.filePath,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      lastError: lastError ?? this.lastError,
      isPlaylist: isPlaylist ?? this.isPlaylist,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      downloadDurationMs: downloadDurationMs ?? this.downloadDurationMs,
      outputMessage: outputMessage ?? this.outputMessage,
    );
  }

  String get displayTitle {
    if (title != null && title!.trim().isNotEmpty) {
      return title!;
    }
    return url;
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'url': url,
      'priority': priority,
      'status': status.index,
      'progress': progress,
      'speed': speed,
      'eta': eta,
      'retries': retries,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'order_index': orderIndex,
      'title': title,
      'artist': artist,
      'file_path': filePath,
      'size_bytes': sizeBytes,
      'last_error': lastError,
      'is_playlist': isPlaylist ? 1 : 0,
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'download_duration_ms': downloadDurationMs,
      'output_message': outputMessage,
    };
  }

  String toJson() => jsonEncode(toMap());

  factory DownloadTask.fromMap(Map<String, dynamic> map) {
    return DownloadTask(
      id: map['id']?.toString(),
      url: map['url']?.toString() ?? '',
      priority: (map['priority'] as num?)?.toInt() ?? 1,
      status: TaskStatus.values[(map['status'] as num?)?.toInt() ?? 0],
      progress: (map['progress'] as num?)?.toDouble() ?? 0,
      speed: map['speed']?.toString() ?? '0',
      eta: map['eta']?.toString() ?? '0',
      retries: (map['retries'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now().toUtc(),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? '') ??
          DateTime.now().toUtc(),
      orderIndex: (map['order_index'] as num?)?.toInt() ?? 0,
      title: map['title']?.toString(),
      artist: map['artist']?.toString(),
      filePath: map['file_path']?.toString(),
      sizeBytes: (map['size_bytes'] as num?)?.toInt() ?? 0,
      lastError: map['last_error']?.toString(),
      isPlaylist: ((map['is_playlist'] as num?)?.toInt() ?? 0) == 1,
      startedAt: DateTime.tryParse(map['started_at']?.toString() ?? ''),
      completedAt: DateTime.tryParse(map['completed_at']?.toString() ?? ''),
      downloadDurationMs: (map['download_duration_ms'] as num?)?.toInt() ?? 0,
      outputMessage: map['output_message']?.toString(),
    );
  }

  factory DownloadTask.fromJson(String json) {
    return DownloadTask.fromMap(jsonDecode(json) as Map<String, dynamic>);
  }
}
