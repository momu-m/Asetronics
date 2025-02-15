//Dienst zur Speicherung von Einstellungen
// settings_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../settings_model.dart';

class SettingsService {
  static const String _settingsKey = 'app_settings';

  // Speichert Einstellungen
  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  // Lädt Einstellungen
  Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsJson = prefs.getString(_settingsKey);

    if (settingsJson != null) {
      return AppSettings.fromJson(jsonDecode(settingsJson));
    }

    return AppSettings(); // Standardeinstellungen
  }

  // Setzt Einstellungen zurück
  Future<void> resetSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_settingsKey);
  }
}