import '../models/epg_programme.dart';

class EpgTimeline {
  static DateTime floorToHour(DateTime time) =>
    DateTime(time.year, time.month, time.day, time.hour);

  static List<EpgProgramme> overlapping(List<EpgProgramme> programmes,
      DateTime start, DateTime end) => programmes.where((p) =>
        p.isValid && p.start.isBefore(end) && p.end.isAfter(start)).toList();

  static double clippedStart(EpgProgramme p, DateTime start, DateTime end) {
    final length = end.difference(start).inMilliseconds;
    if (length <= 0) return 0;
    return (p.start.difference(start).inMilliseconds / length).clamp(0.0, 1.0).toDouble();
  }

  static double clippedWidth(EpgProgramme p, DateTime start, DateTime end) {
    final length = end.difference(start).inMilliseconds;
    if (length <= 0) return 0;
    final left = p.start.isBefore(start) ? start : p.start;
    final right = p.end.isAfter(end) ? end : p.end;
    return (right.difference(left).inMilliseconds / length).clamp(0.0, 1.0).toDouble();
  }
}
