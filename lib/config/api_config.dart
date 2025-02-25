// lib/config/api_config.dart
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:io'; // Für die Zertifikatsvalidierung

class ApiConfig {
  static const String _domain = 'nsylelsq.ddns.net';
  static const int _port = 443; // Port auf 443 ändern, da HTTPS verwendet wird
  static String getUserProfileUrl(String userId) => '$usersUrl/$userId/profile';
  static String changePasswordUrl(String userId) => '$usersUrl/$userId/password';
  static String uploadProfileImageUrl(String userId) => '$usersUrl/$userId/profile-image';
  static String updateLastLoginUrl(String userId) => '$usersUrl/$userId/last-login';

  // Timeout-Einstellungen
  static const Duration connectionTimeout = Duration(seconds: 15);
  static const Duration responseTimeout = Duration(seconds: 30);

  // Getter für die Basis-URL
  static String get baseUrl => 'https://$_domain:$_port/api'; // HTTPS verwenden

  // Standard-Header für API-Anfragen
  static Map<String, String> get defaultHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // API-Endpunkte
  static String get loginUrl => '$baseUrl/users/login';
  static String get usersUrl => '$baseUrl/users';
  static String get tasksUrl => '$baseUrl/tasks';
  static String get maintenanceUrl => '$baseUrl/maintenance';
  static String get errorsUrl => '$baseUrl/errors';
  static String get testUrl => '$baseUrl/test';

  // Neue Endpunkte für den Planner
  static String get machinesUrl => '$baseUrl/machines';
  static String get maintenanceTasksUrl => '$baseUrl/maintenance/tasks';
  static String get techniciansUrl => '$baseUrl/users?role=technician';

  // Verbesserte HTTP-Client Methode mit Debug-Logging
// api_config.dart - Die sendRequest-Methode aktualisieren

  static Future<http.Response> sendRequest({
    required String url,
    required String method,
    Map<String, String>? headers,
    Object? body,
  }) async {
    final startTime = DateTime.now();
    print('🕒 Request Start: $startTime');
    print('📍 URL: $url');
    print('📝 Method: $method');

    try {
      final Uri uri = Uri.parse(url);
      final Map<String, String> finalHeaders = {
        ...defaultHeaders,
        ...(headers ?? {}),
      };

      http.Response response;

      switch (method.toUpperCase()) {
        case 'GET':
          print('⏳ Starte GET Request...');
          response = await http.get(
            uri,
            headers: finalHeaders,
          ).timeout(responseTimeout);
          break;

        case 'POST':
          print('⏳ Starte POST Request...');
          print('📦 Body: $body');
          response = await http.post(
            uri,
            headers: finalHeaders,
            body: body,
          ).timeout(responseTimeout);
          break;

        case 'PATCH':
          print('⏳ Starte PATCH Request...');
          print('📦 Body: $body');
          response = await http.patch(
            uri,
            headers: finalHeaders,
            body: body,
          ).timeout(responseTimeout);
          break;

        case 'DELETE':  // Neue DELETE-Methode hinzufügen
          print('⏳ Starte DELETE Request...');
          if (body != null) print('📦 Body: $body');
          response = await http.delete(
            uri,
            headers: finalHeaders,
            body: body,
          ).timeout(responseTimeout);
          break;

        case 'PUT':  // Auch PUT hinzufügen für Vollständigkeit
          print('⏳ Starte PUT Request...');
          print('📦 Body: $body');
          response = await http.put(
            uri,
            headers: finalHeaders,
            body: body,
          ).timeout(responseTimeout);
          break;

        default:
          throw Exception('Nicht unterstützte HTTP-Methode: $method');
      }

      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      print('🕒 Request Ende: $endTime');
      print('⌛ Dauer: ${duration.inMilliseconds}ms');
      print('📊 Status Code: ${response.statusCode}');
      print('📄 Response Body Length: ${response.body.length}');

      return response;

    } catch (e) {
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      print('❌ Fehler nach ${duration.inMilliseconds}ms:');
      print('❌ Error Details: $e');
      rethrow;
    }
  }

  // Neue Methode für Verbindungstest
  static Future<bool> testConnection() async {
    try {
      final startTime = DateTime.now();
      print('🔍 Starte Verbindungstest...');
      final response = await sendRequest(
        url: '${ApiConfig.baseUrl}/test',
        method: 'GET',
      );

      final endTime = DateTime.now();
      print('🔍 Verbindungstest beendet nach ${endTime.difference(startTime).inMilliseconds}ms');
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Verbindungstest fehlgeschlagen: $e');
      return false;
    }
  }
}