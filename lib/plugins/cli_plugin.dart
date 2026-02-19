abstract class CliPlugin {
  String get id;
  String get name;

  bool supportsUrl(String url);

  String buildDownloadCommand(String url, String outputTemplate);
}
