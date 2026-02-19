import 'cli_plugin.dart';

class SpotdlPlugin implements CliPlugin {
  @override
  String get id => 'spotdl';

  @override
  String get name => 'Spotify/SpotDL';

  @override
  bool supportsUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('spotify.com') || lower.contains('open.spotify');
  }

  @override
  String buildDownloadCommand(String url, String outputTemplate) {
    return 'spotdl "$url" --output "$outputTemplate" --print-errors --overwrite skip';
  }
}
