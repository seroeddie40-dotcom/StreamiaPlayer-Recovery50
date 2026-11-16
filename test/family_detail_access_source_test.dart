import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('movie detail rechecks current catalog and child category permissions', () {
    final source = File('lib/screens/vod_screen.dart').readAsStringSync();
    final detail = source.substring(source.indexOf('class VodDetailScreen'));
    expect(detail.contains('context.watch<FamilySessionProvider>()'), isTrue);
    expect(detail.contains('candidate.streamUrl == source.streamUrl'), isTrue);
    expect(detail.contains("contentType: 'vod'"), isTrue);
    expect(detail.contains('if (!permitted)'), isTrue);
  });

  test('series detail checks source, current catalog and permissions', () {
    final source = File('lib/screens/series_screen.dart').readAsStringSync();
    final detail = source.substring(source.indexOf('class _SeriesDetailScreenState'));
    expect(detail.contains('context.watch<FamilySessionProvider>()'), isTrue);
    expect(detail.contains('!sourceChanged && family.isReady'), isTrue);
    expect(detail.contains("contentType: 'series'"), isTrue);
    expect(detail.contains('if (!permitted)'), isTrue);
  });
}
