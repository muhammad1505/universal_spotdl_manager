import 'package:flutter/material.dart';

import '../core/theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[Color(0xFF0D0E10), Color(0xFF050505)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              const SizedBox(height: 24),
              // App icon + branding
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: AppTheme.spotifyGreen.withValues(alpha: 0.3),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.music_note_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'Universal SpotDL Manager',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.spotifyGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'v1.0.0-beta',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.spotifyGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Cross-platform CLI media download orchestrator',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Features section
              _SectionHeader(title: 'Features'),
              const SizedBox(height: 8),
              _FeatureTile(
                icon: Icons.queue_music_rounded,
                title: 'Smart Download Queue',
                subtitle: 'Multi-download, pause/resume, priority, drag reorder',
                color: Colors.lightBlueAccent,
              ),
              _FeatureTile(
                icon: Icons.terminal_rounded,
                title: 'Termux Integration',
                subtitle: 'Seamless bridge to spotdl in Termux sandbox',
                color: AppTheme.spotifyGreen,
              ),
              _FeatureTile(
                icon: Icons.headphones_rounded,
                title: 'Built-in Player',
                subtitle: 'Play downloaded tracks without leaving the app',
                color: Colors.purpleAccent,
              ),
              _FeatureTile(
                icon: Icons.bar_chart_rounded,
                title: 'Analytics Dashboard',
                subtitle: 'Track downloads, success rates, and trends',
                color: Colors.orangeAccent,
              ),
              _FeatureTile(
                icon: Icons.devices_rounded,
                title: 'Cross-platform',
                subtitle: 'Android, Windows, Linux, macOS',
                color: Colors.cyanAccent,
              ),

              const SizedBox(height: 24),

              _SectionHeader(title: 'Tech Stack'),
              const SizedBox(height: 8),
              _InfoRow(label: 'Framework', value: 'Flutter / Dart'),
              _InfoRow(label: 'Native Bridge', value: 'Kotlin (Android)'),
              _InfoRow(label: 'CLI Engine', value: 'spotdl'),
              _InfoRow(label: 'Database', value: 'SQLite (sqflite)'),
              _InfoRow(label: 'State', value: 'Riverpod'),

              const SizedBox(height: 24),

              _SectionHeader(title: 'Plugin System (Coming Soon)'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  _PluginChip(label: 'YouTube CLI'),
                  _PluginChip(label: 'SoundCloud CLI'),
                  _PluginChip(label: 'Instagram CLI'),
                  _PluginChip(label: 'Torrent CLI'),
                ],
              ),

              const SizedBox(height: 32),

              Center(
                child: Text(
                  'Made with ❤️ and spotdl',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: AppTheme.spotifyGreen,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.8),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PluginChip extends StatelessWidget {
  const _PluginChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: Colors.white.withValues(alpha: 0.5),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
