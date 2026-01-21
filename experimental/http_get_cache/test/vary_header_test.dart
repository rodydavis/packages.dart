import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:http_get_cache/http_get_cache.dart';

void main() {
  late Directory tempDir;
  late HttpGetCacheDatabase db;
  late SqliteHttpCacheStore store;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('http_get_cache_test_');
    final settings = DatabaseSettings(
      'test.db',
      databaseDir: tempDir.path,
      cacheDir: tempDir.path,
    );
    db = HttpGetCacheDatabase(settings, NativeDatabase.memory());
    store = SqliteHttpCacheStore(db);
  });

  tearDown(() {
    db.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('Vary header differentiates cache entries', () async {
    final client = MockClient((request) async {
      return Response(
        'Response for ${request.headers['User-Agent']}',
        200,
        headers: {
          'cache-control': 'max-age=100',
          'vary': 'User-Agent',
        },
      );
    });

    final cache = HttpGetCache(client, store);

    // Request 1: User-Agent A
    final req1 = Request('GET', Uri.parse('https://example.com/api'));
    req1.headers['User-Agent'] = 'AgentA';
    final res1 = await cache.save(req1);
    expect(await res1.stream.bytesToString(), 'Response for AgentA');

    // Request 2: User-Agent B
    final req2 = Request('GET', Uri.parse('https://example.com/api'));
    req2.headers['User-Agent'] = 'AgentB';
    final res2 = await cache.save(req2);
    expect(await res2.stream.bytesToString(), 'Response for AgentB');

    // Verify correct cache hits

    // Using a fail-client to ensure we hit the cache
    final clientFail =
        MockClient((req) async => throw Exception('Network call made!'));
    final cacheHit = HttpGetCache(clientFail, store);

    // Request 3: User-Agent A again -> Should get Cached A
    final req3 = Request('GET', Uri.parse('https://example.com/api'));
    req3.headers['User-Agent'] = 'AgentA';
    final res3 = await (cacheHit.send(req3));
    expect(await res3.stream.bytesToString(), 'Response for AgentA');

    // Request 4: User-Agent B again -> Should get Cached B
    final req4 = Request('GET', Uri.parse('https://example.com/api'));
    req4.headers['User-Agent'] = 'AgentB';
    final res4 = await (cacheHit.send(req4));
    expect(await res4.stream.bytesToString(), 'Response for AgentB');
  });
}
