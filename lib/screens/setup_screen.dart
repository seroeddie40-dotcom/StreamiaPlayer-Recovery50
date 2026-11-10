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
import '../services/playlist_source_store.dart';
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

  Future<void> _pickFile(bool isM3u) async {
    setState(() { _isLoading = true; _importError = null; });
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: isM3u ? ['m3u', 'm3u8'] : ['xml', 'gz'],
        withData: true, // Wichtig für stabile Android-Kompatibilität
      );
      
      if (result != null && result.files.single.bytes != null) {
        final content = utf8.decode(result.files.single.bytes!, allowMalformed: true);
        setState(() {
          if (isM3u) {
            _m3uController.text = content;
          } else {
            _epgController.text = content;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Laden der Datei: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _processPlaylist(String input) async {
    if (input.isEmpty) return;
    setState(() { _isLoading = true; _importError = null; });
    try {
      final contentProvider = context.read<ContentProvider>();
      await PlaylistParser.parseAndLoad(input, contentProvider)
          .timeout(const Duration(seconds: 90));
      if (input.trim().startsWith('http://') || input.trim().startsWith('https://')) {
        await PlaylistSourceStore().save(PlaylistSourceConfig(
          sourceKey: contentProvider.sourceKey, type: 'm3u', m3uUrl: input.trim(),
        ));
      } else {
        // Persist imported local playlists in the app-private documents directory.
        final directory = await getApplicationDocumentsDirectory();
        final playlistDirectory = Directory('${directory.path}/streamia_playlists');
        if (!await playlistDirectory.exists()) await playlistDirectory.create(recursive: true);
        final safeKey = contentProvider.sourceKey.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
        final localPath = '${playlistDirectory.path}/$safeKey.m3u';
        await File(localPath).writeAsString(input, flush: true);
        await PlaylistSourceStore().save(PlaylistSourceConfig(
          sourceKey: contentProvider.sourceKey, type: 'm3u', localFilePath: localPath,
        ));
      }
      await PlaylistProfileStore().upsert(PlaylistProfile(
        sourceKey: contentProvider.sourceKey,
        displayName: _m3uNameController.text.trim().isEmpty ? 'M3U Playlist' : _m3uNameController.text.trim(),
        type: 'm3u',
        folderName: '',
        isVisible: true,
        isActive: true,
        createdAt: DateTime.now(),
      ));
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
    final server = _xtreamServerController.text.trim();
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
      await PlaylistSourceStore().save(PlaylistSourceConfig(
        sourceKey: sourceKey, type: 'xtream', serverUrl: server.trim(),
        username: user.trim(), password: pass,
      ));
      await PlaylistProfileStore().upsert(PlaylistProfile(
        sourceKey: sourceKey,
        displayName: _xtreamNameController.text.trim().isEmpty ? 'Xtream Playlist' : _xtreamNameController.text.trim(),
        type: 'xtream',
        folderName: '',
        isVisible: true,
        isActive: true,
        createdAt: DateTime.now(),
      ));
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('setup_title')),
        automaticallyImplyLeading: widget.returnToPreviousOnSuccess,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppTheme.electricBlue,
          labelColor: AppTheme.electricBlue,
          unselectedLabelColor: Colors.grey,
          tabs: [
            Tab(icon: const Icon(Icons.qr_code), text: l10n.t('tab_qr')),
            Tab(text: l10n.t('tab_m3u')),
            Tab(text: l10n.t('tab_xtream')),
          ],
        ),
      ),
      body: _isLoading
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 18),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(_loadingMessage ?? _tr('Playlist wird geladen…', 'Oynatma listesi yükleniyor…', 'Loading playlist…'), textAlign: TextAlign.center)),
          ]))
        : FocusTraversalGroup(
            policy: ReadingOrderTraversalPolicy(),
            child: TabBarView(
            controller: _tabController,
            children: [
              _buildQrTab(auth, l10n),
              _buildM3uTab(l10n),
              _buildXtreamTab(l10n),
            ],
          ),
        ),
    );
  }

  Widget _buildQrTab(AuthProvider auth, AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Text(
            l10n.t('qr_title'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.t('qr_desc'),
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          
          if (_qrLink != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                data: _qrLink!,
                version: QrVersions.auto,
                size: 250,
                backgroundColor: Colors.white,
              ),
            )
          else
            const CircularProgressIndicator(),

          const SizedBox(height: 32),
          
          Card(
            color: AppTheme.darkSurface,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.wifi, color: AppTheme.electricBlue),
                    title: Text(l10n.t('local_ip')),
                    subtitle: Text(_ipAddress ?? 'Lade...', style: const TextStyle(fontFamily: 'monospace')),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.devices, color: AppTheme.electricBlue),
                    title: Text(l10n.t('mac_address')),
                    subtitle: Text(auth.macAddress, style: const TextStyle(fontFamily: 'monospace')),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          ElevatedButton.icon(
            autofocus: true,
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.electricBlue, overlayColor: Colors.white24),
            onPressed: () => _tabController.animateTo(1),
            icon: const Icon(Icons.edit, color: Colors.white),
            label: Text(l10n.t('qr_btn_manual'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildM3uTab(AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _m3uNameController,
            textCapitalization: TextCapitalization.none,
            decoration: InputDecoration(labelText: l10n.t('playlist_display_name'), border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.label_outline)),
          ),
          const SizedBox(height: 16),
          Text(l10n.t('m3u_url'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          VoiceInputField(
            controller: _m3uController,
            appLanguageCode: context.watch<LocaleProvider>().locale.languageCode,
            keyboardType: TextInputType.url,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'http://example.com/playlist.m3u',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.link),
            ),
          ),
          const SizedBox(height: 16),
          Text(l10n.t('epg_url'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          VoiceInputField(
            controller: _epgController,
            appLanguageCode: context.watch<LocaleProvider>().locale.languageCode,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              hintText: 'http://example.com/epg.xml',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.calendar_today),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(overlayColor: AppTheme.electricBlue.withValues(alpha: 0.18)),
                  onPressed: () => _pickFile(true),
                  icon: const Icon(Icons.folder_open),
                  label: Text(l10n.t('btn_m3u_phone'), textAlign: TextAlign.center),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(overlayColor: AppTheme.electricBlue.withValues(alpha: 0.18)),
                  onPressed: () => _pickFile(false),
                  icon: const Icon(Icons.calendar_today),
                  label: Text(l10n.t('btn_epg_phone'), textAlign: TextAlign.center),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.electricBlue,
                overlayColor: Colors.white24,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                if (_m3uController.text.isNotEmpty) {
                  _processPlaylist(_m3uController.text);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bitte M3U Daten eingeben oder hochladen')));
                }
              },
              child: Text(l10n.t('btn_start'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  void _applyServerScheme(String scheme) {
    final current = _xtreamServerController.text.trimLeft();
    final withoutScheme = current.replaceFirst(RegExp(r'^https?://', caseSensitive: false), '');
    _xtreamServerController.value = TextEditingValue(
      text: '$scheme$withoutScheme',
      selection: TextSelection.collapsed(offset: ('$scheme$withoutScheme').length),
    );
    _xtreamServerFocus.requestFocus();
  }

  Widget _buildXtreamTab(AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _xtreamNameController,
              textCapitalization: TextCapitalization.none,
              decoration: InputDecoration(labelText: l10n.t('playlist_display_name'), border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.label_outline)),
            ),
            const SizedBox(height: 16),
            Text(l10n.t('xtream_server'), style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  label: const Text('http://'),
                  tooltip: 'http:// einfügen',
                  onPressed: () => _applyServerScheme('http://'),
                ),
                ActionChip(
                  label: const Text('https://'),
                  tooltip: 'https:// einfügen',
                  onPressed: () => _applyServerScheme('https://'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            VoiceInputField(
              controller: _xtreamServerController,
              appLanguageCode: context.watch<LocaleProvider>().locale.languageCode,
              focusNode: _xtreamServerFocus,
              keyboardType: TextInputType.url,
              textCapitalization: TextCapitalization.none,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _xtreamUserFocus.requestFocus(),
              decoration: InputDecoration(labelText: l10n.t('xtream_server'), hintText: 'http://server.com:8080', border: const OutlineInputBorder(), focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: AppTheme.electricBlue, width: 2))),
            ),
            const SizedBox(height: 16),
            VoiceInputField(
              controller: _xtreamUserController,
              appLanguageCode: context.watch<LocaleProvider>().locale.languageCode,
              focusNode: _xtreamUserFocus,
              textCapitalization: TextCapitalization.none,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _xtreamPassFocus.requestFocus(),
              decoration: InputDecoration(labelText: l10n.t('xtream_user'), border: const OutlineInputBorder(), focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: AppTheme.electricBlue, width: 2))),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _xtreamPassController,
              focusNode: _xtreamPassFocus,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.none,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _xtreamConnectFocus.requestFocus(),
              decoration: InputDecoration(
                labelText: l10n.t('xtream_pass'),
                border: const OutlineInputBorder(),
                focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: AppTheme.electricBlue, width: 2)),
                suffixIcon: IconButton(
                  tooltip: 'TV keyboard',
                  icon: const Icon(Icons.keyboard_alt_outlined),
                  onPressed: () => TvTextKeyboard.show(
                    context,
                    controller: _xtreamPassController,
                    languageCode: context.read<LocaleProvider>().locale.languageCode,
                    secret: true,
                    onConfirmed: () => _xtreamConnectFocus.requestFocus(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                focusNode: _xtreamConnectFocus,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.electricBlue,
                  overlayColor: Colors.white24,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _connectXtream,
                child: Text(l10n.t('btn_start'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
