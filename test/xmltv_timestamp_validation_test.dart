import 'package:flutter_test/flutter_test.dart';
import 'package:streamia_player/services/xmltv_epg_parser.dart';

void main() {
  test('XMLTV timestamps reject invalid dates and offsets', () {
    expect(XmltvEpgParser.parseTimestamp('20260230090000 +0300'), isNull);
    expect(XmltvEpgParser.parseTimestamp('20261122120000 +2460'), isNull);
    expect(XmltvEpgParser.parseTimestamp('20261122240000 +0300'), isNull);
    expect(XmltvEpgParser.parseTimestamp('20261122120000 +0300 junk'), isNull);
  });

  test('XMLTV UTC offsets preserve programme instant', () {
    expect(
      XmltvEpgParser.parseTimestamp('20261122120000 +0300')?.toUtc(),
      DateTime.utc(2026, 11, 22, 9),
    );
    expect(
      XmltvEpgParser.parseTimestamp('202611221200 -0500')?.toUtc(),
      DateTime.utc(2026, 11, 22, 17),
    );
  });
}
