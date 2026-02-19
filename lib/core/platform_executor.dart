import 'dart:io';
import 'package:flutter/foundation.dart';

/// Abstract class to handle platform-specific command execution.
abstract class PlatformExecutor {
  /// Checks if a command is available in the system (returns version if found).
  Future<String?> checkCommand(String command, {List<String> args = const ['--version']});

  /// installing a command (returns success/failure).
  Future<bool> installCommand(String command);

  /// Runs a command with arguments.
  Future<ProcessResult> run(String command, List<String> args);
  
  /// Gets the platform-specific shell command (e.g., 'sh', 'powershell').
  String get shell;
  
  /// Gets the arguments to run a command in the shell (e.g., ['-c']).
  List<String> get shellArgs;

  // Protected constructor for subclasses
  const PlatformExecutor.protected();

  factory PlatformExecutor() {
    if (Platform.isWindows) {
      return WindowsExecutor();
    } else if (Platform.isAndroid || _isTermux) {
      return AndroidExecutor();
    } else {
      return LinuxExecutor(); // Default to Linux-like (macOS/Linux)
    }
  }

  static bool get _isTermux => Platform.environment.containsKey('TERMUX_VERSION');
}

class LinuxExecutor extends PlatformExecutor {
  LinuxExecutor() : super.protected();

  @override
  String get shell => 'sh';

  @override
  List<String> get shellArgs => ['-c'];

  @override
  Future<String?> checkCommand(String command, {List<String> args = const ['--version']}) async {
    try {
      // Try `which` first to see if binary exists
      final which = await Process.run('which', [command]);
      if (which.exitCode != 0) return null;
      
      final result = await Process.run(command, args);
      if (result.exitCode == 0) {
        return result.stdout.toString().trim();
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<bool> installCommand(String command) async {
    // On generic Linux, we can't safely assume sudo/package manager non-interactively.
    // But we can try 'pip' for python packages if python exists.
    if (command == 'spotdl') {
      try {
        final res = await Process.run('python3', ['-m', 'pip', 'install', 'spotdl']);
        return res.exitCode == 0;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  @override
  Future<ProcessResult> run(String command, List<String> args) {
     return Process.run(command, args);
  }
}

class WindowsExecutor extends PlatformExecutor {
  WindowsExecutor() : super.protected();

  @override
  String get shell => 'powershell';

  @override
  List<String> get shellArgs => ['-Command'];

  @override
  Future<String?> checkCommand(String command, {List<String> args = const ['--version']}) async {
    try {
      // In Windows, often we need to run via shell or check .exe
      // Trying direct run first
      final result = await Process.run(command, args, runInShell: true);
      if (result.exitCode == 0) {
        return result.stdout.toString().trim();
      }
      
      // If checking python, also try 'py' launcher
      if (command == 'python' || command == 'python3') {
         final resultPy = await Process.run('py', ['--version'], runInShell: true);
          if (resultPy.exitCode == 0) {
            return resultPy.stdout.toString().trim();
          }
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<bool> installCommand(String command) async {
     if (command == 'spotdl') {
      try {
        final res = await Process.run('python', ['-m', 'pip', 'install', 'spotdl'], runInShell: true);
        return res.exitCode == 0;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  @override
  Future<ProcessResult> run(String command, List<String> args) {
    return Process.run(command, args, runInShell: true);
  }
}

class AndroidExecutor extends PlatformExecutor {
  AndroidExecutor() : super.protected();

  @override
  String get shell => 'sh';

  @override
  List<String> get shellArgs => ['-c'];

  @override
  Future<String?> checkCommand(String command, {List<String> args = const ['--version']}) async {
    try {
      // Termux often requires running in shell
      final result = await Process.run(command, args, runInShell: true, 
        environment: Platform.environment // Inherit termux vars
      );
      if (result.exitCode == 0) {
        return result.stdout.toString().trim();
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<bool> installCommand(String command) async {
     if (command == 'spotdl') {
       // Termux python usually is just 'python', not 'python3' strictly needed but both might existing
       try {
         // Upgrade pip first is often good practice but might fail if network issues, skipping for speed
         final res = await Process.run('pip', ['install', 'spotdl'], runInShell: true);
         return res.exitCode == 0;
       } catch (_) {
         return false;
       }
     } else if (command == 'python') {
       try {
         final res = await Process.run('pkg', ['install', '-y', 'python'], runInShell: true);
         return res.exitCode == 0;
       } catch (_) {
         return false;
       }
     } else if (command == 'ffmpeg') {
       try {
         final res = await Process.run('pkg', ['install', '-y', 'ffmpeg'], runInShell: true);
         return res.exitCode == 0;
       } catch (_) {
         return false;
       }
     }
     
    return false;
  }

  @override
  Future<ProcessResult> run(String command, List<String> args) {
     return Process.run(command, args, runInShell: true);
  }
}
