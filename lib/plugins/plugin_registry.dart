import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cli_plugin.dart';
import 'spotdl_plugin.dart';

class PluginRegistry {
  PluginRegistry({List<CliPlugin>? plugins})
      : _plugins = plugins ?? <CliPlugin>[SpotdlPlugin()];

  final List<CliPlugin> _plugins;

  List<CliPlugin> get plugins => List<CliPlugin>.unmodifiable(_plugins);

  CliPlugin resolve(String url) {
    for (final plugin in _plugins) {
      if (plugin.supportsUrl(url)) {
        return plugin;
      }
    }
    return _plugins.first;
  }
}

final pluginRegistryProvider = Provider<PluginRegistry>((ref) {
  return PluginRegistry();
});
