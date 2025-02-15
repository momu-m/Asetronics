// Neue Datei: lib/utils/logger.dart
class Logger {
  static void logError(String location, dynamic error, StackTrace? stackTrace) {
    print('=== FEHLER PROTOKOLL ===');
    print('Ort: $location');
    print('Zeitpunkt: ${DateTime.now()}');
    print('Fehler: $error');
    if (stackTrace != null) {
      print('Stack Trace: $stackTrace');
    }
    print('=====================');
  }
}