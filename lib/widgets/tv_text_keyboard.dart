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
    await showDialog<void>(
      context: context,
      builder: (_) => _TvKeyboardDialog(
        controller: controller,
        languageCode: languageCode,
        secret: secret,
        urlMode: urlMode && !secret,
        onConfirmed: onConfirmed,
      ),
    );
  }
}

class _TvKeyboardDialog extends StatefulWidget {
  const _TvKeyboardDialog({required this.controller, required this.languageCode, required this.secret, required this.urlMode, this.onConfirmed});
  final TextEditingController controller;
  final String languageCode;
  final bool secret;
  final bool urlMode;
  final VoidCallback? onConfirmed;

  @override
  State<_TvKeyboardDialog> createState() => _TvKeyboardDialogState();
}

class _TvKeyboardDialogState extends State<_TvKeyboardDialog> {
  late final TextEditingController _draft;
  bool _showSecret = false;
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
    Navigator.of(context).pop();
    // Run after closing the modal so focus is not trapped in the dialog.
    widget.onConfirmed?.call();
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
    final alphabet = lang == 'ru' || lang == 'ar'
        ? TvTextKeyboard._extraLetters[lang]!
        : 'abcdefghijklmnopqrstuvwxyz${TvTextKeyboard._extraLetters[lang] ?? ''}';
    final letters = <String>{...alphabet.split('')}.toList();
    final digits = '0123456789'.split('');
    final viewport = MediaQuery.sizeOf(context);
    // A TV keyboard must fit both compact 720p screens and wide 1080p displays.
    final width = (viewport.width - 32).clamp(260.0, 680.0);
    final maxHeight = (viewport.height - MediaQuery.viewInsetsOf(context).bottom - 96).clamp(180.0, 520.0);
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
        title: Text(tr('tv_keyboard_title')),
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
                  border: const OutlineInputBorder(),
                  labelText: tr('tv_keyboard_input'),
                  suffixIcon: widget.secret ? Focus(canRequestFocus: false, child: IconButton(
                    tooltip: _showSecret ? tr('tv_keyboard_hide_password') : tr('tv_keyboard_show_password'),
                    onPressed: () => setState(() => _showSecret = !_showSecret),
                    icon: Icon(_showSecret ? Icons.visibility_off : Icons.visibility),
                  )) : null,
                ),
              ),
              const SizedBox(height: 6),
              Expanded(child: SingleChildScrollView(child: Column(children: [
                Wrap(spacing: 4, runSpacing: 4, alignment: WrapAlignment.center, children: [
                  // Every letter case has its own remote-selectable button.
                  // No Shift step is required between lowercase and uppercase.
                  for (var i = 0; i < letters.length; i++) ...[
                    _key(letters[i], letters[i], order: (i * 2).toDouble(), autofocus: i == 0),
                    if (letters[i].toUpperCase() != letters[i])
                      _key(letters[i].toUpperCase(), letters[i].toUpperCase(), order: (i * 2 + 1).toDouble()),
                  ],
                  for (var i = 0; i < digits.length; i++) _key(digits[i], digits[i], order: 100 + i.toDouble()),
                  for (var i = 0; i < const ['.', '/', ':', '-', '_', '@', '?', '&', '=', '%', '+', '#'].length; i++)
                    _key(const ['.', '/', ':', '-', '_', '@', '?', '&', '=', '%', '+', '#'][i],
                         const ['.', '/', ':', '-', '_', '@', '?', '&', '=', '%', '+', '#'][i], order: 120 + i.toDouble()),
                ]),
                const SizedBox(height: 6),
                Wrap(spacing: 5, runSpacing: 5, alignment: WrapAlignment.center, children: [
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
        width: 49,
        height: 49,
        child: OutlinedButton(
          focusNode: _focusNode,
          autofocus: widget.autofocus,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
          onPressed: widget.onPressed,
          child: Text(widget.label, style: const TextStyle(fontSize: 15)),
        ),
      );
}
