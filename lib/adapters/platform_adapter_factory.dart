import 'dart:io';

import 'android_termux_executor.dart';
import 'command_executor.dart';
import 'linux_executor.dart';
import 'mac_executor.dart';
import 'windows_executor.dart';

class PlatformAdapterFactory {
  static CommandExecutor getExecutor() {
    if (Platform.isAndroid) {
      return AndroidTermuxExecutor();
    }

    if (Platform.isWindows) {
      return WindowsShellExecutor();
    }

    if (Platform.isLinux) {
      return LinuxShellExecutor();
    }

    if (Platform.isMacOS) {
      return MacShellExecutor();
    }

    throw UnsupportedError('Unsupported platform for command execution.');
  }
}
