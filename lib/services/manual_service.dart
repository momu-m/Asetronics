// manual_service.dart
import 'package:asetronics_ag_app/services/user_service.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../config/api_config.dart';

class ManualService extends ChangeNotifier {
  // Singleton-Pattern
  static final ManualService _instance = ManualService._internal();
  factory ManualService() => _instance;
  ManualService._internal();

  // Liste der geladenen Anleitungen
  List<Map<String, dynamic>> _manuals = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Getter
  List<Map<String, dynamic>> get manuals => List.unmodifiable(_manuals);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Lädt alle Anleitungen vom Server
  Future<void> loadManuals() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/manuals'),
        headers: ApiConfig.defaultHeaders,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _manuals = List<Map<String, dynamic>>.from(data);

        // WICHTIG: Hier fügen wir die URL für jede Anleitung hinzu, falls sie nicht vom Backend kommt
        for (var manual in _manuals) {
          if (!manual.containsKey('url') || manual['url'] == null || manual['url'].startsWith('/')) {
            // Stellen sicher, dass wir eine vollständige URL verwenden
            final String id = manual['id'];
            // Verwende absolute URL mit vollständigem Schema (http oder https)
            manual['url'] = '${ApiConfig.baseUrl}/manuals/$id/file';
          }
        }
      } else {
        _errorMessage = 'Fehler beim Laden der Anleitungen: ${response.statusCode}';
        print('API-Fehler: ${response.body}');
      }
    } catch (e) {
      _errorMessage = 'Netzwerkfehler: $e';
      print('Fehler beim Laden der Anleitungen: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Lädt eine spezifische Anleitung
  Future<Map<String, dynamic>?> getManual(String id) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/manuals/$id'),
        headers: ApiConfig.defaultHeaders,
      );

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      print('Fehler beim Laden der Anleitung: $e');
      return null;
    }
  }

  // Lädt eine Anleitung für einen bestimmten Maschinentyp
  Future<Map<String, dynamic>?> getManualForMachine(String machineType) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/manuals/search?machine_type=$machineType'),
        headers: ApiConfig.defaultHeaders,
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = jsonDecode(response.body);
        if (results.isNotEmpty) {
          return Map<String, dynamic>.from(results.first);
        }
      }
      return null;
    } catch (e) {
      print('Fehler beim Suchen der Anleitung: $e');
      return null;
    }
  }

  // Sucht nach Anleitungen
  List<Map<String, dynamic>> searchManuals(String query) {
    if (query.isEmpty) return _manuals;

    final queryLower = query.toLowerCase();
    return _manuals.where((manual) {
      return manual['title'].toString().toLowerCase().contains(queryLower) ||
          manual['machine_type'].toString().toLowerCase().contains(queryLower) ||
          manual['description'].toString().toLowerCase().contains(queryLower);
    }).toList();
  }

  // Lädt eine Anleitung hoch
  Future<bool> uploadManual({
    required String title,
    required String description,
    required String machineType,
    required Uint8List fileBytes,
    required String fileName,
    String? category,
    String? line,
    String? serialNumber,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Erstelle multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/manuals'),
      );

      // Metadaten hinzufügen
      request.fields['title'] = title;
      request.fields['description'] = description;
      request.fields['machine_type'] = machineType;
      if (category != null) request.fields['category'] = category;
      if (line != null) request.fields['line'] = line;
      if (serialNumber != null) request.fields['serial_number'] = serialNumber;

      // Benutzer-ID hinzufügen, wenn verfügbar
      final currentUser = await getCurrentUser();
      if (currentUser != null) {
        request.fields['created_by'] = currentUser['id'];
      }

      // Datei hinzufügen
      final file = http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: fileName,
        contentType: MediaType('application', 'pdf'),
      );
      request.files.add(file);

      // Request senden
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        await loadManuals(); // Aktualisiere die Liste
        return true;
      } else {
        _errorMessage = 'Fehler beim Hochladen: ${response.body}';
        return false;
      }
    } catch (e) {
      _errorMessage = 'Netzwerkfehler: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Löscht eine Anleitung
  Future<bool> deleteManual(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/manuals/$id'),
        headers: ApiConfig.defaultHeaders,
      );

      if (response.statusCode == 200) {
        await loadManuals(); // Aktualisiere die Liste
        return true;
      }
      return false;
    } catch (e) {
      print('Fehler beim Löschen der Anleitung: $e');
      return false;
    }
  }

  // Hilfsmethode für aktuellen Benutzer
  Future<Map<String, dynamic>?> getCurrentUser() async {
    // Hol dir den echten User aus dem UserService-Singleton:
    final user = UserService().currentUser;
    if (user == null) return null; // oder fehlerbehandeln

    return {
      'id': user.id,
      'role': user.role.toString()
    };
  }
}