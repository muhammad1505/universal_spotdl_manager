import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../managers/queue_manager.dart';
import '../models/download_task.dart';
import 'glass_container.dart';

class DownloadList extends ConsumerWidget {
  const DownloadList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueState = ref.watch(queueProvider);
    final tasks = queueState.tasks;

    if (tasks.isEmpty) {
      return const Center(child: Text('Queue is empty'));
    }

    return ReorderableListView.builder(
      itemCount: tasks.length,
      buildDefaultDragHandles: false,
      onReorder: (oldIndex, newIndex) {
        ref.read(queueProvider.notifier).reorder(oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        final task = tasks[index];
        return Padding(
          key: ValueKey(task.id),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: _TaskCard(task: task, index: index),
        );
      },
    );
  }
}

class _TaskCard extends ConsumerWidget {
  const _TaskCard({required this.task, required this.index});

  final DownloadTask task;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.read(queueProvider.notifier);
    final color = _statusColor(task.status);

    return GlassContainer(
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              ReorderableDragStartListener(
                index: index,
                child: Icon(Icons.drag_indicator, color: Colors.white.withValues(alpha: 0.5)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      task.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Priority ${task.priority} • ${task.status.name.toUpperCase()}',
                      style: TextStyle(color: color, fontSize: 12),
                    ),
                  ],
                ),
              ),
              _actionButtons(queue),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: task.progress <= 0 ? null : task.progress / 100,
              minHeight: 6,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('${task.progress.toStringAsFixed(1)}% • ${task.speed}'),
              Text('ETA ${task.eta}'),
            ],
          ),
          if (task.outputMessage != null && task.outputMessage!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                task.outputMessage!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _actionButtons(QueueManager queue) {
    if (task.status == TaskStatus.downloading) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.pause_circle_outline),
            onPressed: () {
              queue.pauseTask(task.id);
            },
          ),
          IconButton(
            icon: const Icon(Icons.cancel_outlined),
            onPressed: () {
              queue.cancelTask(task.id);
            },
          ),
        ],
      );
    }

    if (task.status == TaskStatus.paused) {
      return IconButton(
        icon: const Icon(Icons.play_circle_outline),
        onPressed: () {
          queue.resumeTask(task.id);
        },
      );
    }

    if (task.status == TaskStatus.failed) {
      return IconButton(
        icon: const Icon(Icons.refresh_outlined),
        onPressed: () {
          queue.resumeTask(task.id);
        },
      );
    }

    if (task.status.isTerminal) {
      return IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: () {
          queue.removeTask(task.id);
        },
      );
    }

    return IconButton(
      icon: const Icon(Icons.cancel_outlined),
      onPressed: () {
        queue.cancelTask(task.id);
      },
    );
  }

  Color _statusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.completed:
        return AppTheme.spotifyGreen;
      case TaskStatus.failed:
        return Colors.redAccent;
      case TaskStatus.downloading:
        return Colors.lightBlueAccent;
      case TaskStatus.waiting:
        return Colors.amberAccent;
      case TaskStatus.paused:
        return Colors.deepOrangeAccent;
      case TaskStatus.cancelled:
        return Colors.grey;
    }
  }
}
