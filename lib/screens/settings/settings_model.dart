//Einstellungsmodell


enum AppThemeMode {
  light,
  dark,
  system
}

enum NotificationPreference {
  all,
  important,
  none
}

class AppSettings {
  final AppThemeMode themeMode;
  final bool enableNotifications;
  final NotificationPreference notificationLevel;
  final String language;
  final bool enableBiometricLogin;
  final bool enableBiometrics;

  const AppSettings({
    this.themeMode = AppThemeMode.system,
    this.enableNotifications = true,
    this.notificationLevel = NotificationPreference.important,
    this.language = 'de',
    this.enableBiometricLogin = false,
    this.enableBiometrics = false,

  });

  // Erstellt eine Kopie der Einstellungen mit optionalen Änderungen
  AppSettings copyWith({
    AppThemeMode? themeMode,
    bool? enableNotifications,
    NotificationPreference? notificationLevel,
    String? language,
    bool? enableBiometricLogin,
    bool? enableBiometrics,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      enableNotifications: enableNotifications ?? this.enableNotifications,
      notificationLevel: notificationLevel ?? this.notificationLevel,
      language: language ?? this.language,
      enableBiometricLogin: enableBiometricLogin ?? this.enableBiometricLogin,
      enableBiometrics: enableBiometrics ?? this.enableBiometrics,
    );
  }

  // Konvertiert Einstellungen zu JSON für Speicherung
  Map<String, dynamic> toJson() {
    return {
      'themeMode': themeMode.index,
      'enableNotifications': enableNotifications,
      'notificationLevel': notificationLevel.index,
      'language': language,
      'enableBiometricLogin': enableBiometricLogin,
      'enableBiometrics': enableBiometrics,
    };
  }

  // Erstellt Einstellungen aus JSON
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      themeMode: AppThemeMode.values[json['themeMode'] ?? 0],
      enableNotifications: json['enableNotifications'] ?? true,
      notificationLevel: NotificationPreference.values[json['notificationLevel'] ?? 1],
      language: json['language'] ?? 'de',
      enableBiometricLogin: json['enableBiometricLogin'] ?? false,
      enableBiometrics: json['enableBiometrics'] ?? false,
    );
  }
}
