import 'package:flutter_test/flutter_test.dart';
import 'package:streamia_player/services/download_service.dart';

void main() {
  const entry = DownloadEntry(id: 'id', title: 'Movie', kind: 'movie',
    sourceUrl: 'https://example.com/movie.mp4', filename: 'movie.mp4',
    state: DownloadState.queued, ownerAccountId: 'account', ownerProfileId: 'child');
  test('ownership survives persistence and progress changes', () {
    final restored = DownloadEntry.fromJson(entry.copyWith(progress: .5).toJson());
    expect(restored.belongsTo('account', 'child'), isTrue);
    expect(restored.belongsTo('account', 'adult'), isFalse);
    expect(restored.belongsTo('other', 'child'), isFalse);
  });
  test('legacy downloads are not silently assigned', () {
    final json = entry.toJson()..remove('ownerAccountId')..remove('ownerProfileId');
    expect(DownloadEntry.fromJson(json).isUnassigned, isTrue);
    expect(DownloadEntry.fromJson(json).belongsTo('account', 'child'), isFalse);
  });
  test('unsafe filenames are rejected', () {
    for (final name in ['..', '.', '', 'downloads.json', 'downloads.json.tmp', 'movie.mp4.part', '../movie.mp4', r'other\movie.mp4']) {
      expect(DownloadEntry.fromJson(entry.toJson()..['filename'] = name).hasSafeFilename, isFalse);
    }
    expect(entry.hasSafeFilename, isTrue);
  });
  test('IDs distinguish profile and playlist', () {
    final id = DownloadService.scopedId('a', 'p', 's', 'movie');
    expect(id, isNot(DownloadService.scopedId('a', 'q', 's', 'movie')));
    expect(id, isNot(DownloadService.scopedId('a', 'p', 't', 'movie')));
  });
}
