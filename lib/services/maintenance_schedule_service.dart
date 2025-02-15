// lib/services/maintenance_schedule_service.dart

import 'package:flutter/foundation.dart';
import '../models/maintenance_schedule.dart';
import '../models/user_role.dart';
import 'dart:convert';
import '../config/api_config.dart';

class MaintenanceScheduleService extends ChangeNotifier {
  // Singleton-Pattern
  static final MaintenanceScheduleService _instance = MaintenanceScheduleService._internal();
  factory MaintenanceScheduleService() => _instance;
  MaintenanceScheduleService._internal();

  // Lokaler Cache für Wartungsaufgaben
  List<MaintenanceTask> _tasks = [];
  List<MaintenanceTask> get tasks => List.unmodifiable(_tasks);

  Future<void> initialize() async {
    try {
      await loadTasks();
      print('MaintenanceScheduleService erfolgreich initialisiert');
    } catch (e) {
      print('Fehler bei MaintenanceScheduleService Initialisierung: $e');
      _tasks = []; // Leere Liste als Fallback
    }
  }
  // Cache für zugewiesene Techniker
  final Map<String, User> _technicianCache = {};

  // Lädt alle Wartungsaufgaben
  Future<void> loadTasks() async {
    try {
      final response = await ApiConfig.sendRequest(
        url: '${ApiConfig.baseUrl}/maintenance/tasks',
        method: 'GET',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _tasks = data.map((json) => MaintenanceTask.fromJson(json)).toList();

        // Sortiere nach Priorität und Datum
        _tasks.sort((a, b) {
          final priorityCompare = b.priority.index.compareTo(a.priority.index);
          if (priorityCompare != 0) return priorityCompare;
          return a.nextDue.compareTo(b.nextDue);
        });

        notifyListeners();
      } else {
        throw Exception('Server-Fehler: ${response.statusCode}');
      }
    } catch (e) {
      print('Fehler beim Laden der Aufgaben: $e');
      // Behalte existierende Tasks im Cache
      rethrow;
    }
  }

  final Map<String, String> _machineStatusCache = {};

  Future<List<Map<String, dynamic>>> loadActiveMachines() async {
    try {
      final response = await ApiConfig.sendRequest(
        url: '${ApiConfig.baseUrl}/machines',
        method: 'GET',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final machines = List<Map<String, dynamic>>.from(data);

        // Cache aktualisieren
        for (var machine in machines) {
          _machineStatusCache[machine['id'].toString()] = machine['status'].toString();
        }

        // Nur aktive Maschinen zurückgeben
        return machines.where((m) => m['status'] == 'active').toList();
      }
      throw Exception('Fehler beim Laden der Maschinen');
    } catch (e) {
      print('Fehler beim Laden der Maschinen: $e');
      return [];
    }
  }

  // Hilfsmethode um Maschinenstatus zu prüfen
  bool isMachineActive(String machineId) {
    return _machineStatusCache[machineId] == 'active';
  }

  // Neue Task erstellen mit verbesserter Validierung
  Future<bool> addTask(MaintenanceTask task) async {
    try {
      if (!isMachineActive(task.machineId)) {
        throw Exception('Die ausgewählte Maschine ist nicht aktiv');
      }

      final response = await ApiConfig.sendRequest(
        url: '${ApiConfig.baseUrl}/maintenance/tasks',
        method: 'POST',
        body: jsonEncode(task.toJson()),
      );

      if (response.statusCode == 201) {
        await loadTasks(); // Liste aktualisieren
        return true;
      }
      return false;
    } catch (e) {
      print('Fehler beim Erstellen der Wartungsaufgabe: $e');
      return false;
    }
  }



  // Aktualisiert eine bestehende Wartungsaufgabe
  Future<bool> updateTask(MaintenanceTask task) async {
    try {
      final response = await ApiConfig.sendRequest(
        url: '${ApiConfig.maintenanceUrl}/tasks/${task.id}',
        method: 'PUT',
        body: jsonEncode(task.toJson()),
      );

      if (response.statusCode == 200) {
        // Cache aktualisieren
        final index = _tasks.indexWhere((t) => t.id == task.id);
        if (index != -1) {
          _tasks[index] = task;
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      _logError('Fehler beim Aktualisieren der Wartungsaufgabe', e);
      return false;
    }
  }

  // Markiert eine Aufgabe als abgeschlossen
  Future<bool> completeTask(String taskId) async {
    try {
      final response = await ApiConfig.sendRequest(
        url: '${ApiConfig.maintenanceUrl}/tasks/$taskId/complete',
        method: 'POST',
      );

      if (response.statusCode == 200) {
        await loadTasks(); // Aktualisiere die Liste
        return true;
      }
      return false;
    } catch (e) {
      _logError('Fehler beim Abschließen der Wartungsaufgabe', e);
      return false;
    }
  }

  // Lädt verfügbare Techniker
  Future<List<User>> getAvailableTechnicians() async {
    try {
      final response = await ApiConfig.sendRequest(
        url: '${ApiConfig.usersUrl}?role=technician',
        method: 'GET',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final technicians = data.map((json) => User.fromJson(json)).toList();

        // Cache aktualisieren
        for (var tech in technicians) {
          _technicianCache[tech.id] = tech;
        }

        return technicians;
      }
      return [];
    } catch (e) {
      _logError('Fehler beim Laden der Techniker', e);
      return [];
    }
  }

  // Hilfsmethoden für gefilterte Listen
  List<MaintenanceTask> getTodaysTasks() {
    final now = DateTime.now();
    return _tasks.where((task) {
      final taskDate = DateTime(task.nextDue.year, task.nextDue.month, task.nextDue.day);
      final today = DateTime(now.year, now.month, now.day);
      return taskDate.isAtSameMomentAs(today);
    }).toList();
  }

  List<MaintenanceTask> getOverdueTasks() {
    final now = DateTime.now();
    return _tasks.where((task) =>
    task.status != MaintenanceTaskStatus.completed &&
        task.nextDue.isBefore(now)
    ).toList();
  }

  // Berechnet das nächste Fälligkeitsdatum
  DateTime calculateNextDueDate(MaintenanceInterval interval, DateTime fromDate) {
    switch (interval) {
      case MaintenanceInterval.daily:
        return fromDate.add(const Duration(days: 1));
      case MaintenanceInterval.weekly:
        return fromDate.add(const Duration(days: 7));
      case MaintenanceInterval.monthly:
        return DateTime(fromDate.year, fromDate.month + 1, fromDate.day);
      case MaintenanceInterval.quarterly:
        return DateTime(fromDate.year, fromDate.month + 3, fromDate.day);
      case MaintenanceInterval.yearly:
        return DateTime(fromDate.year + 1, fromDate.month, fromDate.day);
    }
  }

  // Logging
  void _logError(String message, Object error) {
    debugPrint('❌ ERROR: $message');
    debugPrint('DETAILS: $error');
  }
}