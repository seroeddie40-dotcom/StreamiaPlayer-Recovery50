
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path_provider/path_provider.dart';

import '../services/recording_service.dart';

class RecordingsScreen extends StatefulWidget {
  const RecordingsScreen({super.key});

  @override
  State<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingEntry {
  const _RecordingEntry({
    required this.name,
    required this.location,
    required this.isUsb,
    required this.size,
    required this.modified,
  });

  final String name;
  final String location;
  final bool isUsb;
  final int size;
  final DateTime? modified;
}

class _RecordingsScreenState extends State<RecordingsScreen> {
  static const MethodChannel _channel =
      MethodChannel('com.streamia/recording');

  List<_RecordingEntry> _recordings = [];
  bool _loading = true;
  String? _error;
  String? _usbWarning;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
      _usbWarning = null;
    });

    final entries = <_RecordingEntry>[];

    try {
      final root = await getExternalStorageDirectory();

      if (root != null) {
        final folder = Directory('${root.path}/recordings');

        if (await folder.exists()) {
          await for (final entity
              in folder.list(followLinks: false)) {
            if (entity is! File ||
                !entity.path.toLowerCase().endsWith('.ts')) {
              continue;
            }

            try {
              final stat = await entity.stat();

              entries.add(
                _RecordingEntry(
                  name: entity.uri.pathSegments.last,
                  location: entity.path,
                  isUsb: false,
                  size: stat.size,
                  modified: stat.modified,
                ),
              );
            } catch (_) {
              // Ignore individual files that disappeared.
            }
          }
        }
      }
    } catch (error) {
      _error = 'Lokale Aufnahmen konnten nicht gelesen werden: $error';
    }

    try {
      final raw = await _channel.invokeMethod<List<dynamic>>(
        'listUsbRecordings',
      );

      for (final item in raw ?? <dynamic>[]) {
        if (item is! Map) continue;

        final data = Map<String, dynamic>.from(item);

        final uri = data['uri']?.toString() ?? '';
        if (uri.isEmpty) continue;

        final sizeValue = data['size'];
        final modifiedValue = data['modified'];

        final size = sizeValue is num
            ? sizeValue.toInt()
            : 0;

        final modifiedMillis = modifiedValue is num
            ? modifiedValue.toInt()
            : 0;

        entries.add(
          _RecordingEntry(
            name: data['name']?.toString() ?? 'Aufnahme.ts',
            location: uri,
            isUsb: true,
            size: size,
            modified: modifiedMillis > 0
                ? DateTime.fromMillisecondsSinceEpoch(
                    modifiedMillis,
                  )
                : null,
          ),
        );
      }
    } on MissingPluginException {
      _usbWarning =
          'USB-Aufnahmen benötigen noch die Android-Erweiterung.';
    } on PlatformException catch (error) {
      _usbWarning =
          error.message ?? 'USB-Speicher konnte nicht gelesen werden.';
    } catch (error) {
      _usbWarning = 'USB-Aufnahmen konnten nicht geladen werden: $error';
    }

    entries.sort((a, b) {
      final aTime = a.modified?.millisecondsSinceEpoch ?? 0;
      final bTime = b.modified?.millisecondsSinceEpoch ?? 0;
      return bTime.compareTo(aTime);
    });

    if (!mounted) return;

    setState(() {
      _recordings = entries;
      _loading = false;
    });
  }

  String _size(int bytes) {
    if (bytes >= 1073741824) {
      return '${(bytes / 1073741824).toStringAsFixed(2)} GB';
    }

    if (bytes >= 1048576) {
      return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    }

    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }

    return '$bytes B';
  }

  void _message(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> _play(_RecordingEntry entry) async {
    try {
      String path = entry.location;

      if (entry.isUsb) {
        final prepared = await _channel.invokeMethod<String>(
          'prepareUsbRecordingPlayback',
          {'uri': entry.location},
        );

        if (prepared == null || prepared.isEmpty) {
          throw StateError('USB-Aufnahme konnte nicht geöffnet werden.');
        }

        path = prepared;
      }

      final file = File(path);

      if (!await file.exists()) {
        throw const FileSystemException(
          'Aufnahmedatei nicht gefunden',
        );
      }

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _RecordingPlayback(
            file: file,
            title: entry.name,
            temporaryFile: entry.isUsb,
          ),
        ),
      );
    } on PlatformException catch (error) {
      _message(
        error.message ?? 'USB-Aufnahme konnte nicht abgespielt werden.',
      );
    } catch (error) {
      _message('Wiedergabe fehlgeschlagen: $error');
    }
  }

  Future<void> _delete(_RecordingEntry entry) async {
    try {
      final status = await RecordingService.refreshStatus();

      if (!mounted) return;

      if (status.isBusy &&
          status.outputPath == entry.location) {
        _message(
          'Eine laufende Aufnahme kann nicht gelöscht werden.',
        );
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Aufnahme löschen?'),
          content: Text(entry.name),
          actions: [
            TextButton(
              autofocus: true,
              onPressed: () =>
                  Navigator.pop(dialogContext, false),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, true),
              child: const Text('Löschen'),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;

      if (entry.isUsb) {
        final deleted = await _channel.invokeMethod<bool>(
          'deleteUsbRecording',
          {'uri': entry.location},
        );

        if (deleted != true) {
          throw StateError('Löschen wurde nicht bestätigt.');
        }
      } else {
        await File(entry.location).delete();
      }

      await _load();
      _message('Aufnahme gelöscht.');
    } on PlatformException catch (error) {
      _message(
        error.message ?? 'Aufnahme konnte nicht gelöscht werden.',
      );
    } catch (error) {
      _message('Löschen fehlgeschlagen: $error');
    }
  }

  Widget _buildRecordingTile(_RecordingEntry entry) {
    final date = entry.modified?.toLocal().toString();

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 5,
      ),
      child: ListTile(
        leading: Icon(
          entry.isUsb
              ? Icons.usb
              : Icons.video_library_outlined,
        ),
        title: Text(
          entry.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${entry.isUsb ? "USB / Extern" : "Gerätespeicher"}'
          ' · ${_size(entry.size)}'
          '${date == null ? "" : " · $date"}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () => _play(entry),
        trailing: IconButton(
          tooltip: 'Aufnahme löschen',
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _delete(entry),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meine Aufnahmen'),
        actions: [
          IconButton(
            tooltip: 'Aktualisieren',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                children: [
                  if (_usbWarning != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _usbWarning!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .error,
                        ),
                      ),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (_recordings.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(
                        child: Text(
                          'Noch keine Aufnahmen vorhanden.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  for (final entry in _recordings)
                    _buildRecordingTile(entry),
                ],
              ),
            ),
    );
  }
}

class _RecordingPlayback extends StatefulWidget {
  const _RecordingPlayback({
    required this.file,
    required this.title,
    required this.temporaryFile,
  });

  final File file;
  final String title;
  final bool temporaryFile;

  @override
  State<_RecordingPlayback> createState() =>
      _RecordingPlaybackState();
}

class _RecordingPlaybackState
    extends State<_RecordingPlayback> {
  late final Player _player;
  late final VideoController _controller;

  @override
  void initState() {
    super.initState();

    _player = Player();
    _controller = VideoController(_player);

    _player.open(
      Media(widget.file.uri.toString()),
    );
  }

  @override
  void dispose() {
    _player.dispose();

    if (widget.temporaryFile) {
      try {
        widget.file.deleteSync();
      } catch (_) {
        // Cache cleanup is best effort.
      }
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Center(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Video(
            controller: _controller,
          ),
        ),
      ),
    );
  }
}
