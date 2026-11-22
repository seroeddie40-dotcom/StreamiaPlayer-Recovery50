import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/epg_programme.dart';
import 'epg_timeline.dart';

/// Four 3-hour rows. D-pad navigation never traps focus at the timeline edge.
class TvEpgTimeline extends StatefulWidget {
  const TvEpgTimeline({super.key, required this.programmes, this.now});
  final List<EpgProgramme> programmes;
  final DateTime? now;
  @override State<TvEpgTimeline> createState() => _TvEpgTimelineState();
}

class _TvEpgTimelineState extends State<TvEpgTimeline> {
  final FocusNode _focus = FocusNode(debugLabel: 'TV EPG');
  int _selected = 0;
  int _selectedRow = 0;
  bool _hasFocus = false;
  late DateTime _windowStart;
  @override void initState() {
    super.initState();
    _windowStart = EpgTimeline.floorToHour(widget.now ?? DateTime.now());
    _focus.addListener(_onFocusChanged);
  }
  void _onFocusChanged() {
    if (mounted) setState(() => _hasFocus = _focus.hasFocus);
  }
  @override
  void didUpdateWidget(covariant TvEpgTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.programmes, widget.programmes) || oldWidget.now != widget.now) {
      if (oldWidget.now != widget.now && widget.now != null) {
        _windowStart = EpgTimeline.floorToHour(widget.now!);
      }
      final items = _items;
      if (items.isEmpty) {
        _selected = 0;
        _selectedRow = 0;
      } else {
        _selected = _selected.clamp(0, items.length - 1);
        _selectedRow = _selectedRow.clamp(0, 3);
      }
    }
  }
  @override void dispose() { _focus.removeListener(_onFocusChanged); _focus.dispose(); super.dispose(); }
  List<EpgProgramme> get _items {
    final end = _windowStart.add(const Duration(hours: 12));
    final entries = EpgTimeline.overlapping(widget.programmes, _windowStart, end);
    entries.sort((a,b) => a.start.compareTo(b.start));
    return entries;
  }
  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final items = _items;
    if (items.isEmpty) return KeyEventResult.ignored;
    // Programmes can change while focus remains on this widget.
    if (_selected >= items.length) _selected = items.length - 1;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight) {
      final next = _selected + (key == LogicalKeyboardKey.arrowRight ? 1 : -1);
      if (next < 0 || next >= items.length) return KeyEventResult.ignored;
      setState(() { _selected = next; _selectedRow = _rowFor(items[next]); });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowDown) {
      // Only navigate to a programme overlapping the adjacent 3-hour row.
      // Ignore boundary presses so parent focus traversal can take over.
      final current = items[_selected];
      final targetRow = _selectedRow + (key == LogicalKeyboardKey.arrowDown ? 1 : -1);
      if (targetRow < 0 || targetRow >= 4) return KeyEventResult.ignored;
      final rowStart = _windowStart.add(Duration(hours: targetRow * 3));
      final rowEnd = rowStart.add(const Duration(hours: 3));
      final candidates = <int>[];
      for (var i = 0; i < items.length; i++) {
        if (i != _selected && items[i].start.isBefore(rowEnd) && items[i].end.isAfter(rowStart)) {
          candidates.add(i);
        }
      }
      if (candidates.isEmpty) return KeyEventResult.ignored;
      final anchor = current.start.add(Duration(milliseconds: current.end.difference(current.start).inMilliseconds ~/ 2));
      candidates.sort((a, b) {
        int distance(int i) {
          final start = items[i].start.isBefore(rowStart) ? rowStart : items[i].start;
          final end = items[i].end.isAfter(rowEnd) ? rowEnd : items[i].end;
          final centre = start.add(Duration(milliseconds: end.difference(start).inMilliseconds ~/ 2));
          return centre.difference(anchor).inMilliseconds.abs();
        }
        return distance(a).compareTo(distance(b));
      });
      setState(() { _selected = candidates.first; _selectedRow = targetRow; });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.select) {
      _showDetails(items[_selected]);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }
  int _rowFor(EpgProgramme item) {
    return (item.start.difference(_windowStart).inMinutes ~/ 180).clamp(0, 3);
  }
  void _showDetails(EpgProgramme item) {
    showDialog<void>(context: context, builder: (context) => AlertDialog(
      title: Text(item.title),
      content: Text(item.description?.isNotEmpty == true ? item.description! : 'Keine Beschreibung verfügbar'),
      actions: [TextButton(autofocus: true, onPressed: () => Navigator.pop(context), child: const Text('Schließen'))],
    ));
  }
  @override Widget build(BuildContext context) {
    final items = _items;
    final now = widget.now ?? DateTime.now();
    if (items.isEmpty) return const Text('Keine EPG-Daten verfügbar', style: TextStyle(color: Colors.white70));
    return FocusTraversalGroup(child: Focus(onKeyEvent: _key, focusNode: _focus, child: Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (row) {
        final start = _windowStart.add(Duration(hours: row * 3));
        final end = start.add(const Duration(hours: 3));
        final visible = EpgTimeline.overlapping(items, start, end);
        return SizedBox(height: 48, child: LayoutBuilder(builder: (context, box) => Stack(children: [
          Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withOpacity(.12)))))),
          for (final item in visible)
            Positioned(
              left: box.maxWidth * EpgTimeline.clippedStart(item, start, end),
              width: box.maxWidth * EpgTimeline.clippedWidth(item, start, end),
              top: 3, bottom: 3,
              child: Builder(builder: (context) {
                final selected = _hasFocus && items.indexOf(item) == _selected && _selectedRow == row;
                final playing = item.isOnAir(now);
                return InkWell(
                  onTap: () { _focus.requestFocus(); setState(() { _selected = items.indexOf(item); _selectedRow = row; }); _showDetails(item); },
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(color: playing ? const Color(0xFF007C84) : const Color(0xFF203047),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: selected ? Colors.white : Colors.white24, width: selected ? 2 : 1)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 12)),
                      if (playing) LinearProgressIndicator(value: item.progress(now), minHeight: 3,
                        color: Colors.cyanAccent, backgroundColor: Colors.black26),
                    ])),
                );
              }),
            ),
        ])));
      }),
    )));
  }
}
