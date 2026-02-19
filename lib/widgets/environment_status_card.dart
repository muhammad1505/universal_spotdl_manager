import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../managers/environment_manager.dart';
import '../models/environment_health.dart';
import 'glass_container.dart';
import 'termux_repair_console.dart';

class EnvironmentStatusCard extends ConsumerWidget {
  const EnvironmentStatusCard({super.key, this.showActions = true});

  final bool showActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final env = ref.watch(environmentProvider);

    return env.when(
      loading: () => const GlassContainer(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, _) => GlassContainer(
        child: Text(
          'Environment check failed: $error',
          style: const TextStyle(color: Colors.redAccent),
        ),
      ),
      data: (report) {
        final color = _color(report.level);
        return GlassContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.health_and_safety_outlined, color: color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Environment ${report.level.name.toUpperCase()} (${report.platform})',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(report.message),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: report.components.map((component) {
                  final isOptionalMissing =
                      !component.required && !component.installed;
                  return Chip(
                    avatar: Icon(
                      component.installed
                          ? Icons.check
                          : (isOptionalMissing ? Icons.info_outline : Icons.close),
                      size: 16,
                      color: component.installed ? Colors.black : Colors.white,
                    ),
                    label: Text(component.name),
                    backgroundColor: component.installed
                        ? AppTheme.spotifyGreen
                        : (isOptionalMissing
                            ? Colors.orange.withValues(alpha: 0.8)
                            : Colors.red.withValues(alpha: 0.7)),
                  );
                }).toList(),
              ),
              ...report.components
                  .where((component) => component.hint != null && component.hint!.isNotEmpty)
                  .map(
                    (component) => Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '- ${component.name}: ${component.hint!}',
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ),
                  ),
              if (showActions) ...<Widget>[
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    ElevatedButton.icon(
                      onPressed: () {
                        ref.read(environmentProvider.notifier).refresh();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Recheck'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        if (Platform.isAndroid) {
                          showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => const TermuxRepairConsoleSheet(),
                          );
                        } else {
                          ref.read(environmentProvider.notifier).repairEnvironment();
                        }
                      },
                      icon: const Icon(Icons.build_circle_outlined),
                      label: const Text('Repair'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Color _color(HealthLevel level) {
    switch (level) {
      case HealthLevel.healthy:
        return AppTheme.spotifyGreen;
      case HealthLevel.warning:
        return Colors.orangeAccent;
      case HealthLevel.error:
        return Colors.redAccent;
      case HealthLevel.checking:
        return Colors.lightBlueAccent;
    }
  }
}
