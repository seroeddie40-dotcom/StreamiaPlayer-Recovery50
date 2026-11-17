import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../core/localization/app_localizations.dart';
import '../core/theme/app_theme.dart';
import 'tv_text_keyboard.dart';

/// Speech-enabled text input. URL dictation preserves existing text and
/// normalizes technical syntax without modifying ordinary search fields.
class VoiceInputField extends StatefulWidget {
  final TextEditingController controller;
  final String appLanguageCode;
  final InputDecoration decoration;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;
  final int? maxLines;
  final bool autofocus;
  final FocusNode? focusNode;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  const VoiceInputField({
    super.key,
    required this.controller,
    required this.appLanguageCode,
    required this.decoration,
    this.keyboardType = TextInputType.text,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
    this.autofocus = false,
    this.focusNode,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
  });

  static String normalizeUrl(String value) {
    var text = value.trim();
    // Speech engines may capitalize schemes, add spaces after colons or
    // transcribe a spoken scheme as words.
    text = text.replaceFirst(
      RegExp(r'^https?\s*:\s*/\s*/', caseSensitive: false),
      text.toLowerCase().startsWith('https') ? 'https://' : 'http://',
    );
    text = text.replaceFirst(
      RegExp(r'^https?\s+(?:colon|doppelpunkt|iki nokta)\s*(?:slash|schrägstrich|barra|/)\s*(?:slash|schrägstrich|barra|/)', caseSensitive: false),
      text.toLowerCase().startsWith('https') ? 'https://' : 'http://',
    );
    text = text.replaceAll(RegExp(r'\s+'), '');
    return text;
  }


  @override
  State<VoiceInputField> createState() => _VoiceInputFieldState();
}

class _VoiceInputFieldState extends State<VoiceInputField> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _ready = false;
  bool _busy = false;
  bool _listening = false;
  String? _localeId;
  String _prefix = '';
  String _suffix = '';
  Timer? _searchTimer;
  int _session = 0;
  bool _acceptResults = false;
  bool _stoppingSearch = false;

  bool get _searchMode => widget.textInputAction == TextInputAction.search;

  Future<void> _finishSearch(int session) async {
    if (!mounted || session != _session) return;
    _searchTimer?.cancel();
    _acceptResults = false;
    _session++;
    _stoppingSearch = true;
    setState(() {
      _listening = false;
      _busy = true;
    });
    try {
      await _speech.stop();
    } catch (_) {
      // Results are already invalidated even if the platform stops late.
    } finally {
      _stoppingSearch = false;
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _urlMode => widget.keyboardType == TextInputType.url;

  String _languageOf(String id) =>
      id.replaceAll('-', '_').split('_').first.toLowerCase();


  Future<void> _startDictation() async {
    if (_busy) return;
    if (_searchMode && _searchTimer?.isActive == true) return;
    if (_listening || _speech.isListening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    setState(() => _busy = true);
    try {
      if (!_ready) {
        final available = await _speech.initialize(
          onStatus: (status) {
            if (mounted && !_searchMode) {
              setState(() => _listening = status == 'listening');
            }
          },
          onError: (_) {
            if (!mounted) return;
            if (!_searchMode) setState(() => _listening = false);
            _message(AppLocalizations.of(context).t('speech_unavailable'));
          },
        );
        if (!mounted) return;
        if (!available) {
          _message(AppLocalizations.of(context).t('speech_unavailable'));
          return;
        }
        final locales = await _speech.locales();
        if (!mounted) return;
        final matches = locales.where((l) =>
            _languageOf(l.localeId) == widget.appLanguageCode.toLowerCase()).toList();
        if (matches.isEmpty) {
          _message(AppLocalizations.of(context).t('speech_language_missing'));
          return;
        }
        _localeId = matches.first.localeId;
        _ready = true;
      }

      final existing = widget.controller.value;
      final replaceSearch = widget.textInputAction == TextInputAction.search;
      final start = existing.selection.isValid
          ? existing.selection.start.clamp(0, existing.text.length)
          : existing.text.length;
      final end = existing.selection.isValid
          ? existing.selection.end.clamp(0, existing.text.length)
          : existing.text.length;
      _prefix = replaceSearch ? '' : existing.text.substring(0, start);
      _suffix = replaceSearch ? '' : existing.text.substring(end);

      final session = ++_session;
      _acceptResults = true;
      if (replaceSearch) {
        setState(() => _listening = true);
        _searchTimer = Timer(const Duration(seconds: 5), () {
          unawaited(_finishSearch(session));
        });
      }
      await _speech.listen(
        localeId: _localeId,
        listenFor: Duration(seconds: replaceSearch ? 5 : 30),
        pauseFor: Duration(seconds: replaceSearch ? 5 : 3),
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: stt.ListenMode.dictation,
        ),
        onResult: (result) {
          if (!mounted || !_acceptResults || session != _session ||
              result.recognizedWords.isEmpty) return;
          final spoken = result.recognizedWords;
          final insertion = _urlMode ? VoiceInputField.normalizeUrl(spoken) : spoken;
          // One recognition session replaces only its own partial result.
          // Previously typed scheme and port are never discarded.
          final separator = !_urlMode && _prefix.isNotEmpty &&
                  !_prefix.endsWith(' ') && insertion.isNotEmpty
              ? ' '
              : '';
          final before = '$_prefix$separator$insertion';
          final value = _urlMode ? VoiceInputField.normalizeUrl('$before$_suffix') : '$before$_suffix';
          widget.controller.value = TextEditingValue(
            text: value,
            selection: TextSelection.collapsed(offset: _urlMode ? value.length : before.length),
          );
        },
      );
      if (mounted && !replaceSearch) {
        setState(() => _listening = _speech.isListening);
      }
    } catch (_) {
      if (_searchMode && _acceptResults) await _finishSearch(_session);
      if (mounted) _message(AppLocalizations.of(context).t('speech_unavailable'));
    } finally {
      if (mounted && !_stoppingSearch) {
        setState(() => _busy = false);
      }
    }
  }

  void _message(String value) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _acceptResults = false;
    _session++;
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final suffix = IconButton(
      tooltip: l10n.t('voice_input'),
      focusColor: AppTheme.electricBlue.withOpacity(0.2),
      onPressed: _busy ? null : _startDictation,
      icon: _busy
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(_listening ? Icons.mic : Icons.mic_none,
              color: _listening ? Colors.redAccent : AppTheme.electricBlue),
    );
    final base = widget.decoration;
    final tvButton = IconButton(
      tooltip: l10n.t('tv_keyboard_title'),
      icon: const Icon(Icons.keyboard_alt_outlined),
      onPressed: () => TvTextKeyboard.show(
        context,
        controller: widget.controller,
        languageCode: widget.appLanguageCode,
        urlMode: _urlMode,
        onConfirmed: widget.onSubmitted == null
            ? null
            : () => widget.onSubmitted!(widget.controller.text),
      ),
    );
    return TextField(
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      textCapitalization: widget.textCapitalization,
      maxLines: widget.maxLines,
      autofocus: widget.autofocus,
      focusNode: widget.focusNode,
      textInputAction: widget.textInputAction,
      onSubmitted: widget.onSubmitted,
      decoration: base.copyWith(
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [tvButton, if (base.suffixIcon != null) base.suffixIcon!, suffix],
        ),
      ),
    );
  }
}
