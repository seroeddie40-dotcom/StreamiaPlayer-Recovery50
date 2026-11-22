import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/epg_programme.dart';
import 'epg_timeline.dart';

/// Four 3-hour rows. D-pad navigation never traps focus at the timeline edge.
class TvEpgTimeline extends StatefulWidget {
  const TvEpgTimeline({super.key, required this.programmes, this.now, this.focusNode, this.onExitDown});
  final List<EpgProgramme> programmes;
  final DateTime? now;
  final FocusNode? focusNode;
  final VoidCallback? onExitDown;
  @override State<TvEpgTimeline> createState() => _TvEpgTimelineState();
}

class _TvEpgTimelineState extends State<TvEpgTimeline> {
  final FocusNode _ownedFocus = FocusNode(debugLabel: 'TV EPG');
  FocusNode get _focus => widget.focusNode ?? _ownedFocus;
  int _selected = 0;
  int _selectedRow = 0;
  bool _hasFocus = false;
  bool _detailsOpen = false;
  late DateTime _windowStart;
  @override void initState() {
    super.initState();
    _windowStart = EpgTimeline.floorToHour(widget.now ?? DateTime.now());
    // The first programme may start in row 2, 3 or 4. Never initialise the
    // selection in an empty row: otherwise the EPG receives focus but nothing
    // is highlighted and left/right cannot recover the selection.
    final initialItems = _items;
    if (initialItems.isNotEmpty) {
      _selectedRow = _rowFor(initialItems.first);
    }
    _focus.addListener(_onFocusChanged);
  }
  void _onFocusChanged() {
    if (mounted) setState(() => _hasFocus = _focus.hasFocus);
  }
  @override
  void didUpdateWidget(covariant TvEpgTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownedFocus).removeListener(_onFocusChanged);
      _focus.addListener(_onFocusChanged);
      _hasFocus = _focus.hasFocus;
    }
    if (!identical(oldWidget.programmes, widget.programmes) || oldWidget.now != widget.now) {
      // Preserve the selected broadcast by identity, not by list index: an
      // EPG refresh may insert or remove earlier programmes.
      final previous = EpgTimeline.overlapping(
        oldWidget.programmes,
        _windowStart,
        _windowStart.add(const Duration(hours: 12)),
      )..sort((a, b) => a.start.compareTo(b.start));
      final selectedBefore = _selected >= 0 && _selected < previous.length
          ? previous[_selected]
          : null;
      if (oldWidget.now != widget.now && widget.now != null) {
        _windowStart = EpgTimeline.floorToHour(widget.now!);
      }
      final items = _items;
      if (items.isEmpty) {
        _selected = 0;
        _selectedRow = 0;
      } else {
        final matchingIndex = selectedBefore == null ? -1 : items.indexWhere(
          (item) => item.channelId == selectedBefore.channelId &&
              item.start == selectedBefore.start && item.end == selectedBefore.end,
        );
        _selected = matchingIndex >= 0
            ? matchingIndex
            : _selected.clamp(0, items.length - 1);
        // A long broadcast can overlap multiple rows. Retain the row when
        // it still overlaps the selected broadcast.
        final rowStart = _windowStart.add(Duration(hours: _selectedRow * 3));
        final rowEnd = rowStart.add(const Duration(hours: 3));
        if (!items[_selected].start.isBefore(rowEnd) ||
            !items[_selected].end.isAfter(rowStart)) {
          _selectedRow = _rowFor(items[_selected]);
        }
      }
    }
  }
  @override void dispose() { _focus.removeListener(_onFocusChanged); _ownedFocus.dispose(); super.dispose(); }
  List<EpgProgramme> get _items {
    final end = _windowStart.add(const Duration(hours: 12));
    final entries = EpgTimeline.overlapping(widget.programmes, _windowStart, end);
    entries.sort((a,b) => a.start.compareTo(b.start));
    return entries;
  }
  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final items = _items;
    if (items.isEmpty) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        widget.onExitDown?.call();
      }
      return KeyEventResult.handled;
    }
    // Programmes can change while focus remains on this widget.
    if (_selected >= items.length) _selected = items.length - 1;
    // EPG updates can remove the selected broadcast while the timeline keeps
    // focus. Ensure that the selected row actually contains that broadcast.
    final selectedRowStart = _windowStart.add(Duration(hours: _selectedRow * 3));
    final selectedRowEnd = selectedRowStart.add(const Duration(hours: 3));
    if (!items[_selected].start.isBefore(selectedRowEnd) ||
        !items[_selected].end.isAfter(selectedRowStart)) {
      setState(() => _selectedRow = _rowFor(items[_selected]));
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight) {
      // Horizontal navigation must stay within the active three-hour row.
      // The global programme list also contains broadcasts from other rows;
      // moving by its index could jump the highlight several hours away.
      final rowStart = _windowStart.add(Duration(hours: _selectedRow * 3));
      final rowEnd = rowStart.add(const Duration(hours: 3));
      final rowIndices = <int>[
        for (var i = 0; i < items.length; i++)
          if (items[i].start.isBefore(rowEnd) && items[i].end.isAfter(rowStart)) i,
      ];
      final position = rowIndices.indexOf(_selected);
      if (position < 0) return KeyEventResult.handled;
      final next = position + (key == LogicalKeyboardKey.arrowRight ? 1 : -1);
      if (next < 0 || next >= rowIndices.length) return KeyEventResult.handled;
      setState(() => _selected = rowIndices[next]);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowDown) {
      // Only navigate to a programme overlapping the adjacent 3-hour row.
      // Consume boundary presses; exit downward only via the explicit callback.
      final current = items[_selected];
      final targetRow = _selectedRow + (key == LogicalKeyboardKey.arrowDown ? 1 : -1);
      if (targetRow < 0 || targetRow >= 4) {
        if (targetRow >= 4) widget.onExitDown?.call();
        return KeyEventResult.handled;
      }
      final rowStart = _windowStart.add(Duration(hours: targetRow * 3));
      final rowEnd = rowStart.add(const Duration(hours: 3));
      // A single long programme may span several three-hour rows. Move the
      // highlighted row without changing programme identity in that case.
      if (current.start.isBefore(rowEnd) && current.end.isAfter(rowStart)) {
        setState(() => _selectedRow = targetRow);
        return KeyEventResult.handled;
      }
      final candidates = <int>[];
      for (var i = 0; i < items.length; i++) {
        if (items[i].start.isBefore(rowEnd) && items[i].end.isAfter(rowStart)) {
          candidates.add(i);
        }
      }
      if (candidates.isEmpty) {
        // Keep the current selection when the adjacent three-hour window has
        // no programmes; do not transfer focus to an unrelated player control.
        return KeyEventResult.handled;
      }
      // Compare positions *inside the visible source row*. A programme that
      // began hours before this window would otherwise anchor navigation far
      // outside the displayed timeline and select the wrong target programme.
      final sourceRowStart = _windowStart.add(Duration(hours: _selectedRow * 3));
      final sourceRowEnd = sourceRowStart.add(const Duration(hours: 3));
      final sourceStart = current.start.isBefore(sourceRowStart)
          ? sourceRowStart : current.start;
      final sourceEnd = current.end.isAfter(sourceRowEnd)
          ? sourceRowEnd : current.end;
      final anchor = sourceStart.add(Duration(
        milliseconds: sourceEnd.difference(sourceStart).inMilliseconds ~/ 2,
      ));
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
  Future<void> _showDetails(EpgProgramme item) async {
    // A held OK key must not stack multiple dialogs on top of the player.
    if (_detailsOpen || !mounted) return;
    _detailsOpen = true;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(item.title),
          content: Text(item.description?.isNotEmpty == true
              ? item.description!
              : 'Keine Beschreibung verfügbar'),
          actions: [
            TextButton(
              autofocus: true,
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Schließen'),
            ),
          ],
        ),
      );
    } finally {
      _detailsOpen = false;
      if (mounted && _items.isNotEmpty) {
        // Restore EPG keyboard navigation, not the video or a hidden control.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_detailsOpen && _focus.canRequestFocus) {
            _focus.requestFocus();
          }
        });
      }
    }
  }
  @override Widget build(BuildContext context) {
    final items = _items;
    final now = widget.now ?? DateTime.now();
    // Keep the EPG focus target mounted even when the provider has no
    // programmes. Otherwise Up from the player controls requests focus on an
    // unattached node and the remote appears stuck until the overlay closes.
    if (items.isEmpty) {
      return Focus(
        focusNode: _focus,
        onKeyEvent: _key,
        child: const Text('Keine EPG-Daten verfügbar',
            style: TextStyle(color: Colors.white70)),
      );
    }
    // The parent player overlay may be shorter than the full guide on some
    // Android TV resolutions. Keep a bounded scroll viewport instead of
    // allowing the four timeline rows to overflow the available height.
    return FocusTraversalGroup(child: Focus(
      onKeyEvent: _key,
      focusNode: _focus,
      child: SingleChildScrollView(
        primary: false,
        physics: const ClampingScrollPhysics(),
        child: Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (row) {
        final start = _windowStart.add(Duration(hours: row * 3));
        final end = start.add(const Duration(hours: 3));
        final visible = EpgTimeline.overlapping(items, start, end);
        return SizedBox(height: 48, child: Column(children: [
          SizedBox(height: 15, child: Row(children: List.generate(4, (tick) {
            final hour = start.add(Duration(hours: tick));
            final label = '${hour.hour.toString().padLeft(2, '0')}:00';
            return Expanded(child: Text(label,
              textAlign: tick == 3 ? TextAlign.right : TextAlign.left,
              style: const TextStyle(fontSize: 10, color: Colors.white70),
              maxLines: 1, overflow: TextOverflow.clip));
          }))),
          SizedBox(height: 33, child: LayoutBuilder(builder: (context, box) => Stack(children: [
          Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withOpacity(.12)))))),
          for (final item in visible)
            Positioned(
              left: box.maxWidth * EpgTimeline.clippedStart(item, start, end),
              width: box.maxWidth * EpgTimeline.clippedWidth(item, start, end),
              top: 1, bottom: 1,
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
                        style: const TextStyle(color: Colors.white, fontSize: 11)),
                      if (playing) LinearProgressIndicator(value: item.progress(now), minHeight: 3,
                        color: Colors.cyanAccent, backgroundColor: Colors.black26),
                    ])),
                );
              }),
            ),
        ]))),
        ]));
      }),
    ))));
  }
}
