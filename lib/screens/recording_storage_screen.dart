
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RecordingStorageScreen extends StatefulWidget {
  const RecordingStorageScreen({super.key});

  @override
  State<RecordingStorageScreen> createState() =>
      _RecordingStorageScreenState();
}

class _RecordingStorageScreenState
    extends State<RecordingStorageScreen> {
  static const MethodChannel _channel =
      MethodChannel('com.streamia/recording');

  bool _loading = true;
  bool _busy = false;
  String? _folderUri;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFolder();
  }

  String _text(
    String de,
    String tr,
    String en,
  ) {
    final language =
        Localizations.localeOf(context).languageCode;

    if (language == 'de') return de;
    if (language == 'tr') return tr;
    return en;
  }

  Future<void> _loadFolder() async {
    try {
      final folder =
          await _channel.invokeMethod<String>(
        'getRecordingFolder',
      );

      if (!mounted) return;

      setState(() {
        _folderUri = folder;
        _error = null;
        _loading = false;
      });
    } on PlatformException catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.message ?? e.code;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _chooseFolder() async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final folder =
          await _channel.invokeMethod<String>(
        'chooseRecordingFolder',
      );

      if (!mounted) return;

      if (folder != null && folder.isNotEmpty) {
        setState(() {
          _folderUri = folder;
        });
      }
    } on PlatformException catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.message ?? e.code;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _clearFolder() async {
    if (_busy || _folderUri == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          _text(
            'Aufnahmeordner zurücksetzen?',
            'Kayıt klasörü sıfırlansın mı?',
            'Reset recording folder?',
          ),
        ),
        content: Text(
          _text(
            'Die gespeicherte Ordnerfreigabe wird entfernt. '
                'Vorhandene Dateien werden nicht gelöscht.',
            'Kaydedilen klasör izni kaldırılacak. '
                'Mevcut dosyalar silinmeyecek.',
            'The saved folder permission will be removed. '
                'Existing files will not be deleted.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: Text(
              _text(
                'Abbrechen',
                'İptal',
                'Cancel',
              ),
            ),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            child: Text(
              _text(
                'Zurücksetzen',
                'Sıfırla',
                'Reset',
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await _channel.invokeMethod<bool>(
        'clearRecordingFolder',
      );

      if (!mounted) return;

      setState(() {
        _folderUri = null;
      });
    } on PlatformException catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.message ?? e.code;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _text(
            'Aufnahmespeicher',
            'Kayıt depolama alanı',
            'Recording storage',
          ),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : FocusTraversalGroup(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Icon(
                      Icons.storage_rounded,
                      size: 52,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _text(
                        'Speicherort für Aufnahmen',
                        'Kayıtların depolama konumu',
                        'Recording storage location',
                      ),
                      style:
                          theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _text(
                        'Wähle einen Ordner auf deinem Gerät '
                            'oder auf einem angeschlossenen '
                            'USB-Stick bzw. einer Festplatte.',
                        'Cihazında veya bağlı bir USB bellek '
                            'ya da sabit diskte klasör seç.',
                        'Choose a folder on your device '
                            'or a connected USB drive.',
                      ),
                    ),
                    const SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding:
                            const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              _text(
                                'Gespeicherter Ordner',
                                'Kaydedilen klasör',
                                'Saved folder',
                              ),
                              style: theme
                                  .textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(
                                  _folderUri == null
                                      ? Icons.folder_off_outlined
                                      : Icons.folder_rounded,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _folderUri == null
                                        ? _text(
                                            'Kein Ordner ausgewählt',
                                            'Klasör seçilmedi',
                                            'No folder selected',
                                          )
                                        : _text(
                                            'Ordnerfreigabe gespeichert',
                                            'Klasör izni kaydedildi',
                                            'Folder permission saved',
                                          ),
                                  ),
                                ),
                              ],
                            ),
                            if (_folderUri != null) ...[
                              const SizedBox(height: 12),
                              SelectableText(
                                _folderUri!,
                                style: theme
                                    .textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed:
                          _busy ? null : _chooseFolder,
                      icon: const Icon(
                        Icons.create_new_folder_outlined,
                      ),
                      label: Text(
                        _text(
                          'Aufnahmeordner auswählen',
                          'Kayıt klasörü seç',
                          'Choose recording folder',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed:
                          _busy || _folderUri == null
                              ? null
                              : _clearFolder,
                      icon: const Icon(
                        Icons.folder_off_outlined,
                      ),
                      label: Text(
                        _text(
                          'Ordnerfreigabe zurücksetzen',
                          'Klasör iznini sıfırla',
                          'Reset folder permission',
                        ),
                      ),
                    ),
                    if (_busy) ...[
                      const SizedBox(height: 20),
                      const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 20),
                      Card(
                        color:
                            colorScheme.errorContainer,
                        child: Padding(
                          padding:
                              const EdgeInsets.all(16),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: colorScheme
                                  .onErrorContainer,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding:
                            const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              _text(
                                'Hinweise',
                                'Bilgiler',
                                'Information',
                              ),
                              style: theme
                                  .textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _text(
                                'Streamia formatiert keine '
                                    'Speichermedien. NTFS, exFAT '
                                    'und FAT32 funktionieren nur, '
                                    'wenn Android das Laufwerk '
                                    'beschreiben kann.',
                                'Streamia depolama aygıtlarını '
                                    'biçimlendirmez. NTFS, exFAT '
                                    've FAT32 yalnızca Android '
                                    'yazma erişimi sağlarsa çalışır.',
                                'Streamia never formats storage. '
                                    'NTFS, exFAT and FAT32 work '
                                    'only when Android allows '
                                    'writing to the drive.',
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _text(
                                'Die Ordnerauswahl speichert '
                                    'zunächst nur die Berechtigung. '
                                    'Automatisches Speichern und '
                                    'Speicherlimits folgen.',
                                'Klasör seçimi şimdilik yalnızca '
                                    'izni kaydeder. Otomatik kayıt '
                                    've depolama sınırları '
                                    'daha sonra eklenecek.',
                                'Folder selection currently saves '
                                    'permission only. Automatic '
                                    'saving and storage limits '
                                    'will be added next.',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
