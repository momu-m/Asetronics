// services/task_assignment_service.dart

import 'package:flutter/foundation.dart';
import '../models/task_model.dart';
import '../models/user_role.dart';
import '../main.dart' show databaseService, userService, notificationService;
import 'email_notification_service.dart';

// TaskAssignmentService verwaltet die Zuweisung von Aufgaben
class TaskAssignmentService extends ChangeNotifier {
  // Singleton-Pattern: Stellt sicher, dass nur eine Instanz existiert
  static final TaskAssignmentService _instance =
      TaskAssignmentService._internal();
  factory TaskAssignmentService() => _instance;
  TaskAssignmentService._internal();

  // Private Liste für zugewiesene Aufgaben
  final List<Task> _assignedTasks = [];

  // Öffentlicher Getter für die Aufgaben
  List<Task> get assignedTasks => List.unmodifiable(_assignedTasks);

  // Weist einem Benutzer eine Aufgabe zu Hauptfunktionen

  Future<void> assignTask(Task task, String userId) async {
    try {
      // Prüfe ob der zuweisende Benutzer die Berechtigung hat
      final currentUser = userService.currentUser;
      if (currentUser == null ||
          !(currentUser.role == UserRole.admin ||
              currentUser.role == UserRole.teamlead)) {
        throw Exception('Keine Berechtigung zum Zuweisen von Aufgaben');
      }

      // Aktualisiere die Aufgabe mit der Zuweisung
      final updatedTask =
          task.copyWith(assignedToId: userId, status: TaskStatus.pending);

      // Speichere die Änderung in der Datenbank
      await databaseService.updateTask(updatedTask.toJson());

      // Sende eine Benachrichtigung
      await notificationService.showErrorNotification('Neue Aufgabe',
          'Ihnen wurde eine neue Aufgabe zugewiesen: ${task.title}');

      // E-Mail-Benachrichtigung senden
      // E-Mail-Benachrichtigung senden
      try {
        final emailService = EmailNotificationService();

        // Prüfe die E-Mail-Benachrichtigungseinstellungen des Benutzers
        final prefs = await emailService.loadPreferences(userId);

        // Sende nur eine E-Mail, wenn der Benutzer E-Mail-Benachrichtigungen aktiviert hat
        if (prefs['email_enabled'] == true && prefs['task_notify'] == true) {
          await emailService.sendTaskNotification(task.id, userId);
          print('E-Mail-Benachrichtigung für Aufgabe ${task.id} an Benutzer $userId gesendet');
        }
      } catch (e) {
        print('Fehler beim Senden der E-Mail-Benachrichtigung: $e');
        // Wir werfen keine Exception, da der Hauptprozess nicht unterbrochen werden soll
      }

      // Aktualisiere die lokale Liste
      final index = _assignedTasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        _assignedTasks[index] = updatedTask;
      } else {
        _assignedTasks.add(updatedTask);
      }

      notifyListeners();
    } catch (e) {
      print('Fehler beim Zuweisen der Aufgabe: $e');
      rethrow;
    }
  }

  // Lädt alle zugewiesenen Aufgaben für einen Benutzer Hilfsfunktionen
  Future<List<Task>> getTasksForUser(String userId) async {
    try {
      final tasks = await databaseService.getTasks();
      return tasks
          .where((task) => task['assignedToId'] == userId)
          .map((json) => Task.fromJson(json))
          .toList();
    } catch (e) {
      print('Fehler beim Laden der Aufgaben: $e');
      return [];
    }
  }

  // Prüft ob ein Benutzer eine bestimmte Aufgabe zugewiesen bekommen kann
  bool canAssignTaskToUser(User user, Task task) {
    // Techniker können nur bestimmte Aufgabentypen bekommen
    if (user.role == UserRole.technician) {
      return task.priority != TaskPriority.urgent ||
          task.status != TaskStatus.blocked;
    }
    return true;
  }

  // Lädt alle verfügbaren Techniker
  Future<List<User>> getAvailableTechnicians() async {
    try {
      return await userService.getUsersByRole(UserRole.technician);
    } catch (e) {
      print('Fehler beim Laden der Techniker: $e');
      return [];
    }
  }
}
