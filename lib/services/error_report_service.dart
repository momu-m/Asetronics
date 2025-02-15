// lib/services/error_report_service.dart

import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../config/api_config.dart';

class ErrorReportService extends ChangeNotifier {
  // Singleton-Pattern
  static final ErrorReportService _instance = ErrorReportService._internal();
  factory ErrorReportService() => _instance;
  ErrorReportService._internal();

  // Lokaler Cache für Fehlerberichte
  List<Map<String, dynamic>> _cachedReports = [];

  // Fehlerbericht speichern
  Future<bool> saveErrorReport(Map<String, dynamic> errorData) async {
    try {
      _logDebug('Speichere Fehlermeldung: ${jsonEncode(errorData)}');

      final response = await ApiConfig.sendRequest(
        url: ApiConfig.errorsUrl,
        method: 'POST',
        body: jsonEncode(errorData),
      );

      if (response.statusCode == 201) {
        // Cache aktualisieren
        _cachedReports.add(errorData);
        notifyListeners();
        return true;
      }

      _logError('Server-Fehler', 'Status: ${response.statusCode}, Body: ${response.body}');
      return false;
    } catch (e) {
      _logError('Fehler beim Speichern', e);
      return false;
    }
  }

  // Fehlerberichte abrufen
  Future<List<Map<String, dynamic>>> getErrorReports() async {
    try {
      final response = await ApiConfig.sendRequest(
        url: ApiConfig.errorsUrl,
        method: 'GET',
      );

      if (response.statusCode == 200) {
        _cachedReports = List<Map<String, dynamic>>.from(jsonDecode(response.body));
        return _cachedReports;
      }

      return _cachedReports; // Verwende Cache bei Fehlern
    } catch (e) {
      _logError('Fehler beim Laden der Fehlermeldungen', e);
      return _cachedReports; // Verwende Cache bei Fehlern
    }
  }

  // Status eines Fehlerberichts aktualisieren
  Future<bool> updateErrorStatus(String errorId, String newStatus) async {
    try {
      final response = await ApiConfig.sendRequest(
        url: '${ApiConfig.errorsUrl}/$errorId',
        method: 'PATCH',
        body: jsonEncode({'status': newStatus}),
      );

      if (response.statusCode == 200) {
        // Cache aktualisieren
        final index = _cachedReports.indexWhere((report) => report['id'] == errorId);
        if (index != -1) {
          _cachedReports[index]['status'] = newStatus;
          notifyListeners();
        }
        return true;
      }

      return false;
    } catch (e) {
      _logError('Fehler beim Aktualisieren des Status', e);
      return false;
    }
  }

  // Resolved-Zeitstempel setzen
  Future<bool> setResolvedTime(String errorId) async {
    try {
      final response = await ApiConfig.sendRequest(
        url: '${ApiConfig.errorsUrl}/$errorId/resolve',
        method: 'PATCH',
      );

      return response.statusCode == 200;
    } catch (e) {
      _logError('Fehler beim Setzen des resolved_at Zeitstempels', e);
      return false;
    }
  }

  // Hilfsmethoden für Logging
  void _logDebug(String message) {
    debugPrint('📘 DEBUG: $message');
  }

  void _logError(String message, Object error) {
    debugPrint('❌ ERROR: $message');
    debugPrint('DETAILS: $error');
  }
}