class AppConstants {
  static const String appName = 'Universal SpotDL Manager';
  static const String spotdlCommand = 'spotdl';
  static const String ffmpegCommand = 'ffmpeg';
  static const Duration defaultCommandTimeout = Duration(minutes: 45);
  static const Duration analyticsLookback = Duration(days: 30);
  static const int defaultMaxConcurrent = 3;
  static const int maxRetry = 3;

  static const String queueLogFile = 'queue.jsonl';
  static const String appLogFile = 'app.jsonl';
  static const String queueExportFile = 'queue_export.json';
  static const String analyticsCsvFile = 'analytics_export.csv';
}
