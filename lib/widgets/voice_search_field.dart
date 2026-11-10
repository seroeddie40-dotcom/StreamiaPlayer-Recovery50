import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../core/localization/app_localizations.dart';
import '../core/theme/app_theme.dart';

/// Text search with optional native Android speech recognition.
/// Available languages/dialects are supplied by the device's recognition service.
class VoiceSearchField extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final String appLanguageCode;
  final TextEditingController? controller;

  const VoiceSearchField({
    super.key,
    required this.onChanged,
    required this.appLanguageCode,
    this.controller,
  });

  @override
  State<VoiceSearchField> createState() => _VoiceSearchFieldState();
}

class _VoiceSearchFieldState extends State<VoiceSearchField> {
  late final TextEditingController _controller = widget.controller ?? TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  List<stt.LocaleName> _locales = [];
  String? _selectedLocaleId;
  bool _initialized = false;
  bool _initializing = false;
  bool _listening = false;
  bool _ownsController = false;

  static const _supported = {'de', 'tr', 'en', 'ru', 'ar', 'pl', 'es', 'fr'};

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
  }

  @override
  void dispose() {
    _speech.stop();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  String _codeOf(String localeId) => localeId.replaceAll('-', '_').split('_').first.toLowerCase();

  Future<void> _prepare() async {
    if (_initialized) return;
    if (_initializing) return;
    setState(() => _initializing = true);
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          setState(() => _listening = status == 'listening');
        },
        onError: (error) {
          if (!mounted) return;
          setState(() => _listening = false);
          _showMessage(AppLocalizations.of(context).t('speech_unavailable'));
        },
        debugLogging: false,
      );
      if (!available) {
        if (mounted) _showMessage(AppLocalizations.of(context).t('speech_unavailable'));
        return;
      }
      final all = await _speech.locales();
      _locales = all.where((l) => _supported.contains(_codeOf(l.localeId))).toList()
        ..sort((a, b) => a.localeId.compareTo(b.localeId));
      _initialized = true;
      final appMatches = _locales.where((l) => _codeOf(l.localeId) == widget.appLanguageCode.toLowerCase()).toList();
      if (appMatches.isNotEmpty) {
        _selectedLocaleId = appMatches.first.localeId;
      } else if (_locales.isNotEmpty) {
        _selectedLocaleId = _locales.first.localeId;
      }
    } catch (_) {
      if (mounted) _showMessage(AppLocalizations.of(context).t('speech_unavailable'));
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleListening() async {
    if (_listening || _speech.isListening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    await _prepare();
    if (!mounted || !_initialized) return;
    if (_locales.isEmpty || _selectedLocaleId == null) {
      _showMessage(AppLocalizations.of(context).t('speech_language_missing'));
      return;
    }
    try {
      await _speech.listen(
        onResult: (result) {
          if (!mounted || result.recognizedWords.isEmpty) return;
          _controller.value = TextEditingValue(
            text: result.recognizedWords,
            selection: TextSelection.collapsed(offset: result.recognizedWords.length),
          );
          widget.onChanged(result.recognizedWords);
        },
        localeId: _selectedLocaleId,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: stt.ListenMode.search,
        ),
      );
      if (mounted) setState(() => _listening = true);
    } catch (_) {
      _showMessage(AppLocalizations.of(context).t('speech_unavailable'));
    }
  }

  Future<void> _chooseLocale() async {
    await _prepare();
    if (!mounted) return;
    if (_locales.isEmpty) {
      _showMessage(AppLocalizations.of(context).t('speech_language_missing'));
      return;
    }
    final l10n = AppLocalizations.of(context);
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.t('choose_voice_language'), style: Theme.of(context).textTheme.titleMedium),
            ),
            ..._locales.map((locale) => ListTile(
              leading: const Icon(Icons.language),
              title: Text(locale.name),
              autofocus: locale.localeId == _selectedLocaleId || (_selectedLocaleId == null && _locales.isNotEmpty && locale.localeId == _locales.first.localeId),
              focusColor: AppTheme.electricBlue.withOpacity(0.16),
              subtitle: Text(locale.localeId),
              trailing: locale.localeId == _selectedLocaleId ? const Icon(Icons.check, color: AppTheme.electricBlue) : null,
              onTap: () => Navigator.pop(sheetContext, locale.localeId),
            )),
          ],
        ),
      ),
    );
    if (selected != null && mounted) setState(() => _selectedLocaleId = selected);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: l10n.t('search_hint'),
        prefixIcon: const Icon(Icons.search),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: l10n.t('choose_voice_language'),
              focusColor: AppTheme.electricBlue.withOpacity(0.18),
              onPressed: _chooseLocale,
              icon: const Icon(Icons.translate),
            ),
            IconButton(
              tooltip: l10n.t('voice_search'),
              focusColor: AppTheme.electricBlue.withOpacity(0.18),
              onPressed: _initializing ? null : _toggleListening,
              icon: _initializing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(_listening ? Icons.mic : Icons.mic_none,
                      color: _listening ? Colors.redAccent : AppTheme.electricBlue),
            ),
          ],
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        filled: true,
      ),
    );
  }
}
