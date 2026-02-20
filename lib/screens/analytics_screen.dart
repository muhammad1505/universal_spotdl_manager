import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../managers/analytics_manager.dart';
import '../models/analytics_snapshot.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(analyticsProvider);

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
          child: analytics.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Error: $error')),
            data: (snapshot) => _AnalyticsBody(
              snapshot: snapshot,
              onExport: () async {
                final path =
                    await ref.read(analyticsProvider.notifier).exportCsv();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('CSV exported: $path'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _AnalyticsBody extends StatelessWidget {
  const _AnalyticsBody({required this.snapshot, required this.onExport});
  final AnalyticsSnapshot snapshot;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        // Header
        Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.bar_chart_rounded,
                color: Colors.orangeAccent,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Analytics',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'Download statistics & trends',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 32,
              child: TextButton.icon(
                onPressed: onExport,
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('CSV', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.orangeAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Metric cards
        Row(
          children: <Widget>[
            Expanded(
              child: _MetricCard(
                title: 'Total',
                value: snapshot.totalDownloads.toString(),
                icon: Icons.download_done_rounded,
                color: AppTheme.spotifyGreen,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricCard(
                title: 'Today',
                value: snapshot.downloadsDay.toString(),
                icon: Icons.today_rounded,
                color: Colors.lightBlueAccent,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricCard(
                title: 'Week',
                value: snapshot.downloadsWeek.toString(),
                icon: Icons.date_range_rounded,
                color: Colors.purpleAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: _MetricCard(
                title: 'Fail Rate',
                value: '${(snapshot.failureRatio * 100).toStringAsFixed(1)}%',
                icon: Icons.error_outline_rounded,
                color: snapshot.failureRatio > 0.2
                    ? Colors.redAccent
                    : Colors.orangeAccent,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricCard(
                title: 'Played',
                value: snapshot.playbackCount.toString(),
                icon: Icons.headphones_rounded,
                color: Colors.cyanAccent,
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(child: SizedBox()),
          ],
        ),

        const SizedBox(height: 24),

        // Daily trend chart
        _ChartSection(
          title: 'Daily Downloads',
          child: SizedBox(
            height: 180,
            child: _TrendBarChart(snapshot: snapshot),
          ),
        ),

        const SizedBox(height: 16),

        // Success vs Failure pie
        _ChartSection(
          title: 'Success vs Failure',
          child: SizedBox(
            height: 180,
            child: _FailurePie(snapshot: snapshot),
          ),
        ),

        const SizedBox(height: 16),

        // Line trend
        _ChartSection(
          title: 'Download Trend',
          child: SizedBox(
            height: 180,
            child: _LineTrend(snapshot: snapshot),
          ),
        ),

        const SizedBox(height: 20),

        // Top Artists
        if (snapshot.topArtists.isNotEmpty) ...<Widget>[
          _ListSection(title: 'Top Artists'),
          ...snapshot.topArtists.map(
            (item) => _RankItem(name: item.name, count: item.value),
          ),
          const SizedBox(height: 16),
        ],

        // Top Tracks
        if (snapshot.topTracks.isNotEmpty) ...<Widget>[
          _ListSection(title: 'Top Tracks'),
          ...snapshot.topTracks.map(
            (item) => _RankItem(name: item.name, count: item.value),
          ),
        ],

        const SizedBox(height: 16),
      ],
    );
  }
}

// ─── Supporting Widgets ───

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartSection extends StatelessWidget {
  const _ChartSection({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ListSection extends StatelessWidget {
  const _ListSection({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: AppTheme.spotifyGreen,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankItem extends StatelessWidget {
  const _RankItem({required this.name, required this.count});
  final String name;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.spotifyGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.spotifyGreen,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Chart Widgets ───

class _TrendBarChart extends StatelessWidget {
  const _TrendBarChart({required this.snapshot});
  final AnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final points = snapshot.dailyTrend;
    if (points.isEmpty) {
      return Center(
        child: Text(
          'No data yet',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
        ),
      );
    }

    return BarChart(
      BarChartData(
        barGroups: points.asMap().entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: <BarChartRodData>[
              BarChartRodData(
                toY: entry.value.value,
                width: 10,
                borderRadius: BorderRadius.circular(4),
                gradient: AppTheme.primaryGradient,
              ),
            ],
          );
        }).toList(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.white.withValues(alpha: 0.05),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= points.length) {
                  return const SizedBox.shrink();
                }
                return Text(
                  points[idx].label,
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                );
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
    final failures =
        (snapshot.totalDownloads * snapshot.failureRatio).toDouble();
    final success = (snapshot.totalDownloads.toDouble() - failures)
        .clamp(0, double.infinity)
        .toDouble();

    if (snapshot.totalDownloads == 0) {
      return Center(
        child: Text(
          'No data yet',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
        ),
      );
    }

    return PieChart(
      PieChartData(
        sections: <PieChartSectionData>[
          PieChartSectionData(
            value: success,
            title: 'Success',
            radius: 60,
            color: AppTheme.spotifyGreen,
            titleStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          PieChartSectionData(
            value: failures,
            title: 'Fail',
            radius: 60,
            color: Colors.redAccent,
            titleStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
        sectionsSpace: 2,
        centerSpaceRadius: 32,
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
      return Center(
        child: Text(
          'No trend yet',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
        ),
      );
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.white.withValues(alpha: 0.05),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        lineBarsData: <LineChartBarData>[
          LineChartBarData(
            isCurved: true,
            curveSmoothness: 0.3,
            spots: points
                .asMap()
                .entries
                .map((entry) =>
                    FlSpot(entry.key.toDouble(), entry.value.value))
                .toList(),
            barWidth: 2.5,
            color: AppTheme.spotifyGreen,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) =>
                  FlDotCirclePainter(
                radius: 3,
                color: AppTheme.spotifyGreen,
                strokeWidth: 1.5,
                strokeColor: Colors.white24,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: <Color>[
                  AppTheme.spotifyGreen.withValues(alpha: 0.15),
                  AppTheme.spotifyGreen.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
