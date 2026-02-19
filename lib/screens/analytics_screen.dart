import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../managers/analytics_manager.dart';
import '../models/analytics_snapshot.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(analyticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export CSV',
            onPressed: () async {
              final path = await ref.read(analyticsProvider.notifier).exportCsv();
              if (!context.mounted) {
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('CSV exported: $path')),
              );
            },
          ),
        ],
      ),
      body: analytics.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load analytics: $error')),
        data: (snapshot) => _AnalyticsBody(snapshot: snapshot),
      ),
    );
  }
}

class _AnalyticsBody extends StatelessWidget {
  const _AnalyticsBody({required this.snapshot});

  final AnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        // Refresh handled by parent provider action in real flow.
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              _MetricCard(title: 'Total', value: snapshot.totalDownloads.toString()),
              _MetricCard(title: 'Today', value: snapshot.downloadsDay.toString()),
              _MetricCard(title: 'Week', value: snapshot.downloadsWeek.toString()),
              _MetricCard(
                title: 'Failure Ratio',
                value: '${(snapshot.failureRatio * 100).toStringAsFixed(1)}%',
              ),
              _MetricCard(
                title: 'Playback Count',
                value: snapshot.playbackCount.toString(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Daily Download Trend', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SizedBox(height: 220, child: _TrendBarChart(snapshot: snapshot)),
          const SizedBox(height: 20),
          const Text('Success vs Failure', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SizedBox(height: 220, child: _FailurePie(snapshot: snapshot)),
          const SizedBox(height: 20),
          const Text('Line Trend', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SizedBox(height: 220, child: _LineTrend(snapshot: snapshot)),
          const SizedBox(height: 20),
          const Text('Top Artists', style: TextStyle(fontWeight: FontWeight.bold)),
          ...snapshot.topArtists.map(
            (item) => ListTile(
              dense: true,
              title: Text(item.name),
              trailing: Text(item.value.toString()),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Top Tracks', style: TextStyle(fontWeight: FontWeight.bold)),
          ...snapshot.topTracks.map(
            (item) => ListTile(
              dense: true,
              title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Text(item.value.toString()),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 6),
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrendBarChart extends StatelessWidget {
  const _TrendBarChart({required this.snapshot});

  final AnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final points = snapshot.dailyTrend;

    return BarChart(
      BarChartData(
        barGroups: points.asMap().entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: <BarChartRodData>[
              BarChartRodData(
                toY: entry.value.value,
                width: 12,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= points.length) {
                  return const SizedBox.shrink();
                }
                return Text(points[idx].label, style: const TextStyle(fontSize: 10));
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _FailurePie extends StatelessWidget {
  const _FailurePie({required this.snapshot});

  final AnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final failures = (snapshot.totalDownloads * snapshot.failureRatio).toDouble();
    final success = (snapshot.totalDownloads.toDouble() - failures)
        .clamp(0, double.infinity)
        .toDouble();

    if (snapshot.totalDownloads == 0) {
      return const Center(child: Text('No data yet'));
    }

    return PieChart(
      PieChartData(
        sections: <PieChartSectionData>[
          PieChartSectionData(value: success, title: 'Success', radius: 72),
          PieChartSectionData(value: failures, title: 'Fail', radius: 72),
        ],
      ),
    );
  }
}

class _LineTrend extends StatelessWidget {
  const _LineTrend({required this.snapshot});

  final AnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final points = snapshot.dailyTrend;

    if (points.isEmpty) {
      return const Center(child: Text('No trend yet'));
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: const FlTitlesData(show: false),
        lineBarsData: <LineChartBarData>[
          LineChartBarData(
            isCurved: true,
            spots: points
                .asMap()
                .entries
                .map((entry) => FlSpot(entry.key.toDouble(), entry.value.value))
                .toList(),
            barWidth: 3,
            dotData: const FlDotData(show: true),
          ),
        ],
      ),
    );
  }
}
