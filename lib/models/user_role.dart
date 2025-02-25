// user_role.dart
import 'package:flutter/foundation.dart';

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
    switch (role) {
      case UserRole.admin:
        return 'Administrator';
      case UserRole.teamlead:
        return 'Teamleiter';
      case UserRole.technician:
        return 'Techniker';
      case UserRole.operator:
        return 'Bediener';
    }
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
  final String id;
  final String username;
  final String password;
  final UserRole role;
  final bool isActive;

  // Neue Attribute für den Profilbereich
  final String? fullName;         // Vollständiger Name
  final String? email;            // E-Mail-Adresse
  final String? phone;            // Telefonnummer
  final String? department;       // Abteilung
  final String? profileImageUrl;  // URL zum Profilbild
  final String? profileImageBase64; // Base64-kodiertes Profilbild (für Offline)
  final DateTime? lastLogin;      // Letzter Login-Zeitpunkt
  final Map<String, dynamic>? preferences; // Benutzerpräferenzen

  const User({
    required this.id,
    required this.username,
    required this.password,
    required this.role,
    this.isActive = true,
    this.fullName,
    this.email,
    this.phone,
    this.department,
    this.profileImageUrl,
    this.profileImageBase64,
    this.lastLogin,
    this.preferences,
  });

  User copyWith({
    String? id,
    String? username,
    String? password,
    UserRole? role,
    bool? isActive,
    String? fullName,
    String? email,
    String? phone,
    String? department,
    String? profileImageUrl,
    String? profileImageBase64,
    DateTime? lastLogin,
    Map<String, dynamic>? preferences,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      password: password ?? this.password,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      department: department ?? this.department,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      profileImageBase64: profileImageBase64 ?? this.profileImageBase64,
      lastLogin: lastLogin ?? this.lastLogin,
      preferences: preferences ?? this.preferences,
    );
  }

  // Konvertiert den Benutzer von JSON
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'].toString(),
      username: json['username'] as String,
      password: json['password'] as String? ?? '',
      role: _parseRole(json['role']),
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      fullName: json['full_name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      department: json['department'] as String?,
      profileImageUrl: json['profile_image_url'] as String?,
      profileImageBase64: json['profile_image_base64'] as String?,
      lastLogin: json['last_login'] != null
          ? DateTime.parse(json['last_login'])
          : null,
      preferences: json['preferences'] != null
          ? Map<String, dynamic>.from(json['preferences'])
          : null,
    );
  }

  // Konvertiert den Benutzer zu JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'password': password,
      'role': role.toString().split('.').last,
      'is_active': isActive ? 1 : 0,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'department': department,
      'profile_image_url': profileImageUrl,
      'profile_image_base64': profileImageBase64,
      'last_login': lastLogin?.toIso8601String(),
      'preferences': preferences,
    };
  }


  // Prüft, ob der Benutzer eine bestimmte Berechtigung hat
  bool hasPermission(String permission) {
    switch (permission) {
      case 'create_error_reports':
        return true; // Alle Benutzer können Fehler melden
      case 'view_all_reports':
        return role == UserRole.admin || role == UserRole.teamlead;
      case 'manage_maintenance':
        return role == UserRole.admin || role == UserRole.teamlead;
      case 'manage_users':
        return role == UserRole.admin;
      default:
        return false;
    }
  }

  // Hilfsmethode zum Parsen der Rolle
  static UserRole _parseRole(dynamic roleValue) {
    if (roleValue is UserRole) return roleValue;

    final roleStr = roleValue.toString().toLowerCase();
    switch (roleStr) {
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




  // Getter für alle Berechtigungen der Rolle
  List<String> get permissions => UserPermissions.getPermissionsForRole(role);
}