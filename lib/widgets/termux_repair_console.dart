import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../managers/environment_manager.dart';
import '../services/android_system_service.dart';

class TermuxRepairConsoleSheet extends ConsumerStatefulWidget {
  const TermuxRepairConsoleSheet({super.key});

  @override
  ConsumerState<TermuxRepairConsoleSheet> createState() =>
      _TermuxRepairConsoleSheetState();
}

class _TermuxRepairConsoleSheetState
    extends ConsumerState<TermuxRepairConsoleSheet> {
  final List<String> _logs = <String>[];
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<String>? _subscription;
  bool _running = true;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    _subscription = ref.read(androidSystemServiceProvider).repairLogs().listen(
      (line) {
        if (line.startsWith('__DONE__:')) {
          final ok = line.contains('success');
          setState(() {
            _running = false;
            _success = ok;
          });
          ref.read(environmentProvider.notifier).refresh();
          return;
        }

        setState(() {
          _logs.add(line);
        });
        _scrollToBottom();
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final started =
          await ref.read(androidSystemServiceProvider).repairTermuxEnvironment();
      if (!mounted) {
        return;
      }
      if (!started) {
        setState(() {
          _running = false;
          _logs.add('[error] Repair tidak bisa dimulai (sedang berjalan atau gagal trigger)');
        });
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _copyLogs() {
    if (_logs.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _logs.join('\n')));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Log disalin ke clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Color(0xFF0F1012),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: <Widget>[
            const SizedBox(height: 10),
            const Text(
              'Termux Repair Console',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              _running
                  ? 'Menjalankan setup environment...'
                  : (_success ? 'Selesai' : 'Gagal'),
              style: TextStyle(
                color: _running
                    ? Colors.orangeAccent
                    : (_success ? AppTheme.spotifyGreen : Colors.redAccent),
              ),
            ),
            const Divider(height: 20),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _logs.isEmpty
                    ? const Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          'Waiting for logs...',
                          style: TextStyle(fontFamily: 'monospace', color: Colors.white70),
                        ),
                      )
                    : Scrollbar(
                        controller: _scrollController,
                        thumbVisibility: true,
                        thickness: 4,
                        radius: const Radius.circular(2),
                        child: ListView.builder(
                          controller: _scrollController,
                          itemCount: _logs.length,
                          padding: const EdgeInsets.only(right: 8),
                          itemBuilder: (context, index) {
                            return Text(
                              _logs[index],
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _logs.isEmpty ? null : _copyLogs,
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _running
                          ? null
                          : () {
                              Navigator.of(context).pop();
                            },
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
