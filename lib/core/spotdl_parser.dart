class SpotDLProgress {
  const SpotDLProgress({
    required this.percent,
    required this.speed,
    required this.eta,
  });

  final double percent;
  final String speed;
  final String eta;
}

class SpotDLParser {
  static final RegExp _progressRegex = RegExp(
    r'(\\d{1,3}(?:\\.\\d+)?)%.*?(?:at\\s+([^\\s]+))?.*?(?:ETA\\s+([0-9:]+))?',
    caseSensitive: false,
  );

  static SpotDLProgress? parseProgress(String line) {
    final match = _progressRegex.firstMatch(line);
    if (match == null) {
      return null;
    }

    final percent = double.tryParse(match.group(1) ?? '0') ?? 0;
    return SpotDLProgress(
      percent: percent.clamp(0, 100),
      speed: (match.group(2) ?? '0').trim(),
      eta: (match.group(3) ?? '0').trim(),
    );
  }

  static bool isSuccess(String line) {
    final lower = line.toLowerCase();
    return lower.contains('downloaded') ||
        lower.contains('finished') ||
        lower.contains('saved') ||
        lower.contains('already exists');
  }

  static bool isFailure(String line) {
    final lower = line.toLowerCase();
    return lower.contains('error') ||
        lower.contains('failed') ||
        lower.contains('exception') ||
        lower.contains('traceback');
  }

  static bool isPlaylistUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('/playlist/') || lower.contains('playlist?');
  }
}
