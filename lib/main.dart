import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'core/theme.dart';
import 'screens/startup_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'io.universal.spotdl.playback',
      androidNotificationChannelName: 'Universal SpotDL Playback',
      androidNotificationOngoing: true,
    );
  } catch (_) {
    // Background init can fail in test or unsupported platforms.
  }

  runApp(
    const ProviderScope(
      child: SpotdlApp(),
    ),
  );
}

class SpotdlApp extends StatelessWidget {
  const SpotdlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Universal SpotDL Manager',
      theme: AppTheme.darkTheme,
      home: const StartupScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
