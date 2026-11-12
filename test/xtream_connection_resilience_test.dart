
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:streamia_player/services/xtream_service.dart';

void main() {
  test('retries a temporary 503 and loads live channels', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return calls == 1
          ? http.Response('temporary', 503)
          : http.Response('[]', 200);
    });

    final service = XtreamService(
      baseUrl: 'https://example.com',
      username: 'user',
      password: 'secret',
      client: client,
      retryDelay: Duration.zero,
    );

    try {
      expect(await service.getLiveStreams(), isEmpty);
      expect(calls, 2);
    } finally {
      service.close();
    }
  });

  test('does not retry rejected credentials or disclose server body',
      () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return http.Response('secret user password', 403);
    });

    final service = XtreamService(
      baseUrl: 'https://example.com',
      username: 'user',
      password: 'secret',
      client: client,
      retryDelay: Duration.zero,
    );

    try {
      await expectLater(
        service.getLiveStreams(),
        throwsA(isA<XtreamConnectionException>()),
      );
      expect(calls, 1);
    } finally {
      service.close();
    }
  });

  test('reports timeout without exposing credentials', () async {
    final client = MockClient((request) async {
      await Future<void>.delayed(
        const Duration(milliseconds: 30),
      );
      return http.Response('[]', 200);
    });

    final service = XtreamService(
      baseUrl: 'https://example.com',
      username: 'user',
      password: 'secret',
      client: client,
      requestTimeout: const Duration(milliseconds: 1),
      retryDelay: Duration.zero,
    );

    try {
      await expectLater(
        service.getLiveStreams(),
        throwsA(isA<XtreamConnectionException>()),
      );
    } finally {
      service.close();
    }
  });
}
