import 'dart:async';

// Mocking the result enum to avoid depending on connectivity_plus directly in the harness
// if the package is not yet added to dependencies (it wasn't in the list I saw).
// But usually one would import 'package:connectivity_plus/connectivity_plus.dart';
// Since I haven't added connectivity_plus to the package dependencies (I only added http, etc),
// I will define a compatible enum here. If the user app uses connectivity_plus, they can map it.

enum ConnectivityResult { wifi, mobile, none, ethernet, bluetooth, other, vpn }

/// A mock adapter for simulating OS connectivity changes.
class MockConnectivity {
  final _controller = StreamController<ConnectivityResult>.broadcast();

  Stream<ConnectivityResult> get onConnectivityChanged => _controller.stream;

  ConnectivityResult _current = ConnectivityResult.wifi;
  ConnectivityResult get current => _current;

  /// Simulates going offline (Airplane Mode).
  void goOffline() {
    _current = ConnectivityResult.none;
    _controller.add(_current);
  }

  /// Simulates connecting to WiFi.
  void goWifi() {
    _current = ConnectivityResult.wifi;
    _controller.add(_current);
  }

  /// Simulates connecting to Mobile Data.
  void goMobile() {
    _current = ConnectivityResult.mobile;
    _controller.add(_current);
  }

  void dispose() {
    _controller.close();
  }
}
