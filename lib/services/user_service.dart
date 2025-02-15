// lib/services/user_service.dart
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/user_role.dart';
import 'dart:convert';
import '../config/api_config.dart';

class UserService extends ChangeNotifier {
  // Singleton-Pattern
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  // Interner Status
  User? _currentUser;
  User? get currentUser => _currentUser;

  // Cache für Benutzer
  final Map<String, User> _userCache = {};
  final Map<String, String> _usernameCache = {};

  // Login-Methode
  Future<bool> login(String username, String password) async {
    try {
      print('Login-Versuch mit Benutzername: $username');

      // Admin-Login Check
      if (username == 'admin' && password == 'admin') {
        _currentUser = User(
          id: 'admin-${DateTime.now().millisecondsSinceEpoch}',
          username: username,
          password: 'admin',
          role: UserRole.admin,
          isActive: true,
        );
        notifyListeners();
        print('Admin-Login erfolgreich');
        return true;
      }

      final response = await http.post(
        Uri.parse('http://nsylelsq.ddns.net:5004/api/users/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'username': username,
          'password': password
        }),
      );

      print('Server Antwort Status: ${response.statusCode}');
      print('Server Antwort Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['success'] == true && data['user'] != null) {
          _currentUser = User(
            id: data['user']['id'].toString(),
            username: data['user']['username'].toString(),
            password: '', // Passwort nicht speichern
            role: _parseRole(data['user']['role'].toString()),
            isActive: data['user']['is_active'] == 1,
          );
          notifyListeners();
          print('Login erfolgreich für: ${_currentUser?.username}');
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Login-Fehler: $e');
      return false;
    }
  }


  // Benutzer abrufen
  Future<List<Map<String, dynamic>>> fetchUsers() async {
    try {
      // Nutzt den Basis-Users-Endpoint ohne /all
      final response = await ApiConfig.sendRequest(
        url: ApiConfig.usersUrl,  // Nur /api/users
        method: 'GET',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      }
      return [];
    } catch (e) {
      _logError('Fehler beim Laden der Benutzer', e);
      return [];
    }
  }

  // Benutzername abrufen
  // In der getUserName Methode des UserService (user_service.dart)

  Future<String> getUserName(String userId) async {
    try {
      // Prüfe zuerst den Cache
      if (_usernameCache.containsKey(userId)) {
        return _usernameCache[userId]!;
      }

      // Hole den kompletten Benutzer statt nur den Benutzernamen
      final response = await ApiConfig.sendRequest(
        url: '${ApiConfig.baseUrl}/data',
        method: 'POST',
        body: jsonEncode({
          'query': 'SELECT username FROM users WHERE id = %s',
          'params': [userId]
        }),
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = jsonDecode(response.body);
        if (results.isNotEmpty) {
          final username = results[0]['username'] as String;
          // Speichere im Cache
          _usernameCache[userId] = username;
          return username;
        }
      }
      return 'Unbekannt';
    } catch (e) {
      print('❌ Fehler beim Laden des Benutzernamens: $e');
      return 'Fehler';
    }
  }


  Future<List<Map<String, dynamic>>> getUsers() async {
    try {
      final response = await ApiConfig.sendRequest(
          url: '${ApiConfig.baseUrl}/data',  // Änderung hier
          method: 'POST',  // POST statt GET
          body: jsonEncode({
            'query': 'SELECT * FROM users WHERE is_active = 1',
            'params': []
          })
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      }
      return [];
    } catch (e) {
      _logError('Fehler beim Laden der Benutzer', e);
      return [];
    }
  }
  // Benutzer nach Rolle filtern
  Future<List<User>> getUsersByRole(UserRole role) async {
    try {
      final roleStr = role.toString().split('.').last.toLowerCase();
      print('Requesting users with role: $roleStr');

      final response = await ApiConfig.sendRequest(
        url: '${ApiConfig.usersUrl}?role=$roleStr',
        method: 'GET',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        print('Received ${data.length} users');

        // Debug-Log für die JSON-Struktur
        print('JSON Struktur: ${data.first}');

        return data.map((json) => User(
          id: json['id'].toString(), // Konvertiere explizit zu String
          username: json['username'] as String,
          password: '', // Leeres Passwort, da es in der API-Antwort nicht enthalten ist
          role: _parseRole(json['role'] as String),
          isActive: json['is_active'] == 1,
        )).toList();
      }
      return [];
    } catch (e) {
      print('Error loading users by role: $e');
      return [];
    }
  }

  // Benutzer erstellen
  Future<bool> createUser(Map<String, dynamic> userData) async {
    try {
      final response = await ApiConfig.sendRequest(
        url: ApiConfig.usersUrl,
        method: 'POST',
        body: jsonEncode(userData),
      );

      if (response.statusCode == 201) {
        // Cache invalidieren
        _userCache.clear();
        _usernameCache.clear();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _logError('Fehler beim Erstellen des Benutzers', e);
      return false;
    }
  }

  // Benutzer aktualisieren
  Future<bool> updateUser(Map<String, dynamic> userData) async {
    try {
      final response = await http.put(
        Uri.parse('http://nsylelsq.ddns.net:5004/api/users/${userData['id']}'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(userData),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Fehler beim Aktualisieren des Benutzers: $e');
      return false;
    }
  }

  // Benutzer deaktivieren
  Future<bool> deactivateUser(String userId) async {
    try {
      final response = await http.delete(
        Uri.parse('http://nsylelsq.ddns.net:5004/api/users/$userId'),
        headers: {
          'Accept': 'application/json',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Fehler beim Deaktivieren des Benutzers: $e');
      return false;
    }
  }
  Future<bool> resetPassword(String userId, String newPassword) async {
    try {
      final response = await http.put(
        Uri.parse('http://nsylelsq.ddns.net:5004/api/users/$userId/password'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'password': newPassword,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Fehler beim Zurücksetzen des Passworts: $e');
      return false;
    }
  }
  UserRole _parseRole(String roleStr) {
    switch (roleStr.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'teamlead':
        return UserRole.teamlead;
      case 'technician':
        return UserRole.technician;
      case 'operator':
      default:
        return UserRole.operator;
    }
  }
  // Benutzer ausloggen
  void logout() {
    _currentUser = null;
    notifyListeners();
  }

  // Logging
  void _logError(String message, Object error) {
    debugPrint('❌ ERROR: $message');
    debugPrint('DETAILS: $error');
  }
}