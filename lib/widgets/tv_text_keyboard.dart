import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/localization/app_localizations.dart';

/// Remote-control friendly text entry. The OS keyboard remains available;
/// this dialog is an alternative for devices without a convenient IME.
class TvTextKeyboard {
  static const Map<String, String> _extraLetters = {
    'de': 'äöüß', 'tr': 'çğıöşü', 'en': '', 'ru': 'абвгдеёжзийклмнопрстуфхцчшщъыьэюя',
    'pl': 'ąćęłńóśźż', 'es': 'áéíñóúü', 'fr': 'àâæçéèêëîïôœùûüÿ',
    'ar': 'ابتثجحخدذرزسشصضطظعغفقكلمنهويءآأإؤئىة',
  };

  static Future<void> show(
    BuildContext context, {
    required TextEditingController controller,
    required String languageCode,
    bool secret = false,
    bool urlMode = false,
    VoidCallback? onConfirmed,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _TvKeyboardDialog(
        controller: controller,
        languageCode: languageCode,
        secret: secret,
        urlMode: urlMode && !secret,

      ),
    );
    if (confirmed == true && context.mounted) onConfirmed?.call();
  }
}

class _TvKeyboardDialog extends StatefulWidget {
  const _TvKeyboardDialog({required this.controller, required this.languageCode, required this.secret, required this.urlMode});
  final TextEditingController controller;
  final String languageCode;
  final bool secret;
  final bool urlMode;

  @override
  State<_TvKeyboardDialog> createState() => _TvKeyboardDialogState();
}

class _TvKeyboardDialogState extends State<_TvKeyboardDialog> {
  late final TextEditingController _draft;
  bool _showSecret = false;
  bool _uppercase = false;
  bool _symbols = false;
  bool _latin = false;
  late final FocusNode _cancelFocus;
  late final FocusNode _confirmFocus;
  FocusNode? _lastKeyFocus;

  // Arrow keys use spatial navigation, while Tab keeps the explicit order.
  // This handler is an ancestor of the dialog's buttons so it also receives
  // key events when the currently focused key is inside the scrolling area.
  KeyEventResult _handleDpad(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final direction = switch (key) {
      LogicalKeyboardKey.arrowLeft => TraversalDirection.left,
      LogicalKeyboardKey.arrowRight => TraversalDirection.right,
      LogicalKeyboardKey.arrowUp => TraversalDirection.up,
      LogicalKeyboardKey.arrowDown => TraversalDirection.down,
      _ => null,
    };
    if (direction == null) return KeyEventResult.ignored;
    final current = FocusManager.instance.primaryFocus;
    if (current == null || current == node) return KeyEventResult.ignored;

    final onCancel = identical(current, _cancelFocus);
    final onConfirm = identical(current, _confirmFocus);
    if (onCancel || onConfirm) {
      if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight) {
        (onCancel ? _confirmFocus : _cancelFocus).requestFocus();
      } else if (key == LogicalKeyboardKey.arrowUp) {
        final target = _lastKeyFocus;
        if (target != null && target.canRequestFocus) {
          target.requestFocus();
        } else {
          FocusTraversalGroup.of(context).inDirection(current, TraversalDirection.up);
        }
      }
      // At the bottom edge, do not let focus escape the dialog.
      return KeyEventResult.handled;
    }

    _lastKeyFocus = current;
    final moved = FocusTraversalGroup.of(context).inDirection(current, direction);
    if (!moved && key == LogicalKeyboardKey.arrowDown) {
      _confirmFocus.requestFocus();
    }
    // Always consume direction keys inside the modal dialog. Otherwise a
    // second traversal pass may move focus again or escape to the background.
    return KeyEventResult.handled;
  }

  void _cancel() => Navigator.of(context).pop();

  void _confirm() {
    widget.controller.value = TextEditingValue(
      text: _draft.text,
      selection: TextSelection.collapsed(offset: _draft.text.length),
    );
    Navigator.of(context).pop(true);
  }

  @override
  void initState() {
    super.initState();
    _draft = TextEditingController(text: widget.controller.text);
    _cancelFocus = FocusNode(debugLabel: 'TV keyboard cancel');
    _confirmFocus = FocusNode(debugLabel: 'TV keyboard confirm');
  }

  @override
  void dispose() {
    _draft.dispose();
    _cancelFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  void _insert(String value) {
    final text = _draft.text;
    final selection = _draft.selection;
    final start = selection.isValid ? selection.start.clamp(0, text.length).toInt() : text.length;
    final end = selection.isValid ? selection.end.clamp(0, text.length).toInt() : text.length;
    final updated = text.replaceRange(start, end, value);
    _draft.value = TextEditingValue(text: updated, selection: TextSelection.collapsed(offset: start + value.length));
    setState(() {});
  }

  // URL shortcuts must not turn an existing http://host into
  // https://http://host. Replace a leading scheme rather than append it.
  // The remaining URL (including port, path and query) stays unchanged.
  void _insertUrlScheme(String scheme) {
    final current = _draft.text;
    final existing = RegExp(r'^https?://', caseSensitive: false).firstMatch(current);
    final updated = existing == null
        ? '$scheme$current'
        : '$scheme${current.substring(existing.end)}';
    _draft.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: scheme.length),
    );
    setState(() {});
  }

  void _delete() {
    final text = _draft.text;
    final selection = _draft.selection;
    final end = selection.isValid ? selection.end.clamp(0, text.length).toInt() : text.length;
    final start = selection.isValid ? selection.start.clamp(0, text.length).toInt() : text.length;
    if (start != end) {
      _draft.value = TextEditingValue(text: text.replaceRange(start, end, ''), selection: TextSelection.collapsed(offset: start));
    } else if (start > 0) {
      // Unicode code points, not UTF-16 units, so emoji are not split in half.
      final before = text.substring(0, start);
      final last = before.runes.last;
      final deleteStart = start - String.fromCharCode(last).length;
      _draft.value = TextEditingValue(text: text.replaceRange(deleteStart, start, ''), selection: TextSelection.collapsed(offset: deleteStart));
    }
    setState(() {});
  }

  Widget _key(String label, String value, {required double order, bool autofocus = false}) =>
      FocusTraversalOrder(
        order: NumericFocusOrder(order),
        child: _TvKeyboardKey(
        label: label,
        autofocus: autofocus,
        onPressed: () => _insert(value),
      ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String tr(String key) => l10n.t(key);
    final lang = widget.languageCode.toLowerCase().replaceAll('_', '-').split('-').first;
    final nativeScript = lang == 'ru' || lang == 'ar';
    final latinAlphabet = switch (lang) {
      'de' => 'qwertzuiopasdfghjklyxcvbnm',
      'fr' => 'azertyuiopqsdfghjklmwxcvbn',
      _ => 'qwertyuiopasdfghjklzxcvbnm',
    };
    final alphabet = nativeScript && !_latin
        ? TvTextKeyboard._extraLetters[lang]!
        : '$latinAlphabet${nativeScript ? '' : TvTextKeyboard._extraLetters[lang] ?? ''}';
    final letters = alphabet.split('');
    final symbols = ['.', '/', ':', '-', '_', '@', '?', '&', '=', '%', '+', '#', '!', r'$', '*', '(', ')', '[', ']', '{', '}', ';', ',', '~', '^', '|', '<', '>', '"', "'", r'\', '`'];
    final keys = [...'1234567890'.split(''), ...(_symbols ? symbols : letters.map((letter) {
      if (!_uppercase) return letter;
      if (lang == 'tr' && letter == 'i') return 'İ';
      return letter.toUpperCase();
    }))];
    final viewport = MediaQuery.sizeOf(context);
    final width = (viewport.width * .82).clamp(240.0, 560.0).toDouble();
    final maxHeight = (viewport.height * .52).clamp(120.0, 340.0).toDouble();
    return Focus(
      canRequestFocus: false,
      onKeyEvent: _handleDpad,
      child: CallbackShortcuts(
      bindings: {LogicalKeySet(LogicalKeyboardKey.escape): _cancel},
      child: Directionality(
      textDirection: lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        title: Text(tr('tv_keyboard_title'), style: const TextStyle(fontSize: 17)),
        titlePadding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        contentPadding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        content: SizedBox(
          width: width,
          height: maxHeight,
          child: FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child: Column(children: [
              TextField(
                canRequestFocus: false,
                controller: _draft,
                readOnly: true, // Do not pop up the OS IME over the TV keyboard.
                showCursor: true,
                obscureText: widget.secret && !_showSecret,
                enableSuggestions: false,
                autocorrect: false,
                textCapitalization: TextCapitalization.none,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: const OutlineInputBorder(),
                  labelText: tr('tv_keyboard_input'),
                  suffixIcon: widget.secret ? IconButton(
                    tooltip: _showSecret ? tr('tv_keyboard_hide_password') : tr('tv_keyboard_show_password'),
                    onPressed: () => setState(() => _showSecret = !_showSecret),
                    icon: Icon(_showSecret ? Icons.visibility_off : Icons.visibility),
                  ) : null,
                ),
              ),
              const SizedBox(height: 6),
              Expanded(child: SingleChildScrollView(child: Column(children: [
                Wrap(spacing: 3, runSpacing: 3, alignment: WrapAlignment.center, children: [
                  for (var i = 0; i < keys.length; i++)
                    _key(keys[i], keys[i], order: i.toDouble(), autofocus: i == 0),
                ]),
                const SizedBox(height: 6),
                Wrap(spacing: 5, runSpacing: 5, alignment: WrapAlignment.center, children: [
                  FocusTraversalOrder(order: const NumericFocusOrder(190), child: OutlinedButton(onPressed: () => setState(() { _uppercase = !_uppercase; _symbols = false; }), child: Text(_uppercase ? 'ABC' : 'abc'))),
                  FocusTraversalOrder(order: const NumericFocusOrder(191), child: OutlinedButton(onPressed: () => setState(() => _symbols = !_symbols), child: Text(_symbols ? 'ABC' : '123#!'))),
                  if (nativeScript) FocusTraversalOrder(order: const NumericFocusOrder(192), child: OutlinedButton(onPressed: () => setState(() => _latin = !_latin), child: Text(_latin ? (lang == 'ru' ? 'АБВ' : 'أبج') : 'ABC'))),
                  FocusTraversalOrder(order: const NumericFocusOrder(200), child: OutlinedButton(onPressed: () => _insert(' '), child: Text(tr('tv_keyboard_space')))),
                  FocusTraversalOrder(order: const NumericFocusOrder(201), child: OutlinedButton(onPressed: _delete, child: Text(tr('tv_keyboard_backspace')))),
                  if (widget.urlMode) ...[
                    FocusTraversalOrder(order: const NumericFocusOrder(202), child: OutlinedButton(onPressed: () => _insertUrlScheme('http://'), child: const Text('http://'))),
                    FocusTraversalOrder(order: const NumericFocusOrder(203), child: OutlinedButton(onPressed: () => _insertUrlScheme('https://'), child: const Text('https://'))),
                  ],
                ]),
              ]))),
            ]),
          ),
        ),
        actions: [
          FocusTraversalOrder(order: const NumericFocusOrder(300), child: TextButton(focusNode: _cancelFocus, onPressed: _cancel, child: Text(tr('tv_keyboard_cancel')))),
          FocusTraversalOrder(order: const NumericFocusOrder(301), child: FilledButton(focusNode: _confirmFocus, onPressed: _confirm, child: Text(tr('tv_keyboard_confirm')))),
        ],
      ),
      ),
      ),
      ),
    );
  }
}

/// Keeps the currently selected key visible while navigating with a TV D-pad.
/// Each key owns its focus node, so rebuilding the dialog does not lose focus.
class _TvKeyboardKey extends StatefulWidget {
  const _TvKeyboardKey({
    required this.label,
    required this.onPressed,
    this.autofocus = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool autofocus;

  @override
  State<_TvKeyboardKey> createState() => _TvKeyboardKeyState();
}

class _TvKeyboardKeyState extends State<_TvKeyboardKey> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'TV key ${widget.label}');
    _focusNode.addListener(_keepFocusedKeyVisible);
  }

  void _keepFocusedKeyVisible() {
    if (!_focusNode.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_focusNode.hasFocus) return;
      // Only scroll the nearest ancestor (the keyboard's own scroll area).
      // Do not move the whole dialog when focus changes.
      Scrollable.ensureVisible(
        context,
        alignment: 0.5,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  @override
  void dispose() {
    _focusNode.removeListener(_keepFocusedKeyVisible);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 38,
        height: 34,
        child: OutlinedButton(
          focusNode: _focusNode,
          autofocus: widget.autofocus,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            foregroundColor: Colors.white,
            backgroundColor: const Color(0xFF25344E),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ).copyWith(
            backgroundColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.focused)
                    ? const Color(0xFF087EAA)
                    : const Color(0xFF25344E)),
          ),
          onPressed: widget.onPressed,
          child: Text(widget.label, style: const TextStyle(fontSize: 14)),
        ),
      );
}
