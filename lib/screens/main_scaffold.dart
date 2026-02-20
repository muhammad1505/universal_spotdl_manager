import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../widgets/mini_player.dart';
import 'about_screen.dart';
import 'analytics_screen.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'settings_screen.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _index = 0;

  final _screens = const <Widget>[
    HomeScreen(),
    LibraryScreen(),
    AnalyticsScreen(),
    SettingsScreen(),
    AboutScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          Expanded(child: _screens[_index]),
          const MiniPlayer(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0B),
          border: Border(
            top: BorderSide(
              color: Colors.white.withValues(alpha: 0.06),
              width: 1,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          indicatorColor: AppTheme.spotifyGreen.withValues(alpha: 0.15),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          height: 64,
          onDestinationSelected: (next) {
            setState(() {
              _index = next;
            });
          },
          destinations: <NavigationDestination>[
            NavigationDestination(
              icon: Icon(Icons.home_outlined,
                  color: Colors.white.withValues(alpha: 0.5)),
              selectedIcon:
                  const Icon(Icons.home_rounded, color: AppTheme.spotifyGreen),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.library_music_outlined,
                  color: Colors.white.withValues(alpha: 0.5)),
              selectedIcon: const Icon(Icons.library_music_rounded,
                  color: AppTheme.spotifyGreen),
              label: 'Library',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined,
                  color: Colors.white.withValues(alpha: 0.5)),
              selectedIcon: const Icon(Icons.bar_chart_rounded,
                  color: AppTheme.spotifyGreen),
              label: 'Analytics',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined,
                  color: Colors.white.withValues(alpha: 0.5)),
              selectedIcon: const Icon(Icons.settings_rounded,
                  color: AppTheme.spotifyGreen),
              label: 'Settings',
            ),
            NavigationDestination(
              icon: Icon(Icons.info_outline_rounded,
                  color: Colors.white.withValues(alpha: 0.5)),
              selectedIcon:
                  const Icon(Icons.info_rounded, color: AppTheme.spotifyGreen),
              label: 'About',
            ),
          ],
        ),
      ),
    );
  }
}
