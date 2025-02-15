// user_role.dart

// Definition der verfügbaren Benutzerrollen
enum UserRole {
  admin,      // Administrator
  teamlead,   // Teamleiter
  technician, // Techniker
  operator    // Bediener
}

extension UserRoleExtension on UserRole {
  String toDatabaseValue() {
    return this.toString().split('.').last.toLowerCase();
  }

  static UserRole fromDatabaseValue(String value) {
    switch (value.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'teamlead':
        return UserRole.teamlead;
      case 'technician':
        return UserRole.technician;
      case 'operator':
      default:
        return UserRole.operator;
    }
  }
}
// Klasse zur Verwaltung der Benutzerberechtigungen
class UserPermissions {
  // Statische Methode zur Überprüfung der Berechtigungen
  static bool hasPermission(UserRole role, String action) {
    final permissions = {
      UserRole.admin: [
        'manage_users',
        'manage_roles',
        'view_statistics',
        'manage_machines',
        'manage_maintenance',
        'manage_tasks',
        'delete_reports',
        'export_data',
        'view_all_reports',
        'edit_all_reports',
        'scan_qr',           // Hinzugefügt
        'create_error_reports', // Hinzugefügt
        'create_reports',    // Hinzugefügt
        'view_assigned_tasks', // Hinzugefügt
        'view_manuals'       // Hinzugefügt
      ],
      UserRole.teamlead: [
        'view_statistics',
        'manage_maintenance',
        'manage_tasks',
        'view_all_reports',
        'edit_team_reports',
        'export_data'
      ],
      UserRole.technician: [
        'create_reports',
        'edit_own_reports',
        'view_assigned_tasks',
        'complete_tasks',
        'scan_qr'
      ],
      UserRole.operator: [
        'view_manuals',
        'create_error_reports',
        'scan_qr',
        'view_own_reports'
      ]
    };

    // Prüfe ob die Rolle die angeforderte Berechtigung hat
    return permissions[role]?.contains(action) ?? false;
  }

  // Gibt alle verfügbaren Berechtigungen für eine Rolle zurück
  static List<String> getPermissionsForRole(UserRole role) {
    return switch (role) {
      UserRole.admin => [
        'manage_users',
        'manage_roles',
        'view_statistics',
        'manage_machines',
        'manage_maintenance',
        'manage_tasks',
        'delete_reports',
        'export_data',
        'view_all_reports',
        'edit_all_reports'
      ],
      UserRole.teamlead => [
        'view_statistics',
        'manage_maintenance',
        'manage_tasks',
        'view_all_reports',
        'edit_team_reports',
        'export_data'
      ],
      UserRole.technician => [
        'create_reports',
        'edit_own_reports',
        'view_assigned_tasks',
        'complete_tasks',
        'scan_qr'
      ],
      UserRole.operator => [
        'view_manuals',
        'create_error_reports',
        'scan_qr',
        'view_own_reports'
      ]
    };
  }

  // Rollenbezeichnung auf Deutsch
  static String getRoleDisplayName(UserRole role) {
    return switch (role) {
      UserRole.admin => 'Administrator',
      UserRole.teamlead => 'Teamleiter',
      UserRole.technician => 'Techniker',
      UserRole.operator => 'Bediener'
    };
  }

  // Beschreibung der Rolle
  static String getRoleDescription(UserRole role) {
    return switch (role) {
      UserRole.admin => 'Vollzugriff auf alle Funktionen',
      UserRole.teamlead => 'Verwaltung von Team und Wartungsaufgaben',
      UserRole.technician => 'Durchführung von Wartungsarbeiten',
      UserRole.operator => 'Grundlegende Maschinenbedienung'
    };
  }
}

// In der User-Klasse in user_role.dart

// user_role.dart

class User {
  final String id;           // varchar(36)
  final String username;     // varchar(50)
  final String password;     // varchar(255)
  final UserRole role;       // varchar(50) - wird als enum gespeichert
  final bool isActive;       // tinyint(1)

  User({
    required this.id,
    required this.username,
    required this.password,
    required this.role,
    this.isActive = true,    // Standardwert ist 1 (true) wie in der Datenbank
  });

  // Konvertiert JSON/Datenbank-Daten in ein User-Objekt
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,  // Hier könnte der Fehler liegen
      username: json['username'] as String,
      password: json['password'] ?? '',  // password könnte fehlen
      role: _parseRole(json['role'] as String),
      isActive: json['is_active'] == 1,
    );
  }

  // Konvertiert User-Objekt zurück in JSON/Datenbank-Format
  // In user_role.dart - Methode toJson() anpassen
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'password': password,
      'role': role.toDatabaseValue(), // Verwende die vordefinierte Methode
      'is_active': isActive ? 1 : 0,
    };
  }
  // Hilfsmethode zum Konvertieren des role-Strings in UserRole enum
  static UserRole _parseRole(String roleStr) {
    switch (roleStr.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'teamlead':
        return UserRole.teamlead;
      case 'technician':
        return UserRole.technician;
      case 'operator':
      default:
        return UserRole.operator;
    }
  }

  // Methode zur Berechtigungsprüfung
  bool hasPermission(String action) {
    return UserPermissions.hasPermission(role, action);
  }

  // Getter für alle Berechtigungen der Rolle
  List<String> get permissions => UserPermissions.getPermissionsForRole(role);
}