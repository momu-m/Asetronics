// maintenance_schedule.dart
// Dieses File enthält die Datenmodelle für den Wartungsplaner

// Definition der möglichen Wartungsintervalle
enum MaintenanceInterval {
  daily,     // Täglich
  weekly,    // Wöchentlich
  monthly,   // Monatlich
  quarterly, // Vierteljährlich
  yearly     // Jährlich
}

// Definition der möglichen Status einer Wartungsaufgabe
enum MaintenanceTaskStatus {
  pending,    // Ausstehend
  inProgress, // In Bearbeitung
  completed,  // Abgeschlossen
  overdue     // Überfällig
}
enum MaintenancePriority {
  low,
  medium,
  high,
  urgent
}
// Hauptklasse für eine Wartungsaufgabe
class MaintenanceTask {
  final String id;
  final String machineId;  // Dies muss immer einen Wert haben
  final String title;
  final String description;
  final MaintenanceInterval interval;
  final Duration estimatedDuration;
  final List<String> requiredTools;
  final List<String> requiredParts;
  MaintenanceTaskStatus status;
  DateTime? lastCompleted;
  DateTime nextDue;
  String? assignedTo;
  List<String>? viewers;
  bool? isPublic;
  String? createdBy;// Ersteller der Aufgabe
  MaintenancePriority priority;  // Neues Feld


  // Konstruktor mit benötigten und optionalen Parametern
  MaintenanceTask({
    required this.id,
    required this.machineId,  // Muss required bleiben
    required this.title,
    required this.description,
    required this.interval,
    required this.estimatedDuration,
    this.requiredTools = const [],
    this.requiredParts = const [],
    this.status = MaintenanceTaskStatus.pending,
    this.lastCompleted,
    required this.nextDue,
    this.assignedTo,
    this.viewers,
    this.isPublic = true,
    this.createdBy,
    this.priority = MaintenancePriority.medium,
  });


  // Erstellt ein MaintenanceTask-Objekt aus JSON-Daten
  factory MaintenanceTask.fromJson(Map<String, dynamic> json) {
    return MaintenanceTask(
      id: json['id']?.toString() ?? '',  // Sicherere Konvertierung
      machineId: json['machine_id']?.toString() ?? '',  // Sicherere Konvertierung
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      interval: MaintenanceInterval.values.firstWhere(
            (e) => e.toString() == json['interval'],
        orElse: () => MaintenanceInterval.monthly,
      ),
      estimatedDuration: Duration(minutes: int.tryParse(json['estimated_duration']?.toString() ?? '0') ?? 0),
      nextDue: DateTime.parse(json['due_date'] ?? DateTime.now().toIso8601String()),
      assignedTo: json['assigned_to']?.toString(),
      status: _parseStatus(json['status']),
      priority: _parsePriority(json['priority']),  // Neue Zeile

    );
  }

  static MaintenancePriority _parsePriority(dynamic priority) {
    if (priority == null) return MaintenancePriority.medium;

    switch(priority.toString().toLowerCase()) {
      case 'low':
        return MaintenancePriority.low;
      case 'high':
        return MaintenancePriority.high;
      case 'urgent':
        return MaintenancePriority.urgent;
      default:
        return MaintenancePriority.medium;
    }
  }
  static MaintenanceTaskStatus _parseStatus(dynamic status) {
    if (status == null) return MaintenanceTaskStatus.pending;

    switch(status.toString().toLowerCase()) {
      case 'in_progress':
        return MaintenanceTaskStatus.inProgress;
      case 'completed':
        return MaintenanceTaskStatus.completed;
      case 'overdue':
        return MaintenanceTaskStatus.overdue;
      default:
        return MaintenanceTaskStatus.pending;
    }
  }

  // Konvertiert das MaintenanceTask-Objekt in JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'machine_id': machineId,
      'title': title,
      'description': description,
      'interval': interval.toString(),
      'estimated_duration': estimatedDuration.inMinutes,
      'required_tools': requiredTools,
      'required_parts': requiredParts,
      'status': status.toString().split('.').last.toLowerCase(),
      'last_completed': lastCompleted?.toIso8601String(),
      'due_date': nextDue.toIso8601String(),
      'assigned_to': assignedTo,
      'is_public': isPublic,
      'created_by': createdBy,
      'priority': priority.toString().split('.').last.toLowerCase(),  // Neue Zeile

    };
  }


  // Berechnet das nächste Fälligkeitsdatum basierend auf dem Intervall
  void calculateNextDueDate() {
    if (lastCompleted == null) return;

    switch (interval) {
      case MaintenanceInterval.daily:
        nextDue = lastCompleted!.add(const Duration(days: 1));
        break;
      case MaintenanceInterval.weekly:
        nextDue = lastCompleted!.add(const Duration(days: 7));
        break;
      case MaintenanceInterval.monthly:
        nextDue = DateTime(
          lastCompleted!.year,
          lastCompleted!.month + 1,
          lastCompleted!.day,
        );
        break;
      case MaintenanceInterval.quarterly:
        nextDue = DateTime(
          lastCompleted!.year,
          lastCompleted!.month + 3,
          lastCompleted!.day,
        );
        break;
      case MaintenanceInterval.yearly:
        nextDue = DateTime(
          lastCompleted!.year + 1,
          lastCompleted!.month,
          lastCompleted!.day,
        );
        break;
    }
  }

  // Prüft ob die Aufgabe überfällig ist
  bool isOverdue() {
    return DateTime.now().isAfter(nextDue);
  }

  // Aktualisiert den Status basierend auf dem aktuellen Datum
  void updateStatus() {
    if (status == MaintenanceTaskStatus.completed) return;

    if (isOverdue()) {
      status = MaintenanceTaskStatus.overdue;
    } else {
      status = MaintenanceTaskStatus.pending;
    }
  }

  // Erstellt eine Kopie der Aufgabe mit aktualisierten Werten
  MaintenanceTask copyWith({
    String? id,
    String? machineId,
    String? title,
    String? description,
    MaintenanceInterval? interval,
    Duration? estimatedDuration,
    List<String>? requiredTools,
    List<String>? requiredParts,
    MaintenanceTaskStatus? status,
    DateTime? lastCompleted,
    DateTime? nextDue,
    String? assignedTo,
    List<String>? viewers,
    bool? isPublic,
    String? createdBy,
  }) {
    return MaintenanceTask(
      id: id ?? this.id,
      machineId: machineId ?? this.machineId,
      title: title ?? this.title,
      description: description ?? this.description,
      interval: interval ?? this.interval,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      requiredTools: requiredTools ?? this.requiredTools,
      requiredParts: requiredParts ?? this.requiredParts,
      status: status ?? this.status,
      lastCompleted: lastCompleted ?? this.lastCompleted,
      nextDue: nextDue ?? this.nextDue,
      assignedTo: assignedTo ?? this.assignedTo,
      viewers: viewers ?? this.viewers,
      isPublic: isPublic ?? this.isPublic,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}