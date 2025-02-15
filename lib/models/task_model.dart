// task_model.dart

import 'package:flutter/foundation.dart';

// Aufgabenprioritäten
enum TaskPriority {
  low,        // Niedrige Priorität
  medium,     // Mittlere Priorität
  high,       // Hohe Priorität
  urgent, normal      // Dringend
}

// Status einer Aufgabe
enum TaskStatus {
  pending,     // Ausstehend
  in_progress,  // In Bearbeitung
  completed,   // Abgeschlossen
  blocked      // Blockiert
}

// Hauptklasse für eine Aufgabe
class Task {
  final String id;               // Eindeutige ID der Aufgabe
  final String title;           // Titel der Aufgabe
  final String description;     // Beschreibung der Aufgabe
  final String assignedToId;    // ID des zugewiesenen Technikers
  final String createdById;     // ID des Erstellers (Teamleiter)
  final DateTime createdAt;     // Erstellungszeitpunkt
  final DateTime deadline;      // Deadline der Aufgabe
  final TaskPriority priority;  // Priorität der Aufgabe
  TaskStatus status;           // Aktueller Status
  List<String> images;         // Liste von Bild-URLs
  List<TaskFeedback> feedback; // Liste von Rückmeldungen

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.assignedToId,
    required this.createdById,
    required this.createdAt,
    required this.deadline,
    this.priority = TaskPriority.medium,
    this.status = TaskStatus.pending,
    this.images = const [],
    this.feedback = const [],
  });

  // Erstellt ein Task-Objekt aus JSON-Daten
  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      assignedToId: json['assignedToId'] as String,
      createdById: json['createdById'] as String,
      createdAt: DateTime.parse(json['createdAt']),
      deadline: DateTime.parse(json['deadline']),
      priority: TaskPriority.values.firstWhere(
            (e) => e.toString() == 'TaskPriority.${json['priority']}',
      ),
      status: TaskStatus.values.firstWhere(
            (e) => e.toString() == 'TaskStatus.${json['status']}',
      ),
      images: List<String>.from(json['images'] ?? []),
      feedback: (json['feedback'] as List<dynamic>? ?? [])
          .map((f) => TaskFeedback.fromJson(f))
          .toList(),
    );
  }

  // Konvertiert das Task-Objekt in JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'assignedToId': assignedToId,
      'createdById': createdById,
      'createdAt': createdAt.toIso8601String(),
      'deadline': deadline.toIso8601String(),
      'priority': priority.toString().split('.').last,
      'status': status.toString().split('.').last,
      'images': images,
      'feedback': feedback.map((f) => f.toJson()).toList(),
    };
  }

  // Erstellt eine Kopie mit aktualisierten Werten
  Task copyWith({
    String? title,
    String? description,
    String? assignedToId,
    DateTime? deadline,
    TaskPriority? priority,
    TaskStatus? status,
    List<String>? images,
    List<TaskFeedback>? feedback,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      assignedToId: assignedToId ?? this.assignedToId,
      createdById: createdById,
      createdAt: createdAt,
      deadline: deadline ?? this.deadline,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      images: images ?? this.images,
      feedback: feedback ?? this.feedback,
    );
  }
}

// Klasse für Rückmeldungen zu einer Aufgabe
class TaskFeedback {
  final String id;
  final String userId;     // ID des Benutzers der die Rückmeldung gibt
  final String message;    // Nachricht
  final DateTime createdAt; // Zeitpunkt der Erstellung
  final List<String> images; // Optionale Bilder zur Rückmeldung

  TaskFeedback({
    required this.id,
    required this.userId,
    required this.message,
    required this.createdAt,
    this.images = const [],
  });

  // Erstellt ein TaskFeedback-Objekt aus JSON
  factory TaskFeedback.fromJson(Map<String, dynamic> json) {
    return TaskFeedback(
      id: json['id'] as String,
      userId: json['userId'] as String,
      message: json['message'] as String,
      createdAt: DateTime.parse(json['createdAt']),
      images: List<String>.from(json['images'] ?? []),
    );
  }

  // Konvertiert das TaskFeedback-Objekt in JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'message': message,
      'createdAt': createdAt.toIso8601String(),
      'images': images,
    };
  }
}