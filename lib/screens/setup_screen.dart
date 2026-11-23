import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/content_provider.dart';
import '../services/playlist_parser.dart';
import '../services/xtream_service.dart';
import '../utils/xtream_input_validator.dart';
import '../services/tv_server.dart';
import '../services/playlist_profile_store.dart';
import '../services/playlist_management_service.dart';
import '../models/playlist_source_config.dart';
import '../models/playlist_profile.dart';
import '../core/localization/app_localizations.dart';
import '../core/platform/device_layout.dart';
import '../core/platform/tv_remote_navigation.dart';
import '../widgets/voice_input_field.dart';
import '../widgets/tv_text_keyboard.dart';

class SetupScreen extends StatefulWidget {
  final bool returnToPreviousOnSuccess;
  const SetupScreen({super.key, this.returnToPreviousOnSuccess = false});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _tvTabs = List.generate(3, (i) => FocusNode(debugLabel: 'Setup tab $i'));
  final _tvFirst = List.generate(3, (i) => FocusNode(debugLabel: 'Setup first $i'));

  void _tvTabChanged() {
    if (mounted && DeviceLayout.isTelevision) setState(() {});
  }

  void _selectTvTab(int index, {bool enter = false}) {
    _tabController.index = index;
    if (enter) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _tabController.index == index && !_isLoading) {
          _tvFirst[index].requestFocus();
        }
      });
    } else {
      _tvTabs[index].requestFocus();
    }
  }

  PreferredSizeWidget _tvTabBar(AppLocalizations l10n) {
    final labels = [l10n.t('tab_qr'), l10n.t('tab_m3u'), l10n.t('tab_xtream')];
    const icons = [Icons.qr_code_2, Icons.playlist_play_rounded, Icons.dns_outlined];
    return PreferredSize(
      preferredSize: const Size.fromHeight(60),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Row(children: List.generate(3, (i) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Focus(
              canRequestFocus: false,
              onKeyEvent: (_, event) {
                if (event is! KeyDownEvent) return KeyEventResult.ignored;
                if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                  _selectTvTab(i, enter: true);
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                    event.logicalKey == LogicalKeyboardKey.arrowRight) {
                  final rtl = Directionality.of(context) == TextDirection.rtl;
                  final right = event.logicalKey == LogicalKeyboardKey.arrowRight;
                  final next = i + (right != rtl ? 1 : -1);
                  if (next >= 0 && next < 3) _tvTabs[next].requestFocus();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: OutlinedButton.icon(
                focusNode: _tvTabs[i],
                autofocus: i == 0,
                onPressed: _isLoading ? null : () => _selectTvTab(i, enter: true),
                style: ButtonStyle(
                  minimumSize: WidgetStateProperty.all(const Size(0, 48)),
                  side: WidgetStateProperty.resolveWith((states) => BorderSide(
                    color: states.contains(WidgetState.focused) ? _aqua :
                        (_tabController.index == i ? _blue : const Color(0xFF405575)),
                    width: states.contains(WidgetState.focused) ? 3 : 1,
                  )),
                ),
                icon: Icon(icons[i]),
                label: Text(labels[i], maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ),
        ))),
      ),
    );
  }
  
  final TextEditingController _m3uNameController = TextEditingController(text: 'M3U Playlist');
  final TextEditingController _xtreamNameController = TextEditingController(text: 'Xtream Playlist');
  final TextEditingController _m3uController = TextEditingController();
  final TextEditingController _epgController = TextEditingController();

  String? get _configuredEpgUrl {
    final value = _epgController.text.trim();
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) return null;
    return value;
  }
  final TextEditingController _xtreamServerController = TextEditingController();
  final TextEditingController _xtreamUserController = TextEditingController();
  final TextEditingController _xtreamPassController = TextEditingController();
  final FocusNode _xtreamServerFocus = FocusNode(debugLabel: 'Xtream server');
  final FocusNode _xtreamUserFocus = FocusNode(debugLabel: 'Xtream username');
  final FocusNode _xtreamPassFocus = FocusNode(debugLabel: 'Xtream password');
  final FocusNode _m3uConnectFocus = FocusNode(debugLabel: 'M3U connect');
  final FocusNode _xtreamConnectFocus = FocusNode(debugLabel: 'Xtream connect');

  bool _isLoading = false;
  String? _loadingMessage;
  String? _selectedM3uPath;
  String? _selectedM3uName;
  String? _receivedM3uPath;

  Future<void> _deleteReceivedFile(String path) async {
    try { await File(path).parent.delete(recursive: true); } catch (_) {}
  }

  static const _setupTranslations = <String, Map<String, String>>{
    "Connect your phone and TV to the same local network.": <String, String>{'ru': "Подключите телефон и ТВ к одной локальной сети.", 'pl': "Połącz telefon i telewizor z tą samą siecią lokalną.", 'es': "Conecta el teléfono y el televisor a la misma red local.", 'fr': "Connectez le téléphone et le téléviseur au même réseau local.", 'ar': "وصّل الهاتف والتلفاز بالشبكة المحلية نفسها."},
    "Load EPG file from storage": <String, String>{'ru': "Загрузить файл EPG из памяти", 'pl': "Wczytaj plik EPG z pamięci", 'es': "Cargar archivo EPG del almacenamiento", 'fr': "Charger un fichier EPG depuis le stockage", 'ar': "تحميل ملف EPG من وحدة التخزين"},
    "Load M3U file from storage": <String, String>{'ru': "Загрузить файл M3U из памяти", 'pl': "Wczytaj plik M3U z pamięci", 'es': "Cargar archivo M3U del almacenamiento", 'fr': "Charger un fichier M3U depuis le stockage", 'ar': "تحميل ملف M3U من وحدة التخزين"},
    "The selected file could not be opened.": <String, String>{'ru': "Не удалось открыть выбранный файл.", 'pl': "Nie można otworzyć wybranego pliku.", 'es': "No se pudo abrir el archivo seleccionado.", 'fr': "Impossible d’ouvrir le fichier sélectionné.", 'ar': "تعذر فتح الملف المحدد."},
    "File is too large (maximum 12 MB).": <String, String>{'ru': "Файл слишком большой (максимум 12 МБ).", 'pl': "Plik jest za duży (maksymalnie 12 MB).", 'es': "El archivo es demasiado grande (máximo 12 MB).", 'fr': "Le fichier est trop volumineux (12 Mo maximum).", 'ar': "الملف كبير جدًا (الحد الأقصى 12 ميغابايت)."},
    "Compressed EPG files cannot be inserted as text here. Please use an XML URL.": <String, String>{'ru': "Сжатые файлы EPG нельзя вставить как текст. Используйте URL XML.", 'pl': "Skompresowanych plików EPG nie można wstawić jako tekstu. Użyj adresu XML.", 'es': "No se pueden insertar archivos EPG comprimidos como texto. Usa una URL XML.", 'fr': "Les fichiers EPG compressés ne peuvent pas être insérés comme texte. Utilisez une URL XML.", 'ar': "لا يمكن إدراج ملفات EPG المضغوطة كنص. استخدم رابط XML."},
    "File selection failed. Please try another file.": <String, String>{'ru': "Не удалось выбрать файл. Попробуйте другой.", 'pl': "Nie udało się wybrać pliku. Spróbuj innego.", 'es': "Error al seleccionar el archivo. Prueba con otro.", 'fr': "Échec de la sélection. Essayez un autre fichier.", 'ar': "تعذر اختيار الملف. جرّب ملفًا آخر."},
    "No active access. Please check your account first.": <String, String>{'ru': "Нет активного доступа. Проверьте свой аккаунт.", 'pl': "Brak aktywnego dostępu. Sprawdź konto.", 'es': "No hay acceso activo. Comprueba tu cuenta.", 'fr': "Aucun accès actif. Vérifiez votre compte.", 'ar': "لا يوجد وصول نشط. تحقق من حسابك أولاً."},
    "Multiple playlists exist. Please resolve them in playlist management.": <String, String>{'ru': "Есть несколько плейлистов. Упорядочьте их в управлении плейлистами.", 'pl': "Istnieje kilka playlist. Uporządkuj je w zarządzaniu playlistami.", 'es': "Hay varias listas. Resuélvelo en la gestión de listas.", 'fr': "Plusieurs listes existent. Gérez-les dans le gestionnaire de listes.", 'ar': "توجد عدة قوائم تشغيل. عالج ذلك في إدارة القوائم."},
    "Replace playlist?": <String, String>{'ru': "Заменить плейлист?", 'pl': "Zastąpić playlistę?", 'es': "¿Reemplazar lista?", 'fr': "Remplacer la liste ?", 'ar': "استبدال قائمة التشغيل؟"},
    "Only one playlist is allowed during the trial. The old playlist will be replaced after a successful import. Trial time and devices stay unchanged.": <String, String>{'ru': "В пробный период разрешён один плейлист. Старый будет заменён после успешного импорта. Срок и устройства не изменятся.", 'pl': "W okresie próbnym dozwolona jest jedna playlista. Stara zostanie zastąpiona po udanym imporcie. Okres próbny i urządzenia pozostaną bez zmian.", 'es': "Durante la prueba solo se permite una lista. La anterior se sustituirá tras importar correctamente. El periodo de prueba y los dispositivos no cambian.", 'fr': "Une seule liste est autorisée pendant l’essai. L’ancienne sera remplacée après un import réussi. La durée de l’essai et les appareils restent inchangés.", 'ar': "يُسمح بقائمة واحدة خلال الفترة التجريبية. ستُستبدل القائمة القديمة بعد نجاح الاستيراد. لن تتغير مدة التجربة أو الأجهزة."},
    "Cancel": <String, String>{'ru': "Отмена", 'pl': "Anuluj", 'es': "Cancelar", 'fr': "Annuler", 'ar': "إلغاء"},
    "Replace": <String, String>{'ru': "Заменить", 'pl': "Zastąp", 'es': "Reemplazar", 'fr': "Remplacer", 'ar': "استبدال"},
    "Enter an M3U link or select a file.": <String, String>{'ru': "Введите ссылку M3U или выберите файл.", 'pl': "Wpisz link M3U lub wybierz plik.", 'es': "Introduce un enlace M3U o selecciona un archivo.", 'fr': "Saisissez un lien M3U ou choisissez un fichier.", 'ar': "أدخل رابط M3U أو اختر ملفًا."},
    "Reading local M3U file…": <String, String>{'ru': "Чтение локального файла M3U…", 'pl': "Odczyt lokalnego pliku M3U…", 'es': "Leyendo archivo M3U local…", 'fr': "Lecture du fichier M3U local…", 'ar': "جارٍ قراءة ملف M3U المحلي…"},
    "Could not read or save the M3U file.": <String, String>{'ru': "Не удалось прочитать или сохранить файл M3U.", 'pl': "Nie można odczytać lub zapisać pliku M3U.", 'es': "No se pudo leer o guardar el archivo M3U.", 'fr': "Impossible de lire ou d’enregistrer le fichier M3U.", 'ar': "تعذرت قراءة ملف M3U أو حفظه."},
    "Processing playlist…": <String, String>{'ru': "Обработка плейлиста…", 'pl': "Przetwarzanie playlisty…", 'es': "Procesando lista…", 'fr': "Traitement de la liste…", 'ar': "جارٍ معالجة قائمة التشغيل…"},
    "Could not load or save the playlist.": <String, String>{'ru': "Не удалось загрузить или сохранить плейлист.", 'pl': "Nie można wczytać lub zapisać playlisty.", 'es': "No se pudo cargar o guardar la lista.", 'fr': "Impossible de charger ou d’enregistrer la liste.", 'ar': "تعذر تحميل قائمة التشغيل أو حفظها."},
    "Loading live TV…": <String, String>{'ru': "Загрузка ТВ…", 'pl': "Wczytywanie telewizji…", 'es': "Cargando TV en directo…", 'fr': "Chargement de la TV en direct…", 'ar': "جارٍ تحميل البث المباشر…"},
    "Loading movies…": <String, String>{'ru': "Загрузка фильмов…", 'pl': "Wczytywanie filmów…", 'es': "Cargando películas…", 'fr': "Chargement des films…", 'ar': "جارٍ تحميل الأفلام…"},
    "Loading series…": <String, String>{'ru': "Загрузка сериалов…", 'pl': "Wczytywanie seriali…", 'es': "Cargando series…", 'fr': "Chargement des séries…", 'ar': "جارٍ تحميل المسلسلات…"},
    "Timeout: Server did not respond. Check address, network and credentials.": <String, String>{'ru': "Время ожидания истекло. Проверьте адрес, сеть и данные входа.", 'pl': "Przekroczono czas oczekiwania. Sprawdź adres, sieć i dane logowania.", 'es': "Tiempo agotado. Comprueba la dirección, la red y las credenciales.", 'fr': "Délai dépassé. Vérifiez l’adresse, le réseau et les identifiants.", 'ar': "انتهت مهلة الاتصال. تحقق من العنوان والشبكة وبيانات الدخول."},
    "Invalid server response.": <String, String>{'ru': "Недопустимый ответ сервера.", 'pl': "Nieprawidłowa odpowiedź serwera.", 'es': "Respuesta del servidor no válida.", 'fr': "Réponse du serveur non valide.", 'ar': "استجابة الخادم غير صالحة."},
    "Xtream connection failed. Check credentials and network.": <String, String>{'ru': "Не удалось подключиться к Xtream. Проверьте данные входа и сеть.", 'pl': "Połączenie Xtream nie powiodło się. Sprawdź dane logowania i sieć.", 'es': "Error de conexión Xtream. Comprueba las credenciales y la red.", 'fr': "Échec de la connexion Xtream. Vérifiez les identifiants et le réseau.", 'ar': "فشل اتصال Xtream. تحقق من بيانات الدخول والشبكة."},
    "Your credentials are stored securely.": <String, String>{'ru': "Ваши данные входа защищены при хранении.", 'pl': "Twoje dane logowania są bezpiecznie przechowywane.", 'es': "Tus credenciales se guardan de forma segura.", 'fr': "Vos identifiants sont stockés de façon sécurisée.", 'ar': "تُحفظ بيانات الدخول بأمان."},
    "Loading playlist…": <String, String>{'ru': "Загрузка плейлиста…", 'pl': "Wczytywanie playlisty…", 'es': "Cargando lista…", 'fr': "Chargement de la liste…", 'ar': "جارٍ تحميل قائمة التشغيل…"},
    "Please wait. The bar indicates activity, not an estimated percentage.": <String, String>{'ru': "Подождите. Индикатор показывает активность, а не процент выполнения.", 'pl': "Poczekaj. Pasek pokazuje aktywność, a nie szacowany procent.", 'es': "Espera. La barra indica actividad, no un porcentaje estimado.", 'fr': "Patientez. La barre indique une activité, pas un pourcentage estimé.", 'ar': "يرجى الانتظار. يشير الشريط إلى النشاط وليس نسبة تقديرية."},
    "QR connection unavailable. Use manual setup.": <String, String>{'ru': "QR-подключение недоступно. Используйте ручную настройку.", 'pl': "Połączenie QR niedostępne. Użyj konfiguracji ręcznej.", 'es': "Conexión QR no disponible. Usa la configuración manual.", 'fr': "Connexion QR indisponible. Utilisez la configuration manuelle.", 'ar': "اتصال QR غير متاح. استخدم الإعداد اليدوي."},
    "Device ID": <String, String>{'ru': "ID устройства", 'pl': "Identyfikator urządzenia", 'es': "ID del dispositivo", 'fr': "Identifiant de l’appareil", 'ar': "معرّف الجهاز"},
    "Refresh QR code": <String, String>{'ru': "Обновить QR-код", 'pl': "Odśwież kod QR", 'es': "Renovar código QR", 'fr': "Renouveler le code QR", 'ar': "تجديد رمز QR"},
    "Add M3U playlist": <String, String>{'ru': "Добавить плейлист M3U", 'pl': "Dodaj playlistę M3U", 'es': "Añadir lista M3U", 'fr': "Ajouter une liste M3U", 'ar': "إضافة قائمة M3U"},
    "Enter a playlist link or select a file from your device.": <String, String>{'ru': "Введите ссылку на плейлист или выберите файл на устройстве.", 'pl': "Wpisz link do playlisty lub wybierz plik z urządzenia.", 'es': "Introduce un enlace a la lista o selecciona un archivo de tu dispositivo.", 'fr': "Saisissez un lien ou choisissez un fichier sur votre appareil.", 'ar': "أدخل رابط قائمة التشغيل أو اختر ملفًا من جهازك."},
    "My playlist": <String, String>{'ru': "Мой плейлист", 'pl': "Moja playlista", 'es': "Mi lista", 'fr': "Ma liste", 'ar': "قائمة التشغيل الخاصة بي"},
    "Optional – program guide": <String, String>{'ru': "Необязательно — телепрограмма", 'pl': "Opcjonalnie – przewodnik TV", 'es': "Opcional – guía de programación", 'fr': "Facultatif – guide des programmes", 'ar': "اختياري – دليل البرامج"},
    "Connect Xtream Codes": <String, String>{'ru': "Подключить Xtream Codes", 'pl': "Połącz Xtream Codes", 'es': "Conectar Xtream Codes", 'fr': "Connecter Xtream Codes", 'ar': "ربط Xtream Codes"},
    "Enter the login details provided by your service.": <String, String>{'ru': "Введите данные входа от вашего поставщика.", 'pl': "Wprowadź dane logowania od dostawcy.", 'es': "Introduce los datos de acceso de tu proveedor.", 'fr': "Saisissez les identifiants de votre fournisseur.", 'ar': "أدخل بيانات الدخول التي وفرها مزود الخدمة."},
    "My Xtream playlist": <String, String>{'ru': "Мой плейлист Xtream", 'pl': "Moja playlista Xtream", 'es': "Mi lista Xtream", 'fr': "Ma liste Xtream", 'ar': "قائمة Xtream الخاصة بي"},
    "Username": <String, String>{'ru': "Имя пользователя", 'pl': "Nazwa użytkownika", 'es': "Usuario", 'fr': "Nom d’utilisateur", 'ar': "اسم المستخدم"},
    "Password": <String, String>{'ru': "Пароль", 'pl': "Hasło", 'es': "Contraseña", 'fr': "Mot de passe", 'ar': "كلمة المرور"},
  };

  String _tr(String de, String tr, String en) {
    final code = context.read<LocaleProvider>().locale.languageCode;
    return code == 'tr' ? tr : code == 'de' ? de : (_setupTranslations[en]?[code] ?? en);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 8)),
    );
  }
  String? _ipAddress;
  String? _qrLink;
  Timer? _qrExpiry;
  bool _startingQr = false;
  bool _qrImportPending = false;

  void _runReceivedQrImport(bool isXtream) {
    if (!mounted || _qrImportPending || _isLoading) return;
    _qrImportPending = true;
    // Defer navigation/import until the pairing HTTP request can complete.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) { _qrImportPending = false; return; }
      try {
        if (isXtream) {
          await _connectXtream();
        } else {
          await _startM3uImport();
        }
      } finally {
        _qrImportPending = false;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    // Keep playlist entry and loading in portrait on phones, never on TV.
    if (!DeviceLayout.isTelevision) {
      unawaited(SystemChrome.setPreferredOrientations(
        const <DeviceOrientation>[DeviceOrientation.portraitUp],
      ));
    }
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_tvTabChanged);
    _m3uController.addListener(() {
      if (_selectedM3uPath != null && _m3uController.text.trim().isNotEmpty && mounted) {
        setState(() { _selectedM3uPath = null; _selectedM3uName = null; });
      }
    });
    _initServer();
  }

  Future<void> _initServer() async {
    if (!mounted || _startingQr || _isLoading) return;
    _qrExpiry?.cancel();
    setState(() { _startingQr = true; _qrLink = null; _ipAddress = null; });
    String? serverIp;

    final langCode = context.read<LocaleProvider>().locale.languageCode;
    try {
      serverIp = await TvServer.start((type, d1, d2, d3) {
        if (!mounted || _isLoading || _qrImportPending) {
          if (type == 'm3u_file') unawaited(_deleteReceivedFile(d1));
          return;
        }
        _qrExpiry?.cancel();
        setState(() => _qrLink = null);
        if (type == 'm3u' || type == 'm3u_file') {
          final previous = _receivedM3uPath;
          if (previous != null) unawaited(_deleteReceivedFile(previous));
          setState(() {
            _selectedM3uPath = null;
            _selectedM3uName = null;
            _receivedM3uPath = null;
            _m3uController.clear();
            _epgController.text = d2;
            if (type == 'm3u_file') {
              _receivedM3uPath = d1;
              _selectedM3uPath = d1;
              _selectedM3uName = 'playlist.m3u';
            } else {
              _m3uController.text = d1;
            }
          });
          _tabController.animateTo(1);
          _runReceivedQrImport(false);
        } else if (type == 'xtream') {
          setState(() {
            _xtreamServerController.text = d1;
            _xtreamUserController.text = d2;
            _xtreamPassController.text = d3;
          });
          _tabController.animateTo(2);
          _runReceivedQrImport(true);
        }
      }, langCode);
    } catch (_) {
      // The user can still configure a playlist manually if LAN import fails.
    }

    if (!mounted) { TvServer.stop(); return; }
    final token = TvServer.pairingToken;
    final link = serverIp == null || token == null ? null : Uri(
      scheme: 'http', host: serverIp, port: 8080, path: '/',
      queryParameters: {'token': token},
    ).toString();
    setState(() {
      _startingQr = false;
      _ipAddress = serverIp;
      _qrLink = link;
    });
    if (link != null) {
      _qrExpiry = Timer(const Duration(minutes: 9, seconds: 55), () {
        if (mounted) setState(() => _qrLink = null);
      });
    }
  }

  // Keep local playlist contents out of TextEditingController: large M3U files
  // can otherwise exhaust memory during text layout and IME synchronization.
  Future<void> _pickFile(bool isM3u) async {
    if (_isLoading) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: isM3u ? ['m3u', 'm3u8'] : ['xml', 'gz'],
        withData: false,
      );
      if (!mounted || result == null || result.files.isEmpty) return;
      final selected = result.files.single;
      final path = selected.path;
      if (path == null || path.isEmpty) {
        _showError(_copy(
          'Die ausgewählte Datei konnte nicht geöffnet werden.',
          'Seçilen dosya açılamadı.',
          'The selected file could not be opened.',
        ));
        return;
      }
      // XML EPG is still inserted into a text field; limit only that path.
      const maxBytes = 12 * 1024 * 1024;
      if (!isM3u && selected.size > maxBytes) {
        _showError(_copy(
          'Datei ist zu groß (maximal 12 MB).',
          'Dosya çok büyük (en fazla 12 MB).',
          'File is too large (maximum 12 MB).',
        ));
        return;
      }
      if (isM3u) {
        setState(() {
          _selectedM3uPath = path;
          _selectedM3uName = selected.name;
          _m3uController.clear();
        });
      } else {
        if (selected.name.toLowerCase().endsWith('.gz')) {
          _showError(_copy(
            'Komprimierte EPG-Dateien können hier nicht als Text eingefügt werden. Bitte eine XML-URL verwenden.',
            'Sıkıştırılmış EPG dosyaları buraya metin olarak eklenemez. Lütfen XML bağlantısı kullanın.',
            'Compressed EPG files cannot be inserted as text here. Please use an XML URL.',
          ));
          return;
        }
        setState(() => _isLoading = true);
        try {
          final content = await File(path).readAsString();
          if (mounted) setState(() => _epgController.text = content);
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      }
    } catch (_) {
      _showError(_copy(
        'Dateiauswahl fehlgeschlagen. Bitte eine andere Datei versuchen.',
        'Dosya seçimi başarısız. Lütfen başka bir dosya deneyin.',
        'File selection failed. Please try another file.',
      ));
    }
  }

  bool get _isTrialAccount => PlaylistManagementService.isTrialAccess(
    context.read<AuthProvider>().access,
  );

  Future<bool?> _confirmTrialReplacement() async {
    final auth = context.read<AuthProvider>();
    if (!auth.hasAccess) {
      _showError(_copy('Kein aktiver Zugang. Bitte zuerst dein Konto prüfen.',
        'Aktif erişim yok. Lütfen önce hesabınızı kontrol edin.',
        'No active access. Please check your account first.'));
      return null;
    }
    if (!_isTrialAccount) return false;
    final profiles = await PlaylistProfileStore().load();
    if (!mounted) return null;
    if (profiles.isEmpty) return false;
    if (profiles.length > 1) {
      _showError(_copy('Mehrere Playlists vorhanden. Bitte zuerst in der Playlist-Verwaltung bereinigen.',
        'Birden fazla liste mevcut. Önce liste yönetiminde düzenleyin.',
        'Multiple playlists exist. Please resolve them in playlist management.'));
      return null;
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_copy('Playlist ersetzen?', 'Oynatma listesi değiştirilsin mi?', 'Replace playlist?')),
        content: Text(_copy(
          'Während der Testphase ist nur eine Playlist erlaubt. Nach erfolgreichem Import wird die bisherige Playlist ersetzt. Deine Testzeit und Geräte bleiben unverändert.',
          'Deneme süresince yalnızca bir listeye izin verilir. Yeni liste başarıyla yüklendikten sonra eski liste değiştirilir. Deneme süreniz ve cihazlarınız değişmez.',
          'Only one playlist is allowed during the trial. The old playlist will be replaced after a successful import. Trial time and devices stay unchanged.',
        )),
        actions: [
          TextButton(autofocus: true, onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(_copy('Abbrechen', 'İptal', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(_copy('Ersetzen', 'Değiştir', 'Replace'))),
        ],
      ),
    );
    if (!mounted || accepted != true) return null;
    return true;
  }

  Future<void> _persistImportedPlaylist({
    required PlaylistSourceConfig source,
    required String name,
    required String type,
    required bool replaceTrial,
  }) async {
    await PlaylistManagementService().saveImportedPlaylist(
      source: source,
      profile: PlaylistProfile(
        sourceKey: source.sourceKey,
        displayName: name.trim().isEmpty ? (type == 'xtream' ? 'Xtream Playlist' : 'M3U Playlist') : name.trim(),
        type: type,
        folderName: '',
        isVisible: true,
        isActive: true,
        createdAt: DateTime.now(),
      ),
      isTrial: _isTrialAccount,
      replaceExistingTrialPlaylist: replaceTrial,
    );
  }

  Future<void> _startM3uImport() async {
    if (_isLoading) return;
    final path = _selectedM3uPath;
    if (path == null) {
      final value = _m3uController.text.trim();
      if (value.isEmpty) {
        _showError(_copy('Bitte M3U-Link eingeben oder Datei auswählen.',
          'M3U bağlantısı girin veya dosya seçin.',
          'Enter an M3U link or select a file.'));
        return;
      }
      await _processPlaylist(value);
      return;
    }
    final replaceTrial = await _confirmTrialReplacement();
    if (replaceTrial == null || !mounted) return;
    setState(() {
      _isLoading = true;
      _loadingMessage = _copy('Lokale M3U-Datei wird gelesen…',
        'Yerel M3U dosyası okunuyor…', 'Reading local M3U file…');
    });
    final staged = ContentProvider();
    String? newlyCopiedPath;
    bool committed = false;
    try {
      final file = File(path);
      if (!await file.exists()) {
        throw const FileSystemException('Selected playlist is no longer available.');
      }
      // Parse into an isolated provider. The active library is not touched
      // until source credentials and playlist metadata have been committed.
      await PlaylistParser.parseAndLoadFile(path, staged);
      if (!mounted) return;
      final sourceKey = staged.sourceKey;
      if (sourceKey.isEmpty || sourceKey == 'legacy:default') {
        throw StateError('The imported playlist has no valid source identity.');
      }
      final directory = await getApplicationDocumentsDirectory();
      final playlistDirectory = Directory('${directory.path}/streamia_playlists');
      await playlistDirectory.create(recursive: true);
      final safeKey = sourceKey.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      // Use a unique path: never overwrite the previous working local file
      // before the new profile and source have been saved.
      final localPath = '${playlistDirectory.path}/${safeKey}_${DateTime.now().microsecondsSinceEpoch}.m3u';
      await file.copy(localPath);
      newlyCopiedPath = localPath;
      await _persistImportedPlaylist(
        source: PlaylistSourceConfig(
          sourceKey: sourceKey, type: 'm3u', epgUrl: _configuredEpgUrl, localFilePath: localPath,
        ),
        name: _m3uNameController.text,
        type: 'm3u',
        replaceTrial: replaceTrial,
      );
      committed = true;
      if (!mounted) return;
      context.read<ContentProvider>().replaceLibrary(
        channels: staged.channels,
        vod: staged.vodItems,
        series: staged.series,
        sourceKey: sourceKey,
        sourceLabel: _m3uNameController.text.trim(),
      );
      if (widget.returnToPreviousOnSuccess) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      _showError(_copy('Die M3U-Datei konnte nicht gelesen oder gespeichert werden.',
        'M3U dosyası okunamadı veya kaydedilemedi.',
        'Could not read or save the M3U file.'));
    } finally {
      if (!committed && newlyCopiedPath != null) {
        try { await File(newlyCopiedPath).delete(); } catch (_) {}
      }
      if (path == _receivedM3uPath && (committed || !mounted)) {
        _receivedM3uPath = null;
        await _deleteReceivedFile(path);
      }
      await staged.waitForCatalogWrites();
      staged.dispose();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _processPlaylist(String input) async {
    if (input.isEmpty || !mounted || _isLoading) return;
    final replaceTrial = await _confirmTrialReplacement();
    if (replaceTrial == null || !mounted) return;
    setState(() {
      _isLoading = true;
      _loadingMessage = _copy('Playlist wird verarbeitet…',
        'Oynatma listesi işleniyor…', 'Processing playlist…');
    });
    final staged = ContentProvider();
    String? newlyWrittenPath;
    bool committed = false;
    try {
      await PlaylistParser.parseAndLoad(input, staged)
          .timeout(const Duration(seconds: 90));
      if (!mounted) return;
      final sourceKey = staged.sourceKey;
      if (sourceKey.isEmpty || sourceKey == 'legacy:default') {
        throw StateError('The imported playlist has no valid source identity.');
      }
      PlaylistSourceConfig source;
      if (input.trim().startsWith('http://') ||
          input.trim().startsWith('https://')) {
        source = PlaylistSourceConfig(
          sourceKey: sourceKey, type: 'm3u', epgUrl: _configuredEpgUrl, m3uUrl: input.trim(),
        );
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final playlistDirectory = Directory('${directory.path}/streamia_playlists');
        await playlistDirectory.create(recursive: true);
        final safeKey = sourceKey.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
        final localPath = '${playlistDirectory.path}/${safeKey}_${DateTime.now().microsecondsSinceEpoch}.m3u';
        await File(localPath).writeAsString(input, flush: true);
        newlyWrittenPath = localPath;
        source = PlaylistSourceConfig(
          sourceKey: sourceKey, type: 'm3u', epgUrl: _configuredEpgUrl, localFilePath: localPath,
        );
      }
      await _persistImportedPlaylist(
        source: source,
        name: _m3uNameController.text,
        type: 'm3u',
        replaceTrial: replaceTrial,
      );
      committed = true;
      if (!mounted) return;
      context.read<ContentProvider>().replaceLibrary(
        channels: staged.channels,
        vod: staged.vodItems,
        series: staged.series,
        sourceKey: sourceKey,
        sourceLabel: _m3uNameController.text.trim(),
      );
      if (widget.returnToPreviousOnSuccess) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      _showError(_copy('Fehler beim Laden oder Speichern der Playlist.',
        'Oynatma listesi yüklenirken veya kaydedilirken hata oluştu.',
        'Could not load or save the playlist.'));
    } finally {
      if (!committed && newlyWrittenPath != null) {
        try { await File(newlyWrittenPath).delete(); } catch (_) {}
      }
      await staged.waitForCatalogWrites();
      staged.dispose();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _connectXtream() async {
    if (_isLoading) return;
    final server = VoiceInputField.normalizeUrl(_xtreamServerController.text);
    _xtreamServerController.text = server;
    final user = _xtreamUserController.text.trim();
    final pass = _xtreamPassController.text;
    final validationError = XtreamInputValidator.serverError(server) ??
        XtreamInputValidator.usernameError(user) ??
        XtreamInputValidator.passwordError(pass);
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError)),
      );
      return;
    }

    final replaceTrial = await _confirmTrialReplacement();
    if (replaceTrial == null || !mounted) return;

    setState(() { _isLoading = true; _loadingMessage = null; });
    XtreamService? service;
    try {
      final sourceIdentity = 'xtream:v2:${server.trim().replaceFirst(RegExp(r'/+$'), '').toLowerCase()}|${user.trim()}';
      final sourceKey = 'src:v1:${sha256.convert(utf8.encode(sourceIdentity)).toString()}';
      service = XtreamService(baseUrl: server, username: user, password: pass, sourceKey: sourceKey);
      // Fetch the complete library before replacing the currently displayed data.
      setState(() => _loadingMessage = _tr('Live-TV wird geladen…', 'Canlı TV yükleniyor…', 'Loading live TV…'));
      final live = await service.getLiveStreams().timeout(const Duration(seconds: 45));
      if (!mounted) return;
      setState(() => _loadingMessage = _tr('Filme werden geladen…', 'Filmler yükleniyor…', 'Loading movies…'));
      final vod = await service.getVodStreams().timeout(const Duration(seconds: 45));
      if (!mounted) return;
      setState(() => _loadingMessage = _tr('Serien werden geladen…', 'Diziler yükleniyor…', 'Loading series…'));
      final series = await service.getSeries().timeout(const Duration(seconds: 45));
      if (!mounted) return;
      // Stable source identity excludes the password: changing credentials must not
      // silently create a different favorites namespace, and secrets must never
      // be included in a value later hashed or exported.

      await _persistImportedPlaylist(
        source: PlaylistSourceConfig(
          sourceKey: sourceKey, type: 'xtream', serverUrl: server.trim(),
          username: user.trim(), password: pass,
        ),
        name: _xtreamNameController.text,
        type: 'xtream',
        replaceTrial: replaceTrial,
      );
      context.read<ContentProvider>().replaceLibrary(
        channels: live,
        vod: vod,
        series: series,
        sourceKey: sourceKey,
        sourceLabel: Uri.tryParse(server)?.host ?? 'Xtream',
      );
      context.read<ContentProvider>().setLoaded(true);
      if (widget.returnToPreviousOnSuccess) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is TimeoutException
              ? _tr('Zeitüberschreitung: Der Server antwortet nicht. Bitte Adresse, Netzwerk und Zugangsdaten prüfen.', 'Zaman aşımı: Sunucu yanıt vermiyor. Adresi, ağı ve giriş bilgilerini kontrol edin.', 'Timeout: Server did not respond. Check address, network and credentials.')
              : e is FormatException
                  ? _tr('Ungültige Serverantwort.', 'Sunucudan geçersiz yanıt.', 'Invalid server response.')
                  : _tr('Xtream-Verbindung fehlgeschlagen. Bitte Zugangsdaten und Netzwerk prüfen.', 'Xtream bağlantısı başarısız. Giriş bilgilerini ve ağı kontrol edin.', 'Xtream connection failed. Check credentials and network.'))),
        );
      }
    } finally {
      service?.close();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    // Returning from playlist editing to an existing dashboard restores landscape.
    if (widget.returnToPreviousOnSuccess && !DeviceLayout.isTelevision) {
      unawaited(SystemChrome.setPreferredOrientations(
        const <DeviceOrientation>[
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
      ));
    }
    _qrExpiry?.cancel();
    TvServer.stop();
    final received = _receivedM3uPath;
    if (received != null && !_isLoading) unawaited(_deleteReceivedFile(received));
    _tabController.removeListener(_tvTabChanged);
    _tabController.dispose();
    for (final node in [..._tvTabs, ..._tvFirst]) { node.dispose(); }
    _m3uNameController.dispose();
    _xtreamNameController.dispose();
    _m3uController.dispose();
    _epgController.dispose();
    _xtreamServerController.dispose();
    _xtreamUserController.dispose();
    _xtreamPassController.dispose();
    _xtreamServerFocus.dispose();
    _xtreamUserFocus.dispose();
    _xtreamPassFocus.dispose();
    _m3uConnectFocus.dispose();
    _xtreamConnectFocus.dispose();
    super.dispose();
  }

  // Premium setup UI: responsive on phones, tablets and Android TV.
  static const Color _blue = Color(0xFF238BFF);
  static const Color _aqua = Color(0xFF28D6CF);

  String _copy(String de, String tr, String en) => _tr(de, tr, en);

  Widget _panel({required Widget child}) {
    return Container(
      padding: EdgeInsets.all(DeviceLayout.isTelevision ? 16 : 22),
      decoration: BoxDecoration(
        color: const Color(0xFF151F30),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF2B3C55)),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 24, offset: Offset(0, 12))],
      ),
      child: child,
    );
  }

  Widget _fieldTitle(String title, {String? hint}) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white)),
      if (hint != null) ...[
        const SizedBox(height: 3),
        Text(hint, style: const TextStyle(fontSize: 12, color: Color(0xFF9EADC4))),
      ],
    ]),
  );

  InputDecoration _decoration(String hint, IconData icon, {Widget? suffix}) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF8393AA)),
    prefixIcon: Icon(icon, color: _aqua),
    suffixIcon: suffix,
    filled: true,
    fillColor: const Color(0xFF0D1625),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF34445C))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _aqua, width: 2)),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
  );

  Widget _actionButton({required String text, required IconData icon, required VoidCallback? onPressed, bool primary = true, FocusNode? focusNode}) {
    final style = ButtonStyle(
      minimumSize: WidgetStateProperty.all(const Size(0, 56)),
      padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 16, vertical: 13)),
      shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      backgroundColor: WidgetStateProperty.all(primary ? _blue : const Color(0xFF202F45)),
      foregroundColor: WidgetStateProperty.all(Colors.white),
      side: WidgetStateProperty.resolveWith((states) =>
        DeviceLayout.isTelevision && states.contains(WidgetState.focused)
          ? const BorderSide(color: _aqua, width: 3)
          : BorderSide(color: primary ? Colors.transparent : const Color(0xFF405575))),
    );
    return ElevatedButton.icon(
      focusNode: focusNode,
      style: style,
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  Widget _pageContent({required IconData icon, required String title, required String description, required Widget form}) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, DeviceLayout.isTelevision ? 12 : 20, 16, 36),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: DeviceLayout.isTelevision ? 940 : 680),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(color: _blue.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)),
                child: Icon(icon, color: _aqua, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis,
                   style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 4),
                Text(description, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFFA6B5CB), height: 1.4)),
              ])),
            ]),
            const SizedBox(height: 22),
            _panel(child: form),
            const SizedBox(height: 18),
            Row(children: [
              const Icon(Icons.shield_outlined, size: 16, color: _aqua),
              const SizedBox(width: 8),
              Expanded(child: Text(_copy('Deine Zugangsdaten werden geschützt gespeichert.', 'Giriş bilgileriniz güvenli şekilde saklanır.', 'Your credentials are stored securely.'), style: const TextStyle(color: Color(0xFF9EADC4), fontSize: 12))),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _loadingView() {
    return Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 450),
      child: _panel(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_download_outlined, size: 50, color: _aqua),
        const SizedBox(height: 20),
        const LinearProgressIndicator(color: _aqua, backgroundColor: Color(0xFF33445C)),
        const SizedBox(height: 20),
        Text(_loadingMessage ?? _copy('Playlist wird geladen…', 'Oynatma listesi yükleniyor…', 'Loading playlist…'),
          textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Text(_copy('Bitte warten. Der Fortschrittsbalken zeigt die laufende Verarbeitung, keine geschätzten Prozentwerte.',
          'Lütfen bekleyin. İlerleme çubuğu işlemi gösterir, tahmini yüzde vermez.',
          'Please wait. The bar indicates activity, not an estimated percentage.'),
          textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF9EADC4), fontSize: 12)),
      ])),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = context.watch<AuthProvider>();
    return Theme(
      data: TvRemoteNavigation.theme(ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: const ColorScheme.dark(primary: _blue, secondary: _aqua, surface: Color(0xFF101A2A)),
        scaffoldBackgroundColor: const Color(0xFF0A1220),
      )),
      child: Scaffold(
        backgroundColor: const Color(0xFF0A1220),
        appBar: AppBar(
          backgroundColor: const Color(0xFF101A2A),
          automaticallyImplyLeading: widget.returnToPreviousOnSuccess,
          toolbarHeight: DeviceLayout.isTelevision ? 56 : 72,
          title: Row(children: [
            Container(width: 36, height: 36, alignment: Alignment.center,
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [_blue, _aqua]), borderRadius: BorderRadius.circular(11)),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('STREAMIA', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.8, fontSize: 17)),
              Text(l10n.t('setup_title'), maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF9EADC4))),
            ])),
          ]),
          bottom: DeviceLayout.isTelevision ? _tvTabBar(l10n) : TabBar(
            controller: _tabController,
            indicatorColor: _aqua,
            indicatorWeight: 3,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: Colors.white,
            unselectedLabelColor: const Color(0xFF91A0B6),
            tabs: [
              Tab(icon: const Icon(Icons.qr_code_2), text: l10n.t('tab_qr')),
              Tab(icon: const Icon(Icons.playlist_play_rounded), text: l10n.t('tab_m3u')),
              Tab(icon: const Icon(Icons.dns_outlined), text: l10n.t('tab_xtream')),
            ],
          ),
        ),
        body: _isLoading ? _loadingView() : FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: DeviceLayout.isTelevision
            ? KeyedSubtree(key: ValueKey(_tabController.index), child: [
                () => _buildQrTab(auth, l10n),
                () => _buildM3uTab(l10n),
                () => _buildXtreamTab(l10n),
              ][_tabController.index]())
            : TabBarView(controller: _tabController, children: [
            _buildQrTab(auth, l10n),
            _buildM3uTab(l10n),
            _buildXtreamTab(l10n),
          ]),
        ),
      ),
    );
  }

  Widget _buildQrTab(AuthProvider auth, AppLocalizations l10n) {
    return _pageContent(
      icon: Icons.qr_code_2,
      title: l10n.t('qr_title'),
      description: '${l10n.t('qr_desc')}\n${_copy("Verbinde Smartphone und TV mit demselben lokalen Netzwerk.", "Telefonu ve TV’yi aynı yerel ağa bağlayın.", "Connect your phone and TV to the same local network.")}',
      form: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(child: _qrLink == null
          ? const Padding(padding: EdgeInsets.all(30), child: Icon(Icons.wifi_off_outlined, color: _aqua, size: 48))
          : Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
              child: QrImageView(data: _qrLink!, version: QrVersions.auto, size: DeviceLayout.isTelevision ? 160 : 220, backgroundColor: Colors.white))),
        const SizedBox(height: 18),
        if (_qrLink == null) Text(_copy('QR-Verbindung derzeit nicht verfügbar. Nutze die manuelle Einrichtung.',
          'QR bağlantısı şu anda kullanılamıyor. Manuel kurulumu kullanın.',
          'QR connection unavailable. Use manual setup.'), textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFB4C1D2))),
        const SizedBox(height: 16),
        _infoRow(Icons.wifi_rounded, l10n.t('local_ip'), _ipAddress ?? '—'),
        const Divider(color: Color(0xFF33445C)),
        _infoRow(Icons.devices_outlined, _copy('Gerätekennung', 'Cihaz kimliği', 'Device ID'), auth.macAddress),
        const SizedBox(height: 22),
        _actionButton(text: _copy('QR-Code erneuern', 'QR kodunu yenile', 'Refresh QR code'),
          icon: Icons.refresh, primary: false,
          onPressed: _startingQr || _isLoading ? null : () { _initServer(); }),
        const SizedBox(height: 8),
        _actionButton(text: l10n.t('qr_btn_manual'), icon: Icons.edit_outlined,
          focusNode: DeviceLayout.isTelevision ? _tvFirst[0] : null,
          onPressed: () {
            if (DeviceLayout.isTelevision) { _selectTvTab(1, enter: true); }
            else { _tabController.animateTo(1); }
          }),
      ]),
    );
  }

  Widget _infoRow(IconData icon, String title, String value) => Row(children: [
    Icon(icon, color: _aqua), const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: Color(0xFF9EADC4), fontSize: 12)),
      const SizedBox(height: 3),
      if (DeviceLayout.isTelevision)
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14))
      else SelectableText(value, style: const TextStyle(color: Colors.white, fontSize: 14)),
    ])),
  ]);

  Widget _buildM3uTab(AppLocalizations l10n) {
    final language = context.watch<LocaleProvider>().locale.languageCode;
    return _pageContent(
      icon: Icons.playlist_play_rounded,
      title: _copy('M3U-Playlist hinzufügen', 'M3U oynatma listesi ekle', 'Add M3U playlist'),
      description: _copy('Playlist-Link eingeben oder eine Datei von deinem Gerät auswählen.',
        'Oynatma listesi bağlantısı girin veya cihazınızdan dosya seçin.',
        'Enter a playlist link or select a file from your device.'),
      form: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _fieldTitle(l10n.t('playlist_display_name')),
        if (DeviceLayout.isTelevision)
          VoiceInputField(controller: _m3uNameController, appLanguageCode: language,
            focusNode: _tvFirst[1], textCapitalization: TextCapitalization.none,
            decoration: _decoration(_copy('Meine Playlist', 'Oynatma listem', 'My playlist'), Icons.drive_file_rename_outline))
        else TextField(controller: _m3uNameController, textCapitalization: TextCapitalization.none,
          decoration: _decoration(_copy('Meine Playlist', 'Oynatma listem', 'My playlist'), Icons.drive_file_rename_outline,
            suffix: DeviceLayout.isTelevision ? IconButton(
              tooltip: l10n.t('tv_keyboard_title'), icon: const Icon(Icons.keyboard_alt_outlined),
              onPressed: () => TvTextKeyboard.show(context, controller: _m3uNameController, languageCode: language),
            ) : null)),
        const SizedBox(height: 20),
        _fieldTitle(l10n.t('m3u_url')),
        VoiceInputField(controller: _m3uController, appLanguageCode: language,
          keyboardType: TextInputType.url, maxLines: 3,
          decoration: _decoration('https://example.com/playlist.m3u', Icons.link_rounded)),
        if (_selectedM3uName != null) ...[
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.insert_drive_file_outlined, color: _aqua, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(_selectedM3uName!, maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70))),
            IconButton(tooltip: 'Remove selected file',
              onPressed: () => setState(() {
                _selectedM3uName = null;
                _selectedM3uPath = null;
              }), icon: const Icon(Icons.close, size: 18)),
          ]),
        ],
        const SizedBox(height: 20),
        _fieldTitle(l10n.t('epg_url'), hint: _copy('Optional – Programmübersicht', 'İsteğe bağlı – yayın rehberi', 'Optional – program guide')),
        VoiceInputField(controller: _epgController, appLanguageCode: language, keyboardType: TextInputType.url,
          decoration: _decoration('https://example.com/epg.xml', Icons.calendar_month_outlined)),
        const SizedBox(height: 22),
        LayoutBuilder(builder: (context, constraints) {
          final narrow = constraints.maxWidth < 440;
          final first = _actionButton(text: _copy("M3U-Datei aus dem Speicher laden", "M3U dosyasını depolamadan yükle", "Load M3U file from storage"), icon: Icons.folder_open_outlined, primary: false, onPressed: () => _pickFile(true));
          final second = _actionButton(text: _copy("EPG-Datei aus dem Speicher laden", "EPG dosyasını depolamadan yükle", "Load EPG file from storage"), icon: Icons.event_note_outlined, primary: false, onPressed: () => _pickFile(false));
          return narrow
            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [first, const SizedBox(height: 12), second])
            : Row(children: [Expanded(child: first), const SizedBox(width: 12), Expanded(child: second)]);
        }),
        const SizedBox(height: 24),
        _actionButton(text: l10n.t('btn_start'), icon: Icons.arrow_forward_rounded, focusNode: _m3uConnectFocus, onPressed: _startM3uImport),
      ]),
    );
  }

  void _applyServerScheme(String scheme) {
    final current = _xtreamServerController.text.trimLeft();
    final withoutScheme = current.replaceFirst(RegExp(r'^https?://', caseSensitive: false), '');
    final value = VoiceInputField.normalizeUrl('$scheme$withoutScheme');
    _xtreamServerController.value = TextEditingValue(text: value, selection: TextSelection.collapsed(offset: value.length));
    _xtreamServerFocus.requestFocus();
  }

  Widget _buildXtreamTab(AppLocalizations l10n) {
    final language = context.watch<LocaleProvider>().locale.languageCode;
    return _pageContent(
      icon: Icons.dns_outlined,
      title: _copy('Xtream Codes verbinden', 'Xtream Codes bağlantısı', 'Connect Xtream Codes'),
      description: _copy('Trage die Zugangsdaten deines Anbieters ein.',
        'Sağlayıcınızın bağlantı bilgilerini girin.', 'Enter the login details provided by your service.'),
      form: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _fieldTitle(l10n.t('playlist_display_name')),
        if (DeviceLayout.isTelevision)
          VoiceInputField(controller: _xtreamNameController, appLanguageCode: language,
            focusNode: _tvFirst[2], textCapitalization: TextCapitalization.none,
            decoration: _decoration(_copy('Meine Xtream-Playlist', 'Xtream listem', 'My Xtream playlist'), Icons.drive_file_rename_outline))
        else TextField(controller: _xtreamNameController, textCapitalization: TextCapitalization.none,
          decoration: _decoration(_copy('Meine Xtream-Playlist', 'Xtream listem', 'My Xtream playlist'), Icons.drive_file_rename_outline,
            suffix: DeviceLayout.isTelevision ? IconButton(
              tooltip: l10n.t('tv_keyboard_title'), icon: const Icon(Icons.keyboard_alt_outlined),
              onPressed: () => TvTextKeyboard.show(context, controller: _xtreamNameController, languageCode: language),
            ) : null)),
        const SizedBox(height: 20),
        _fieldTitle(l10n.t('xtream_server')),
        Wrap(spacing: 10, runSpacing: 8, children: [
          ActionChip(label: const Text('http://'), onPressed: () => _applyServerScheme('http://'),
            backgroundColor: const Color(0xFF22364C), labelStyle: const TextStyle(color: Colors.white)),
          ActionChip(label: const Text('https://'), onPressed: () => _applyServerScheme('https://'),
            backgroundColor: const Color(0xFF22364C), labelStyle: const TextStyle(color: Colors.white)),
        ]),
        const SizedBox(height: 10),
        VoiceInputField(controller: _xtreamServerController, appLanguageCode: language,
          focusNode: _xtreamServerFocus, keyboardType: TextInputType.url,
          textCapitalization: TextCapitalization.none, textInputAction: TextInputAction.next,
          onSubmitted: (_) => _xtreamUserFocus.requestFocus(),
          decoration: _decoration('http://server.com:8080', Icons.language_rounded)),
        const SizedBox(height: 20),
        _fieldTitle(l10n.t('xtream_user')),
        VoiceInputField(controller: _xtreamUserController, appLanguageCode: language,
          credentialMode: true,
          focusNode: _xtreamUserFocus, textCapitalization: TextCapitalization.none,
          textInputAction: TextInputAction.next, onSubmitted: (_) => _xtreamPassFocus.requestFocus(),
          decoration: _decoration(_copy('Benutzername', 'Kullanıcı adı', 'Username'), Icons.person_outline)),
        const SizedBox(height: 20),
        _fieldTitle(l10n.t('xtream_pass')),
        VoiceInputField(controller: _xtreamPassController, focusNode: _xtreamPassFocus,
          appLanguageCode: language, credentialMode: true, secret: true,
          obscureText: true, keyboardType: TextInputType.visiblePassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _xtreamConnectFocus.requestFocus(),
          decoration: _decoration(_copy('Passwort', 'Şifre', 'Password'), Icons.lock_outline)),
        const SizedBox(height: 26),
        _actionButton(text: l10n.t('btn_start'), icon: Icons.arrow_forward_rounded,
          focusNode: _xtreamConnectFocus, onPressed: _connectXtream),
      ]),
    );
  }
}
