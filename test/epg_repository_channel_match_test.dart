import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:streamia_player/services/epg_repository.dart';

void main() {
  test('XMLTV channel IDs match exactly or uniquely ignoring case and spaces', () async {
    final client = MockClient((_) async => http.Response('''<tv>
      <programme channel="ZDF.de" start="20261122100000 +0000" stop="20261122110000 +0000"><title>News</title></programme>
      <programme channel="RTL.de" start="20261122100000 +0000" stop="20261122110000 +0000"><title>Show</title></programme>
    </tv>''', 200));
    final repo = EpgRepository(client: client);
    const url = 'https://example.test/guide.xml';
    expect((await repo.programmes(url, 'ZDF.de')).single.title, 'News');
    expect((await repo.programmes(url, ' zdf.DE ')).single.title, 'News');
    expect(await repo.programmes(url, 'missing'), isEmpty);
    repo.dispose();
  });

  test('ambiguous normalized XMLTV IDs never select an arbitrary channel', () async {
    final client = MockClient((_) async => http.Response('''<tv>
      <programme channel="ZDF.de" start="20261122100000 +0000" stop="20261122110000 +0000"><title>First</title></programme>
      <programme channel="zdf.DE" start="20261122100000 +0000" stop="20261122110000 +0000"><title>Second</title></programme>
    </tv>''', 200));
    final repo = EpgRepository(client: client);
    expect(await repo.programmes('https://example.test/guide.xml', ' zdf.de '), isEmpty);
    repo.dispose();
  });

  test('exact channel IDs remain available even when normalized IDs collide', () async {
    var requests = 0;
    final client = MockClient((_) async {
      requests++;
      return http.Response('''<tv>
        <programme channel="ZDF.de" start="20261122100000 +0000" stop="20261122110000 +0000"><title>First</title></programme>
        <programme channel="zdf.DE" start="20261122100000 +0000" stop="20261122110000 +0000"><title>Second</title></programme>
      </tv>''', 200);
    });
    final repo = EpgRepository(client: client);
    const url = 'https://example.test/guide.xml';
    expect((await repo.programmes(url, 'ZDF.de')).single.title, 'First');
    expect((await repo.programmes(url, 'zdf.DE')).single.title, 'Second');
    expect(await repo.programmes(url, ' zdf.de '), isEmpty);
    expect(requests, 1, reason: 'Channel changes must share the guide cache');
    repo.dispose();
  });

  test('evicting a guide also evicts its exact and normalized channel indexes', () async {
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      final title = request.url.pathSegments.last;
      return http.Response('<tv><programme channel="Channel" '
          'start="20261122100000 +0000" stop="20261122110000 +0000">'
          '<title>$title</title></programme></tv>', 200);
    });
    final repo = EpgRepository(client: client);
    const a = 'https://example.test/a';
    const b = 'https://example.test/b';
    const c = 'https://example.test/c';
    expect((await repo.programmes(a, ' channel ')).single.title, 'a');
    expect((await repo.programmes(b, 'Channel')).single.title, 'b');
    expect((await repo.programmes(c, 'Channel')).single.title, 'c');
    expect(repo.cached(a, 'Channel'), isEmpty);
    expect(repo.cached(a, ' channel '), isEmpty);
    expect((await repo.programmes(a, 'Channel')).single.title, 'a');
    expect(requests, 4);
    repo.dispose();
  });

}
