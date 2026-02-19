import 'cli_plugin.dart';

class YoutubeCliPlugin implements CliPlugin {
  @override
  String get id => 'youtube-cli';

  @override
  String get name => 'YouTube CLI';

  @override
  bool supportsUrl(String url) => url.contains('youtube.com') || url.contains('youtu.be');

  @override
  String buildDownloadCommand(String url, String outputTemplate) {
    return 'echo "Implement youtube download for $url -> $outputTemplate"';
  }
}

class InstagramCliPlugin implements CliPlugin {
  @override
  String get id => 'instagram-cli';

  @override
  String get name => 'Instagram CLI';

  @override
  bool supportsUrl(String url) => url.contains('instagram.com');

  @override
  String buildDownloadCommand(String url, String outputTemplate) {
    return 'echo "Implement instagram download for $url -> $outputTemplate"';
  }
}

class TorrentCliPlugin implements CliPlugin {
  @override
  String get id => 'torrent-cli';

  @override
  String get name => 'Torrent CLI';

  @override
  bool supportsUrl(String url) => url.startsWith('magnet:');

  @override
  String buildDownloadCommand(String url, String outputTemplate) {
    return 'echo "Implement torrent download for $url -> $outputTemplate"';
  }
}

class SoundCloudCliPlugin implements CliPlugin {
  @override
  String get id => 'soundcloud-cli';

  @override
  String get name => 'SoundCloud CLI';

  @override
  bool supportsUrl(String url) => url.contains('soundcloud.com');

  @override
  String buildDownloadCommand(String url, String outputTemplate) {
    return 'echo "Implement soundcloud download for $url -> $outputTemplate"';
  }
}
