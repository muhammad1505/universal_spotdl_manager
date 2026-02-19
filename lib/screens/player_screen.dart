import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../managers/player_manager.dart';

class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final notifier = ref.read(playerProvider.notifier);
    final track = player.currentTrack;

    return Scaffold(
      appBar: AppBar(title: const Text('Now Playing')),
      body: track == null
          ? const Center(child: Text('Tidak ada track yang diputar'))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: <Widget>[
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: Colors.white12,
                        ),
                        child: const Icon(Icons.album_outlined, size: 120),
                      ),
                    ),
                  ),
                  Text(
                    track.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(track.artist ?? 'Unknown Artist'),
                  const SizedBox(height: 16),
                  Slider(
                    value: player.position.inMilliseconds
                        .toDouble()
                        .clamp(0, player.duration.inMilliseconds.toDouble().clamp(1, double.infinity)),
                    max: player.duration.inMilliseconds.toDouble().clamp(1, double.infinity),
                    onChanged: (value) {
                      notifier.seek(Duration(milliseconds: value.toInt()));
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(_fmt(player.position)),
                      Text(_fmt(player.duration)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      IconButton(
                        onPressed: () {
                          notifier.previous();
                        },
                        icon: const Icon(Icons.skip_previous, size: 34),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () {
                          if (player.isPlaying) {
                            notifier.pause();
                          } else {
                            notifier.resume();
                          }
                        },
                        child: Icon(player.isPlaying ? Icons.pause : Icons.play_arrow),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          notifier.next();
                        },
                        icon: const Icon(Icons.skip_next, size: 34),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      const Text('Speed'),
                      Expanded(
                        child: Slider(
                          value: player.playbackSpeed,
                          min: 0.5,
                          max: 2.0,
                          divisions: 6,
                          label: '${player.playbackSpeed.toStringAsFixed(1)}x',
                          onChanged: (value) {
                            notifier.setPlaybackSpeed(value);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  String _fmt(Duration duration) {
    final mm = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hh = duration.inHours;
    if (hh > 0) {
      return '$hh:$mm:$ss';
    }
    return '$mm:$ss';
  }
}
