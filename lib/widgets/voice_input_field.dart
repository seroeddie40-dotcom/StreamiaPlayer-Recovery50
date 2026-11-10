import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../core/localization/app_localizations.dart';
import '../core/theme/app_theme.dart';
import 'tv_text_keyboard.dart';

/// Dictation-enabled input for non-secret values (URLs, usernames, search terms).
/// Recognition uses the selected app language when the device provides it.
/// Recognized text is inserted verbatim; the user can review and correct it.
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

  @override
  State<VoiceInputField> createState() => _VoiceInputFieldState();
}

class _VoiceInputFieldState extends State<VoiceInputField> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _ready = false;
  bool _busy = false;
  bool _listening = false;
  String? _localeId;

  String _languageOf(String id) => id.replaceAll('-', '_').split('_').first.toLowerCase();

  Future<void> _startDictation() async {
    if (_busy) return;
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
            if (mounted) setState(() => _listening = status == 'listening');
          },
          onError: (_) {
            if (mounted) {
              setState(() => _listening = false);
              _message(AppLocalizations.of(context).t('speech_unavailable'));
            }
          },
        );
        if (!available) {
          _message(AppLocalizations.of(context).t('speech_unavailable'));
          return;
        }
        final locales = await _speech.locales();
        final matches = locales.where((l) => _languageOf(l.localeId) == widget.appLanguageCode.toLowerCase()).toList();
        if (matches.isEmpty) {
          _message(AppLocalizations.of(context).t('speech_language_missing'));
          return;
        }
        _localeId = matches.first.localeId;
        _ready = true;
      }
      await _speech.listen(
        localeId: _localeId,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: stt.ListenMode.dictation,
        ),
        onResult: (result) {
          if (!mounted || result.recognizedWords.isEmpty) return;
          final text = result.recognizedWords;
          widget.controller.value = TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
        },
      );
      if (mounted) setState(() => _listening = true);
    } catch (_) {
      _message(AppLocalizations.of(context).t('speech_unavailable'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String value) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  void dispose() {
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
      tooltip: 'TV keyboard',
      icon: const Icon(Icons.keyboard_alt_outlined),
      onPressed: () => TvTextKeyboard.show(
        context,
        controller: widget.controller,
        languageCode: widget.appLanguageCode,
        urlMode: widget.keyboardType == TextInputType.url,
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
