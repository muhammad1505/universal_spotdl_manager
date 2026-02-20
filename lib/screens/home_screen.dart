import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../managers/queue_manager.dart';
import '../services/android_system_service.dart';
import '../widgets/download_list.dart';
import '../widgets/glass_container.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _batchController = TextEditingController();
  final TextEditingController _consoleController = TextEditingController();
  final ScrollController _consoleScrollController = ScrollController();
  final FocusNode _consoleFocusNode = FocusNode();
  int _priority = 1;
  bool _consoleExpanded = false;

  // Console state
  final List<String> _consoleOutput = <String>[];
  bool _consoleRunning = false;
  StreamSubscription<String>? _repairSubscription;
  StreamSubscription<String>? _downloadLogSubscription;

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Subscribe to download logs after first frame (when ref is available)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _downloadLogSubscription = ref
          .read(queueProvider.notifier)
          .downloadLogStream
          .listen((line) {
        // Auto-expand console when download logs arrive
        if (!_consoleExpanded) {
          setState(() {
            _consoleExpanded = true;
          });
        }
        _appendConsole(line);
      });
    });
  }

  @override
  void dispose() {
    _batchController.dispose();
    _consoleController.dispose();
    _consoleScrollController.dispose();
    _consoleFocusNode.dispose();
    _pulseController.dispose();
    _repairSubscription?.cancel();
    _downloadLogSubscription?.cancel();
    super.dispose();
  }

  void _scrollConsoleToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_consoleScrollController.hasClients) {
        _consoleScrollController.animateTo(
          _consoleScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _appendConsole(String line) {
    setState(() {
      _consoleOutput.add(line);
    });
    _scrollConsoleToBottom();
  }

  void _runRepair() {
    if (_consoleRunning) return;

    setState(() {
      _consoleOutput.clear();
      _consoleRunning = true;
      _consoleExpanded = true;
    });
    _pulseController.repeat(reverse: true);

    final service = ref.read(androidSystemServiceProvider);

    _repairSubscription?.cancel();
    _repairSubscription = service.repairLogs().listen((line) {
      if (line.startsWith('__DONE__:')) {
        final ok = line.contains('success');
        _appendConsole(ok
            ? '\n✓ Setup selesai dengan sukses!'
            : '\n✗ Setup gagal. Cek log di atas.');
        setState(() {
          _consoleRunning = false;
        });
        _pulseController.stop();
        _pulseController.reset();
        return;
      }
      _appendConsole(line);
    });

    service.repairTermuxEnvironment().then((started) {
      if (!mounted) return;
      if (!started) {
        _appendConsole('[error] Repair tidak bisa dimulai');
        setState(() {
          _consoleRunning = false;
        });
        _pulseController.stop();
        _pulseController.reset();
      }
    });
  }

  void _copyConsoleLogs() {
    if (_consoleOutput.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _consoleOutput.join('\n')));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Log disalin ke clipboard'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final queueState = ref.watch(queueProvider);
    final queue = ref.read(queueProvider.notifier);
    final isAndroid = Platform.isAndroid;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[Color(0xFF0D0E10), Color(0xFF050505)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: <Widget>[
              // ── Header ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.music_note_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Universal SpotDL',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              'Download Manager',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white54,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Queue status chip
                      _StatusChip(
                        active: queueState.activeTaskIds.length,
                        max: queueState.maxConcurrent,
                        paused: queueState.enginePaused,
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // ── Batch Input ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: GlassContainer(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Icon(
                              Icons.link_rounded,
                              color: AppTheme.spotifyGreen.withValues(alpha: 0.9),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Add Links',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _batchController,
                          maxLines: 3,
                          minLines: 2,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Paste Spotify URLs here (satu per baris)',
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            filled: true,
                            fillColor: Colors.black26,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppTheme.spotifyGreen,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: <Widget>[
                            // Priority selector
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: _priority,
                                  isDense: true,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.white,
                                  ),
                                  items: const <DropdownMenuItem<int>>[
                                    DropdownMenuItem(value: 1, child: Text('P1 High')),
                                    DropdownMenuItem(value: 2, child: Text('P2 Normal')),
                                    DropdownMenuItem(value: 3, child: Text('P3 Low')),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        _priority = value;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                            const Spacer(),
                            // Add batch button
                            SizedBox(
                              height: 36,
                              child: FilledButton.icon(
                                onPressed: () async {
                                  final lines = _batchController.text
                                      .split(RegExp(r'\s+'))
                                      .map((line) => line.trim())
                                      .where((line) => line.isNotEmpty)
                                      .toList(growable: false);

                                  if (lines.isEmpty) return;

                                  final inserted =
                                      await queue.addBatch(lines, priority: _priority);

                                  if (!context.mounted) return;

                                  _batchController.clear();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('$inserted link(s) ditambahkan'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text(
                                  'Add',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.spotifyGreen,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if ((queueState.message ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              queueState.message!,
                              style: const TextStyle(
                                color: AppTheme.warningColor,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 8)),

              // ── Queue Controls ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: <Widget>[
                      _MiniActionButton(
                        icon: queueState.enginePaused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                        label: queueState.enginePaused ? 'Resume' : 'Pause',
                        onPressed: queueState.enginePaused
                            ? () => queue.resumeQueue()
                            : () => queue.pauseQueue(),
                        accent: true,
                      ),
                      const SizedBox(width: 8),
                      _MiniActionButton(
                        icon: Icons.stop_rounded,
                        label: 'Cancel All',
                        onPressed: () => queue.cancelAll(),
                      ),
                      const Spacer(),
                      if (isAndroid) ...<Widget>[
                        _MiniActionButton(
                          icon: Icons.terminal_rounded,
                          label: 'Console',
                          onPressed: () {
                            setState(() {
                              _consoleExpanded = !_consoleExpanded;
                            });
                          },
                          accent: _consoleExpanded,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // ── Console Panel ──
              if (_consoleExpanded && isAndroid)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                    child: _buildConsolePanel(),
                  ),
                ),

              // ── Queue Section Header ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.queue_music_rounded, size: 16, color: Colors.white54),
                      const SizedBox(width: 8),
                      Text(
                        'Download Queue',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.7),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${queueState.tasks.length} item(s)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Download List ──
              SliverFillRemaining(
                hasScrollBody: true,
                child: DownloadList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConsolePanel() {
    return GlassContainer(
      padding: EdgeInsets.zero,
      borderRadius: 12,
      child: Column(
        children: <Widget>[
          // Console header
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: <Widget>[
                // Status indicator
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _consoleRunning
                            ? Color.lerp(
                                AppTheme.spotifyGreen,
                                AppTheme.spotifyGreen.withValues(alpha: 0.3),
                                _pulseController.value,
                              )
                            : Colors.white24,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                Text(
                  _consoleRunning ? 'Running...' : 'Terminal',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  height: 28,
                  child: TextButton.icon(
                    onPressed: _consoleRunning ? null : _runRepair,
                    icon: const Icon(Icons.build_rounded, size: 14),
                    label: const Text('Repair', style: TextStyle(fontSize: 11)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.spotifyGreen,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: IconButton(
                    onPressed: _consoleOutput.isEmpty ? null : _copyConsoleLogs,
                    icon: const Icon(Icons.copy_rounded, size: 14),
                    padding: EdgeInsets.zero,
                    tooltip: 'Copy logs',
                  ),
                ),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: IconButton(
                    onPressed: () {
                      setState(() {
                        _consoleExpanded = false;
                      });
                    },
                    icon: const Icon(Icons.close_rounded, size: 14),
                    padding: EdgeInsets.zero,
                    tooltip: 'Close',
                  ),
                ),
              ],
            ),
          ),
          // Console output
          Container(
            height: 200,
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            child: _consoleOutput.isEmpty
                ? Text(
                    'Tekan "Repair" untuk setup environment Termux.\nAtau gunakan terminal ini untuk melihat log.',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  )
                : Scrollbar(
                    controller: _consoleScrollController,
                    thumbVisibility: true,
                    thickness: 3,
                    child: ListView.builder(
                      controller: _consoleScrollController,
                      itemCount: _consoleOutput.length,
                      padding: const EdgeInsets.only(right: 8),
                      itemBuilder: (context, index) {
                        final line = _consoleOutput[index];
                        return Text(
                          line,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            height: 1.4,
                            color: _consoleLineColor(line),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Color _consoleLineColor(String line) {
    if (line.contains('[error]')) return Colors.redAccent;
    if (line.contains('[warn]')) return Colors.orangeAccent;
    if (line.contains('[ok]') || line.startsWith('✓')) return AppTheme.spotifyGreen;
    if (line.contains('[hint]')) return Colors.cyanAccent.withValues(alpha: 0.7);
    if (line.contains('[debug]')) return Colors.white30;
    if (line.contains('[step]')) return Colors.lightBlueAccent;
    if (line.contains('[stdout]')) return Colors.white70;
    if (line.contains('[stderr]')) return Colors.orange.withValues(alpha: 0.7);
    return Colors.white60;
  }
}

// ─── Supporting Widgets ───

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.active,
    required this.max,
    required this.paused,
  });

  final int active;
  final int max;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: paused
            ? Colors.orange.withValues(alpha: 0.15)
            : AppTheme.spotifyGreen.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: paused
              ? Colors.orange.withValues(alpha: 0.3)
              : AppTheme.spotifyGreen.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: paused ? Colors.orange : AppTheme.spotifyGreen,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            paused ? 'Paused' : '$active/$max active',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: paused ? Colors.orange : AppTheme.spotifyGreen,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniActionButton extends StatelessWidget {
  const _MiniActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        style: TextButton.styleFrom(
          foregroundColor: accent ? AppTheme.spotifyGreen : Colors.white70,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: accent
                  ? AppTheme.spotifyGreen.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.1),
            ),
          ),
        ),
      ),
    );
  }
}
