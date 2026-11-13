import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:network_info_plus/network_info_plus.dart';
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
import '../core/theme/app_theme.dart';
import '../widgets/voice_input_field.dart';
import '../widgets/tv_text_keyboard.dart';
import 'dashboard_screen.dart';

class SetupScreen extends StatefulWidget {
  final bool returnToPreviousOnSuccess;
  const SetupScreen({super.key, this.returnToPreviousOnSuccess = false});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  final TextEditingController _m3uNameController = TextEditingController(text: 'M3U Playlist');
  final TextEditingController _xtreamNameController = TextEditingController(text: 'Xtream Playlist');
  final TextEditingController _m3uController = TextEditingController();
  final TextEditingController _epgController = TextEditingController();
  final TextEditingController _xtreamServerController = TextEditingController();
  final TextEditingController _xtreamUserController = TextEditingController();
  final TextEditingController _xtreamPassController = TextEditingController();
  final FocusNode _xtreamServerFocus = FocusNode(debugLabel: 'Xtream server');
  final FocusNode _xtreamUserFocus = FocusNode(debugLabel: 'Xtream username');
  final FocusNode _xtreamPassFocus = FocusNode(debugLabel: 'Xtream password');
  final FocusNode _xtreamConnectFocus = FocusNode(debugLabel: 'Xtream connect');

  bool _isLoading = false;
  String? _loadingMessage;
  String? _importError;
  String? _selectedM3uPath;
  String? _selectedM3uName;

  String _tr(String de, String tr, String en) {
    final code = context.read<LocaleProvider>().locale.languageCode;
    return code == 'tr' ? tr : code == 'de' ? de : en;
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _importError = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 8)),
    );
  }
  String? _ipAddress;
  String? _qrLink;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _m3uController.addListener(() {
      if (_selectedM3uPath != null && _m3uController.text.trim().isNotEmpty && mounted) {
        setState(() { _selectedM3uPath = null; _selectedM3uName = null; });
      }
    });
    _initServer();
  }

  Future<void> _initServer() async {
    String? ip;
    String? serverIp;
    try {
      ip = await NetworkInfo().getWifiIP();
    } catch (_) {
      // QR/LAN import is optional; setup must remain usable without Wi-Fi info.
    }
    if (!mounted) return;

    final langCode = context.read<LocaleProvider>().locale.languageCode;
    try {
      serverIp = await TvServer.start((type, d1, d2, d3) {
        if (!mounted) return;
        if (type == 'm3u') {
          setState(() {
            _m3uController.text = d1;
            if (d2.isNotEmpty) _epgController.text = d2;
          });
          _tabController.animateTo(1);
          _processPlaylist(d1);
        } else {
          setState(() {
            _xtreamServerController.text = d1;
            _xtreamUserController.text = d2;
            _xtreamPassController.text = d3;
          });
          _tabController.animateTo(2);
        }
      }, langCode);
    } catch (_) {
      // The user can still configure a playlist manually if LAN import fails.
    }

    if (!mounted) return;
    setState(() {
      _ipAddress = serverIp ?? ip ?? '127.0.0.1';
      _qrLink = serverIp == null ? null : 'http://$_ipAddress:8080';
    });
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
          _importError = null;
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
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false),
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
      _importError = null;
      _loadingMessage = _copy('Lokale M3U-Datei wird gelesen…',
        'Yerel M3U dosyası okunuyor…', 'Reading local M3U file…');
    });
    try {
      final file = File(path);
      if (!await file.exists()) {
        throw const FileSystemException('Selected playlist is no longer available.');
      }
      final contentProvider = context.read<ContentProvider>();
      await PlaylistParser.parseAndLoadFile(path, contentProvider);
      if (!mounted) return;
      // Keep a private copy so reactivation does not depend on the picker cache.
      final directory = await getApplicationDocumentsDirectory();
      final playlistDirectory = Directory('${directory.path}/streamia_playlists');
      await playlistDirectory.create(recursive: true);
      final safeKey = contentProvider.sourceKey.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final localPath = '${playlistDirectory.path}/$safeKey.m3u';
      if (file.absolute.path != File(localPath).absolute.path) {
        await file.copy(localPath);
      }
      await _persistImportedPlaylist(
        source: PlaylistSourceConfig(
          sourceKey: contentProvider.sourceKey, type: 'm3u', localFilePath: localPath,
        ),
        name: _m3uNameController.text,
        type: 'm3u',
        replaceTrial: replaceTrial,
      );
      contentProvider.setLoaded(true);
      if (!mounted) return;
      if (widget.returnToPreviousOnSuccess) {
        Navigator.of(context).pop(true);
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    } catch (_) {
      _showError(_copy('Die M3U-Datei konnte nicht gelesen werden.',
        'M3U dosyası okunamadı.', 'Could not read the M3U file.'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _processPlaylist(String input) async {
    if (input.isEmpty || !mounted || _isLoading) return;
    final replaceTrial = await _confirmTrialReplacement();
    if (replaceTrial == null || !mounted) return;
    setState(() { _isLoading = true; _importError = null; _loadingMessage = _copy('Playlist wird verarbeitet…', 'Oynatma listesi işleniyor…', 'Processing playlist…'); });
    try {
      final contentProvider = context.read<ContentProvider>();
      await PlaylistParser.parseAndLoad(input, contentProvider)
          .timeout(const Duration(seconds: 90));
      PlaylistSourceConfig source;
      if (input.trim().startsWith('http://') || input.trim().startsWith('https://')) {
        source = PlaylistSourceConfig(
          sourceKey: contentProvider.sourceKey, type: 'm3u', m3uUrl: input.trim(),
        );
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final playlistDirectory = Directory('${directory.path}/streamia_playlists');
        await playlistDirectory.create(recursive: true);
        final safeKey = contentProvider.sourceKey.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
        final localPath = '${playlistDirectory.path}/$safeKey.m3u';
        await File(localPath).writeAsString(input, flush: true);
        source = PlaylistSourceConfig(
          sourceKey: contentProvider.sourceKey, type: 'm3u', localFilePath: localPath,
        );
      }
      await _persistImportedPlaylist(
        source: source,
        name: _m3uNameController.text,
        type: 'm3u',
        replaceTrial: replaceTrial,
      );
      contentProvider.setLoaded(true);
      
      if (mounted) {
        if (widget.returnToPreviousOnSuccess) {
          Navigator.of(context).pop(true);
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Laden: $e')),
        );
      }
    } finally {
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

    setState(() { _isLoading = true; _importError = null; _loadingMessage = null; });
    XtreamService? service;
    try {
      service = XtreamService(baseUrl: server, username: user, password: pass);
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
      final sourceIdentity = 'xtream:v2:${server.trim().replaceFirst(RegExp(r'/+$'), '').toLowerCase()}|${user.trim()}';
      final sourceKey = 'src:v1:${sha256.convert(utf8.encode(sourceIdentity)).toString()}';
      context.read<ContentProvider>().replaceLibrary(
        channels: live,
        vod: vod,
        series: series,
        sourceKey: sourceKey,
        sourceLabel: Uri.tryParse(server)?.host ?? 'Xtream',
      );
      await _persistImportedPlaylist(
        source: PlaylistSourceConfig(
          sourceKey: sourceKey, type: 'xtream', serverUrl: server.trim(),
          username: user.trim(), password: pass,
        ),
        name: _xtreamNameController.text,
        type: 'xtream',
        replaceTrial: replaceTrial,
      );
      context.read<ContentProvider>().setLoaded(true);
      if (widget.returnToPreviousOnSuccess) {
        Navigator.of(context).pop(true);
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
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
    TvServer.stop();
    _tabController.dispose();
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
    _xtreamConnectFocus.dispose();
    super.dispose();
  }

  // Premium setup UI: responsive on phones, tablets and Android TV.
  static const Color _blue = Color(0xFF238BFF);
  static const Color _aqua = Color(0xFF28D6CF);

  String _copy(String de, String tr, String en) => _tr(de, tr, en);

  Widget _panel({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(22),
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
      side: primary ? null : WidgetStateProperty.all(const BorderSide(color: Color(0xFF405575))),
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
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 36),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
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
      data: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: const ColorScheme.dark(primary: _blue, secondary: _aqua, surface: Color(0xFF101A2A)),
        scaffoldBackgroundColor: const Color(0xFF0A1220),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF0A1220),
        appBar: AppBar(
          backgroundColor: const Color(0xFF101A2A),
          automaticallyImplyLeading: widget.returnToPreviousOnSuccess,
          toolbarHeight: 72,
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
          bottom: TabBar(
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
          child: TabBarView(controller: _tabController, children: [
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
      description: l10n.t('qr_desc'),
      form: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(child: _qrLink == null
          ? const Padding(padding: EdgeInsets.all(30), child: Icon(Icons.wifi_off_outlined, color: _aqua, size: 48))
          : Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
              child: QrImageView(data: _qrLink!, version: QrVersions.auto, size: 220, backgroundColor: Colors.white))),
        const SizedBox(height: 18),
        if (_qrLink == null) Text(_copy('QR-Verbindung derzeit nicht verfügbar. Nutze die manuelle Einrichtung.',
          'QR bağlantısı şu anda kullanılamıyor. Manuel kurulumu kullanın.',
          'QR connection unavailable. Use manual setup.'), textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFB4C1D2))),
        const SizedBox(height: 16),
        _infoRow(Icons.wifi_rounded, l10n.t('local_ip'), _ipAddress ?? '—'),
        const Divider(color: Color(0xFF33445C)),
        _infoRow(Icons.devices_outlined, l10n.t('mac_address'), auth.macAddress),
        const SizedBox(height: 22),
        _actionButton(text: l10n.t('qr_btn_manual'), icon: Icons.edit_outlined,
          onPressed: () => _tabController.animateTo(1)),
      ]),
    );
  }

  Widget _infoRow(IconData icon, String title, String value) => Row(children: [
    Icon(icon, color: _aqua), const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: Color(0xFF9EADC4), fontSize: 12)),
      const SizedBox(height: 3),
      SelectableText(value, style: const TextStyle(color: Colors.white, fontSize: 14)),
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
        TextField(controller: _m3uNameController, textCapitalization: TextCapitalization.none,
          decoration: _decoration(_copy('Meine Playlist', 'Oynatma listem', 'My playlist'), Icons.drive_file_rename_outline)),
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
          final first = _actionButton(text: l10n.t('btn_m3u_phone'), icon: Icons.folder_open_outlined, primary: false, onPressed: () => _pickFile(true));
          final second = _actionButton(text: l10n.t('btn_epg_phone'), icon: Icons.event_note_outlined, primary: false, onPressed: () => _pickFile(false));
          return narrow
            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [first, const SizedBox(height: 12), second])
            : Row(children: [Expanded(child: first), const SizedBox(width: 12), Expanded(child: second)]);
        }),
        const SizedBox(height: 24),
        _actionButton(text: l10n.t('btn_start'), icon: Icons.arrow_forward_rounded, onPressed: _startM3uImport),
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
        TextField(controller: _xtreamNameController, textCapitalization: TextCapitalization.none,
          decoration: _decoration(_copy('Meine Xtream-Playlist', 'Xtream listem', 'My Xtream playlist'), Icons.drive_file_rename_outline)),
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
          focusNode: _xtreamUserFocus, textCapitalization: TextCapitalization.none,
          textInputAction: TextInputAction.next, onSubmitted: (_) => _xtreamPassFocus.requestFocus(),
          decoration: _decoration(_copy('Benutzername', 'Kullanıcı adı', 'Username'), Icons.person_outline)),
        const SizedBox(height: 20),
        _fieldTitle(l10n.t('xtream_pass')),
        TextField(controller: _xtreamPassController, focusNode: _xtreamPassFocus,
          obscureText: true, autocorrect: false, enableSuggestions: false,
          textCapitalization: TextCapitalization.none, textInputAction: TextInputAction.done,
          onSubmitted: (_) => _xtreamConnectFocus.requestFocus(),
          decoration: _decoration(_copy('Passwort', 'Şifre', 'Password'), Icons.lock_outline,
            suffix: IconButton(
              tooltip: _copy('TV-Tastatur', 'TV klavyesi', 'TV keyboard'),
              icon: const Icon(Icons.keyboard_alt_outlined, color: _aqua),
              onPressed: () => TvTextKeyboard.show(context, controller: _xtreamPassController,
                languageCode: context.read<LocaleProvider>().locale.languageCode,
                secret: true, onConfirmed: () => _xtreamConnectFocus.requestFocus()),
            ))),
        const SizedBox(height: 26),
        _actionButton(text: l10n.t('btn_start'), icon: Icons.arrow_forward_rounded,
          focusNode: _xtreamConnectFocus, onPressed: _connectXtream),
      ]),
    );
  }
}
