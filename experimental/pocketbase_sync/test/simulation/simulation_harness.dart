import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:logging/logging.dart';
// Import to use in harness if needed, or generic.
import 'pocketbase_controller.dart';
import 'toxiproxy_client.dart';
import 'mock_connectivity.dart';

/// The Hypervisor that orchestrates the simulation.
class SimulationHarness {
  final ToxiproxyController toxiproxy;
  final PocketBaseController pocketbase;
  final MockConnectivity connectivity;
  final Logger _logger = Logger('SimulationHarness');

  Process? _toxiProcess;
  final String? toxiproxyBinary;

  SimulationHarness({
    ToxiproxyController? toxiproxy,
    PocketBaseController? pocketbase,
    MockConnectivity? connectivity,
    this.toxiproxyBinary,
  })  : toxiproxy = toxiproxy ?? ToxiproxyController(),
        pocketbase = pocketbase ?? PocketBaseController(),
        connectivity = connectivity ?? MockConnectivity();

  String get proxyUrl =>
      'http://localhost:8080'; // The address the app connects to

  /// Sets up the infrastructure: Starts PB, Creates Proxy.
  Future<void> setUp() async {
    _logger.info('Setting up simulation environment...');

    // 0. Start Toxiproxy Server if binary provided
    if (toxiproxyBinary != null) {
      _logger.info('Starting Toxiproxy server from $toxiproxyBinary');
      _toxiProcess = await Process.start(toxiproxyBinary!, []);

      // Pipe output to see if it fails to start (e.g. port binding)
      _toxiProcess!.stdout.transform(utf8.decoder).listen((data) {
        // _logger.fine('Toxiproxy(out): $data');
        print('Toxiproxy: $data');
      });
      _toxiProcess!.stderr.transform(utf8.decoder).listen((data) {
        _logger.warning('Toxiproxy(err): $data');
        print('Toxiproxy(err): $data');
      });

      // Wait for it to boot
      await Future.delayed(const Duration(seconds: 1));
    }

    // 1. Start PocketBase
    await pocketbase.start();

    // Initialize DB (Create Admin + Import Collections)
    await pocketbase.initialize(
      adminEmail: 'rody.davis.jr@gmail.com',
      adminPass: 'razroq-hedne5-cafdaT',
      schemaPath: './example/pb_collections.json',
    );

    _logger.info('PocketBase started at ${pocketbase.baseUrl}');

    // 2. Setup Toxiproxy
    // We want localhost:8080 (Proxy) -> localhost:PbPort (Upstream)
    // If running binary locally, PB is also local (localhost).
    // So upstream is 'localhost:${pocketbase.port}'.

    // Docker logic fallback
    // final upstream = 'host.docker.internal:${pocketbase.port}';

    // Local binary logic
    final upstream = 'localhost:${pocketbase.port}';

    try {
      // Clean start
      _logger.info('Resetting Toxiproxy...');
      await toxiproxy.reset();
      _logger.info('Toxiproxy reset. Creating proxy pb_api...');
      await toxiproxy.createProxy('pb_api', '0.0.0.0:8080', upstream);
      _logger.info('Proxy setup: localhost:8080 -> $upstream');
    } catch (e) {
      _logger.warning(
          'Failed to setup toxiproxy. make sure it is running at ${toxiproxy.host}:${toxiproxy.port}',
          e);
      // We might throw here if strict
      rethrow;
    }
  }

  /// Tears down the infrastructure.
  Future<void> tearDown() async {
    _logger.info('Tearing down simulation...');
    await pocketbase.stop();
    try {
      await toxiproxy.deleteProxy('pb_api');
      await toxiproxy.reset(); // Clean up toxics
    } catch (_) {}

    if (_toxiProcess != null) {
      _toxiProcess!.kill();
      _toxiProcess = null;
    }

    connectivity.dispose();
  }

  // --- Chaos Helpers ---

  Future<void> goOffline() async {
    _logger.info('Simulating OFFLINE');
    connectivity.goOffline(); // OS says offline
    await toxiproxy.disable('pb_api'); // Cable cut
  }

  Future<void> goOnline() async {
    _logger.info('Simulating ONLINE');
    await toxiproxy.enable('pb_api');
    connectivity.goWifi();
  }

  Future<void> injectLatency({int latencyMs = 1000, int jitterMs = 500}) async {
    await toxiproxy.addToxic(
        'pb_api', Toxic.latency(latency: latencyMs, jitter: jitterMs));
  }

  Future<void> injectSlowNetwork() async {
    // Edge network: High latency, low bandwidth
    await toxiproxy.addToxic(
        'pb_api', Toxic.latency(latency: 2000, jitter: 1000));
    await toxiproxy.addToxic('pb_api', Toxic.bandwidth(rate: 10)); // 10KB/s
  }

  Future<void> clearNetworkFaults() async {
    await toxiproxy.deleteToxics('pb_api');
  }
}
