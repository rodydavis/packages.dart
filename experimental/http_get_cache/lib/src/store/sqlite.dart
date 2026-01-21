import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart';
import 'package:path/path.dart' as p;

import '../constants.dart';
import '../database/database.dart';
import '../date_parser.dart';
import '../request_headers.dart';
import 'base.dart';

class SqliteHttpCacheStore extends HttpCacheStore {
  final HttpGetCacheDatabase database;

  SqliteHttpCacheStore(this.database);

  static Future<String> getCacheDir(HttpGetCacheDatabase database) async {
    if (kIsWeb) return '';
    final cachePath = database.settings.cachePath;
    final cacheDir = Directory(cachePath);
    if (!cacheDir.existsSync()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir.path;
  }

  static Future<void> deleteCacheDir(HttpGetCacheDatabase database) async {
    if (kIsWeb) return;
    final cachePath = await getCacheDir(database);
    if (cachePath.isEmpty) return;
    final cacheDir = Directory(cachePath);

    if (cacheDir.existsSync()) {
      cacheDir.deleteSync(recursive: true);
    }
  }

  static Future<int> getCacheDirSize(HttpGetCacheDatabase database) async {
    if (kIsWeb) return 0;
    final cachePath = await getCacheDir(database);
    if (cachePath.isEmpty) return 0;
    final cacheDir = Directory(cachePath);

    if (cacheDir.existsSync()) {
      final files = await cacheDir.list(recursive: true).toList();
      final dirSize =
          files.fold(0, (int sum, file) => sum + file.statSync().size);
      return dirSize;
    }

    return 0;
  }

  static Future<void> deleteExpired(HttpGetCacheDatabase database) async {
    await database.deleteHttpCacheStale();
  }

  Stream<List<int>> _streamAndSaveBytes(
    BaseRequest req,
    StreamedResponse res,
    File file,
  ) async* {
    final date = res.requestHeaders.created ?? getDateInt();
    if (!file.existsSync()) {
      await file.create(recursive: true);
    }
    final writer = file.openWrite();
    await for (final event in res.stream) {
      yield event;
      writer.add(event);
    }
    await writer.flush();
    await writer.close();

    final vary = res.headers['vary'] ?? '';
    final requestHeaders = <String, String>{};
    if (vary.isNotEmpty && vary != '*') {
      final keys =
          vary.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
      for (final key in keys) {
        requestHeaders[key] = req.headers[key] ?? '';
      }
    }

    await database.setHttpCache(
      url: req.url.key,
      headers: jsonEncode(res.headers),
      requestHeaders: jsonEncode(requestHeaders),
      body: file.path,
      maxAge: res.cacheControl.maxAge,
      staleWhileRevalidate: res.cacheControl.staleWhileRevalidate.$1,
      staleIfError: res.cacheControl.staleIfError.$1,
      immutable: res.cacheControl.immutable,
      date: date,
    );
  }

  @override
  Future<StreamedResponse> set(
    BaseRequest request,
    StreamedResponse response,
  ) async {
    if (kIsWeb) return response;
    // Don't cache if Vary is *
    if (response.headers['vary'] == '*') {
      return response;
    }

    if (response.cacheControl.noStore || request.cacheControl.noStore) {
      return response;
    }
    final dirPath = await getCacheDir(database);
    if (dirPath.isEmpty) return response;
    final dir = Directory(dirPath);
    // Use a unique file name to allow multiple responses per URL.
    // We can't rely just on URL key anymore.
    // We'll append a random string or use UUID if we had it, but here just use random hash or
    // simply use the existing method but append request headers hash.
    // To safe space and keep it simple, let's use a combination.
    // However, if we change the file naming, we orphan old files or we need to manage them.
    // Since we delete by DB entry (which stores path), it's fine.
    // Just need a unique name.

    // Simple unique name strategy: hash(url + vary request headers)
    // But we don't know vary headers yet... wait, we do get them from response.
    // We computed `requestHeaders` in _streamAndSaveBytes.
    // Ideally we compute path there too? But we pass file into it.

    // Let's modify behavior: Generate a random ID for the file?
    // Or just make `key` unique-ish.
    // sha256(url + timestamp + random) is safe enough.

    final uniqueId = sha256
        .convert(utf8.encode(
            '${request.url.key}${DateTime.now().microsecondsSinceEpoch}'))
        .toString();
    final file = File(p.join(dir.path, uniqueId));

    return StreamedResponse(
      _streamAndSaveBytes(request, response, file),
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  Future<StreamedResponse?> get(BaseRequest request) async {
    final candidates = await database //
        .getHttpCache(url: request.url.key)
        .get();

    for (final candidate in candidates) {
      final responseHeaders = _parseHeaders(candidate.headers);
      final vary = responseHeaders['vary'];

      if (vary == '*') {
        continue; // Should not happen if we don't store it, but check anyway.
      }

      bool match = true;
      if (vary != null && vary.isNotEmpty) {
        final storedRequestHeaders = _parseHeaders(candidate.requestHeaders);
        final varyKeys =
            vary.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
        for (final key in varyKeys) {
          if (request.headers[key] != storedRequestHeaders[key]) {
            match = false;
            break;
          }
        }
      }

      if (match) {
        final path = candidate.body;
        final file = File(path);
        if (await file.exists()) {
          final stats = await file.stat();
          final h = {...responseHeaders};
          final rq = RequestHeaders(h);
          if (rq.created == null) {
            final d = DateTime.fromMillisecondsSinceEpoch(candidate.date);
            h['Date'] = d.toIso8601String();
          }
          return StreamedResponse(
            file.openRead(),
            200,
            contentLength: stats.size,
            headers: h,
          );
        }
      }
    }
    return null;
  }
}

// extension on BaseRequest {
//   String get key => sha256.convert(utf8.encode(url.key)).toString();
// }

extension on Uri {
  String get key => toString();
}

Map<String, String> _parseHeaders(String key) {
  final headers = <String, String>{};
  if (key.isNotEmpty) {
    final data = jsonDecode(key) as Map<String, Object?>;
    for (final entry in data.entries) {
      headers[entry.key] = entry.value?.toString() ?? '';
    }
  }
  return headers;
}
