import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/favorites_backup_service.dart';

class FavoritesBackupScreen extends StatefulWidget {
  const FavoritesBackupScreen({super.key});
  @override
  State<FavoritesBackupScreen> createState() => _FavoritesBackupScreenState();
}

class _FavoritesBackupScreenState extends State<FavoritesBackupScreen> {
  late final FavoritesBackupService _service;
  bool _busy = false;
  String? _message;
  String? _error;
  Map<String, int> _counts = {'live': 0, 'vod': 0, 'series': 0};

  @override
  void initState() {
    super.initState();
    _service = FavoritesBackupService(Supabase.instance.client);
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final rows = await _service.loadAll();
      if (!mounted) return;
      setState(() {
        _counts = {'live': 0, 'vod': 0, 'series': 0};
        for (final row in rows) {
          final type = row['content_type']?.toString();
          if (_counts.containsKey(type)) _counts[type] = _counts[type]! + 1;
        }
      });
    } catch (e) { if (mounted) setState(() => _error = e.toString()); }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() { _busy = true; _error = null; _message = null; });
    try { await action(); await _refresh(); }
    catch (e) { if (mounted) setState(() => _error = e.toString()); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _import() async {
    await _run(() async {
      final count = await _service.importBackup();
      if (mounted) setState(() => _message = '$count Favoriten importiert bzw. abgeglichen.');
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Favoriten sichern & übertragen')),
    body: AbsorbPointer(
      absorbing: _busy,
      child: FocusTraversalGroup(child: ListView(padding: const EdgeInsets.all(24), children: [
        const Text('Deine Favoriten sind mit deinem Streamia-Konto verknüpft. Melde dich auf einem neuen Gerät mit demselben Konto an, um sie automatisch zu synchronisieren.', style: TextStyle(fontSize: 16)),
        const SizedBox(height: 20),
        _countTile(Icons.live_tv, 'Sender-Favoriten', _counts['live']!),
        _countTile(Icons.movie, 'Film-Favoriten', _counts['vod']!),
        _countTile(Icons.video_library, 'Serien-Favoriten', _counts['series']!),
        const Divider(height: 32),
        FilledButton.icon(onPressed: () => _run(() => _service.exportBackup()), icon: const Icon(Icons.download), label: const Text('Alle Favoriten herunterladen')),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: () => _run(() => _service.exportBackup(onlyType: 'live')), icon: const Icon(Icons.tv), label: const Text('Nur Sender exportieren')),
        OutlinedButton.icon(onPressed: () => _run(() => _service.exportBackup(onlyType: 'vod')), icon: const Icon(Icons.movie), label: const Text('Nur Filme exportieren')),
        OutlinedButton.icon(onPressed: () => _run(() => _service.exportBackup(onlyType: 'series')), icon: const Icon(Icons.video_library), label: const Text('Nur Serien exportieren')),
        const SizedBox(height: 16),
        FilledButton.tonalIcon(onPressed: _import, icon: const Icon(Icons.upload_file), label: const Text('Favoriten-Backup importieren')),
        const SizedBox(height: 12),
        if (_busy) const Center(child: CircularProgressIndicator()),
        if (_message != null) Text(_message!, style: const TextStyle(color: Colors.green)),
        if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        const SizedBox(height: 16),
        const Text('Hinweis: Das Backup enthält nur Favoriten-Metadaten (Titel, Typ und Quellkennung), niemals Playlist-Passwörter, Stream-URLs oder Medieninhalte.', style: TextStyle(fontSize: 13)),
      ])),
    ),
  );

  Widget _countTile(IconData icon, String title, int count) => Card(
    child: ListTile(leading: Icon(icon), title: Text(title), trailing: Text('$count')),
  );
}
