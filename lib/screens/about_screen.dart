import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const <Widget>[
          ListTile(
            title: Text('Universal Cross-Platform CLI Media Orchestrator'),
            subtitle: Text('Smart Queue • Analytics • Player • Environment Health'),
          ),
          SizedBox(height: 8),
          ListTile(
            leading: Icon(Icons.devices_outlined),
            title: Text('Platforms'),
            subtitle: Text('Android, Windows, Linux, macOS'),
          ),
          ListTile(
            leading: Icon(Icons.terminal_outlined),
            title: Text('CLI Engine'),
            subtitle: Text('spotdl (no embedded Python, no external server)'),
          ),
          ListTile(
            leading: Icon(Icons.extension_outlined),
            title: Text('Future Plugin System'),
            subtitle: Text('YouTube CLI, Instagram CLI, Torrent CLI, SoundCloud CLI'),
          ),
        ],
      ),
    );
  }
}
