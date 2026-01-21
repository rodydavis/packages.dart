# http_get_cache

A robust, HTTP-compliant caching library for Flutter and Dart. `http_get_cache` wraps the standard [`http`](https://pub.dev/packages/http) package to automatically cache GET requests based on `Cache-Control`, `Vary`, `ETag`, and `Last-Modified` headers.

It uses **SQLite** (via [`drift`](https://pub.dev/packages/drift)) for metadata storage and the file system for caching response bodies, ensuring separate, non-blocking storage.

## Features

- 🚀 **HTTP Client Wrapper**: Drop-in replacement for `http.Client`.
- 💾 **Persistent Caching**: Stores cache data in SQLite and files on disk.
- 🌍 **Vary Header Support**: Caches variations of responses based on request headers (e.g., `User-Agent`).
- 🔄 **Standard Compliant**: Respects `max-age`, `no-cache`, `no-store`, `stale-while-revalidate`, and more.
- 🖼️ **HttpImageProvider**: A cached `ImageProvider` for Flutter.
- 📱 **Cross Platform**: Works on Android, iOS, macOS, Windows, and Linux.

> [!WARNING]
> This package **does not support Web**. On Web, `http_get_cache` logic is disabled. 
> You should use the [`fetch_client`](https://pub.dev/packages/fetch_client) package instead, which leverages the browser's native caching capabilities.

## Installation

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  http_get_cache: ^latest_version
```

## Usage

### 1. Initialization

You must initialize the cache database before making requests.

**Flutter:**

```dart
import 'package:flutter/material.dart';
import 'package:http_get_cache/http_get_cache_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize caching with default paths
  await initFlutterHttpGetCache();
  
  runApp(const MyApp());
}
```

**Dart (Standalone):**

```dart
import 'package:http_get_cache/http_get_cache.dart';

void main() async {
  await initHttpGetCache(
    cachePath: './.cache',
    databasePath: './.db',
  );
}
```

### 2. Making Requests

Use the global `httpClient()` helper to get a `Client` that handles caching automatically.

```dart
import 'package:http_get_cache/http_get_cache.dart'; 

Future<void> fetchData() async {
  final client = httpClient();
  
  // This request will be cached if headers allow it
  final response = await client.get(Uri.parse('https://jsonplaceholder.typicode.com/posts/1'));
  
  if (response.statusCode == 200) {
    print('Response: ${response.body}');
  }
  
  client.close();
}
```

### 3. Caching Images in Flutter

Use `HttpImageProvider` to load and cache images efficiently.

```dart
import 'package:flutter/material.dart';
import 'package:http_get_cache/http_image_provider.dart';

class MyImageWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Image(
      image: HttpImageProvider(
        Uri.parse('https://via.placeholder.com/150'),
      ),
    );
  }
}
```

## How It Works

This package implements most of [RFC 7234](https://httpwg.org/specs/rfc7234.html).

1.  **Cache-Control**: Checks `max-age` to determine if a cached response is still fresh.
2.  **Stale-While-Revalidate**: Can return stale content while updating the cache in the background.
3.  **Vary**: Stores distinct cache entries if the server response includes a `Vary` header (e.g. varying by `Accept-Language`).
4.  **Revalidation**: Uses `ETag` and `Last-Modified` to check with the server if the cached content has changed (Returns `304 Not Modified` if valid).

## Web Support

This package is designed for native platforms where persistent HTTP caching is not built-in. 

**On Web**, browsers handle caching automatically via the `Fetch API`. Using this package on Web adds unnecessary overhead as the internal caching logic is disabled (`kIsWeb` checks).

**Recommendation:**
Use [fetch_client](https://pub.dev/packages/fetch_client) directly for Web applications.

## Advanced Usage

### Custom Client
You can use a custom inner client (e.g. `http.Client`, `RetryClient`) with `HttpGetCache`.

```dart
import 'package:http/http.dart' as http;
import 'package:http_get_cache/http_get_cache.dart';

void main() async {
  final db = await initFlutterHttpGetCache();
  final store = SqliteHttpCacheStore(db);
  
  final client = HttpGetCache(
    http.Client(), // Inner client
    store,
  );
  
  // Use client...
}

```

### Native Networking

To improve performance on mobile devices (e.g. HTTP/3 support), you can provide a native HTTP client to `httpClient`:

1. Add dependencies: `cronet_http` and `cupertino_http`.
2. Pass the native client as `innerClient`.

```dart
import 'dart:io';
import 'package:cronet_http/cronet_http.dart';
import 'package:cupertino_http/cupertino_http.dart';
import 'package:http/http.dart';
import 'package:http_get_cache/http_get_cache.dart';

Client getNativeClient() {
  if (Platform.isAndroid) {
    return CronetClient.defaultCronetEngine();
  }
  if (Platform.isIOS || Platform.isMacOS) {
    return CupertinoClient.defaultSessionConfiguration();
  }
  return Client();
}

void main() async {
  await initFlutterHttpGetCache();

  final client = httpClient(
    innerClient: getNativeClient(),
  );
}
```

### Platform Support

| Platform | Support | Storage |
| :--- | :--- | :--- |
| **Android** | ✅ | SQLite + File System |
| **iOS** | ✅ | SQLite + File System |
| **macOS** | ✅ | SQLite + File System |
| **Windows** | ✅ | SQLite + File System |
| **Linux** | ✅ | SQLite + File System |
| **Web** | ⚠️ | **Not Supported** (Use `fetch_client`) |
