import 'package:flutter/material.dart';
import '../models/epg_programme.dart';

class MobileEpgList extends StatelessWidget {
  const MobileEpgList({super.key, required this.programmes, this.now});
  final List<EpgProgramme> programmes;
  final DateTime? now;
  @override Widget build(BuildContext context) {
    final current = now ?? DateTime.now();
    final visible = programmes.where((p) => p.isValid && p.end.isAfter(current))
      .toList()..sort((a,b) => a.start.compareTo(b.start));
    if (visible.isEmpty) return const Text('Keine EPG-Daten verfügbar');
    String clock(DateTime date) => '${date.hour.toString().padLeft(2,'0')}:${date.minute.toString().padLeft(2,'0')}';
    return ListView.builder(shrinkWrap: true, itemCount: visible.length.clamp(0, 12),
      itemBuilder: (context, index) {
        final item = visible[index];
        return ListTile(dense: true, title: Text(item.title, maxLines: 2),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${clock(item.start)} – ${clock(item.end)}'),
            if (item.isOnAir(current)) LinearProgressIndicator(value: item.progress(current)),
          ]),
          onTap: () => showDialog<void>(context: context, builder: (context) => AlertDialog(
            title: Text(item.title), content: Text(item.description ?? 'Keine Beschreibung verfügbar'),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Schließen'))],
          )),
        );
      });
  }
}
