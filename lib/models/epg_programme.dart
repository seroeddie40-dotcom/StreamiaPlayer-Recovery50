class EpgProgramme {
  final String channelId;
  final String title;
  final String? description;
  final DateTime start;
  final DateTime end;

  const EpgProgramme({required this.channelId, required this.title,
    required this.start, required this.end, this.description});

  bool get isValid => end.isAfter(start);
  bool isOnAir(DateTime now) => !now.isBefore(start) && now.isBefore(end);
  double progress(DateTime now) {
    if (!isValid) return 0;
    return (now.difference(start).inMilliseconds /
      end.difference(start).inMilliseconds).clamp(0.0, 1.0).toDouble();
  }
}
