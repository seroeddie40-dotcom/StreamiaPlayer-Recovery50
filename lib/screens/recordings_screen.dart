import '../widgets/tv_catalog_focus.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../providers/family_session_provider.dart';
import '../models/family_profile.dart';

import '../services/recording_service.dart';
import '../core/platform/device_layout.dart';


// Screen-local translations. Recording filenames and platform errors remain unchanged.
const Map<String, Map<String, String>> _recordingStrings = {
  'de': {
    'legacyNotice': 'Ältere Aufnahmen ohne Profilzuordnung bleiben gespeichert, werden jedoch nicht angezeigt.',
    'title': 'Meine Aufnahmen',
    'refresh': 'Aktualisieren',
    'empty': 'Noch keine Aufnahmen vorhanden.',
    'deleteQuestion': 'Aufnahme löschen?',
    'cancel': 'Abbrechen',
    'delete': 'Löschen',
    'deleteTooltip': 'Aufnahme löschen',
    'device': 'Gerätespeicher',
    'usb': 'USB / Extern',
    'localReadError': 'Lokale Aufnahmen konnten nicht gelesen werden',
    'usbExtension': 'USB-Aufnahmen benötigen noch die Android-Erweiterung.',
    'usbReadError': 'USB-Speicher konnte nicht gelesen werden.',
    'usbLoadError': 'USB-Aufnahmen konnten nicht geladen werden',
    'usbOpenError': 'USB-Aufnahme konnte nicht geöffnet werden.',
    'fileMissing': 'Aufnahmedatei nicht gefunden',
    'usbPlayError': 'USB-Aufnahme konnte nicht abgespielt werden.',
    'playError': 'Wiedergabe fehlgeschlagen',
    'busyDelete': 'Eine laufende Aufnahme kann nicht gelöscht werden.',
    'deleteNotConfirmed': 'Löschen wurde nicht bestätigt.',
    'deleted': 'Aufnahme gelöscht.',
    'deleteError': 'Aufnahme konnte nicht gelöscht werden.',
    'deleteFailed': 'Löschen fehlgeschlagen',
    'defaultName': 'Aufnahme.ts',
  },
  'en': {
    'legacyNotice': 'Older recordings without a profile assignment are retained but not displayed.',
    'title': 'My recordings',
    'refresh': 'Refresh',
    'empty': 'No recordings yet.',
    'deleteQuestion': 'Delete recording?',
    'cancel': 'Cancel',
    'delete': 'Delete',
    'deleteTooltip': 'Delete recording',
    'device': 'Device storage',
    'usb': 'USB / External',
    'localReadError': 'Could not read local recordings',
    'usbExtension': 'USB recordings require the Android extension.',
    'usbReadError': 'Could not read USB storage.',
    'usbLoadError': 'Could not load USB recordings',
    'usbOpenError': 'Could not open USB recording.',
    'fileMissing': 'Recording file not found',
    'usbPlayError': 'Could not play USB recording.',
    'playError': 'Playback failed',
    'busyDelete': 'An active recording cannot be deleted.',
    'deleteNotConfirmed': 'Deletion was not confirmed.',
    'deleted': 'Recording deleted.',
    'deleteError': 'Could not delete recording.',
    'deleteFailed': 'Deletion failed',
    'defaultName': 'Recording.ts',
  },
  'tr': {
    'legacyNotice': 'Profil ataması olmayan eski kayıtlar saklanır ancak gösterilmez.',
    'title': 'Kayıtlarım',
    'refresh': 'Yenile',
    'empty': 'Henüz kayıt yok.',
    'deleteQuestion': 'Kayıt silinsin mi?',
    'cancel': 'İptal',
    'delete': 'Sil',
    'deleteTooltip': 'Kaydı sil',
    'device': 'Cihaz depolama',
    'usb': 'USB / Harici',
    'localReadError': 'Yerel kayıtlar okunamadı',
    'usbExtension': 'USB kayıtları için Android uzantısı gerekli.',
    'usbReadError': 'USB depolama okunamadı.',
    'usbLoadError': 'USB kayıtları yüklenemedi',
    'usbOpenError': 'USB kaydı açılamadı.',
    'fileMissing': 'Kayıt dosyası bulunamadı',
    'usbPlayError': 'USB kaydı oynatılamadı.',
    'playError': 'Oynatma başarısız',
    'busyDelete': 'Devam eden bir kayıt silinemez.',
    'deleteNotConfirmed': 'Silme işlemi onaylanmadı.',
    'deleted': 'Kayıt silindi.',
    'deleteError': 'Kayıt silinemedi.',
    'deleteFailed': 'Silme başarısız',
    'defaultName': 'Kayıt.ts',
  },
  'ru': {
    'legacyNotice': 'Старые записи без профиля сохранены, но не отображаются.',
    'title': 'Мои записи',
    'refresh': 'Обновить',
    'empty': 'Записей пока нет.',
    'deleteQuestion': 'Удалить запись?',
    'cancel': 'Отмена',
    'delete': 'Удалить',
    'deleteTooltip': 'Удалить запись',
    'device': 'Память устройства',
    'usb': 'USB / Внешний',
    'localReadError': 'Не удалось прочитать локальные записи',
    'usbExtension': 'Для USB-записей требуется расширение Android.',
    'usbReadError': 'Не удалось прочитать USB-накопитель.',
    'usbLoadError': 'Не удалось загрузить USB-записи',
    'usbOpenError': 'Не удалось открыть USB-запись.',
    'fileMissing': 'Файл записи не найден',
    'usbPlayError': 'Не удалось воспроизвести USB-запись.',
    'playError': 'Ошибка воспроизведения',
    'busyDelete': 'Нельзя удалить текущую запись.',
    'deleteNotConfirmed': 'Удаление не подтверждено.',
    'deleted': 'Запись удалена.',
    'deleteError': 'Не удалось удалить запись.',
    'deleteFailed': 'Ошибка удаления',
    'defaultName': 'Запись.ts',
  },
  'pl': {
    'legacyNotice': 'Starsze nagrania bez przypisanego profilu są zachowane, ale niewidoczne.',
    'title': 'Moje nagrania',
    'refresh': 'Odśwież',
    'empty': 'Brak nagrań.',
    'deleteQuestion': 'Usunąć nagranie?',
    'cancel': 'Anuluj',
    'delete': 'Usuń',
    'deleteTooltip': 'Usuń nagranie',
    'device': 'Pamięć urządzenia',
    'usb': 'USB / Zewnętrzna',
    'localReadError': 'Nie można odczytać nagrań lokalnych',
    'usbExtension': 'Nagrania USB wymagają rozszerzenia Android.',
    'usbReadError': 'Nie można odczytać pamięci USB.',
    'usbLoadError': 'Nie można wczytać nagrań USB',
    'usbOpenError': 'Nie można otworzyć nagrania USB.',
    'fileMissing': 'Nie znaleziono pliku nagrania',
    'usbPlayError': 'Nie można odtworzyć nagrania USB.',
    'playError': 'Błąd odtwarzania',
    'busyDelete': 'Nie można usunąć trwającego nagrania.',
    'deleteNotConfirmed': 'Nie potwierdzono usunięcia.',
    'deleted': 'Nagranie usunięte.',
    'deleteError': 'Nie można usunąć nagrania.',
    'deleteFailed': 'Błąd usuwania',
    'defaultName': 'Nagranie.ts',
  },
  'es': {
    'legacyNotice': 'Las grabaciones antiguas sin perfil se conservan, pero no se muestran.',
    'title': 'Mis grabaciones',
    'refresh': 'Actualizar',
    'empty': 'Todavía no hay grabaciones.',
    'deleteQuestion': '¿Eliminar grabación?',
    'cancel': 'Cancelar',
    'delete': 'Eliminar',
    'deleteTooltip': 'Eliminar grabación',
    'device': 'Almacenamiento del dispositivo',
    'usb': 'USB / Externo',
    'localReadError': 'No se pudieron leer las grabaciones locales',
    'usbExtension': 'Las grabaciones USB requieren la extensión de Android.',
    'usbReadError': 'No se pudo leer el almacenamiento USB.',
    'usbLoadError': 'No se pudieron cargar las grabaciones USB',
    'usbOpenError': 'No se pudo abrir la grabación USB.',
    'fileMissing': 'Archivo de grabación no encontrado',
    'usbPlayError': 'No se pudo reproducir la grabación USB.',
    'playError': 'Error de reproducción',
    'busyDelete': 'No se puede eliminar una grabación en curso.',
    'deleteNotConfirmed': 'No se confirmó la eliminación.',
    'deleted': 'Grabación eliminada.',
    'deleteError': 'No se pudo eliminar la grabación.',
    'deleteFailed': 'Error al eliminar',
    'defaultName': 'Grabación.ts',
  },
  'fr': {
    'legacyNotice': 'Les anciens enregistrements sans profil sont conservés mais non affichés.',
    'title': 'Mes enregistrements',
    'refresh': 'Actualiser',
    'empty': 'Aucun enregistrement.',
    'deleteQuestion': 'Supprimer cet enregistrement ?',
    'cancel': 'Annuler',
    'delete': 'Supprimer',
    'deleteTooltip': 'Supprimer l’enregistrement',
    'device': 'Stockage de l’appareil',
    'usb': 'USB / Externe',
    'localReadError': 'Impossible de lire les enregistrements locaux',
    'usbExtension': 'Les enregistrements USB nécessitent l’extension Android.',
    'usbReadError': 'Impossible de lire le stockage USB.',
    'usbLoadError': 'Impossible de charger les enregistrements USB',
    'usbOpenError': 'Impossible d’ouvrir l’enregistrement USB.',
    'fileMissing': 'Fichier d’enregistrement introuvable',
    'usbPlayError': 'Impossible de lire l’enregistrement USB.',
    'playError': 'Échec de la lecture',
    'busyDelete': 'Impossible de supprimer un enregistrement en cours.',
    'deleteNotConfirmed': 'Suppression non confirmée.',
    'deleted': 'Enregistrement supprimé.',
    'deleteError': 'Impossible de supprimer l’enregistrement.',
    'deleteFailed': 'Échec de la suppression',
    'defaultName': 'Enregistrement.ts',
  },
  'ar': {
    'legacyNotice': 'يتم الاحتفاظ بالتسجيلات القديمة غير المرتبطة بملف شخصي دون عرضها.',
    'title': 'تسجيلاتي',
    'refresh': 'تحديث',
    'empty': 'لا توجد تسجيلات بعد.',
    'deleteQuestion': 'هل تريد حذف التسجيل؟',
    'cancel': 'إلغاء',
    'delete': 'حذف',
    'deleteTooltip': 'حذف التسجيل',
    'device': 'ذاكرة الجهاز',
    'usb': 'USB / خارجي',
    'localReadError': 'تعذرت قراءة التسجيلات المحلية',
    'usbExtension': 'تتطلب تسجيلات USB إضافة أندرويد.',
    'usbReadError': 'تعذرت قراءة وحدة تخزين USB.',
    'usbLoadError': 'تعذر تحميل تسجيلات USB',
    'usbOpenError': 'تعذر فتح تسجيل USB.',
    'fileMissing': 'ملف التسجيل غير موجود',
    'usbPlayError': 'تعذر تشغيل تسجيل USB.',
    'playError': 'فشل التشغيل',
    'busyDelete': 'لا يمكن حذف تسجيل جارٍ.',
    'deleteNotConfirmed': 'لم يتم تأكيد الحذف.',
    'deleted': 'تم حذف التسجيل.',
    'deleteError': 'تعذر حذف التسجيل.',
    'deleteFailed': 'فشل الحذف',
    'defaultName': 'تسجيل.ts',
  },
};

class RecordingsScreen extends StatefulWidget {
  const RecordingsScreen({super.key, this.managedChild});
  final FamilyProfile? managedChild;

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

String? _recordingOwner(FamilySessionProvider family) {
  final profile = family.activeProfile;
  if (!family.isReady || profile == null) return null;
  return RecordingService.ownerKey(profile.accountUserId, profile.id);
}

class _RecordingsScreenState extends State<RecordingsScreen> {
  static const MethodChannel _channel =
      MethodChannel('com.streamia/recording');

  String _t(String key) {
    final language = Localizations.localeOf(context).languageCode;
    return (_recordingStrings[language] ?? _recordingStrings['en']!)[key] ?? key;
  }

  List<_RecordingEntry> _recordings = [];
  bool _loading = true;
  String? _error;
  String? _usbWarning;
  bool _hasLegacy = false;

  late final FamilySessionProvider _family;
  String? _loadedOwner;
  int _loadGeneration = 0;

  String? _visibleOwner(FamilySessionProvider family) {
    final child = widget.managedChild;
    if (child == null) return _recordingOwner(family);
    if (family.parentAccessToken == null || !child.isChild || family.activeProfile?.accountUserId != child.accountUserId) return null;
    return RecordingService.ownerKey(child.accountUserId, child.id);
  }

  bool _owns(_RecordingEntry entry) {
    final owner = _visibleOwner(_family);
    return owner != null && RecordingService.ownsName(entry.name, owner);
  }

  void _familyChanged() {
    if (_visibleOwner(_family) != _loadedOwner) _load();
  }

  @override
  void initState() {
    super.initState();
    _family = context.read<FamilySessionProvider>();
    _family.addListener(_familyChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _load(); });
  }

  @override
  void dispose() {
    _family.removeListener(_familyChanged);
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;

    final owner = _visibleOwner(_family);
    final generation = ++_loadGeneration;
    _loadedOwner = owner;
    setState(() {
      _recordings = [];
      _loading = owner != null;
      _error = null;
      _usbWarning = null;
      _hasLegacy = false;
    });

    if (owner == null) return;
    final entries = <_RecordingEntry>[];
    String? errorMessage;
    String? usbWarning;
    bool hasLegacy = false;

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

            final name = entity.uri.pathSegments.last;
            if (!RecordingService.ownsName(name, owner)) {
              if (!name.startsWith('sp_')) hasLegacy = true;
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
      errorMessage = mounted ? _t('localReadError') : null;
    }

    try {
      final raw = await _channel.invokeMethod<List<dynamic>>(
        'listUsbRecordings',
      );

      for (final item in raw ?? <dynamic>[]) {
        if (item is! Map) continue;

        final data = Map<String, dynamic>.from(item);

        final uri = data['uri']?.toString() ?? '';
        final name = data['name']?.toString() ?? '';
        if (uri.isEmpty) continue;
        if (!RecordingService.ownsName(name, owner)) {
          if (name.toLowerCase().endsWith('.ts') && !name.startsWith('sp_')) hasLegacy = true;
          continue;
        }

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
            name: name,
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
      usbWarning = mounted ? _t('usbExtension') : null;
    } on PlatformException catch (error) {
      usbWarning = mounted ? _t('usbReadError') : null;
    } catch (error) {
      usbWarning = mounted ? _t('usbLoadError') : null;
    }

    entries.sort((a, b) {
      final aTime = a.modified?.millisecondsSinceEpoch ?? 0;
      final bTime = b.modified?.millisecondsSinceEpoch ?? 0;
      return bTime.compareTo(aTime);
    });

    if (!mounted || generation != _loadGeneration || _visibleOwner(_family) != owner) return;

    setState(() {
      _error = errorMessage;
      _usbWarning = usbWarning;
      _recordings = entries;
      _hasLegacy = hasLegacy;
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
    if (widget.managedChild != null || !_owns(entry)) return;
    final owner = _visibleOwner(_family)!;
    File? temporary;
    try {
      String path = entry.location;

      if (entry.isUsb) {
        final prepared = await _channel.invokeMethod<String>(
          'prepareUsbRecordingPlayback',
          {'uri': entry.location},
        );

        if (prepared == null || prepared.isEmpty) {
          throw StateError(_t('usbOpenError'));
        }

        path = prepared;
        temporary = File(path);
      }

      final file = File(path);

      if (!await file.exists()) {
        throw FileSystemException(
          _t('fileMissing'),
        );
      }

      if (!mounted) return;
      if (!_owns(entry) || _visibleOwner(_family) != owner) return;

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _RecordingPlayback(
            file: file,
            title: entry.name.substring(68),
            ownerKey: owner,
            temporaryFile: entry.isUsb,
          ),
        ),
      );
    } on PlatformException catch (error) {
      _message(
        error.message ?? _t('usbPlayError'),
      );
    } catch (error) {
      if (mounted) _message(_t('playError'));
    } finally {
      if (temporary != null) { try { if (await temporary.exists()) await temporary.delete(); } catch (_) {} }
    }
  }

  Future<void> _delete(_RecordingEntry entry) async {
    if (!_owns(entry)) return;
    try {
      final status = await RecordingService.refreshStatus();

      if (!mounted || !_owns(entry)) return;

      if (status.isBusy &&
          (status.outputPath == entry.location || status.ownerKey == _visibleOwner(_family))) {
        _message(
          _t('busyDelete'),
        );
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(_t('deleteQuestion')),
          content: Text(entry.name.substring(68)),
          actions: [
            TextButton(
              autofocus: true,
              onPressed: () =>
                  Navigator.pop(dialogContext, false),
              child: Text(_t('cancel')),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, true),
              child: Text(_t('delete')),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted || !_owns(entry)) return;
      final latest = await RecordingService.refreshStatus();
      if (!mounted || !_owns(entry)) return;
      if (latest.isBusy && (latest.outputPath == entry.location || latest.ownerKey == _visibleOwner(_family))) { _message(_t('busyDelete')); return; }

      if (entry.isUsb) {
        final deleted = await _channel.invokeMethod<bool>(
          'deleteUsbRecording',
          {'uri': entry.location},
        );

        if (deleted != true) {
          throw StateError(_t('deleteNotConfirmed'));
        }
      } else {
        final file = File(entry.location);
        if (await file.exists()) {
          await file.delete();
        }
        if (await file.exists()) {
          throw StateError(_t('deleteFailed'));
        }
      }

      await _load();
      _message(_t('deleted'));
    } on PlatformException catch (error) {
      _message(
        error.message ?? _t('deleteError'),
      );
    } catch (error) {
      _message('${_t('deleteFailed')}: $error');
    }
  }

  Widget _buildRecordingTile(_RecordingEntry entry) {
    final date = entry.modified?.toLocal().toString();

    final isTv = DeviceLayout.isTelevision;
    return TvCatalogFocus(child: Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 5,
      ),
      child: ListTile(
        autofocus: isTv && _recordings.isNotEmpty &&
            identical(entry, _recordings.first),
        focusColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: EdgeInsets.symmetric(
          horizontal: isTv ? 24 : 16,
          vertical: isTv ? 12 : 0,
        ),
        leading: Icon(
          entry.isUsb
              ? Icons.usb
              : Icons.video_library_outlined,
        ),
        title: Text(
          entry.name.substring(68),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${entry.isUsb ? _t('usb') : _t('device')}'
          ' · ${_size(entry.size)}'
          '${date == null ? "" : " · $date"}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: widget.managedChild == null ? () => _play(entry) : null,
        trailing: IconButton(
          tooltip: _t('deleteTooltip'),
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _delete(entry),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final family = context.watch<FamilySessionProvider>();
    if (_visibleOwner(family) == null || _visibleOwner(family) != _loadedOwner) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.managedChild == null ? _t('title') : '${_t('title')} · ${widget.managedChild!.displayName}'),
        actions: [
          IconButton(
            tooltip: _t('refresh'),
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
                  if (_hasLegacy && widget.managedChild == null && family.parentAccessToken != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_t('legacyNotice'), textAlign: TextAlign.center),
                    ),
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
                    Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(
                        child: Text(
                          _t('empty'),
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
    required this.ownerKey,
  });

  final File file;
  final String title;
  final bool temporaryFile;
  final String ownerKey;

  @override
  State<_RecordingPlayback> createState() =>
      _RecordingPlaybackState();
}

class _RecordingPlaybackState
    extends State<_RecordingPlayback> {
  late final Player _player;
  late final VideoController _controller;
  late final FamilySessionProvider _familySession;

  bool _revoked = false;
  void _onFamilyChanged() {
    if (_recordingOwner(_familySession) != widget.ownerKey) {
      _revoked = true;
      _player.stop();
    }
  }

  @override
  void initState() {
    super.initState();

    _familySession = context.read<FamilySessionProvider>();
    _familySession.addListener(_onFamilyChanged);
    _player = Player();
    _controller = VideoController(_player);

    final family = context.read<FamilySessionProvider>();
    if (_recordingOwner(family) == widget.ownerKey) {
      _player.open(Media(widget.file.uri.toString()));
    }
  }

  @override
  void dispose() {
    _familySession.removeListener(_onFamilyChanged);
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
    final family = context.watch<FamilySessionProvider>();
    if (_revoked || _recordingOwner(family) != widget.ownerKey) {
      return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
    }
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
