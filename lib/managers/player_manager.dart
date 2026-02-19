import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/download_task.dart';
import '../services/audio_service.dart';
import '../services/database_service.dart';
import 'queue_manager.dart';

class PlayerState {
  const PlayerState({
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.playbackSpeed = 1.0,
    this.currentIndex,
    this.playlist = const <DownloadTask>[],
    this.currentTrack,
  });

  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final double playbackSpeed;
  final int? currentIndex;
  final List<DownloadTask> playlist;
  final DownloadTask? currentTrack;

  PlayerState copyWith({
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    double? playbackSpeed,
    int? currentIndex,
    List<DownloadTask>? playlist,
    DownloadTask? currentTrack,
  }) {
    return PlayerState(
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      currentIndex: currentIndex ?? this.currentIndex,
      playlist: playlist ?? this.playlist,
      currentTrack: currentTrack ?? this.currentTrack,
    );
  }
}

class PlayerManager extends Notifier<PlayerState> {
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  DateTime _lastPersist = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  PlayerState build() {
    final audio = ref.read(audioServiceProvider);

    _subscriptions.add(
      audio.player.playerStateStream.listen((playerState) {
        state = state.copyWith(isPlaying: playerState.playing);
      }),
    );

    _subscriptions.add(
      audio.player.positionStream.listen((position) {
        state = state.copyWith(position: position);
        _persistPositionWithDebounce();
      }),
    );

    _subscriptions.add(
      audio.player.durationStream.listen((duration) {
        state = state.copyWith(duration: duration ?? Duration.zero);
      }),
    );

    _subscriptions.add(
      audio.player.currentIndexStream.listen((index) {
        final current =
            index == null || index < 0 || index >= state.playlist.length
                ? null
                : state.playlist[index];

        state = state.copyWith(currentIndex: index, currentTrack: current);
      }),
    );

    _subscriptions.add(
      audio.player.speedStream.listen((speed) {
        state = state.copyWith(playbackSpeed: speed);
      }),
    );

    ref.listen(queueProvider, (_, next) {
      _syncPlaylist(next.tasks);
    });

    ref.onDispose(() {
      for (final subscription in _subscriptions) {
        subscription.cancel();
      }
      _subscriptions.clear();
    });

    return const PlayerState();
  }

  Future<void> playTrack(DownloadTask task) async {
    final playable = state.playlist;
    final targetIndex = playable.indexWhere((item) => item.id == task.id);

    if (targetIndex < 0) {
      await _syncPlaylist(ref.read(queueProvider).tasks, preferredTaskId: task.id);
      return;
    }

    final audio = ref.read(audioServiceProvider);
    await audio.loadPlaylist(playable, initialIndex: targetIndex);
    await audio.play();

    state = state.copyWith(
      currentIndex: targetIndex,
      currentTrack: playable[targetIndex],
    );
  }

  Future<void> pause() => ref.read(audioServiceProvider).pause();

  Future<void> resume() => ref.read(audioServiceProvider).play();

  Future<void> seek(Duration position) =>
      ref.read(audioServiceProvider).seek(position);

  Future<void> next() => ref.read(audioServiceProvider).next();

  Future<void> previous() => ref.read(audioServiceProvider).previous();

  Future<void> setPlaybackSpeed(double speed) async {
    final normalized = speed.clamp(0.5, 2.0);
    await ref.read(audioServiceProvider).setSpeed(normalized);
  }

  Future<void> _syncPlaylist(
    List<DownloadTask> tasks, {
    String? preferredTaskId,
  }) async {
    final playlist = tasks
        .where(
          (task) =>
              task.status == TaskStatus.completed &&
              (task.filePath ?? '').trim().isNotEmpty,
        )
        .toList(growable: false);

    if (playlist.isEmpty) {
      state = state.copyWith(playlist: <DownloadTask>[], currentTrack: null);
      return;
    }

    final audio = ref.read(audioServiceProvider);
    final currentTrack = state.currentTrack;

    final preferredIndex = preferredTaskId == null
        ? -1
        : playlist.indexWhere((task) => task.id == preferredTaskId);

    final currentIndex = currentTrack == null
        ? -1
        : playlist.indexWhere((task) => task.id == currentTrack.id);

    final initialIndex = preferredIndex >= 0
        ? preferredIndex
        : (currentIndex >= 0 ? currentIndex : 0);

    await audio.loadPlaylist(playlist, initialIndex: initialIndex);

    state = state.copyWith(
      playlist: playlist,
      currentIndex: initialIndex,
      currentTrack: playlist[initialIndex],
    );
  }

  Future<void> _persistPositionWithDebounce() async {
    final now = DateTime.now().toUtc();
    if (now.difference(_lastPersist).inSeconds < 5) {
      return;
    }

    _lastPersist = now;
    await ref.read(audioServiceProvider).persistCurrentPosition();

    final current = state.currentTrack;
    if (current != null && state.position.inSeconds >= 15) {
      await ref.read(databaseServiceProvider).recordPlayback(
            taskId: current.id,
            track: current.displayTitle,
            artist: current.artist ?? 'Unknown',
            playedSeconds: state.position.inSeconds,
          );
    }
  }
}

final playerProvider = NotifierProvider<PlayerManager, PlayerState>(
  PlayerManager.new,
);
