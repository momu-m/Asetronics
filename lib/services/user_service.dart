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
        Uri.parse('https://nsylelsq.ddns.net:443/api/users/login'),
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
  Future<String> getUserName(String userId) async {
    try {
      // Wenn userId leer ist, sofort "Unbekannt" zurückgeben
      if (userId == null || userId.isEmpty || userId == 'UNKNOWN_USER') {
        return 'Unbekannt';
      }

      // Prüfe zuerst den Cache
      if (_usernameCache.containsKey(userId)) {
        return _usernameCache[userId]!;
      }

      // Hole den Benutzernamen aus der Datenbank
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
        if (results.isNotEmpty && results[0]['username'] != null) {
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

// Neue Methode zum Aktualisieren des Benutzerprofils
  Future<bool> updateUserProfile(User user) async {
    try {
      final userData = user.toJson();

      // API-Aufruf, um das Profil zu aktualisieren
      final response = await ApiConfig.sendRequest(
        url: '${ApiConfig.usersUrl}/${user.id}/profile',
        method: 'PUT',
        body: jsonEncode(userData),
      );

      if (response.statusCode == 200) {
        // Wenn der aktuelle Benutzer aktualisiert wird, aktualisiere auch _currentUser
        if (_currentUser?.id == user.id) {
          _currentUser = user;
          notifyListeners();
        }

        // Cache aktualisieren
        _userCache[user.id] = user;
        if (user.username.isNotEmpty) {
          _usernameCache[user.id] = user.username;
        }

        return true;
      }
      return false;
    } catch (e) {
      _logError('Fehler beim Aktualisieren des Benutzerprofils', e);
      return false;
    }
  }

// Methode zum Ändern des Passworts
  Future<bool> changePassword(String userId, String currentPassword, String newPassword) async {
    try {
      final response = await ApiConfig.sendRequest(
        url: '${ApiConfig.usersUrl}/$userId/password',
        method: 'PUT',
        body: jsonEncode({
          'current_password': currentPassword,
          'new_password': newPassword,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      _logError('Fehler beim Ändern des Passworts', e);
      return false;
    }
  }

// Methode zum Hochladen des Profilbilds
  Future<bool> uploadProfileImage(String userId, Uint8List imageBytes) async {
    try {
      // Konvertiere das Bild zu Base64
      final base64Image = base64Encode(imageBytes);

      final response = await ApiConfig.sendRequest(
        url: '${ApiConfig.usersUrl}/$userId/profile-image',
        method: 'POST',
        body: jsonEncode({
          'image_data': base64Image,
        }),
      );

      if (response.statusCode == 200) {
        // Profildaten aus der Antwort extrahieren
        final responseData = jsonDecode(response.body);

        // Aktualisiere den Cache mit der neuen Bild-URL
        if (_currentUser != null && _currentUser!.id == userId) {
          _currentUser = _currentUser!.copyWith(
            profileImageUrl: responseData['profile_image_url'],
            profileImageBase64: base64Image,
          );
          notifyListeners();
        }

        return true;
      }
      return false;
    } catch (e) {
      _logError('Fehler beim Hochladen des Profilbilds', e);
      return false;
    }
  }

// Methode zum Aktualisieren der letzten Anmeldezeit
  Future<void> updateLastLogin(String userId) async {
    try {
      final now = DateTime.now();

      // Aktualisiere auf dem Server
      await ApiConfig.sendRequest(
        url: '${ApiConfig.usersUrl}/$userId/last-login',
        method: 'PUT',
        body: jsonEncode({
          'last_login': now.toIso8601String(),
        }),
      );

      // Aktualisiere den lokalen Benutzer
      if (_currentUser != null && _currentUser!.id == userId) {
        _currentUser = _currentUser!.copyWith(lastLogin: now);
        notifyListeners();
      }
    } catch (e) {
      _logError('Fehler beim Aktualisieren der letzten Anmeldezeit', e);
    }
  }

// Methode zum Laden des vollständigen Benutzerprofils
  // In user_service.dart, aktualisiere die getUserProfile Methode
  Future<User?> getUserProfile(String userId) async {
    try {
      final response = await ApiConfig.sendRequest(
        url: '${ApiConfig.usersUrl}/$userId/profile',
        method: 'GET',
      );

      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);

        // Sicheres Parsen des last_login Datums
        if (userData['last_login'] != null && userData['last_login'].toString().isNotEmpty) {
          try {
            DateTime.parse(userData['last_login']);
          } catch (e) {
            print('Fehler beim Parsen des Datums: ${userData['last_login']}');
            userData['last_login'] = DateTime.now().toIso8601String();
          }
        }

        final user = User.fromJson(userData);

        // Überprüfe, ob das Profil tatsächlich vollständig ist
        if (user.fullName?.isNotEmpty == true &&
            user.department?.isNotEmpty == true) {
          return user;
        }

        return null;
      }
      return null;
    } catch (e) {
      print('Fehler beim Laden des Benutzerprofils: $e');
      return null;
    }
  }

// In user_service.dart, aktualisiere die hasCompletedProfile Methode
  Future<bool> hasCompletedProfile(String userId) async {
    try {
      final user = await getUserProfile(userId);
      // Überprüfe, ob die wichtigen Profilfelder ausgefüllt sind
      return user != null &&
          user.fullName?.isNotEmpty == true &&
          user.department?.isNotEmpty == true;
    } catch (e) {
      print('Fehler bei der Profilprüfung: $e');
      return false;
    }
  }
// In user_service.dart innerhalb der UserService-Klasse
  Future<bool> loginWithToken(String token) async {
    if (token.isEmpty) return false;

    try {
      // Für Testzwecke - in einer echten App würde hier ein API-Aufruf erfolgen
      if (token.startsWith('user_session_')) {
        _currentUser = User(
          id: 'admin-${DateTime.now().millisecondsSinceEpoch}',
          username: 'admin',
          password: '',  // Leeres Passwort aus Sicherheitsgründen
          role: UserRole.admin,
          isActive: true,
        );
        notifyListeners();
        print('Token-Login erfolgreich für: admin');
        return true;
      }
      return false;
    } catch (e) {
      print('Token-Login Fehler: $e');
      return false;
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
        Uri.parse('https://nsylelsq.ddns.net:443/api/users/${userData['id']}'),
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
        Uri.parse('https://nsylelsq.ddns.net:443/api/users/$userId'),
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
        Uri.parse('https://nsylelsq.ddns.net:443/api/users/$userId/password'),
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