import 'package:logging/logging.dart';
import 'package:flutter/foundation.dart';

class LogService extends ChangeNotifier {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  final List<LogRecord> _logs = [];
  List<LogRecord> get logs => List.unmodifiable(_logs);

  void init() {
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      _logs.add(record);
      // Limit to last 1000 logs to prevent memory issues
      if (_logs.length > 1000) {
        _logs.removeAt(0);
      }
      notifyListeners();
    });
  }

  void clear() {
    _logs.clear();
    notifyListeners();
  }
}
