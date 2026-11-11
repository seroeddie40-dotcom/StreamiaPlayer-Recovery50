import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/localization/app_localizations.dart';

/// Compact, remote-control-friendly alternative to the device keyboard.
/// The original controller is changed only when the user confirms.
class TvTextKeyboard {
  static const Map<String, String> _extraLetters = {
    'de': 'äöüß',
    'tr': 'çğıöşü',
    'en': '',
    'ru': 'абвгдеёжзийклмнопрстуфхцчшщъыьэюя',
    'pl': 'ąćęłńóśźż',
    'es': 'áéíñóúü',
    'fr': 'àâæçéèêëîïôœùûüÿ',
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
  const _TvKeyboardDialog({
    required this.controller,
    required this.languageCode,
    required this.secret,
    required this.urlMode,
    this.onConfirmed,
  });

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
  late final FocusNode _cancelFocus;
  late final FocusNode _confirmFocus;
  final ScrollController _gridScroll = ScrollController();
  bool _showSecret = false;
  int _page = 0; // 0 lowercase, 1 uppercase, 2 numbers/symbols

  String get _language => widget.languageCode
      .toLowerCase()
      .replaceAll('_', '-')
      .split('-')
      .first;

  @override
  void initState() {
    super.initState();
    _draft = TextEditingController(text: widget.controller.text);
    _draft.selection = TextSelection.collapsed(offset: _draft.text.length);
    _cancelFocus = FocusNode(debugLabel: 'TV keyboard cancel');
    _confirmFocus = FocusNode(debugLabel: 'TV keyboard confirm');
  }

  @override
  void dispose() {
    _draft.dispose();
    _gridScroll.dispose();
    _cancelFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  List<String> get _keys {
    if (_page == 2) {
      return '0123456789'.split('') +
          const ['.', '/', ':', '-', '_', '@', '?', '&', '=', '%', '+', '#',
            '!', '*', '(', ')', ',', ';', '\'', '"'];
    }
    final alphabet = _language == 'ru' || _language == 'ar'
        ? TvTextKeyboard._extraLetters[_language]!
        : 'abcdefghijklmnopqrstuvwxyz${TvTextKeyboard._extraLetters[_language] ?? ''}';
    final unique = alphabet.runes.map(String.fromCharCode).toSet().toList();
    if (_page == 1) {
      return unique.map((letter) => letter.toUpperCase()).toList();
    }
    return unique;
  }

  void _changePage(int page) {
    if (_page == page) return;
    setState(() => _page = page);
    if (_gridScroll.hasClients) _gridScroll.jumpTo(0);
  }

  void _insert(String value) {
    final old = _draft.text;
    final selection = _draft.selection;
    final start = selection.isValid
        ? selection.start.clamp(0, old.length).toInt()
        : old.length;
    final end = selection.isValid
        ? selection.end.clamp(0, old.length).toInt()
        : old.length;
    final updated = old.replaceRange(start, end, value);
    _draft.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: start + value.length),
    );
  }

  void _delete() {
    final old = _draft.text;
    final selection = _draft.selection;
    final start = selection.isValid
        ? selection.start.clamp(0, old.length).toInt()
        : old.length;
    final end = selection.isValid
        ? selection.end.clamp(0, old.length).toInt()
        : old.length;
    if (start != end) {
      _draft.value = TextEditingValue(
        text: old.replaceRange(start, end, ''),
        selection: TextSelection.collapsed(offset: start),
      );
    } else if (start > 0) {
      final before = old.substring(0, start);
      final rune = before.runes.last;
      final length = String.fromCharCode(rune).length;
      final from = start - length;
      _draft.value = TextEditingValue(
        text: old.replaceRange(from, start, ''),
        selection: TextSelection.collapsed(offset: from),
      );
    }
  }

  void _insertUrlScheme(String scheme) {
    final old = _draft.text;
    final existing = RegExp(r'^https?://', caseSensitive: false).firstMatch(old);
    final updated = existing == null
        ? '$scheme$old'
        : '$scheme${old.substring(existing.end)}';
    _draft.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: updated.length),
    );
  }

  void _confirm() {
    widget.controller.value = TextEditingValue(
      text: _draft.text,
      selection: TextSelection.collapsed(offset: _draft.text.length),
    );
    Navigator.of(context).pop();
    widget.onConfirmed?.call();
  }

  Widget _actionButton(String label, VoidCallback onPressed, {IconData? icon}) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        minimumSize: const Size(42, 38),
      ),
      child: icon == null
          ? Text(label, maxLines: 1)
          : Icon(icon, size: 20),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final media = MediaQuery.of(context);
    final size = media.size;
    final availableHeight = size.height - media.viewInsets.bottom;
    final dialogWidth = (size.width - 32).clamp(260.0, 680.0);
    final dialogHeight = (availableHeight - 36).clamp(210.0, 550.0);
    final columns = dialogWidth >= 520 ? 10 : dialogWidth >= 360 ? 8 : 6;
    final keys = _keys;

    return Directionality(
      textDirection: _language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: SizedBox(
          width: dialogWidth,
          height: dialogHeight,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.t('tv_keyboard_title'),
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SizedBox(
                  height: 48,
                  child: TextField(
                    controller: _draft,
                    readOnly: true,
                    canRequestFocus: false,
                    showCursor: true,
                    obscureText: widget.secret && !_showSecret,
                    enableSuggestions: false,
                    autocorrect: false,
                    textCapitalization: TextCapitalization.none,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      border: const OutlineInputBorder(),
                      hintText: l10n.t('tv_keyboard_input'),
                      suffixIcon: widget.secret
                          ? IconButton(
                              tooltip: _showSecret
                                  ? l10n.t('tv_keyboard_hide_password')
                                  : l10n.t('tv_keyboard_show_password'),
                              onPressed: () => setState(
                                  () => _showSecret = !_showSecret),
                              icon: Icon(_showSecret
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _modeButton('abc', 0)),
                    const SizedBox(width: 5),
                    Expanded(child: _modeButton('ABC', 1)),
                    const SizedBox(width: 5),
                    Expanded(child: _modeButton('123 #', 2)),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: GridView.builder(
                    controller: _gridScroll,
                    padding: EdgeInsets.zero,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 5,
                      mainAxisSpacing: 5,
                      childAspectRatio: 1.18,
                    ),
                    itemCount: keys.length,
                    itemBuilder: (context, index) => _TvKeyboardKey(
                      key: ValueKey('$_page-$index'),
                      label: keys[index],
                      autofocus: index == 0,
                      onPressed: () => _insert(keys[index]),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    _actionButton(l10n.t('tv_keyboard_space'), () => _insert(' ')),
                    _actionButton('', _delete, icon: Icons.backspace_outlined),
                    if (widget.urlMode) ...[
                      _actionButton('http://', () => _insertUrlScheme('http://')),
                      _actionButton('https://', () => _insertUrlScheme('https://')),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      focusNode: _cancelFocus,
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.t('tv_keyboard_cancel')),
                    ),
                    const SizedBox(width: 6),
                    FilledButton(
                      focusNode: _confirmFocus,
                      onPressed: _confirm,
                      child: Text(l10n.t('tv_keyboard_confirm')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeButton(String label, int page) {
    return OutlinedButton(
      onPressed: () => _changePage(page),
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        minimumSize: const Size(0, 35),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        backgroundColor: _page == page
            ? Theme.of(context).colorScheme.primaryContainer
            : null,
      ),
      child: Text(label),
    );
  }
}

/// Owns a stable focus node and keeps the selected key in view for TV remotes.
class _TvKeyboardKey extends StatefulWidget {
  const _TvKeyboardKey({
    super.key,
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
    _focusNode.addListener(_keepVisible);
  }

  void _keepVisible() {
    if (!_focusNode.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_focusNode.hasFocus) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.4,
        duration: const Duration(milliseconds: 120),
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  @override
  void dispose() {
    _focusNode.removeListener(_keepVisible);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onPressed: widget.onPressed,
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      ),
      child: Text(widget.label,
          maxLines: 1, style: const TextStyle(fontSize: 16)),
    );
  }
}
