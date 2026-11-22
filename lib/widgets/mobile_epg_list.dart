import 'package:flutter/material.dart';
import '../models/epg_programme.dart';
import '../core/localization/app_localizations.dart';

class MobileEpgList extends StatelessWidget {
  const MobileEpgList({super.key, required this.programmes, this.now});
  final List<EpgProgramme> programmes;
  final DateTime? now;
  @override Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final current = now ?? DateTime.now();
    final visible = programmes.where((p) => p.isValid && p.end.isAfter(current))
      .toList()..sort((a,b) => a.start.compareTo(b.start));
    if (visible.isEmpty) return Text(l10n.t('epg_no_data'));
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
            title: Text(item.title), content: Text((item.description?.trim().isNotEmpty ?? false) ? item.description! : l10n.t('epg_no_description')),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.t('player_close')))],
          )),
        );
      });
  }
}
