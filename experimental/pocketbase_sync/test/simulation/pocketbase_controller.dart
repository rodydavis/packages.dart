import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

/// Manages a local PocketBase process for testing.
class PocketBaseController {
  final Logger _logger =
      Logger('PocketBaseController'); // Added logger instance
  Process? _process;
  final int port;
  final String host;
  final String executablePath;
  Directory? _dataDir;

  final bool managed;

  PocketBaseController({
    this.port = 8090,
    this.host = '127.0.0.1',
    this.executablePath = 'pocketbase', // Assumes in PATH
    this.managed = true,
    String? dataDir,
  }) : _fixedDataDir = dataDir;

  final String? _fixedDataDir;

  String get baseUrl => 'http://$host:$port';

  /// Starts the PocketBase server.
  Future<void> start({bool verbose = false}) async {
    if (!managed) {
      _logger
          .info('PocketBase is unmanaged. Assuming it is running at $baseUrl');
      return;
    }

    if (_process != null) {
      throw StateError('PocketBase is already running');
    }

    // Determine data directory
    if (_fixedDataDir != null) {
      _dataDir = Directory(_fixedDataDir);
      if (!await _dataDir!.exists()) {
        await _dataDir!.create(recursive: true);
      }
      _logger.info('Using fixed data directory: ${_dataDir!.path}');
    } else {
      // Create a temporary directory for data
      _dataDir = await Directory.systemTemp.createTemp('pb_test_data_');
      _logger.info('Created temp data directory: ${_dataDir!.path}');
    }

    final args = [
      'serve',
      '--http=$host:$port',
      '--dir=${_dataDir!.path}',
    ];

    // Using simple process start
    _process = await Process.start(
      executablePath,
      args,
      mode: verbose ? ProcessStartMode.inheritStdio : ProcessStartMode.normal,
    );

    if (!verbose) {
      // Drain stdout/stderr so buffer doesn't fill up
      _process!.stdout.listen((_) {});
      _process!.stderr.listen((_) {});
    }

    // Wait for it to be ready?
    // A simple poll loop or just wait a second.
    // PocketBase starts very fast.
    await Future.delayed(const Duration(seconds: 1));

    // Verify it's running by hitting health check?
    // PocketBase doesn't have a standardized /health endpoint in default setup but the root /api/ works.
  }

  /// Stops the server and cleans up data.
  Future<void> stop() async {
    if (!managed) return;

    _process?.kill(ProcessSignal.sigterm);
    await _process?.exitCode;
    _process = null;

    // Only clean up if we created a TEMP directory (i.e. no fixed dir provided)
    if (_fixedDataDir == null && _dataDir != null && await _dataDir!.exists()) {
      await _dataDir!.delete(recursive: true);
      _dataDir = null;
    }
  }

  /// Initializes the server with an admin account and schema.
  Future<void> initialize({
    required String adminEmail,
    required String adminPass,
    String? schemaPath,
  }) async {
    if (!managed) {
      _logger.info(
          'Unmanaged mode: Skipping initialization (superuser/schema). Assuming pre-configured.');
      return;
    }

    if (managed) {
      // 1. Create Superuser using CLI (Only works if we own the dir)
      _logger.info('Creating superuser: $adminEmail');
      final args = [
        'superuser',
        'create',
        adminEmail,
        adminPass,
        '--dir=${_dataDir!.path}',
      ];

      final p = await Process.run(executablePath, args);
      if (p.exitCode != 0) {
        _logger.warning('Failed to creating superuser via CLI: ${p.stderr}');
      } else {
        _logger.info('Superuser created.');
      }
    } else {
      _logger.info(
          'Skipping CLI superuser creation (unmanaged mode). Assuming user exists.');
    }

    // 2. Import Collections (Works via API regardless of managing process)
    if (schemaPath != null) {
      _logger.info('Importing schema from $schemaPath');
      final schemaFile = File(schemaPath);
      if (await schemaFile.exists()) {
        try {
          // Auth endpoint for superusers (v0.23+)
          // Fallback to old admins if needed, but let's try the new one first or assuming v0.23 based on schema.
          var authUrl =
              '$baseUrl/api/collections/_superusers/auth-with-password';

          final authBody = jsonEncode({
            'identity': adminEmail,
            'password': adminPass,
          });

          var authReq = await http.post(
            Uri.parse(authUrl),
            headers: {'Content-Type': 'application/json'},
            body: authBody,
          );

          // Fallback for older PB versions if 404
          if (authReq.statusCode == 404) {
            _logger.info('Legacy admin auth endpoint fallback...');
            authUrl = '$baseUrl/api/admins/auth-with-password';
            authReq = await http.post(
              Uri.parse(authUrl),
              headers: {'Content-Type': 'application/json'},
              body: authBody,
            );
          }

          if (authReq.statusCode == 200) {
            final token = jsonDecode(authReq.body)['token'];

            // New API does not support bulk import. We must create collections one by one.
            final schemaJson = await schemaFile.readAsString();
            final List<dynamic> collections = jsonDecode(schemaJson);

            _logger.info('Found ${collections.length} collections to import.');

            for (final col in collections) {
              final name = col['name'];
              final type = col['type'];
              // Preserve ID if possible? PB auto-gens ID usually but can accept ID.
              final _ = col['id'];

              // Skip system collections that already exist (usually)
              // In v0.23+, _superusers, _externalAuths, _mfas, _otps, _authOrigins are system.
              if (col['system'] == true || name.startsWith('_')) {
                _logger.info('Skipping system collection: $name');
                continue;
              }

              _logger.info('Creating collection: $name ($type)');

              final createUrl = '$baseUrl/api/collections';
              final createBody = jsonEncode(col);

              final createReq = await http.post(
                Uri.parse(createUrl),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': token,
                },
                body: createBody,
              );

              if (createReq.statusCode == 200) {
                _logger.info('Created collection $name');
              } else if (createReq.statusCode == 400) {
                // Check if loop? or already exists?
                // "Collection name ... already exists"
                final msg = createReq.body;
                if (msg.contains('exists')) {
                  _logger.info(
                      'Collection $name already exists. Skipping or Updating?');
                  // Ideally we update: PUT /api/collections/{id_or_name}
                  // But for now, skip.
                } else {
                  _logger.warning('Failed to create collection $name: $msg');
                }
              } else {
                _logger.warning(
                    'Failed to create collection $name: ${createReq.statusCode} ${createReq.body}');
              }
            }
            _logger.info('Schema import process finished.');
          } else {
            _logger.warning('Failed to login as admin: ${authReq.body}');
          }
        } catch (e) {
          _logger.warning('Error importing schema: $e');
        }
      }
    }
  }

  /// Restarts the server (simulating a crash/restart).
  Future<void> restart() async {
    // Keep data dir!
    final savedDir = _dataDir;

    _process?.kill(ProcessSignal.sigterm);
    await _process?.exitCode;
    _process = null;

    // Restart with SAME data dir
    if (savedDir == null) throw StateError("Cannot restart, never started");

    final args = [
      'serve',
      '--http=$host:$port',
      '--dir=${savedDir.path}',
    ];

    _process = await Process.start(executablePath, args);
    _process!.stdout.listen((_) {});
    _process!.stderr.listen((_) {});

    await Future.delayed(const Duration(seconds: 1));
  }
}
