// theme_service.dart
import 'package:flutter/material.dart';
import '../settings_model.dart';

class ThemeService extends ChangeNotifier {
  // Singleton-Pattern Implementation
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  // Aktuelle Theme-Einstellung
  AppThemeMode _currentThemeMode = AppThemeMode.system;

  // Getter für das aktuelle Theme
  AppThemeMode get currentThemeMode => _currentThemeMode;

  // Getter für das aktuelle ThemeData
  ThemeData getCurrentTheme(BuildContext context) {
    // Wenn System-Theme ausgewählt ist, hole die Einstellung vom System
    if (_currentThemeMode == AppThemeMode.system) {
      var brightness = MediaQuery.of(context).platformBrightness;
      return brightness == Brightness.dark ? getDarkTheme() : getLightTheme();
    }
    // Ansonsten verwende die gespeicherte Einstellung
    return _currentThemeMode == AppThemeMode.dark ? getDarkTheme() : getLightTheme();
  }

  // Helles Theme
  static ThemeData getLightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: Colors.blue[800],
      // Anpassung der Farben für helles Theme
      colorScheme: ColorScheme.light(
        primary: Colors.blue[800]!,
        secondary: Colors.blue[600]!,
        surface: Colors.white,
        background: Colors.grey[50]!,
        error: Colors.red[700]!,
      ),

      // Card-Design im hellen Theme
      cardTheme: CardTheme(
        color: Colors.white,
        elevation: 2,
        margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // AppBar-Design im hellen Theme
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.blue[800],
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
      ),
    );
  }

  // Dunkles Theme
  static ThemeData getDarkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: Colors.blue[900],
      // Anpassung der Farben für dunkles Theme
      colorScheme: ColorScheme.dark(
        primary: Colors.blue[700]!,
        secondary: Colors.blue[500]!,
        surface: Color(0xFF1E1E1E),  // Dunkelgrauer Hintergrund
        background: Color(0xFF121212), // Noch dunklerer Hintergrund
        error: Colors.red[300]!,
      ),

      // Card-Design im dunklen Theme
      cardTheme: CardTheme(
        color: Color(0xFF2D2D2D), // Etwas helleres Grau für Karten
        elevation: 4,
        margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // AppBar-Design im dunklen Theme
      appBarTheme: AppBarTheme(
        backgroundColor: Color(0xFF1E1E1E),
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
      ),

      // Textfarben im dunklen Theme
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: Colors.grey[300]),
        bodyMedium: TextStyle(color: Colors.grey[400]),
        titleLarge: TextStyle(color: Colors.white),
      ),

      // Iconfarben im dunklen Theme
      iconTheme: IconThemeData(
        color: Colors.grey[400],
      ),
    );
  }

  // Methode zum Ändern des Themes
  void setThemeMode(AppThemeMode mode) {
    if (_currentThemeMode != mode) {
      _currentThemeMode = mode;
      notifyListeners(); // Benachrichtigt alle Listener über die Änderung
    }
  }

  // Hilfsmethode zum Umschalten zwischen Hell und Dunkel
  void toggleTheme() {
    if (_currentThemeMode == AppThemeMode.light) {
      setThemeMode(AppThemeMode.dark);
    } else {
      setThemeMode(AppThemeMode.light);
    }
  }
}