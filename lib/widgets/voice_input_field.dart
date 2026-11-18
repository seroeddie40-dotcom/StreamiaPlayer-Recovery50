import 'dart:async';
import 'package:flutter/material.dart';
import '../core/platform/device_layout.dart';
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
  final bool credentialMode;
  final bool obscureText;
  final bool secret;
  final TextStyle? style;
  final TextDirection? textDirection;
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
    this.credentialMode = false,
    this.obscureText = false,
    this.secret = false,
    this.style,
    this.textDirection,
    this.focusNode,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
  });

  // Apply spoken punctuation only to email addresses, not passwords or IDs.
  static String normalizeEmail(String value, String language) {
    const words = <String, Map<String, String>>{
      'de': {'punkt': '.', 'at': '@', 'bindestrich': '-', 'unterstrich': '_'},
      'tr': {'nokta': '.', 'et': '@', 'tire': '-', 'alt çizgi': '_'},
      'en': {'dot': '.', 'at': '@', 'hyphen': '-', 'underscore': '_'},
      'ru': {'точка': '.', 'собака': '@', 'дефис': '-', 'подчеркивание': '_'},
      'pl': {'kropka': '.', 'małpa': '@', 'myślnik': '-', 'podkreślenie': '_'},
      'es': {'punto': '.', 'arroba': '@', 'guion bajo': '_', 'guion': '-'},
      'fr': {'point': '.', 'arobase': '@', 'tiret bas': '_', 'tiret': '-'},
      'ar': {'نقطة': '.', 'آت': '@', 'شرطة سفلية': '_', 'شرطة': '-'},
    };
    var text = value.toLowerCase();
    for (final entry in (words[language] ?? words['en']!).entries) {
      text = text.replaceAllMapped(
        RegExp('(^|\\s+)${RegExp.escape(entry.key)}(?=\\s|\$)'),
        (match) => entry.value,
      );
    }
    return text.replaceAll(RegExp(r'\s+'), '');
  }

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
  bool _keyboardOpen = false;
  bool _tvFocused = false;
  bool _busy = false;
  bool _listening = false;
  String? _localeId;
  String _prefix = '';
  String _suffix = '';
  Timer? _searchTimer;
  Timer? _dictationTimer;
  int _session = 0;
  bool _acceptResults = false;
  bool _stoppingSearch = false;

  bool get _searchMode => widget.textInputAction == TextInputAction.search;

  Future<void> _finishSearch(int session) async {
    if (!mounted || session != _session) return;
    _searchTimer?.cancel();
    _dictationTimer?.cancel();
    _acceptResults = false;
    _session++;
    _stoppingSearch = true;
    setState(() {
      _listening = false;
      _busy = true;
    });
    try {
      await _speech.stop().timeout(const Duration(seconds: 2));
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
      _dictationTimer?.cancel();
      await _finishSearch(_session);
      return;
    }
    setState(() => _busy = true);
    try {
      if (!_ready) {
        final available = await _speech.initialize(
          onStatus: (status) {
            if (!mounted || _searchMode || !_acceptResults) return;
            if (status == 'listening') {
              setState(() => _listening = true);
            } else if (status == 'done' || status == 'notListening') {
              setState(() => _listening = false);
            }
          },
          onError: (_) {
            if (!mounted) return;
            _dictationTimer?.cancel();
            _searchTimer?.cancel();
            _acceptResults = false;
            _session++;
            setState(() { _listening = false; _busy = false; });
            _message(AppLocalizations.of(context).t('speech_unavailable'));
          },
        ).timeout(const Duration(seconds: 5));
        if (!mounted) return;
        if (!available) {
          _message(AppLocalizations.of(context).t('speech_unavailable'));
          return;
        }
        final locales = await _speech.locales().timeout(const Duration(seconds: 5));
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
      if (!replaceSearch) {
        _dictationTimer?.cancel();
        _dictationTimer = Timer(const Duration(seconds: 5), () {
          if (mounted && session == _session) {
            unawaited(_finishSearch(session));
          }
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
          if (!replaceSearch) {
            _dictationTimer?.cancel();
            _dictationTimer = Timer(const Duration(seconds: 30), () {
              if (mounted && session == _session) {
                unawaited(_finishSearch(session));
              }
            });
          }
          final spoken = result.recognizedWords;
          final credential = widget.credentialMode || _urlMode;
          if (credential && !result.finalResult) return;
          final commands = <String, List<String>>{
            'de': ['enter', 'weiter', 'jetzt passwort'],
            'tr': ['enter', 'ileri', 'şimdi şifre'],
            'en': ['enter', 'next', 'now password'],
            'ru': ['enter', 'далее', 'теперь пароль'],
            'pl': ['enter', 'dalej', 'teraz hasło'],
            'es': ['enter', 'siguiente', 'ahora contraseña'],
            'fr': ['enter', 'suivant', 'maintenant mot de passe'],
            'ar': ['enter', 'التالي', 'الآن كلمة المرور'],
          };
          final command = spoken.trim().toLowerCase();
          if (credential && !widget.secret && widget.onSubmitted != null &&
              (commands[widget.appLanguageCode] ?? commands['en']!).contains(command)) {
            // Never insert a partial navigation command into credentials.
            if (result.finalResult) {
              _acceptResults = false;
              _dictationTimer?.cancel();
              unawaited(_finishSearch(session));
              widget.onSubmitted!(widget.controller.text);
            }
            return;
          }
          final rawInsertion = _urlMode ? VoiceInputField.normalizeUrl(spoken) : widget.credentialMode ? spoken.replaceAll(RegExp(r'\s+'), '') : spoken;
          final insertion = widget.keyboardType == TextInputType.emailAddress
              ? VoiceInputField.normalizeEmail(spoken, widget.appLanguageCode)
              : rawInsertion;
          // One recognition session replaces only its own partial result.
          // Previously typed scheme and port are never discarded.
          final separator = !_urlMode && !widget.credentialMode && _prefix.isNotEmpty &&
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
      ).timeout(const Duration(seconds: 5));
      if (mounted && !replaceSearch && session == _session) {
        setState(() => _listening = _speech.isListening);
      }
    } catch (_) {
      _dictationTimer?.cancel();
      if (_acceptResults) await _finishSearch(_session);
      else if (mounted) setState(() => _listening = false);
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
    _dictationTimer?.cancel();
    _acceptResults = false;
    _session++;
    unawaited(_speech.stop().timeout(const Duration(seconds: 2)).then<void>((_) {}, onError: (Object _) {}));
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
    Future<void> openFallbackKeyboard() async {
      if (_keyboardOpen) return;
      _keyboardOpen = true;
      try {
        await TvTextKeyboard.show(
          context,
          controller: widget.controller,
          languageCode: widget.appLanguageCode,
          urlMode: _urlMode,
          secret: widget.secret,
          onConfirmed: widget.onSubmitted == null
              ? null
              : () => widget.onSubmitted!(widget.controller.text),
        );
      } finally {
        _keyboardOpen = false;
      }
    }
    final tvButton = IconButton(
      tooltip: l10n.t('tv_keyboard_title'),
      icon: const Icon(Icons.keyboard_alt_outlined),
      onPressed: openFallbackKeyboard,
    );
    Future<void> openKeyboard() async {
      if (_keyboardOpen || !mounted) return;
      _keyboardOpen = true;
      Object? result;
      try {
        result = await showDialog<Object>(
          context: context,
          builder: (_) => _NativeTvInputDialog(field: widget),
        );
      } finally {
        _keyboardOpen = false;
      }
      if (!mounted) return;
      if (result == _TvInputChoice.fallback) {
        await openFallbackKeyboard();
      } else if (result is String) {
        widget.controller.value = TextEditingValue(
          text: result,
          selection: TextSelection.collapsed(offset: result.length),
        );
        widget.onSubmitted?.call(result);
      }
    }
    if (DeviceLayout.isTelevision) {
      // Keep D-pad traversal separate from editing. OK opens a native IME client.
      return Row(children: [
        Expanded(child: InkWell(
          focusNode: widget.focusNode,
          autofocus: widget.autofocus,
          onTap: openKeyboard,
          onFocusChange: (focused) => setState(() => _tvFocused = focused),
          child: ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) => InputDecorator(
              decoration: base.copyWith(suffixIcon: const SizedBox.shrink()),
              isFocused: _tvFocused,
              isEmpty: widget.controller.text.isEmpty,
              child: Text(
                widget.obscureText
                    ? List.filled(widget.controller.text.runes.length, '•').join()
                    : widget.controller.text,
                style: widget.style,
                textDirection: widget.textDirection,
                maxLines: widget.maxLines,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        )),
        if (base.suffixIcon != null) base.suffixIcon!,
        suffix,
      ]);
    }
    return TextField(
      controller: widget.controller,
      obscureText: widget.obscureText,
      style: widget.style,
      textDirection: widget.textDirection,
      keyboardType: widget.keyboardType,
      autocorrect: !widget.credentialMode && !_urlMode,
      enableSuggestions: !widget.credentialMode && !_urlMode,
      enableIMEPersonalizedLearning: !widget.credentialMode && !_urlMode,
      smartDashesType: widget.credentialMode || _urlMode ? SmartDashesType.disabled : null,
      smartQuotesType: widget.credentialMode || _urlMode ? SmartQuotesType.disabled : null,
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


enum _TvInputChoice { fallback }

class _NativeTvInputDialog extends StatefulWidget {
  final VoiceInputField field;
  const _NativeTvInputDialog({required this.field});

  @override
  State<_NativeTvInputDialog> createState() => _NativeTvInputDialogState();
}

class _NativeTvInputDialogState extends State<_NativeTvInputDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final value = widget.field.controller.text;
    _controller = TextEditingController(text: value);
    _controller.selection = TextSelection.collapsed(offset: value.length);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    final field = widget.field;
    final l10n = AppLocalizations.of(context);
    final technical = field.credentialMode || field.secret ||
        field.keyboardType == TextInputType.url ||
        field.keyboardType == TextInputType.emailAddress;
    // The dialog is above the login/setup route, so its own insets must
    // adapt when the native keyboard reduces the available TV viewport.
    final media = MediaQuery.of(context);
    final availableHeight = media.size.height - media.viewInsets.vertical
        - media.padding.vertical;
    final compact = availableHeight < 340;
    return AlertDialog(
      scrollable: true,
      insetPadding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: compact ? 4 : 16,
      ),
      titlePadding: EdgeInsets.fromLTRB(16, compact ? 8 : 16, 16, 0),
      contentPadding: EdgeInsets.fromLTRB(16, compact ? 6 : 16, 16, 4),
      actionsPadding: EdgeInsets.fromLTRB(8, 0, 8, compact ? 4 : 8),
      title: Text(
        field.decoration.labelText ?? l10n.t('tv_keyboard_input'),
        maxLines: compact ? 1 : 2,
        overflow: TextOverflow.ellipsis,
      ),
      content: SizedBox(
        width: 480,
        child: TextField(
          controller: _controller,
          autofocus: true,
          keyboardType: field.keyboardType,
          obscureText: field.obscureText,
          maxLines: field.obscureText ? 1 : field.maxLines,
          textDirection: field.textDirection,
          textCapitalization: technical ? TextCapitalization.none : field.textCapitalization,
          autocorrect: !technical,
          enableSuggestions: !technical,
          enableIMEPersonalizedLearning: !technical,
          smartDashesType: technical ? SmartDashesType.disabled : null,
          smartQuotesType: technical ? SmartQuotesType.disabled : null,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _confirm(),
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            isDense: compact,
            contentPadding: compact
                ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                : null,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(_TvInputChoice.fallback),
          child: Text(l10n.t('tv_keyboard_title')),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.t('tv_keyboard_cancel')),
        ),
        FilledButton(
          onPressed: _confirm,
          child: Text(l10n.t('tv_keyboard_confirm')),
        ),
      ],
    );
  }
}
