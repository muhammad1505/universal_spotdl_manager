import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../managers/environment_manager.dart';
import '../models/environment_health.dart';
import 'main_scaffold.dart';

class StartupScreen extends ConsumerWidget {
  const StartupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final env = ref.watch(environmentProvider);

    return Scaffold(
      body: Stack(
        children: <Widget>[
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[Color(0xFF1DB954), Color(0xFF0B0C0E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: env.when(
                  loading: () => const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Checking environment...'),
                    ],
                  ),
                  error: (error, _) => _StartupCard(
                    title: 'Environment Check Failed',
                    subtitle: '$error',
                    actions: <Widget>[
                      FilledButton(
                        onPressed: () {
                          ref.read(environmentProvider.notifier).refresh();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                  data: (report) {
                    final healthy = report.level == HealthLevel.healthy;
                    return _StartupCard(
                      title: healthy
                          ? 'Environment Ready'
                          : 'Environment ${report.level.name.toUpperCase()}',
                      subtitle: report.message,
                      actions: <Widget>[
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute<void>(
                                builder: (_) => const MainScaffold(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('Continue'),
                        ),
                        if (!healthy)
                          OutlinedButton.icon(
                            onPressed: () {
                              ref.read(environmentProvider.notifier).repairEnvironment();
                            },
                            icon: const Icon(Icons.build_circle_outlined),
                            label: const Text('Repair'),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StartupCard extends StatelessWidget {
  const _StartupCard({
    required this.title,
    required this.subtitle,
    required this.actions,
  });

  final String title;
  final String subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.music_note_rounded, size: 48),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Wrap(spacing: 10, runSpacing: 10, children: actions),
          ],
        ),
      ),
    );
  }
}
