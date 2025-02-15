// manual_service.dart
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:universal_html/html.dart' as html;

class ManualService extends ChangeNotifier {
  // Singleton-Pattern Implementation
  static final ManualService _instance = ManualService._internal();
  factory ManualService() => _instance;
  ManualService._internal();

  // Konstante für localStorage Key
  static const String MANUALS_KEY = 'manuals';

  // Speichert die Metadaten der Anleitungen
  final List<Map<String, dynamic>> _manuals = [];

  // Getter für die Anleitungen
  List<Map<String, dynamic>> get manuals => List.unmodifiable(_manuals);

  // Lädt eine neue Anleitung hoch
  Future<void> uploadManual(Map<String, dynamic> manual) async {
    try {
      _manuals.add(manual);
      await _saveToLocalStorage();
      notifyListeners();
    } catch (e) {
      print('Fehler beim Hochladen der Anleitung: $e');
      rethrow;
    }
  }

  // Speichert die Anleitungen im localStorage
  Future<void> _saveToLocalStorage() async {
    if (kIsWeb) {
      html.window.localStorage[MANUALS_KEY] = jsonEncode(_manuals);
    }
  }

  // Lädt die Anleitungen aus dem localStorage
  Future<void> loadManuals() async {
    try {
      if (kIsWeb) {
        final String? stored = html.window.localStorage[MANUALS_KEY];
        if (stored != null) {
          final List<dynamic> decoded = jsonDecode(stored);
          _manuals.clear();
          _manuals.addAll(List<Map<String, dynamic>>.from(decoded));
          notifyListeners();
        }
      }
    } catch (e) {
      print('Fehler beim Laden der Anleitungen: $e');
    }
  }

  // Sucht nach Anleitungen basierend auf Suchtext
  List<Map<String, dynamic>> searchManuals(String query) {
    if (query.isEmpty) return _manuals;

    final queryLower = query.toLowerCase();
    return _manuals.where((manual) {
      return manual['title'].toString().toLowerCase().contains(queryLower) ||
          manual['machineType'].toString().toLowerCase().contains(queryLower) ||
          manual['description'].toString().toLowerCase().contains(queryLower);
    }).toList();
  }
// In manual_service.dart füge diese Methode hinzu
  Future<void> initializeTestData() async {
    final testManuals = [
      {
        'id': '1',
        'title': 'Bedienungsanleitung Bestücker 1',
        'machineType': 'SIPLACE SX2',
        'description': 'Komplette Bedienungsanleitung für SIPLACE SX2',
        'url': 'assets/manuals/siplace_sx2.pdf',
        'category': 'Bestücker',
        'line': 'X-Linie',
        'serialNumber': 'M538G-12041572'
      },
      {
        'id': '2',
        'title': 'Wartungshandbuch Reflowofen',
        'machineType': 'Rehm VXP+nitro 3855',
        'description': 'Wartungsanleitung für Reflowofen',
        'url': 'assets/manuals/rehm_vxp.pdf',
        'category': 'Öfen',
        'line': 'X-Linie',
        'serialNumber': '4043'
      },
      {
        'id': '3',
        'title': 'Bedienungsanleitung AOI',
        'machineType': 'Koh Young Zenith',
        'description': 'Bedienungsanleitung für AOI System',
        'url': 'assets/manuals/koh_young.pdf',
        'category': 'Inspektion',
        'line': 'X-Linie',
        'serialNumber': 'AP-SL-00185'
      },
      // Weitere Maschinen aus deiner Anlagenübersicht
    ];

    for (final manual in testManuals) {
      await uploadManual(manual);
    }
  }


  // Holt eine Anleitung für einen bestimmten Maschinentyp
  Map<String, dynamic>? getManualForMachine(String machineType) {
    try {
      return _manuals.firstWhere(
            (manual) => manual['machineType'] == machineType,
        orElse: () => throw Exception('Keine Anleitung gefunden'),
      );
    } catch (e) {
      print('Fehler beim Abrufen der Anleitung: $e');
      return null;
    }
  }
}