// database_service.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'package:universal_html/html.dart' as html;
import 'dart:convert';
import 'mysql_service.dart';

/// Ein Service für alle Datenbankoperationen der App.
class DatabaseService {
  final _mysql = MySQLService();
  // Singleton-Pattern Implementation
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  // Datenbank-Eigenschaften
  static Database? _database;
  static bool _initialized = false;
  static bool _useFallback = false;

  // Konstanten für localStorage Keys
  static const String USERS_KEY = 'users';
  static const String ERROR_REPORTS_KEY = 'errorReports';
  static const String MAINTENANCE_REPORTS_KEY = 'maintenanceReports';
  static const String MACHINES_KEY = 'machines';
  static const String MAINTENANCE_TASKS_KEY = 'maintenanceTasks';

  /// Initialisiert die Datenbank
  Future<void> initialize() async {
    await _mysql.connect();
    await _initializeAdminUser();
    if (_initialized) return;

    if (kIsWeb) {
      try {
        var factory = databaseFactoryFfiWeb;
        databaseFactory = factory;

        _database = await factory.openDatabase(
          'wartungs_app.db',
          options: OpenDatabaseOptions(
            version: 1,
            onCreate: _createTables,
            singleInstance: true,
          ),
        );

        _initialized = true;
        _useFallback = false;
        print('SQLite Datenbank erfolgreich initialisiert');
        await initializeAdminUser();
        await initializeMachines();
        await initializeTasks(); // Diese Zeile hinzufügen
      } catch (e) {
        print('SQLite Initialisierung fehlgeschlagen: $e');
        _useFallback = true;
        _initialized = true;
        await initializeAdminUser();
        await initializeMachines();
        await initializeTasks(); // Diese Zeile hinzufügen
      }
    }
  }
  Future<void> initializeMachines() async {
    try {
      final machines = await getMachines();
      if (machines.isEmpty) {
        // Test-Maschinen aus Ihrer Anlagenübersicht
        final testMachines = [
          {
            'id': '1',
            'name': 'Bestücker 1',
            'type': 'SIPLACE SX2',
            'serialNumber': 'M538G-12041572',
            'line': 'X-Linie',
            'location': 'Produktion',
            'status': 'active',
            'last_maintenance': DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
          },
          {
            'id': '2',
            'name': 'Reflowofen',
            'type': 'Rehm VXP+nitro 3855',
            'serialNumber': '4043',
            'line': 'X-Linie',
            'location': 'Produktion',
            'status': 'active',
            'last_maintenance': DateTime.now().subtract(const Duration(days: 15)).toIso8601String(),
          },
        ];

        for (final machine in testMachines) {
          await saveMachine(machine);
        }
        print('Test-Maschinen erfolgreich initialisiert');
      }
    } catch (e) {
      print('Fehler bei der Maschinen-Initialisierung: $e');
    }
  }
  /// Initialisiert den Admin-Benutzer falls noch keiner existiert

  Future<void> _initializeAdminUser() async {
    final users = await _mysql.query('SELECT * FROM users');
    if (users.isEmpty) {
      await _mysql.query('''
        INSERT INTO users 
        (id, name, username, password, role, department, created_at, is_active) 
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''', [
        'admin-1',
        'Administrator',
        'admin',
        'admin',
        'admin',
        'IT',
        DateTime.now().toIso8601String(),
        1
      ]);
    }
  }
  Future<void> initializeAdminUser() async {
    try {
      final users = await getUsers(); // Async Aufruf
      if (users.isEmpty) {
        await saveUser({
          'id': 'admin-${DateTime.now().millisecondsSinceEpoch}',
          'name': 'Administrator',
          'username': 'admin',
          'password': 'admin',
          'role': 'admin',
          'department': 'IT',
          'created_at': DateTime.now().toIso8601String(),
          'is_active': true,
        });
        await saveUser({
          'id': 'tech-${DateTime.now().millisecondsSinceEpoch}',
          'name': 'Test Techniker',
          'username': 'techniker',
          'password': 'techniker',
          'role': 'technician',
          'department': 'Service',
          'created_at': DateTime.now().toIso8601String(),
          'is_active': true,
        });
        print('Admin-Benutzer erfolgreich erstellt');
      }
    } catch (e) {
      print('Fehler beim Erstellen des Admin-Benutzers: $e');
    }
  }
  // ================ BENUTZER-OPERATIONEN ================

  /// Speichert einen neuen Benutzer
  Future<void> saveUser(Map<String, dynamic> user) async {
    try {
      // Konvertiere preferences zu JSON-String, falls vorhanden
      if (user.containsKey('preferences') && user['preferences'] != null) {
        user['preferences'] = jsonEncode(user['preferences']);
      }

      if (!_useFallback && _database != null) {
        await _database!.insert('users', user);
        print('Benutzer in SQLite gespeichert: ${user['name']}');
      } else {
        final users = await getUsers(); // Async Aufruf
        users.add(user);
        await saveToLocalStorage(USERS_KEY, users);
        print('Benutzer in localStorage gespeichert: ${user['name']}');
      }
    } catch (e) {
      print('Fehler beim Speichern des Benutzers: $e');
      rethrow;
    }
  }

  /// Aktualisiert einen bestehenden Benutzer
  Future<void> updateUser(Map<String, dynamic> user) async {
    try {
      // Konvertiere preferences zu JSON-String, falls vorhanden
      if (user.containsKey('preferences') && user['preferences'] != null) {
        user['preferences'] = jsonEncode(user['preferences']);
      }

      if (!_useFallback && _database != null) {
        await _database!.update(
          'users',
          user,
          where: 'id = ?',
          whereArgs: [user['id']],
        );
      } else {
        final users = await getUsers(); // Async Aufruf
        final index = users.indexWhere((u) => u['id'] == user['id']);
        if (index != -1) {
          users[index] = user;
          await saveToLocalStorage(USERS_KEY, users);
        } else {
          throw Exception('Benutzer nicht gefunden');
        }
      }
    } catch (e) {
      print('Fehler beim Aktualisieren des Benutzers: $e');
      rethrow;
    }
  }

  /// Ruft alle Benutzer ab
  Future<List<Map<String, dynamic>>> getUsers() async {
    try {
      List<Map<String, dynamic>> users;

      if (!_useFallback && _database != null) {
        final result = await _database!.query('users');
        users = List<Map<String, dynamic>>.from(result);
      } else {
        users = getFromLocalStorage(USERS_KEY);
      }

      // Konvertiere preferences zurück zu Objekten
      for (var user in users) {
        if (user.containsKey('preferences') && user['preferences'] is String) {
          try {
            user['preferences'] = jsonDecode(user['preferences']);
          } catch (e) {
            print('Fehler beim Dekodieren der Benutzereinstellungen: $e');
            user['preferences'] = null;
          }
        }
      }

      return users;
    } catch (e) {
      print('Fehler beim Laden der Benutzer: $e');
      return [];
    }
  }

  /// Authentifiziert einen Benutzer
  Future<Map<String, dynamic>?> loginUser(String username, String password) async {
    try {
      if (!_useFallback && _database != null) {
        final results = await _database!.query(
          'users',
          where: 'username = %s AND password = %s AND is_active = 1',
          whereArgs: [username, password],
        );
        return results.isNotEmpty ? results.first : null;
      } else {
        final users = await getUsers(); // Async Aufruf
        return users.firstWhere(
              (user) =>
          user['username'] == username &&
              user['password'] == password &&
              user['isActive'] != false,
          orElse: () => throw Exception('Benutzer nicht gefunden'),
        );
      }
    } catch (e) {
      print('Fehler beim Login: $e');
      return null;
    }
  }

  /// Deaktiviert einen Benutzer (Soft Delete)
  Future<void> deactivateUser(String userId) async {
    try {
      if (!_useFallback && _database != null) {
        await _database!.update(
          'users',
          {'is_active': 0},
          where: 'id = %s',
          whereArgs: [userId],
        );
      } else {
        final users = await getUsers(); // Async Aufruf
        final index = users.indexWhere((u) => u['id'] == userId);
        if (index != -1) {
          users[index]['isActive'] = false;
          await saveToLocalStorage(USERS_KEY, users);
        }
      }
    } catch (e) {
      print('Fehler beim Deaktivieren des Benutzers: $e');
      rethrow;
    }
  }
  // ================ FEHLERMELDUNGS-OPERATIONEN ================

  /// Speichert eine neue Fehlermeldung
  Future<void> saveErrorReport(Map<String, dynamic> report) async {
    try {
      if (!_useFallback && _database != null) {
        await _database!.insert('error_reports', report);
      } else {
        final reports = await getErrorReports(); // Async Aufruf
        reports.add(report);
        await saveToLocalStorage(ERROR_REPORTS_KEY, reports);
      }
    } catch (e) {
      print('Fehler beim Speichern der Fehlermeldung: $e');
      rethrow;
    }
  }

  /// Ruft alle Fehlermeldungen ab
  Future<List<Map<String, dynamic>>> getErrorReports() async {
    try {
      if (!_useFallback && _database != null) {
        final result = await _database!.query('error_reports');
        return List<Map<String, dynamic>>.from(result);
      } else {
        return getFromLocalStorage(ERROR_REPORTS_KEY);
      }
    } catch (e) {
      print('Fehler beim Laden der Fehlermeldungen: $e');
      return [];
    }
  }

  // ================ WARTUNGSBERICHTS-OPERATIONEN ================

  /// Speichert einen neuen Wartungsbericht
  Future<void> saveMaintenanceReport(Map<String, dynamic> report) async {
    try {
      if (!_useFallback && _database != null) {
        await _database!.insert('maintenance_reports', report);
      } else {
        final reports = await getMaintenanceReports(); // Async Aufruf
        reports.add(report);
        await saveToLocalStorage(MAINTENANCE_REPORTS_KEY, reports);
      }
    } catch (e) {
      print('Fehler beim Speichern des Wartungsberichts: $e');
      rethrow;
    }
  }

  /// Ruft alle Wartungsberichte ab
  Future<List<Map<String, dynamic>>> getMaintenanceReports() async {
    try {
      if (!_useFallback && _database != null) {
        final result = await _database!.query('maintenance_reports');
        return List<Map<String, dynamic>>.from(result);
      } else {
        return getFromLocalStorage(MAINTENANCE_REPORTS_KEY);
      }
    } catch (e) {
      print('Fehler beim Laden der Wartungsberichte: $e');
      return [];
    }
  }

  // ================ MASCHINEN-OPERATIONEN ================

  /// Speichert eine neue Maschine
  Future<void> saveMachine(Map<String, dynamic> machine) async {
    try {
      if (!_useFallback && _database != null) {
        await _database!.insert('machines', machine);
      } else {
        final machines = await getMachines(); // Async Aufruf
        machines.add(machine);
        await saveToLocalStorage(MACHINES_KEY, machines);
      }
    } catch (e) {
      print('Fehler beim Speichern der Maschine: $e');
      rethrow;
    }
  }

  /// Ruft alle Maschinen ab
  Future<List<Map<String, dynamic>>> getMachines() async {
    try {
      if (!_useFallback && _database != null) {
        final result = await _database!.query('machines');
        return List<Map<String, dynamic>>.from(result);
      } else {
        return getFromLocalStorage(MACHINES_KEY);
      }
    } catch (e) {
      print('Fehler beim Laden der Maschinen: $e');
      return [];
    }
  }

  // ================ AUFGABEN-OPERATIONEN ================

  /// Speichert eine neue Aufgabe
  Future<void> saveTask(Map<String, dynamic> task) async {
    try {
      if (!_useFallback && _database != null) {
        await _database!.insert('maintenance_tasks', task);
      } else {
        final tasks = await getTasks(); // Async Aufruf
        tasks.add(task);
        await saveToLocalStorage(MAINTENANCE_TASKS_KEY, tasks);
      }
    } catch (e) {
      print('Fehler beim Speichern der Aufgabe: $e');
      rethrow;
    }
  }

  /// Aktualisiert eine bestehende Aufgabe
  Future<void> updateTask(Map<String, dynamic> task) async {
    try {
      if (!_useFallback && _database != null) {
        await _database!.update(
          'maintenance_tasks',
          task,
          where: 'id = ?',
          whereArgs: [task['id']],
        );
      } else {
        final tasks = await getTasks(); // Async Aufruf
        final index = tasks.indexWhere((t) => t['id'] == task['id']);
        if (index != -1) {
          tasks[index] = task;
          await saveToLocalStorage(MAINTENANCE_TASKS_KEY, tasks);
        }
      }
    } catch (e) {
      print('Fehler beim Aktualisieren der Aufgabe: $e');
      rethrow;
    }
  }

  /// Ruft alle Aufgaben ab
  Future<List<Map<String, dynamic>>> getTasks() async {
    try {
      if (!_useFallback && _database != null) {
        final result = await _database!.query('maintenance_tasks');
        return List<Map<String, dynamic>>.from(result);
      } else {
        return getFromLocalStorage(MAINTENANCE_TASKS_KEY);
      }
    } catch (e) {
      print('Fehler beim Laden der Aufgaben: $e');
      return [];
    }
  }

  /// Löscht eine Aufgabe
  Future<void> deleteTask(String taskId) async {
    try {
      if (!_useFallback && _database != null) {
        await _database!.delete(
          'maintenance_tasks',
          where: 'id = ?',
          whereArgs: [taskId],
        );
      } else {
        final tasks = await getTasks(); // Async Aufruf
        tasks.removeWhere((task) => task['id'] == taskId);
        await saveToLocalStorage(MAINTENANCE_TASKS_KEY, tasks);
      }
    } catch (e) {
      print('Fehler beim Löschen der Aufgabe: $e');
      rethrow;
    }
  }
  // ================ HILFS-METHODEN ================

  /// Speichert Daten im localStorage
  Future<void> saveToLocalStorage(String key, List<dynamic> data) async {
    try {
      if (kIsWeb) {
        html.window.localStorage[key] = jsonEncode(data);
        print('Daten erfolgreich in localStorage gespeichert: $key');
      }
    } catch (e) {
      print('Fehler beim Speichern im localStorage: $e');
      rethrow;
    }
  }

  /// Liest Daten aus dem localStorage
  List<Map<String, dynamic>> getFromLocalStorage(String key) {
    try {
      if (kIsWeb) {
        final String? jsonData = html.window.localStorage[key];
        if (jsonData == null) return [];
        final List<dynamic> decoded = jsonDecode(jsonData);
        return List<Map<String, dynamic>>.from(
            decoded.map((x) => Map<String, dynamic>.from(x))
        );
      }
      return [];
    } catch (e) {
      print('Fehler beim Laden aus localStorage: $e');
      return [];
    }
  }

  /// Löscht alle Daten
  Future<void> clearAllData() async {
    if (!_useFallback && _database != null) {
      await _database!.delete('users');
      await _database!.delete('error_reports');
      await _database!.delete('maintenance_reports');
      await _database!.delete('machines');
      await _database!.delete('maintenance_tasks');
    } else {
      html.window.localStorage.clear();
    }
  }

  /// Erstellt die Datenbanktabellen
  Future<void> _createTables(Database db, int version) async {
    // Benutzer-Tabelle mit erweiterten Feldern
    await db.execute('''
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      username TEXT NOT NULL UNIQUE,
      password TEXT NOT NULL,
      role TEXT NOT NULL,
      department TEXT,
      created_at TEXT NOT NULL,
      created_by TEXT,
      is_active INTEGER DEFAULT 1,
      full_name TEXT,
      email TEXT,
      phone TEXT,
      profile_image_url TEXT,
      profile_image_base64 TEXT,
      last_login TEXT,
      preferences TEXT
    )
  ''');

    // Fehlermeldungen-Tabelle
    await db.execute('''
      CREATE TABLE IF NOT EXISTS error_reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        machine_type TEXT,
        location TEXT,
        description TEXT,
        is_urgent BOOLEAN,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        created_by TEXT
      )
    ''');

    // Wartungsberichte-Tabelle
    await db.execute('''
      CREATE TABLE IF NOT EXISTS maintenance_reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        machine_type TEXT,
        description TEXT,
        worked_time INTEGER,
        parts_used TEXT,
        date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        created_by TEXT
      )
    ''');

    // Aufgaben-Tabelle
    await db.execute('''
      CREATE TABLE IF NOT EXISTS maintenance_tasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        machine_id TEXT,
        status TEXT NOT NULL,
        priority TEXT,
        due_date TEXT,
        assigned_to TEXT,
        created_at TEXT NOT NULL,
        created_by TEXT,
        completed_at TEXT
      )
    ''');

    // Maschinen-Tabelle
    await db.execute('''
      CREATE TABLE IF NOT EXISTS machines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        location TEXT,
        status TEXT NOT NULL,
        last_maintenance TEXT,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> initializeTasks() async {
    try {
      final tasks = await getTasks();
      if (tasks.isEmpty) {
        // Test-Aufgaben erstellen
        final testTasks = [
          {
            'id': '1',
            'title': 'Wartung Bestücker',
            'description': 'Monatliche Routinewartung durchführen',
            'machine_id': '1',
            'status': 'pending',
            'priority': 'high',
            'due_date': DateTime.now().add(const Duration(days: 3)).toIso8601String(), // Geändert von deadline zu due_date
            'assigned_to': null,
            'created_at': DateTime.now().toIso8601String(),
            'created_by': 'admin',
            'completed_at': null
          },
          {
            'id': '2',
            'title': 'Reflowofen kalibrieren',
            'description': 'Temperaturprofile überprüfen und anpassen',
            'machine_id': '2',
            'status': 'pending',
            'priority': 'medium',
            'due_date': DateTime.now().add(const Duration(days: 5)).toIso8601String(), // Geändert von deadline zu due_date
            'assigned_to': null,
            'created_at': DateTime.now().toIso8601String(),
            'created_by': 'admin',
            'completed_at': null
          },
        ];

        for (final task in testTasks) {
          await saveTask(task);
        }
        print('Test-Aufgaben erfolgreich erstellt');
      }
    } catch (e) {
      print('Fehler bei Task-Initialisierung: $e');
    }
  }
}