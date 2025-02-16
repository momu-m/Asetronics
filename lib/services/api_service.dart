// api_service.dart
// import 'package:http/http.dart' as http;
// import 'dart:convert';
import 'dart:convert';  // Für jsonEncode
import 'package:http/http.dart' as http;  // Für HTTP-Anfragen
import 'package:flutter/foundation.dart';  // Für Debug-Funktionen

class ApiService {
  // Singleton-Pattern Implementation
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // API URL
  final String apiUrl = 'https://nsylelsq.ddns.net:443/api/data';

  // Debug-Modus für Logging
  final bool _debug = true;

  // POST Methode für Daten senden
  Future<bool> postData(Map<String, dynamic> data) async {
    try {
      _logDebug('Sende Daten an: $apiUrl');

      final response = await http.post(
          Uri.parse(apiUrl),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(data)
      );

      _logDebug('Server Antwort: ${response.body}');
      _logDebug('Status Code: ${response.statusCode}');

      return response.statusCode == 201; // Created

    } catch (e) {
      _logError('API Fehler', e);
      return false;
    }
  }

  // Debug-Logging
  void _logDebug(String message) {
    if (_debug) {
      print('📘 API Service: $message');
    }
  }

  // Error-Logging
  void _logError(String message, Object error) {
    print('❌ API Service Error: $message');
    print('Fehler: $error');
  }
}