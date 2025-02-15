// lib/services/task_service.dart

import 'package:flutter/foundation.dart';
import '../models/task_model.dart';
import '../models/user_role.dart';
import 'dart:convert';
import '../config/api_config.dart';

class TaskService extends ChangeNotifier {
  // Singleton-Pattern
  static final TaskService _instance = TaskService._internal();
  factory TaskService() => _instance;
  TaskService._internal();

  // Lokaler Cache für Tasks
  List<Task> _tasks = [];
  List<Task> get tasks => List.unmodifiable(_tasks);

  // Cache für Task-Feedback
  final Map<String, List<TaskFeedback>> _feedbackCache = {};

  // Tasks laden
  Future<void> loadTasks() async {
    try {
      final response = await ApiConfig.sendRequest(
        url: ApiConfig.tasksUrl,
        method: 'GET',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _tasks = data.map((json) => Task.fromJson(json)).toList();

        // Sortiere nach Deadline und Priorität
        _tasks.sort((a, b) {
          final priorityCompare = b.priority.index.compareTo(a.priority.index);
          if (priorityCompare != 0) return priorityCompare;
          return a.deadline.compareTo(b.deadline);
        });

        notifyListeners();
      }
    } catch (e) {
      _logError('Fehler beim Laden der Aufgaben', e);
      // Behalte die vorhandenen Tasks im Cache
    }
  }

  // Task erstellen
  Future<bool> createTask(Task task) async {
    try {
      final response = await ApiConfig.sendRequest(
        url: ApiConfig.tasksUrl,
        method: 'POST',
        body: jsonEncode(task.toJson()),
      );

      if (response.statusCode == 201) {
        await loadTasks(); // Aktualisiere die Liste
        return true;
      }
      return false;
    } catch (e) {
      _logError('Fehler beim Erstellen der Aufgabe', e);
      return false;
    }
  }

  // Task aktualisieren
  Future<bool> updateTaskStatus(String taskId, TaskStatus newStatus) async {
    try {
      final response = await ApiConfig.sendRequest(
        url: '${ApiConfig.tasksUrl}/$taskId/status',
        method: 'PATCH',
        body: jsonEncode({'status': newStatus.toString().split('.').last}),
      );

      if (response.statusCode == 200) {
        // Cache aktualisieren
        final taskIndex = _tasks.indexWhere((t) => t.id == taskId);
        if (taskIndex != -1) {
          _tasks[taskIndex] = _tasks[taskIndex].copyWith(status: newStatus);
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      _logError('Fehler beim Aktualisieren des Status', e);
      return false;
    }
  }

  // Feedback hinzufügen
  Future<bool> addFeedback(String taskId, TaskFeedback feedback) async {
    try {
      final response = await ApiConfig.sendRequest(
        url: '${ApiConfig.tasksUrl}/$taskId/feedback',
        method: 'POST',
        body: jsonEncode(feedback.toJson()),
      );

      if (response.statusCode == 201) {
        // Cache aktualisieren
        _feedbackCache[taskId] ??= [];
        _feedbackCache[taskId]!.add(feedback);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _logError('Fehler beim Hinzufügen des Feedbacks', e);
      return false;
    }
  }

  // Bilder zu Task hinzufügen
  Future<bool> addImage(String taskId, String imageUrl) async {
    try {
      final response = await ApiConfig.sendRequest(
        url: '${ApiConfig.tasksUrl}/$taskId/images',
        method: 'POST',
        body: jsonEncode({'imageUrl': imageUrl}),
      );

      if (response.statusCode == 201) {
        // Cache aktualisieren
        final taskIndex = _tasks.indexWhere((t) => t.id == taskId);
        if (taskIndex != -1) {
          final updatedImages = List<String>.from(_tasks[taskIndex].images)..add(imageUrl);
          _tasks[taskIndex] = _tasks[taskIndex].copyWith(images: updatedImages);
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      _logError('Fehler beim Hinzufügen des Bildes', e);
      return false;
    }
  }

  // Berechtigungsprüfung
  bool canUserModifyTask(String userId, UserRole userRole, Task task) {
    if (userRole == UserRole.admin || userRole == UserRole.teamlead) {
      return true;
    }
    if (userRole == UserRole.technician) {
      return task.assignedToId == userId;
    }
    return false;
  }

  // Hilfsmethoden für Listen
  List<Task> getTasksForUser(String userId) {
    return _tasks.where((task) => task.assignedToId == userId).toList();
  }

  List<Task> getOverdueTasks() {
    final now = DateTime.now();
    return _tasks.where((task) =>
    task.status != TaskStatus.completed &&
        task.deadline.isBefore(now)
    ).toList();
  }

  // Logging
  void _logError(String message, Object error) {
    debugPrint('❌ ERROR: $message');
    debugPrint('DETAILS: $error');
  }
}