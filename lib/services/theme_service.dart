import 'package:flutter/material.dart';
import '../screens/settings/settings_model.dart';

/// Ein erweiterter ThemeService für dynamische und flexible Theming-Optionen
class ThemeService extends ChangeNotifier {
  // Singleton-Pattern Implementation für globalen Zugriff
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal() {
    // Initialisiere Basis-Themes
    _initializeThemes();
  }

  // Private Variablen für Theme-Konfiguration
  ThemeData? _cachedLightTheme;
  ThemeData? _cachedDarkTheme;

  // Hier NICHT entfernen: Wird von main.dart und anderen Dateien benutzt
  AppThemeMode _currentThemeMode = AppThemeMode.system;

  // Standardfarbpalette für konsistentes Design
  static const Color _primaryLightColor = Color(0xFF0D47A1);
  static const Color _primaryDarkColor = Color(0xFF1976D2);
  static const Color _accentLightColor = Color(0xFF448AFF);
  static const Color _accentDarkColor = Color(0xFF82B1FF);

  // Erweiterte Farbpalette
  static const Color _primaryDarkBlue = Color(0xFF0D47A1);
  static const Color _primaryMediumBlue = Color(0xFF1976D2);
  static const Color _primaryLightBlue = Color(0xFF42A5F5);
  static const Color _accentBlue = Color(0xFF82B1FF);

  // Hintergrundfarben
  static const Color _backgroundLightColor = Color(0xFFF5F9FF);
  static const Color _backgroundDarkColor = Color(0xFF121A2B);
  static const Color _cardLightColor = Colors.white;
  static const Color _cardDarkColor = Color(0xFF1E2333);

  // Error & Success Colors
  static const Color _errorColor = Color(0xFFE53935);
  static const Color _successColor = Color(0xFF43A047);

  // ---- HIER FÜGEN WIR DIE FEHLENDEN GETTER UND METHODEN EIN ----

  /// Getter für den aktuellen ThemeMode (wird in main.dart abgefragt)
  AppThemeMode get currentThemeMode => _currentThemeMode;

  /// Ermöglicht das Setzen eines neuen ThemeMode (z. B. dark/light/system)
  void setThemeMode(AppThemeMode mode) {
    _currentThemeMode = mode;
    // Mit notifyListeners() signalisieren wir Widgets, dass sich das Theme geändert hat
    notifyListeners();
  }

  /// Gibt das Dark Theme zurück (wird in main.dart z. B. bei getDarkTheme() genutzt)
  ThemeData getDarkTheme() {
    return _cachedDarkTheme!;
  }

  /// Gibt das Light Theme zurück (wird in main.dart z. B. bei getLightTheme() genutzt)
  ThemeData getLightTheme() {
    return _cachedLightTheme!;
  }

  /// Initialisiert Basis-Themes mit umfangreichen Konfigurationen
  void _initializeThemes() {
    _cachedLightTheme = _createLightTheme();
    _cachedDarkTheme = _createDarkTheme();
  }

  /// Erstellt ein detailliertes Light Theme mit konsistenten Farben und Standards
  ThemeData _createLightTheme() {
    final ColorScheme colorScheme = ColorScheme.light(
      primary: _primaryLightColor,
      primaryContainer: _primaryLightColor.withOpacity(0.8),
      secondary: _accentLightColor,
      secondaryContainer: _accentLightColor.withOpacity(0.2),
      surface: _cardLightColor,
      background: _backgroundLightColor,
      error: _errorColor,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onBackground: Colors.black87,
      onSurface: Colors.black87,
      onError: Colors.white,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.light,
      primaryColor: _primaryLightColor,
      scaffoldBackgroundColor: _backgroundLightColor,

      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: _primaryLightColor,
        foregroundColor: Colors.white,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      cardTheme: CardTheme(
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: _cardLightColor,
      ),

      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1A1A1A),
        ),
        displayMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1A1A1A),
        ),
        displaySmall: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1A1A1A),
        ),
        headlineMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(0xFF333333),
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF333333),
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: Color(0xFF333333),
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: Color(0xFF666666),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey[100],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _primaryLightColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _errorColor, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _errorColor, width: 2),
        ),
        labelStyle: TextStyle(color: Colors.grey[700]),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryLightColor,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _primaryLightColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _primaryLightColor,
          side: BorderSide(color: _primaryLightColor),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      tabBarTheme: TabBarTheme(
        labelColor: _primaryLightColor,
        unselectedLabelColor: Colors.grey[600],
        indicatorColor: _primaryLightColor,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _primaryLightColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      dialogTheme: DialogTheme(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: _cardLightColor,
        elevation: 8,
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  /// Erstellt ein detailliertes Dark Theme mit konsistenten Farben und Standards
  ThemeData _createDarkTheme() {
    final ColorScheme colorScheme = ColorScheme.dark(
      primary: _primaryDarkColor,
      primaryContainer: _primaryDarkColor.withOpacity(0.7),
      secondary: _accentDarkColor,
      secondaryContainer: _accentDarkColor.withOpacity(0.2),
      surface: _cardDarkColor,
      background: _backgroundDarkColor,
      error: Colors.red[300]!,
      onPrimary: Colors.white,
      onSecondary: Colors.black87,
      onBackground: Colors.white,
      onSurface: Colors.white,
      onError: Colors.black,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.dark,
      primaryColor: _primaryDarkColor,
      scaffoldBackgroundColor: _backgroundDarkColor,

      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: _primaryDarkColor.withOpacity(0.7),
        foregroundColor: Colors.white,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      cardTheme: CardTheme(
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: _cardDarkColor,
      ),

      textTheme: TextTheme(
        displayLarge: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        displayMedium: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        displaySmall: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        headlineMedium: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        titleLarge: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        bodyLarge: const TextStyle(
          fontSize: 16,
          color: Colors.white,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: Colors.grey[300],
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey[800]!.withOpacity(0.3),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[700]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[700]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _accentDarkColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red[300]!, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red[300]!, width: 2),
        ),
        labelStyle: TextStyle(color: Colors.grey[400]),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryDarkColor,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _accentDarkColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _accentDarkColor,
          side: BorderSide(color: _accentDarkColor),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      tabBarTheme: TabBarTheme(
        labelColor: _accentDarkColor,
        unselectedLabelColor: Colors.grey[400],
        indicatorColor: _accentDarkColor,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _primaryDarkColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      dialogTheme: DialogTheme(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: _cardDarkColor,
        elevation: 8,
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
