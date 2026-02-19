import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../managers/queue_manager.dart';
import '../services/file_service.dart';
import '../widgets/environment_status_card.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.enableRuntimeProviders = true});

  final bool enableRuntimeProviders;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _importPath = TextEditingController();

  @override
  void dispose() {
    _importPath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final queueState = widget.enableRuntimeProviders
        ? ref.watch(queueProvider)
        : const QueueState();
    final queue = widget.enableRuntimeProviders
        ? ref.read(queueProvider.notifier)
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          if (widget.enableRuntimeProviders) const EnvironmentStatusCard(),
          if (!widget.enableRuntimeProviders)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text('Environment check disabled for test mode'),
              ),
            ),
          const SizedBox(height: 16),
          const Text(
            'Queue Engine',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Max Concurrent: ${queueState.maxConcurrent}'),
                  Slider(
                    value: queueState.maxConcurrent.toDouble(),
                    min: 1,
                    max: 8,
                    divisions: 7,
                    onChanged: (value) {
                      queue?.setMaxConcurrent(value.toInt());
                    },
                  ),
                  Row(
                    children: <Widget>[
                      FilledButton.icon(
                        onPressed: () async {
                          if (queue == null) {
                            return;
                          }
                          final path = await queue.exportQueueJson();
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Queue exported: $path')),
                          );
                        },
                        icon: const Icon(Icons.upload_file_outlined),
                        label: const Text('Export Queue JSON'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final path = await ref
                              .read(fileServiceProvider)
                              .exportLogs();
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Logs exported: ${path.path}'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.bug_report_outlined),
                        label: const Text('Export Logs'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _importPath,
                    decoration: const InputDecoration(
                      hintText: '/path/to/queue.json',
                      labelText: 'Import Queue JSON Path',
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () async {
                      if (queue == null) {
                        return;
                      }
                      final path = _importPath.text.trim();
                      if (path.isEmpty) {
                        return;
                      }
                      final count = await queue.importQueueJson(path);
                      if (!context.mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Imported $count task(s)')),
                      );
                    },
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Import Queue'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
