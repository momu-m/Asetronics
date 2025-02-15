// problem_model.dart

// Ein Enum für die verschiedenen Problemkategorien
enum ProblemCategory {
  mechanical,    // Mechanische Probleme
  electrical,    // Elektrische Probleme
  software,      // Software Probleme
  process,       // Prozessprobleme
  other          // Sonstige Probleme
}

// Ein Enum für den Status eines Problems
enum ProblemStatus {
  active,        // Problem ist aktiv
  solved,        // Problem wurde gelöst
  inProgress,    // Problem wird bearbeitet
  archived       // Problem wurde archiviert
}

// Hauptklasse für ein Problem in der Datenbank
class Problem {
  final String id;                    // Eindeutige ID des Problems
  final String title;                 // Titel des Problems
  final String description;           // Beschreibung des Problems
  final ProblemCategory category;     // Kategorie des Problems
  final String machineType;           // Typ der betroffenen Maschine
  final List<String> symptoms;        // Liste der Symptome
  final List<String> solutions;       // Liste der Lösungen
  final List<String> relatedParts;    // Betroffene Ersatzteile
  final DateTime createdAt;           // Erstellungsdatum
  final String createdBy;             // Ersteller
  ProblemStatus status;               // Aktueller Status
  int occurrences;                    // Anzahl des Auftretens
  DateTime? lastOccurrence;           // Letztes Auftreten

  // Konstruktor mit benötigten und optionalen Parametern
  Problem({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.machineType,
    this.symptoms = const [],
    this.solutions = const [],
    this.relatedParts = const [],
    required this.createdAt,
    required this.createdBy,
    this.status = ProblemStatus.active,
    this.occurrences = 1,
    this.lastOccurrence,
  });

  // Erstellt ein Problem-Objekt aus JSON-Daten
  factory Problem.fromJson(Map<String, dynamic> json) {
    return Problem(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      category: ProblemCategory.values.firstWhere(
            (e) => e.toString() == 'ProblemCategory.${json['category']}',
      ),
      machineType: json['machineType'] as String,
      symptoms: List<String>.from(json['symptoms'] ?? []),
      solutions: List<String>.from(json['solutions'] ?? []),
      relatedParts: List<String>.from(json['relatedParts'] ?? []),
      createdAt: DateTime.parse(json['createdAt']),
      createdBy: json['createdBy'] as String,
      status: ProblemStatus.values.firstWhere(
            (e) => e.toString() == 'ProblemStatus.${json['status']}',
      ),
      occurrences: json['occurrences'] as int? ?? 1,
      lastOccurrence: json['lastOccurrence'] != null
          ? DateTime.parse(json['lastOccurrence'])
          : null,
    );
  }

  // Konvertiert das Problem-Objekt in JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category.toString().split('.').last,
      'machineType': machineType,
      'symptoms': symptoms,
      'solutions': solutions,
      'relatedParts': relatedParts,
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
      'status': status.toString().split('.').last,
      'occurrences': occurrences,
      'lastOccurrence': lastOccurrence?.toIso8601String(),
    };
  }

  // Erstellt eine Kopie des Problems mit aktualisierten Werten
  Problem copyWith({
    String? id,
    String? title,
    String? description,
    ProblemCategory? category,
    String? machineType,
    List<String>? symptoms,
    List<String>? solutions,
    List<String>? relatedParts,
    DateTime? createdAt,
    String? createdBy,
    ProblemStatus? status,
    int? occurrences,
    DateTime? lastOccurrence,
  }) {
    return Problem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      machineType: machineType ?? this.machineType,
      symptoms: symptoms ?? this.symptoms,
      solutions: solutions ?? this.solutions,
      relatedParts: relatedParts ?? this.relatedParts,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      status: status ?? this.status,
      occurrences: occurrences ?? this.occurrences,
      lastOccurrence: lastOccurrence ?? this.lastOccurrence,
    );
  }
}