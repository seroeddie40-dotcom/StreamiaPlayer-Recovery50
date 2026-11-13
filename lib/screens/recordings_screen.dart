import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path_provider/path_provider.dart';

import '../services/recording_service.dart';

/// Local recordings saved by the Android recording foreground service.
/// This screen does not modify USB partitions or require storage permissions.
class RecordingsScreen extends StatefulWidget {
  const RecordingsScreen({super.key});

  @override
  State<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends State<RecordingsScreen> {
  List<File> _files = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final root = await getExternalStorageDirectory();
      if (root == null) {
        throw const FileSystemException('App-Speicher nicht verfügbar');
      }
      final folder = Directory('${root.path}/recordings');
      final files = await folder.exists()
          ? folder
              .list(followLinks: false)
              .where((entry) => entry is File &&
                  entry.path.toLowerCase().endsWith('.ts'))
              .cast<File>()
              .toList()
          : <File>[];
      files.sort((a, b) =>
          b.statSync().modified.compareTo(a.statSync().modified));
      if (!mounted) return;
      setState(() => _files = files);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Aufnahmen konnten nicht gelesen werden: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _size(int bytes) {
    if (bytes >= 1073741824) {
      return '${(bytes / 1073741824).toStringAsFixed(2)} GB';
    }
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  Future<void> _play(File file) async {
    if (!await file.exists() || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _RecordingPlayback(file: file),
      ),
    );
  }

  Future<void> _delete(File file) async {
    final recording = await RecordingService.refreshStatus();
    if (!mounted) return;
    if (recording.isBusy && recording.outputPath == file.path) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Eine laufende Aufnahme kann nicht gelöscht werden.')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Aufnahme löschen?'),
        content: Text(file.uri.pathSegments.last),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await file.delete();
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aufnahme konnte nicht gelöscht werden.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meine Aufnahmen'),
        actions: [
          IconButton(
            tooltip: 'Aktualisieren',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, textAlign: TextAlign.center),
                ))
              : _files.isEmpty
                  ? const Center(child: Text('Noch keine lokalen Aufnahmen vorhanden.'))
                  : ListView.builder(
                      itemCount: _files.length,
                      itemBuilder: (context, index) {
                        final file = _files[index];
                        final stat = file.statSync();
                        return ListTile(
                          leading: const Icon(Icons.video_library_outlined),
                          title: Text(file.uri.pathSegments.last,
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Text('${_size(stat.size)} · ${stat.modified.toLocal()}'),
                          onTap: () => _play(file),
                          trailing: IconButton(
                            tooltip: 'Aufnahme löschen',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _delete(file),
                          ),
                        );
                      },
                    ),
    );
  }
}

class _RecordingPlayback extends StatefulWidget {
  const _RecordingPlayback({required this.file});
  final File file;

  @override
  State<_RecordingPlayback> createState() => _RecordingPlaybackState();
}

class _RecordingPlaybackState extends State<_RecordingPlayback> {
  late final Player _player;
  late final VideoController _controller;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _player.open(Media(widget.file.uri.toString()));
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.file.uri.pathSegments.last)),
      body: Center(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Video(controller: _controller),
        ),
      ),
    );
  }
}
