import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../managers/player_manager.dart';
import '../screens/player_screen.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final track = player.currentTrack;

    if (track == null) {
      return const SizedBox.shrink();
    }

    final progress = player.duration.inMilliseconds == 0
        ? 0.0
        : (player.position.inMilliseconds / player.duration.inMilliseconds)
            .clamp(0.0, 1.0);

    return Material(
      color: Colors.black.withValues(alpha: 0.85),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const PlayerScreen()),
          );
        },
        child: SizedBox(
          height: 72,
          child: Column(
            children: <Widget>[
              LinearProgressIndicator(value: progress, minHeight: 2),
              Expanded(
                child: Row(
                  children: <Widget>[
                    const SizedBox(width: 12),
                    const Icon(Icons.music_note),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            track.displayTitle,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          Text(
                            track.artist ?? 'Unknown Artist',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: const TextStyle(fontSize: 12, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(player.isPlaying ? Icons.pause : Icons.play_arrow),
                      onPressed: () {
                        if (player.isPlaying) {
                          ref.read(playerProvider.notifier).pause();
                        } else {
                          ref.read(playerProvider.notifier).resume();
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
