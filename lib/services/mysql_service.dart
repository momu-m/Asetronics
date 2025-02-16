// lib/services/mysql_service.dart

import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class MySQLService extends ChangeNotifier {
  // Singleton-Pattern
  static final MySQLService _instance = MySQLService._internal();
  factory MySQLService() => _instance;
  MySQLService._internal();

  // Status-Variablen
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  Future<Map<String, dynamic>?> login(String username, String password) async {
    try {
      final results = await query(
          'SELECT id, username, password, role, is_active FROM users WHERE username = %s AND password = %s AND is_active = 1',
          [username, password]
      );

      if (results.isNotEmpty) {
        _isConnected = true;
        notifyListeners();
        return results.first;
      }
      return null;
    } catch (e) {
      _logError('Login fehlgeschlagen', e);
      return null;
    }
  }


  Future<void> connect() async {
    try {
      final success = await testConnection();
      _isConnected = success;
      notifyListeners();
    } catch (e) {
      _logError('Verbindung fehlgeschlagen', e);
      _isConnected = false;
      notifyListeners();
    }
  }

  // Verbesserte Query-Methode
  // In mysql_service.dart

  Future<List<Map<String, dynamic>>> query(String sql, [List<Object?>? params]) async {
    try {
      _logDebug('Executing query:');
      _logDebug('SQL: $sql');
      _logDebug('Parameters: $params');
      final correctedSql = sql.replaceAll('?', '%s');


      // Neue URL für data/query endpoint
      final response = await http.post(
        Uri.parse('https://nsylelsq.ddns.net:443/api/data/query'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'query': correctedSql,
          'params': params ?? [],
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result is Map && result.containsKey('affected_rows')) {
          return [{'affected_rows': result['affected_rows']}];
        }
        return List<Map<String, dynamic>>.from(result);
      } else {
        throw Exception('Server returned ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      _logError('Query Fehler', e);
      // Rückgabe leerer Liste statt Exception
      return [];
    }
  }

  // Verbesserte Verbindungsmethode
  Future<bool> testConnection() async {
    try {
      _logDebug('Teste Verbindung zu: ${ApiConfig.testUrl}');

      final success = await ApiConfig.testConnection();

      _isConnected = success;
      notifyListeners();

      return success;
    } catch (e) {
      _logError('Verbindungstest fehlgeschlagen', e);
      _isConnected = false;
      notifyListeners();
      return false;
    }
  }

  // Benutzer-spezifische Methoden
  Future<List<Map<String, dynamic>>> getUsers() async {
    try {
      return await query('SELECT * FROM users WHERE is_active = 1');
    } catch (e) {
      _logError('Fehler beim Laden der Benutzer', e);
      return [];
    }
  }

  Future<bool> createUser(Map<String, dynamic> userData) async {
    try {
      final response = await ApiConfig.sendRequest(
        url: ApiConfig.usersUrl,
        method: 'POST',
        body: jsonEncode(userData),
      );

      return response.statusCode == 201;
    } catch (e) {
      _logError('Fehler beim Erstellen des Benutzers', e);
      return false;
    }
  }

  // Cache für Benutzernamen
  final Map<String, String> _userNameCache = {};

  Future<String> getUserName(String userId) async {
    try {
      // Prüfe zuerst den Cache
      if (_userNameCache.containsKey(userId)) {
        return _userNameCache[userId]!;
      }

      final results = await query(
        'SELECT username FROM users WHERE id = %s',
        [userId],
      );

      if (results.isNotEmpty) {
        final username = results.first['username'] as String;
        // Speichere im Cache
        _userNameCache[userId] = username;
        return username;
      }
      return 'Unbekannt';
    } catch (e) {
      _logError('Fehler beim Laden des Benutzernamens', e);
      return 'Fehler';
    }
  }

  // Verbindung schließen
  Future<void> close() async {
    _isConnected = false;
    notifyListeners();
  }

  // Logging-Methoden
  void _logDebug(String message) {
    debugPrint('📘 DEBUG: $message');
  }

  void _logError(String message, Object error) {
    debugPrint('❌ ERROR: $message');
    debugPrint('DETAILS: $error');
  }
}