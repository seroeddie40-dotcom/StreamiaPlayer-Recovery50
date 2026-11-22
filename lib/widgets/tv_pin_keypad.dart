import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// On-screen numeric PIN input for Android TV. No system keyboard is opened.
/// The parent owns the PIN and performs all authorization and validation.
class TvPinKeypad extends StatefulWidget {
  const TvPinKeypad({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onSubmit,
    this.maxLength = 10,
    this.enabled = true,
    this.autofocus = false,
    this.submitLabel = 'OK',
  }) : assert(maxLength > 0);

  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;
  final int maxLength;
  final bool enabled;
  final bool autofocus;
  final String submitLabel;

  @override
  State<TvPinKeypad> createState() => _TvPinKeypadState();
}

class _TvPinKeypadState extends State<TvPinKeypad> {
  final List<FocusNode> _nodes = List.generate(12, (_) => FocusNode());

  @override
  void initState() {
    super.initState();
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.enabled) _nodes[0].requestFocus();
      });
    }
  }

  @override
  void dispose() {
    for (final node in _nodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _activate(int index) {
    if (!widget.enabled) return;
    if (index == 9) {
      if (widget.value.isNotEmpty) {
        widget.onChanged(widget.value.substring(0, widget.value.length - 1));
      }
    } else if (index == 11) {
      widget.onSubmit();
    } else if (widget.value.length < widget.maxLength) {
      final digit = index == 10 ? '0' : '${index + 1}';
      widget.onChanged('${widget.value}$digit');
    }
  }

  void _move(int index, TraversalDirection direction) {
    final row = index ~/ 3;
    final col = index % 3;
    int nextRow = row;
    int nextCol = col;
    switch (direction) {
      case TraversalDirection.up:
        nextRow = row - 1;
      case TraversalDirection.down:
        nextRow = row + 1;
      case TraversalDirection.left:
        nextCol = col - 1;
      case TraversalDirection.right:
        nextCol = col + 1;
    }
    if (nextRow >= 0 && nextRow < 4 && nextCol >= 0 && nextCol < 3) {
      _nodes[nextRow * 3 + nextCol].requestFocus();
    } else {
      Focus.of(context).focusInDirection(direction);
    }
  }

  @override
  Widget build(BuildContext context) {
    const labels = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '⌫', '0', '✓'];
    final colors = Theme.of(context).colorScheme;
    // A fixed-height, screen-relative keypad avoids a GridView requesting its
    // full intrinsic height inside short TV dialogs (landscape PIN screens).
    // The surrounding dialog can still scroll if its other content is tall.
    final viewport = MediaQuery.sizeOf(context);
    final keypadWidth = (viewport.width * 0.72).clamp(180.0, 340.0).toDouble();
    final keypadHeight = (viewport.height * 0.32).clamp(112.0, 236.0).toDouble();
    final cellWidth = (keypadWidth - 16) / 3;
    final cellHeight = (keypadHeight - 24) / 4;
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: SizedBox(
        width: keypadWidth,
        height: keypadHeight,
        child: GridView.builder(
          primary: false,
          shrinkWrap: false,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: cellWidth / cellHeight,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: 12,
          itemBuilder: (context, index) => FocusTraversalOrder(
            order: NumericFocusOrder(index.toDouble()),
            child: Focus(
              focusNode: _nodes[index],
              onKeyEvent: (node, event) {
                if (event is! KeyDownEvent) return KeyEventResult.ignored;
                final key = event.logicalKey;
                if (key == LogicalKeyboardKey.arrowUp) {
                  _move(index, TraversalDirection.up);
                  return KeyEventResult.handled;
                }
                if (key == LogicalKeyboardKey.arrowDown) {
                  _move(index, TraversalDirection.down);
                  return KeyEventResult.handled;
                }
                if (key == LogicalKeyboardKey.arrowLeft) {
                  _move(index, TraversalDirection.left);
                  return KeyEventResult.handled;
                }
                if (key == LogicalKeyboardKey.arrowRight) {
                  _move(index, TraversalDirection.right);
                  return KeyEventResult.handled;
                }
                if (key == LogicalKeyboardKey.select ||
                    key == LogicalKeyboardKey.enter ||
                    key == LogicalKeyboardKey.numpadEnter) {
                  _activate(index);
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: Builder(
                builder: (context) {
                  final focused = Focus.of(context).hasFocus;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: focused ? const Color(0xFF29E5E0) : colors.outlineVariant,
                        width: focused ? 3 : 1,
                      ),
                      color: focused ? const Color(0xFF153A47) : colors.surfaceContainerHigh,
                    ),
                    child: InkWell(
                      canRequestFocus: false,
                      onTap: widget.enabled ? () => _activate(index) : null,
                      child: Center(
                        child: Text(
                          index == 11 ? widget.submitLabel : labels[index],
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: cellHeight < 37 ? 17 : 22,
                            color: focused ? Colors.white : null,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
