// lib/services/email_notification_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/user_role.dart';
import '../utils/error_logger.dart';

/// Ein Service zum Verwalten und Senden von E-Mail-Benachrichtigungen
class EmailNotificationService extends ChangeNotifier {
  // Singleton Pattern
  static final EmailNotificationService _instance = EmailNotificationService._internal();
  factory EmailNotificationService() => _instance;
  EmailNotificationService._internal();

  // Status-Variablen
  bool _isSending = false;
  bool get isSending => _isSending;
  String? _lastError;
  String? get lastError => _lastError;

  // Benachrichtigungspräferenzen
  Map<String, dynamic>? _preferences;
  Map<String, dynamic> get preferences => _preferences ?? {
    'email_enabled': true,
    'maintenance_notify': true,
    'error_notify': true,
    'task_notify': true,
    'system_notify': true,
  };

  /// Lädt die Benachrichtigungspräferenzen eines Benutzers
  Future<Map<String, dynamic>> loadPreferences(String userId) async {
    try {
      final response = await ApiConfig.sendRequest(
        url: '${ApiConfig.baseUrl}/users/$userId/notification_preferences',
        method: 'GET',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _preferences = {
          'email_enabled': data['email_enabled'] == 1 || data['email_enabled'] == true,
          'maintenance_notify': data['maintenance_notify'] == 1 || data['maintenance_notify'] == true,
          'error_notify': data['error_notify'] == 1 || data['error_notify'] == true,
          'task_notify': data['task_notify'] == 1 || data['task_notify'] == true,
          'system_notify': data['system_notify'] == 1 || data['system_notify'] == true,
        };
        notifyListeners();
        return _preferences!;
      }
      throw Exception('Fehler beim Laden der Benachrichtigungspräferenzen');
    } catch (e, stackTrace) {
      ErrorLogger.logError('EmailNotificationService.loadPreferences', e, stackTrace);
      _lastError = e.toString();
      notifyListeners();
      return preferences; // Standardwerte zurückgeben
    }
  }

  /// Aktualisiert die Benachrichtigungspräferenzen eines Benutzers
  Future<bool> updatePreferences(String userId, Map<String, dynamic> newPrefs) async {
    try {
      final prefsToSend = {
        'email_enabled': newPrefs['email_enabled'] == true ? 1 : 0,
        'maintenance_notify': newPrefs['maintenance_notify'] == true ? 1 : 0,
        'error_notify': newPrefs['error_notify'] == true ? 1 : 0,
        'task_notify': newPrefs['task_notify'] == true ? 1 : 0,
        'system_notify': newPrefs['system_notify'] == true ? 1 : 0,
      };

      final response = await ApiConfig.sendRequest(
        url: '${ApiConfig.baseUrl}/users/$userId/notification_preferences',
        method: 'PUT',
        body: jsonEncode(prefsToSend),
      );

      if (response.statusCode == 200) {
        _preferences = Map<String, dynamic>.from(newPrefs);
        notifyListeners();
        return true;
      }
      throw Exception('Fehler beim Aktualisieren der Benachrichtigungspräferenzen');
    } catch (e, stackTrace) {
      ErrorLogger.logError('EmailNotificationService.updatePreferences', e, stackTrace);
      _lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Sende eine direkte Benachrichtigung per E-Mail
  Future<bool> sendDirectNotification({
    required String email,
    required String subject,
    required String content,
  }) async {
    try {
      _isSending = true;
      _lastError = null;
      notifyListeners();

      print('Sende direkte Benachrichtigung an: $email');

      final response = await ApiConfig.sendRequest(
        url: '${ApiConfig.baseUrl}/notifications/direct/email',
        method: 'POST',
        body: jsonEncode({
          'email': email,
          'subject': subject,
          'content': content,
        }),
      );

      print('Direkte Benachrichtigung Response: ${response.statusCode}, ${response.body}');

      _isSending = false;

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          notifyListeners();
          return true;
        } else {
          _lastError = result['message'] ?? 'Unbekannter Fehler';
          notifyListeners();
          return false;
        }
      }

      _lastError = 'Serverfehler: ${response.statusCode}';
      notifyListeners();
      return false;
    } catch (e) {
      print('Fehler beim Senden der direkten Benachrichtigung: $e');
      _lastError = e.toString();
      _isSending = false;
      notifyListeners();
      return false;
    }
  }

  /// Test-Methode für die Email-Verbindung
  Future<bool> testEmailConnection() async {
    try {
      _isSending = true;
      _lastError = null;
      notifyListeners();

      final response = await ApiConfig.sendRequest(
        url: '${ApiConfig.baseUrl}/test/email',
        method: 'GET',
      );

      if (response.statusCode == 200) {
        print('Email-Verbindungstest erfolgreich');
        return true;
      } else {
        _lastError = 'Email-Verbindungstest fehlgeschlagen: ${response.body}';
        print(_lastError);
        return false;
      }
    } catch (e, stackTrace) {
      ErrorLogger.logError('EmailNotificationService.testEmailConnection', e, stackTrace);
      _lastError = 'Fehler beim Email-Verbindungstest: $e';
      return false;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  /// Verbesserte sendTestEmail Methode
  Future<bool> sendTestEmail(String email) async {
    try {
      _isSending = true;
      _lastError = null;
      notifyListeners();

      // Teste zuerst die Verbindung
      final isConnected = await testEmailConnection();
      if (!isConnected) {
        _lastError = 'Keine Verbindung zum Email-Server möglich';
        return false;
      }

      final response = await ApiConfig.sendRequest(
        url: '${ApiConfig.baseUrl}/notifications/email/send',
        method: 'POST',
        body: jsonEncode({
          'to_email': email,
          'subject': 'Test E-Mail von Asetronics Wartungs-App',
          'html_content': '''
            <p>Dies ist eine Test-E-Mail von der Asetronics Wartungs-App.</p>
            <p>Wenn Sie diese E-Mail erhalten, funktioniert der E-Mail-Versand korrekt.</p>
          ''',
        }),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        _lastError = 'Fehler beim Senden: ${response.body}';
        return false;
      }
    } catch (e, stackTrace) {
      ErrorLogger.logError('EmailNotificationService.sendTestEmail', e, stackTrace);
      _lastError = 'Fehler beim Senden der Test-E-Mail: $e';
      return false;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  /// Sendet eine Aufgabenbenachrichtigung per E-Mail
  Future<bool> sendTaskNotification(String taskId, String userId) async {
    try {
      _isSending = true;
      _lastError = null;
      notifyListeners();

      print('Sende Task-Benachrichtigung - TaskID: $taskId, UserID: $userId');

      final response = await ApiConfig.sendRequest(
        url: '${ApiConfig.baseUrl}/notifications/email/task',
        method: 'POST',
        body: jsonEncode({
          'task_id': taskId,
          'user_id': userId,
        }),
      );

      _isSending = false;

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['success'] == true) {
          notifyListeners();
          return true;
        } else {
          _lastError = result['message'] ?? 'Unbekannter Fehler';
          notifyListeners();
          return false;
        }
      }

      throw Exception('Fehler beim Senden der Aufgabenbenachrichtigung');
    } catch (e, stackTrace) {
      ErrorLogger.logError('EmailNotificationService.sendTaskNotification', e, stackTrace);
      _lastError = e.toString();
      _isSending = false;
      notifyListeners();
      return false;
    }
  }

  /// Sendet eine Statusänderungsbenachrichtigung für Fehlermeldungen
  Future<bool> sendErrorStatusNotification(String errorId, List<String> userIds) async {
    try {
      _isSending = true;
      _lastError = null;
      notifyListeners();

      final response = await ApiConfig.sendRequest(
        url: '${ApiConfig.baseUrl}/notifications/email/error',
        method: 'POST',
        body: jsonEncode({
          'error_id': errorId,
          'user_ids': userIds,
        }),
      );

      _isSending = false;

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['success'] == true) {
          notifyListeners();
          return true;
        } else {
          _lastError = result['message'] ?? 'Unbekannter Fehler';
          notifyListeners();
          return false;
        }
      }

      throw Exception('Fehler beim Senden der Fehlerstatusbenachrichtigung');
    } catch (e, stackTrace) {
      ErrorLogger.logError('EmailNotificationService.sendErrorStatusNotification', e, stackTrace);
      _lastError = e.toString();
      _isSending = false;
      notifyListeners();
      return false;
    }
  }

  /// Sendet eine Wartungserinnerung
  Future<bool> sendMaintenanceReminder(String taskId, List<String> userIds) async {
    try {
      _isSending = true;
      _lastError = null;
      notifyListeners();

      final response = await ApiConfig.sendRequest(
        url: '${ApiConfig.baseUrl}/notifications/email/maintenance',
        method: 'POST',
        body: jsonEncode({
          'task_id': taskId,
          'user_ids': userIds,
        }),
      );

      _isSending = false;

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['success'] == true) {
          notifyListeners();
          return true;
        } else {
          _lastError = result['message'] ?? 'Unbekannter Fehler';
          notifyListeners();
          return false;
        }
      }

      throw Exception('Fehler beim Senden der Wartungserinnerung');
    } catch (e, stackTrace) {
      ErrorLogger.logError('EmailNotificationService.sendMaintenanceReminder', e, stackTrace);
      _lastError = e.toString();
      _isSending = false;
      notifyListeners();
      return false;
    }
  }
}