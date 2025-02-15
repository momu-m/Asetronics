// improved_task_service.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import '../../../models/maintenance_schedule.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ImprovedTaskService extends ChangeNotifier {
  static const String _apiUrl = 'http://192.168.1.21:5004/api';

  // Status-Mapping für korrekte Datenbankwerte
  static const Map<MaintenanceTaskStatus, String> _statusMapping = {
    MaintenanceTaskStatus.pending: 'pending',
    MaintenanceTaskStatus.inProgress: 'in_progress',  // Korrigiert
    MaintenanceTaskStatus.completed: 'completed',
    MaintenanceTaskStatus.overdue: 'overdue'
  };

  // Cache für Tasks
  List<MaintenanceTask> _tasks = [];

  // Getter für Tasks mit automatischer Statusaktualisierung
  List<MaintenanceTask> get tasks {
    _updateTaskStatuses();
    return List.unmodifiable(_tasks);
  }

  // Aktualisiert die Status basierend auf Fälligkeitsdatum
  void _updateTaskStatuses() {
    final now = DateTime.now();
    for (var task in _tasks) {
      if (task.status != MaintenanceTaskStatus.completed) {
        if (task.nextDue.isBefore(now)) {
          task.status = MaintenanceTaskStatus.overdue;
        }
      }
    }
  }

  // Lädt Tasks mit verbesserter Fehlerbehandlung
  Future<void> loadTasks() async {
    try {
      final response = await http.get(
        Uri.parse('$_apiUrl/maintenance/tasks'),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Verbindung zum Server fehlgeschlagen'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _tasks = data.map((json) => MaintenanceTask.fromJson(json)).toList();

        // Sortiere nach Priorität und Datum
        _tasks.sort((a, b) {
          if (a.priority != b.priority) {
            return b.priority.index.compareTo(a.priority.index);
          }
          return a.nextDue.compareTo(b.nextDue);
        });

        notifyListeners();
      } else {
        throw HttpException('Fehler beim Laden: ${response.statusCode}');
      }
    } catch (e) {
      print('Task Ladefehler: $e');
      rethrow;
    }
  }

  // Aktualisiert einen Task mit korrektem Status-Mapping
  Future<void> updateTask(MaintenanceTask task) async {
    try {
      final taskData = {
        'id': task.id,
        'title': task.title,
        'description': task.description,
        'machine_id': task.machineId,
        'assigned_to': task.assignedTo,
        'due_date': task.nextDue.toIso8601String(),
        'status': _statusMapping[task.status], // Korrektes Status-Mapping
        'priority': task.priority.toString().split('.').last.toLowerCase(),
      };

      final response = await http.put(
        Uri.parse('$_apiUrl/maintenance/tasks/${task.id}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(taskData),
      );

      if (response.statusCode == 200) {
        await loadTasks();
      } else {
        throw HttpException('Update fehlgeschlagen: ${response.body}');
      }
    } catch (e) {
      print('Task Update Fehler: $e');
      rethrow;
    }
  }

  // Intelligente Task-Filterung
  List<MaintenanceTask> getFilteredTasks({
    MaintenanceTaskStatus? status,
    String? machineId,
    String? assignedTo,
    bool includeOverdue = true,
    int? daysAhead,
  }) {
    return _tasks.where((task) {
      if (status != null && task.status != status) return false;
      if (machineId != null && task.machineId != machineId) return false;
      if (assignedTo != null && task.assignedTo != assignedTo) return false;

      if (!includeOverdue && task.status == MaintenanceTaskStatus.overdue) {
        return false;
      }

      if (daysAhead != null) {
        final deadline = DateTime.now().add(Duration(days: daysAhead));
        if (task.nextDue.isAfter(deadline)) return false;
      }

      return true;
    }).toList();
  }

  // Task-Statistiken
  Map<String, dynamic> getTaskStatistics() {
    return {
      'total': _tasks.length,
      'pending': _tasks.where((t) => t.status == MaintenanceTaskStatus.pending).length,
      'inProgress': _tasks.where((t) => t.status == MaintenanceTaskStatus.inProgress).length,
      'completed': _tasks.where((t) => t.status == MaintenanceTaskStatus.completed).length,
      'overdue': _tasks.where((t) => t.status == MaintenanceTaskStatus.overdue).length,
      'urgent': _tasks.where((t) => t.priority == MaintenancePriority.urgent).length,
      'averageCompletionTime': _calculateAverageCompletionTime(),
    };
  }

  // Berechnet durchschnittliche Bearbeitungszeit
  Duration _calculateAverageCompletionTime() {
    final completedTasks = _tasks.where((t) =>
    t.status == MaintenanceTaskStatus.completed &&
        t.lastCompleted != null
    ).toList();

    if (completedTasks.isEmpty) return Duration.zero;

    final totalDuration = completedTasks.fold<Duration>(
        Duration.zero,
            (total, task) => total + task.nextDue.difference(task.lastCompleted!)
    );

    return Duration(
        milliseconds: totalDuration.inMilliseconds ~/ completedTasks.length
    );
  }
}