import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../managers/player_manager.dart';
import '../managers/queue_manager.dart';
import '../models/download_task.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(queueProvider).tasks;
    final completed = tasks
        .where((task) => task.status == TaskStatus.completed)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: completed.isEmpty
          ? const Center(child: Text('Belum ada file yang selesai diunduh'))
          : ListView.builder(
              itemCount: completed.length,
              itemBuilder: (context, index) {
                final task = completed[index];
                return ListTile(
                  leading: const Icon(Icons.music_note_outlined),
                  title: Text(
                    task.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(task.artist ?? 'Unknown Artist'),
                  trailing: IconButton(
                    icon: const Icon(Icons.play_circle_outline),
                    onPressed: () {
                      ref.read(playerProvider.notifier).playTrack(task);
                    },
                  ),
                );
              },
            ),
    );
  }
}
