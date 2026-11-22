import 'package:xml/xml.dart';
import '../models/epg_programme.dart';

class XmltvEpgParser {
  static DateTime? parseTimestamp(String? raw) {
    if (raw == null) return null;
    final value = raw.trim();
    // XMLTV timestamps are YYYYMMDDHHmm[ss] with an optional UTC offset.
    // Reject malformed dates instead of allowing DateTime.utc to normalize
    // e.g. February 30 into March, which shifts programme blocks silently.
    final match = RegExp(
      r'^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})?\s*([+-]\d{4})?$',
    ).firstMatch(value);
    if (match == null) return null;
    int part(int i) => int.parse(match.group(i)!);
    final year = part(1);
    final month = part(2);
    final day = part(3);
    final hour = part(4);
    final minute = part(5);
    final second = match.group(6) == null ? 0 : part(6);
    if (month < 1 || month > 12 || day < 1 || hour > 23 ||
        minute > 59 || second > 59) return null;
    final utc = DateTime.utc(year, month, day, hour, minute, second);
    if (utc.year != year || utc.month != month || utc.day != day) return null;
    final zone = match.group(7);
    if (zone == null) return utc.toLocal();
    final hours = int.parse(zone.substring(1, 3));
    final minutes = int.parse(zone.substring(3, 5));
    if (hours > 23 || minutes > 59) return null;
    final sign = zone.startsWith('-') ? -1 : 1;
    return utc.subtract(Duration(minutes: sign * (hours * 60 + minutes))).toLocal();
  }

  static List<EpgProgramme> parse(String xmlText, {String? channelId}) {
    final document = XmlDocument.parse(xmlText);
    final output = <EpgProgramme>[];
    for (final node in document.findAllElements('programme')) {
      final id = node.getAttribute('channel') ?? '';
      if (id.isEmpty || (channelId != null && channelId != id)) continue;
      final start = parseTimestamp(node.getAttribute('start'));
      final end = parseTimestamp(node.getAttribute('stop'));
      if (start == null || end == null || !end.isAfter(start)) continue;
      final titles = node.findElements('title');
      final descriptions = node.findElements('desc');
      output.add(EpgProgramme(channelId: id, start: start, end: end,
        title: titles.isEmpty ? 'Ohne Titel' : titles.first.innerText.trim(),
        description: descriptions.isEmpty ? null : descriptions.first.innerText.trim()));
    }
    output.sort((a, b) => a.start.compareTo(b.start));
    return output;
  }
}
