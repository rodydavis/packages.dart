import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Controls the Toxiproxy daemon via its HTTP API.
class ToxiproxyController {
  final String host;
  final int port;
  final Duration timeout;

  ToxiproxyController({
    this.host = 'localhost',
    this.port = 8474,
    this.timeout = const Duration(seconds: 5),
  });

  String get _apiBase => 'http://$host:$port';

  /// Creates a new proxy.
  Future<void> createProxy(String name, String listen, String upstream) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_apiBase/proxies'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': name,
              'listen': listen,
              'upstream': upstream,
              'enabled': true,
            }),
          )
          .timeout(timeout);

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw HttpException('Failed to create proxy: ${response.body}');
      }
    } on TimeoutException {
      throw HttpException('Timeout creating proxy at $_apiBase');
    }
  }

  /// Deletes a proxy.
  Future<void> deleteProxy(String name) async {
    try {
      final response = await http
          .delete(Uri.parse('$_apiBase/proxies/$name'))
          .timeout(timeout);
      if (response.statusCode != 204 && response.statusCode != 404) {
        throw HttpException('Failed to delete proxy: ${response.body}');
      }
    } on TimeoutException {
      throw HttpException('Timeout deleting proxy at $_apiBase');
    }
  }

  /// Clears all proxies and toxics.
  Future<void> reset() async {
    try {
      final response =
          await http.post(Uri.parse('$_apiBase/reset')).timeout(timeout);
      if (response.statusCode != 204) {
        throw HttpException('Failed to reset toxiproxy: ${response.body}');
      }
    } on TimeoutException {
      throw HttpException('Timeout resetting toxiproxy at $_apiBase');
    }
  }

  /// Disables a proxy (Simulates connection cut).
  Future<void> disable(String name) async {
    await _updateState(name, false);
  }

  /// Enables a proxy (Simulates connection restore).
  Future<void> enable(String name) async {
    await _updateState(name, true);
  }

  Future<void> _updateState(String name, bool enabled) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_apiBase/proxies/$name'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'enabled': enabled}),
          )
          .timeout(timeout);
      if (response.statusCode != 200) {
        throw HttpException('Failed to update proxy state: ${response.body}');
      }
    } on TimeoutException {
      throw HttpException('Timeout updating proxy state at $_apiBase');
    }
  }

  /// Adds a toxic (latency, jitter, etc) to a proxy.
  Future<void> addToxic(String proxyName, Toxic toxic) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_apiBase/proxies/$proxyName/toxics'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(toxic.toJson()),
          )
          .timeout(timeout);
      if (response.statusCode != 200 &&
          response.statusCode != 201 &&
          response.statusCode != 409) {
        throw HttpException('Failed to add toxic: ${response.body}');
      }
    } on TimeoutException {
      throw HttpException('Timeout adding toxic at $_apiBase');
    }
  }

  /// Removes all toxics from a proxy.
  Future<void> deleteToxics(String proxyName) async {
    // ...
  }
}

class Toxic {
  final String type;
  final Map<String, dynamic> attributes;
  final String? name; // Optional, Toxiproxy generates one if not provided.
  final double toxicity;

  Toxic({
    required this.type,
    this.attributes = const {},
    this.name,
    this.toxicity = 1.0,
  });

  Map<String, dynamic> toJson() {
    final map = {
      'type': type,
      'attributes': attributes,
      'toxicity': toxicity,
    };
    if (name != null) map['name'] = name!;
    return map;
  }

  static Toxic latency({int latency = 1000, int jitter = 0}) {
    return Toxic(
      type: 'latency',
      attributes: {
        'latency': latency,
        'jitter': jitter,
      },
    );
  }

  static Toxic bandwidth({required int rate}) {
    return Toxic(
      type: 'bandwidth',
      attributes: {
        'rate': rate, // KBs
      },
    );
  }

  static Toxic slowClose({required int delay}) {
    return Toxic(
      type: 'slow_close',
      attributes: {
        'delay': delay,
      },
    );
  }

  // Add more as needed: limit_data, slicer, timeout.
}
