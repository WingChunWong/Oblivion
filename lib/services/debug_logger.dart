import 'package:flutter/foundation.dart';

class DebugLogger {
  static final DebugLogger _instance = DebugLogger._internal();
  factory DebugLogger() => _instance;
  DebugLogger._internal();

  
  Future<void> init() async {
    log('=== Oblivion Launcher Debug Log ===');
    log('Started at: ${DateTime.now()}');
  }

  
  void log(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 23);
    final line = '[$timestamp] $message';
    debugPrint(line);
  }

  
  Future<void> close() async {}
}

void debugLog(String message) {
  DebugLogger().log(message);
}
