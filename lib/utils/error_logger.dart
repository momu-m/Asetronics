class ErrorLogger {
  static void logError(String location, dynamic error, [StackTrace? stackTrace]) {
    print('=== ERROR LOG ===');
    print('Location: $location');
    print('Time: ${DateTime.now()}');
    print('Error: $error');
    if (stackTrace != null) {
      print('StackTrace: $stackTrace');
    }
    print('===============');
  }
}