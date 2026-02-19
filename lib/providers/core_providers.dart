import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../adapters/command_executor.dart';
import '../adapters/platform_adapter_factory.dart';

final commandExecutorProvider = Provider<CommandExecutor>((ref) {
  return PlatformAdapterFactory.getExecutor();
});
