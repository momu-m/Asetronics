// lib/services/ai_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Für das Laden der .env-Datei
import '../config/api_config.dart';
import 'package:http/http.dart' as http;

class AIService extends ChangeNotifier {
  // Singleton-Pattern
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  // Lokaler Cache für häufige Anfragen
  final Map<String, dynamic> _analysisCache = {};

  // Status-Variablen
  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  // Diese Methode durchsucht die Handbücher nach passenden Einträgen
  List<Map<String, dynamic>> suggestManualSections(String query, List<Map<String, dynamic>> manuals) {
    try {
      // Einfache Textsuche in den Handbüchern
      return manuals.where((manual) {
        final titleMatch = manual['title'].toString().toLowerCase().contains(query.toLowerCase());
        final typeMatch = manual['machineType'].toString().toLowerCase().contains(query.toLowerCase());
        final descriptionMatch = manual['description'].toString().toLowerCase().contains(query.toLowerCase());

        return titleMatch || typeMatch || descriptionMatch;
      }).toList();
    } catch (e) {
      print('Fehler bei der Handbuchsuche: $e');
      return [];
    }
  }

  // Hauptmethode für die KI-Anfrage über den eigenen Server
  Future<Map<String, dynamic>> getAIResponse(String query, {String? machineId}) async {
    try {
      final response = await ApiConfig.sendRequest(
        url: '${ApiConfig.baseUrl}/ai/chat',
        method: 'POST',
        body: jsonEncode({
          'query': query,
          'machine_id': machineId,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception('Fehler bei der KI-Anfrage');
    } catch (e) {
      print('KI-Anfrage Fehler: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Hauptmethode für die Problemanalyse über den eigenen Server
  Future<Map<String, dynamic>> analyzeProblem(String description, {String? machineType}) async {
    try {
      final response = await ApiConfig.sendRequest(
        url: '${ApiConfig.baseUrl}/ai/analyze_problem',
        method: 'POST',
        body: jsonEncode({
          'description': description,
          'machine_type': machineType,
        }),
      );

      if (response.statusCode == 200) {
        // Wenn keine spezifische Analyse zurückkommt, erstellen wir eine Standard-Antwort
        final result = jsonDecode(response.body);

        if (result['analysis'] == null || result['analysis']['category'] == 'unbekannt') {
          // Erstelle eine Standard-Analyse basierend auf Schlüsselwörtern
          final lowerDesc = description.toLowerCase();

          String category = 'Allgemein';
          String severity = 'mittel';
          List<String> solutions = [];

          // Einfache Kategorisierung
          if (lowerDesc.contains('motor') || lowerDesc.contains('vibration') || lowerDesc.contains('lager')) {
            category = 'Mechanisch';
            solutions.add('Überprüfung der mechanischen Komponenten');
            solutions.add('Inspektion der Lager und beweglichen Teile');
          } else if (lowerDesc.contains('display') || lowerDesc.contains('sensor') || lowerDesc.contains('strom')) {
            category = 'Elektrisch';
            solutions.add('Überprüfung der elektrischen Verbindungen');
            solutions.add('Testen der Sensoren und Anzeigen');
          } else if (lowerDesc.contains('software') || lowerDesc.contains('programm') || lowerDesc.contains('update')) {
            category = 'Software';
            solutions.add('Überprüfung der Software-Version');
            solutions.add('Neustart des Systems durchführen');
          }

          // Bestimme die Dringlichkeit
          if (lowerDesc.contains('sofort') || lowerDesc.contains('dringend') || lowerDesc.contains('gefahr')) {
            severity = 'hoch';
          } else if (lowerDesc.contains('bald') || lowerDesc.contains('wichtig')) {
            severity = 'mittel';
          } else {
            severity = 'niedrig';
          }

          return {
            'success': true,
            'analysis': {
              'category': category,
              'severity': severity,
              'possible_solutions': solutions,
              'recommendation': 'Basierend auf der Beschreibung empfehle ich eine ' +
                  (severity == 'hoch' ? 'zeitnahe ' : 'planmäßige ') +
                  'Überprüfung der ' + category.toLowerCase() + 'en Komponenten.'
            }
          };
        }

        return result;
      }
      throw Exception('Fehler bei der KI-Analyse');
    } catch (e) {
      print('KI-Analyse Fehler: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Suche nach ähnlichen Problemen
  Future<List<Map<String, dynamic>>> searchSimilarProblems(String description) async {
    try {
      final response = await ApiConfig.sendRequest(
        url: '${ApiConfig.baseUrl}/ai/search_similar_problems',
        method: 'POST',
        body: jsonEncode({'description': description}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['similar_problems']);
      }
      return [];
    } catch (e) {
      print('Ähnliche Probleme Fehler: $e');
      return [];
    }
  }

  // Wartungsempfehlungen generieren
  Future<Map<String, dynamic>> getMaintenanceRecommendations(String machineId) async {
    try {
      final response = await ApiConfig.sendRequest(
        url: '${ApiConfig.baseUrl}/ai/maintenance_recommendations',
        method: 'POST',
        body: jsonEncode({'machine_id': machineId}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception('Fehler beim Abrufen der Wartungsempfehlungen');
    } catch (e) {
      print('Wartungsempfehlungen Fehler: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Lösungsvorschläge generieren
  Future<List<String>> generateSolutionSuggestions(String problemDescription) async {
    try {
      final response = await ApiConfig.sendRequest(
        url: '${ApiConfig.baseUrl}/ai/suggest_solutions',
        method: 'POST',
        body: jsonEncode({'description': problemDescription}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<String>.from(data['suggestions']);
      }
      return [];
    } catch (e) {
      print('Lösungsvorschläge Fehler: $e');
      return [];
    }
  }

  // Neue Methode: Direkte Nutzung der Hugging Face API
  Future<Map<String, dynamic>> getHuggingFaceResponse(String inputText) async {
    // Lade den API-Schlüssel aus der .env-Datei
    final String? apiKey = dotenv.env['HUGGINGFACE_API_KEY'];
    if (apiKey == null) {
      return {
        'success': false,
        'response': 'API-Schlüssel nicht gefunden. Bitte überprüfe deine .env-Datei.'
      };
    }

    // Größeres instruct-getuntes Modell statt gpt2
    const String modelName = 'google/flan-t5-base';

    // Erstelle die URL für das Hugging Face Modell
    final String url = 'https://api-inference.huggingface.co/models/$modelName';

    // Erstelle die Header für die Anfrage
    final Map<String, String> headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };

    // WICHTIG: "inputs": inputText statt prompt
    final String body = jsonEncode({
      'inputs': inputText,
      'parameters': {
        'max_new_tokens': 200,   // Längere Antworten
        'temperature': 0.3       // Geringe Werte => sachlichere, fokussiertere Antworten
      }
    });

    try {
      // Sende die POST-Anfrage an die Hugging Face API
      final http.Response response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'response': data.toString(),
        };
      } else {
        return {
          'success': false,
          'response': 'Fehler: ${response.statusCode} - ${response.reasonPhrase}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'response': 'Ausnahme: $e',
      };
    }
  }

  // Cache leeren
  void clearCache() {
    _analysisCache.clear();
    notifyListeners();
  }

  // Neue Methode: Ruft /api/ai/augmented_chat auf
  Future<Map<String, dynamic>> getAugmentedChatResponse(String queryText) async {
    try {
      final response = await ApiConfig.sendRequest(
        url: '${ApiConfig.baseUrl}/ai/augmented_chat',
        method: 'POST',
        body: jsonEncode({
          'query': queryText,
        }),
      );

      if (response.statusCode == 200) {
        // z. B. { "success": true, "generated_text": "...", "retrieved_data": [...] }
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'error': 'Fehler: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Augmented Chat Fehler: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}
