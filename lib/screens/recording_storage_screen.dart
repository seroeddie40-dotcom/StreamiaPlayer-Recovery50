
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

  // Screen-local labels. Provider filenames and Android errors remain unchanged.
  static const Map<String, Map<String, String>> _labels = {
    'de': {
      'resetTitle': 'Aufnahmeordner zurücksetzen?',
      'resetBody': 'Die gespeicherte Ordnerfreigabe wird entfernt. Vorhandene Dateien werden nicht gelöscht.',
      'cancel': 'Abbrechen',
      'reset': 'Zurücksetzen',
      'screenTitle': 'Aufnahmespeicher',
      'locationTitle': 'Speicherort für Aufnahmen',
      'locationHelp': 'Wähle einen Ordner auf deinem Gerät oder auf einem angeschlossenen USB-Stick bzw. einer Festplatte.',
      'savedFolder': 'Gespeicherter Ordner',
      'noFolder': 'Kein Ordner ausgewählt',
      'permissionSaved': 'Ordnerfreigabe gespeichert',
      'chooseFolder': 'Aufnahmeordner auswählen',
      'resetPermission': 'Ordnerfreigabe zurücksetzen',
      'info': 'Hinweise',
      'formatNotice': 'Streamia formatiert keine Speichermedien. NTFS, exFAT und FAT32 funktionieren nur, wenn Android das Laufwerk beschreiben kann.',
      'permissionNotice': 'Die Ordnerauswahl speichert zunächst nur die Berechtigung. Automatisches Speichern und Speicherlimits folgen.',
    },
    'tr': {
      'resetTitle': 'Kayıt klasörü sıfırlansın mı?',
      'resetBody': 'Kaydedilen klasör izni kaldırılacak. Mevcut dosyalar silinmeyecek.',
      'cancel': 'İptal',
      'reset': 'Sıfırla',
      'screenTitle': 'Kayıt depolama alanı',
      'locationTitle': 'Kayıtların depolama konumu',
      'locationHelp': 'Cihazında veya bağlı bir USB bellek ya da sabit diskte klasör seç.',
      'savedFolder': 'Kaydedilen klasör',
      'noFolder': 'Klasör seçilmedi',
      'permissionSaved': 'Klasör izni kaydedildi',
      'chooseFolder': 'Kayıt klasörü seç',
      'resetPermission': 'Klasör iznini sıfırla',
      'info': 'Bilgiler',
      'formatNotice': 'Streamia depolama aygıtlarını biçimlendirmez. NTFS, exFAT ve FAT32 yalnızca Android yazma erişimi sağlarsa çalışır.',
      'permissionNotice': 'Klasör seçimi şimdilik yalnızca izni kaydeder. Otomatik kayıt ve depolama sınırları daha sonra eklenecek.',
    },
    'en': {
      'resetTitle': 'Reset recording folder?',
      'resetBody': 'The saved folder permission will be removed. Existing files will not be deleted.',
      'cancel': 'Cancel',
      'reset': 'Reset',
      'screenTitle': 'Recording storage',
      'locationTitle': 'Recording storage location',
      'locationHelp': 'Choose a folder on your device or a connected USB drive.',
      'savedFolder': 'Saved folder',
      'noFolder': 'No folder selected',
      'permissionSaved': 'Folder permission saved',
      'chooseFolder': 'Choose recording folder',
      'resetPermission': 'Reset folder permission',
      'info': 'Information',
      'formatNotice': 'Streamia never formats storage. NTFS, exFAT and FAT32 work only when Android allows writing to the drive.',
      'permissionNotice': 'Folder selection currently saves permission only. Automatic saving and storage limits will be added next.',
    },
    'ru': {
      'resetTitle': 'Сбросить папку записей?',
      'resetBody': 'Сохранённое разрешение на доступ к папке будет удалено. Существующие файлы не будут удалены.',
      'cancel': 'Отмена',
      'reset': 'Сбросить',
      'screenTitle': 'Хранилище записей',
      'locationTitle': 'Место хранения записей',
      'locationHelp': 'Выберите папку на устройстве или подключённом USB-накопителе.',
      'savedFolder': 'Сохранённая папка',
      'noFolder': 'Папка не выбрана',
      'permissionSaved': 'Разрешение на доступ к папке сохранено',
      'chooseFolder': 'Выбрать папку для записей',
      'resetPermission': 'Сбросить разрешение на папку',
      'info': 'Информация',
      'formatNotice': 'Streamia не форматирует накопители. NTFS, exFAT и FAT32 работают, только если Android разрешает запись на диск.',
      'permissionNotice': 'Выбор папки пока сохраняет только разрешение. Автоматическое сохранение и ограничения объёма будут добавлены позже.',
    },
    'pl': {
      'resetTitle': 'Zresetować folder nagrań?',
      'resetBody': 'Zapisane uprawnienie dostępu do folderu zostanie usunięte. Istniejące pliki nie zostaną usunięte.',
      'cancel': 'Anuluj',
      'reset': 'Resetuj',
      'screenTitle': 'Pamięć nagrań',
      'locationTitle': 'Lokalizacja nagrań',
      'locationHelp': 'Wybierz folder na urządzeniu lub podłączonym dysku USB.',
      'savedFolder': 'Zapisany folder',
      'noFolder': 'Nie wybrano folderu',
      'permissionSaved': 'Uprawnienie do folderu zapisane',
      'chooseFolder': 'Wybierz folder nagrań',
      'resetPermission': 'Zresetuj uprawnienie do folderu',
      'info': 'Informacje',
      'formatNotice': 'Streamia nie formatuje nośników. NTFS, exFAT i FAT32 działają tylko wtedy, gdy Android zezwala na zapis na dysku.',
      'permissionNotice': 'Wybór folderu zapisuje na razie tylko uprawnienie. Automatyczne zapisywanie i limity pamięci zostaną dodane później.',
    },
    'es': {
      'resetTitle': '¿Restablecer la carpeta de grabaciones?',
      'resetBody': 'Se eliminará el permiso guardado de la carpeta. Los archivos existentes no se eliminarán.',
      'cancel': 'Cancelar',
      'reset': 'Restablecer',
      'screenTitle': 'Almacenamiento de grabaciones',
      'locationTitle': 'Ubicación de las grabaciones',
      'locationHelp': 'Elige una carpeta del dispositivo o de una unidad USB conectada.',
      'savedFolder': 'Carpeta guardada',
      'noFolder': 'No se ha seleccionado ninguna carpeta',
      'permissionSaved': 'Permiso de carpeta guardado',
      'chooseFolder': 'Elegir carpeta de grabaciones',
      'resetPermission': 'Restablecer permiso de carpeta',
      'info': 'Información',
      'formatNotice': 'Streamia no formatea unidades. NTFS, exFAT y FAT32 solo funcionan si Android permite escribir en la unidad.',
      'permissionNotice': 'Por ahora, elegir una carpeta solo guarda el permiso. El guardado automático y los límites de almacenamiento se añadirán después.',
    },
    'fr': {
      'resetTitle': 'Réinitialiser le dossier des enregistrements ?',
      'resetBody': 'L’autorisation enregistrée pour le dossier sera supprimée. Les fichiers existants ne seront pas effacés.',
      'cancel': 'Annuler',
      'reset': 'Réinitialiser',
      'screenTitle': 'Stockage des enregistrements',
      'locationTitle': 'Emplacement des enregistrements',
      'locationHelp': 'Choisissez un dossier sur votre appareil ou sur un disque USB connecté.',
      'savedFolder': 'Dossier enregistré',
      'noFolder': 'Aucun dossier sélectionné',
      'permissionSaved': 'Autorisation du dossier enregistrée',
      'chooseFolder': 'Choisir le dossier des enregistrements',
      'resetPermission': 'Réinitialiser l’autorisation du dossier',
      'info': 'Informations',
      'formatNotice': 'Streamia ne formate aucun support. NTFS, exFAT et FAT32 ne fonctionnent que si Android autorise l’écriture sur le disque.',
      'permissionNotice': 'Pour le moment, le choix du dossier enregistre uniquement l’autorisation. L’enregistrement automatique et les limites de stockage seront ajoutés plus tard.',
    },
    'ar': {
      'resetTitle': 'إعادة تعيين مجلد التسجيلات؟',
      'resetBody': 'ستتم إزالة إذن الوصول المحفوظ للمجلد. لن تُحذف الملفات الموجودة.',
      'cancel': 'إلغاء',
      'reset': 'إعادة تعيين',
      'screenTitle': 'تخزين التسجيلات',
      'locationTitle': 'موقع حفظ التسجيلات',
      'locationHelp': 'اختر مجلدًا على جهازك أو على وحدة تخزين USB متصلة.',
      'savedFolder': 'المجلد المحفوظ',
      'noFolder': 'لم يتم اختيار مجلد',
      'permissionSaved': 'تم حفظ إذن الوصول إلى المجلد',
      'chooseFolder': 'اختيار مجلد التسجيلات',
      'resetPermission': 'إعادة تعيين إذن المجلد',
      'info': 'معلومات',
      'formatNotice': 'لا يقوم Streamia بتهيئة وحدات التخزين. تعمل NTFS وexFAT وFAT32 فقط عندما يسمح Android بالكتابة على الوحدة.',
      'permissionNotice': 'اختيار المجلد يحفظ الإذن فقط حاليًا. ستُضاف ميزة الحفظ التلقائي وحدود التخزين لاحقًا.',
    },
  };

  String _t(String key) {
    final language = Localizations.localeOf(context).languageCode;
    return _labels[language]?[key] ?? _labels['en']![key]!;
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
          _t('resetTitle'),
        ),
        content: Text(
          _t('resetBody'),
        ),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: Text(
              _t('cancel'),
            ),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            child: Text(
              _t('reset'),
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
          _t('screenTitle'),
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
                      _t('locationTitle'),
                      style:
                          theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _t('locationHelp'),
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
                              _t('savedFolder'),
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
                                        ? _t('noFolder')
                                        : _t('permissionSaved'),
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
                        _t('chooseFolder'),
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
                        _t('resetPermission'),
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
                              _t('info'),
                              style: theme
                                  .textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _t('formatNotice'),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _t('permissionNotice'),
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
