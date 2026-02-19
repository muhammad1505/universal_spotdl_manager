import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../managers/queue_manager.dart';
import '../widgets/download_list.dart';
import '../widgets/environment_status_card.dart';
import '../widgets/glass_container.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _batchController = TextEditingController();
  int _priority = 1;

  @override
  void dispose() {
    _batchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final queueState = ref.watch(queueProvider);
    final queue = ref.read(queueProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Universal SpotDL Manager'),
      ),
      body: Stack(
        children: <Widget>[
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[Color(0xFF0D0E10), Color(0xFF050505)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: EnvironmentStatusCard(showActions: false),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: GlassContainer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Batch Link Paste',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _batchController,
                          maxLines: 4,
                          minLines: 2,
                          decoration: const InputDecoration(
                            hintText: 'Paste one Spotify URL per line',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: <Widget>[
                            DropdownButton<int>(
                              value: _priority,
                              items: const <DropdownMenuItem<int>>[
                                DropdownMenuItem(value: 1, child: Text('Priority 1')),
                                DropdownMenuItem(value: 2, child: Text('Priority 2')),
                                DropdownMenuItem(value: 3, child: Text('Priority 3')),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _priority = value;
                                  });
                                }
                              },
                            ),
                            const Spacer(),
                            ElevatedButton.icon(
                              onPressed: () async {
                                final lines = _batchController.text
                                    .split(RegExp(r'\s+'))
                                    .map((line) => line.trim())
                                    .where((line) => line.isNotEmpty)
                                    .toList(growable: false);

                                final inserted =
                                    await queue.addBatch(lines, priority: _priority);

                                if (!context.mounted) {
                                  return;
                                }

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('$inserted link(s) added to queue'),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.playlist_add),
                              label: const Text('Add Batch'),
                            ),
                          ],
                        ),
                        if ((queueState.message ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              queueState.message!,
                              style: const TextStyle(color: AppTheme.warningColor),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: <Widget>[
                      FilledButton.icon(
                        onPressed: queueState.enginePaused
                            ? () {
                                queue.resumeQueue();
                              }
                            : () {
                                queue.pauseQueue();
                              },
                        icon: Icon(
                          queueState.enginePaused ? Icons.play_arrow : Icons.pause,
                        ),
                        label: Text(queueState.enginePaused ? 'Resume Queue' : 'Pause Queue'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () {
                          queue.cancelAll();
                        },
                        icon: const Icon(Icons.cancel_schedule_send_outlined),
                        label: const Text('Cancel All'),
                      ),
                      const Spacer(),
                      Chip(
                        label: Text(
                          'Active ${queueState.activeTaskIds.length}/${queueState.maxConcurrent}',
                        ),
                      ),
                    ],
                  ),
                ),
                const Expanded(child: DownloadList()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
