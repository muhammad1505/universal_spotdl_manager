class MetricPoint {
  const MetricPoint({
    required this.label,
    required this.value,
  });

  final String label;
  final double value;
}

class RankedMetric {
  const RankedMetric({
    required this.name,
    required this.value,
  });

  final String name;
  final int value;
}

class AnalyticsSnapshot {
  const AnalyticsSnapshot({
    required this.totalDownloads,
    required this.downloadsDay,
    required this.downloadsWeek,
    required this.downloadsMonth,
    required this.totalBytes,
    required this.failureRatio,
    required this.averageDownloadMs,
    required this.playbackCount,
    required this.topArtists,
    required this.topTracks,
    required this.dailyTrend,
  });

  final int totalDownloads;
  final int downloadsDay;
  final int downloadsWeek;
  final int downloadsMonth;
  final int totalBytes;
  final double failureRatio;
  final double averageDownloadMs;
  final int playbackCount;
  final List<RankedMetric> topArtists;
  final List<RankedMetric> topTracks;
  final List<MetricPoint> dailyTrend;

  static const empty = AnalyticsSnapshot(
    totalDownloads: 0,
    downloadsDay: 0,
    downloadsWeek: 0,
    downloadsMonth: 0,
    totalBytes: 0,
    failureRatio: 0,
    averageDownloadMs: 0,
    playbackCount: 0,
    topArtists: <RankedMetric>[],
    topTracks: <RankedMetric>[],
    dailyTrend: <MetricPoint>[],
  );
}
