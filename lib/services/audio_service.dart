import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/download_task.dart';

class AudioService {
  AudioService() : _player = AudioPlayer();

  final AudioPlayer _player;
  List<DownloadTask> _playlist = <DownloadTask>[];

  AudioPlayer get player => _player;
  List<DownloadTask> get playlist => List<DownloadTask>.unmodifiable(_playlist);

  Future<void> initialize() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  }

  Future<void> loadPlaylist(
    List<DownloadTask> tasks, {
    int initialIndex = 0,
  }) async {
    final playable = tasks
        .where((task) => (task.filePath ?? '').trim().isNotEmpty)
        .toList(growable: false);

    _playlist = playable;

    if (playable.isEmpty) {
      await _player.stop();
      return;
    }

    final sources = playable
        .map(
          (task) => AudioSource.uri(
            Uri.file(task.filePath!),
            tag: task.id,
          ),
        )
        .toList(growable: false);

    await _player.setAudioSources(
      sources,
      initialIndex: initialIndex.clamp(0, playable.length - 1),
    );

    final restored = await _restorePosition(playable[initialIndex.clamp(0, playable.length - 1)].id);
    if (restored > Duration.zero) {
      await _player.seek(restored);
    }
  }

  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();
  Future<void> stop() => _player.stop();
  Future<void> seek(Duration position) => _player.seek(position);
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);
  Future<void> next() => _player.seekToNext();
  Future<void> previous() => _player.seekToPrevious();

  Future<void> playFile(
    String filePath, {
    String? taskId,
  }) async {
    await _player.setFilePath(filePath);

    if (taskId != null) {
      final position = await _restorePosition(taskId);
      if (position > Duration.zero) {
        await _player.seek(position);
      }
    }

    await _player.play();
  }

  Future<void> persistCurrentPosition() async {
    final index = _player.currentIndex;
    if (index == null || index < 0 || index >= _playlist.length) {
      return;
    }

    final task = _playlist[index];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('pos_${task.id}', _player.position.inMilliseconds);
  }

  Future<Duration> _restorePosition(String taskId) async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt('pos_$taskId') ?? 0;
    return Duration(milliseconds: ms);
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}

final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  unawaited(service.initialize());
  ref.onDispose(() {
    unawaited(service.dispose());
  });
  return service;
});
