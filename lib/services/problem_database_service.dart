// problem_database_service.dart
import 'package:flutter/foundation.dart';
import '../models/problem_model.dart';
import '../main.dart' show databaseService;
import '../utils/error_logger.dart';

class ProblemDatabaseService extends ChangeNotifier {
  // Singleton-Pattern Implementation
  static final ProblemDatabaseService _instance = ProblemDatabaseService._internal();
  factory ProblemDatabaseService() => _instance;
  ProblemDatabaseService._internal();

  // Private Liste für die Probleme
  List<Problem> _problems = [];

  // Öffentlicher Getter für die Probleme
  List<Problem> get problems => List.unmodifiable(_problems);

  // Konstante für den localStorage Key
  static const String PROBLEMS_KEY = 'problems';

  // Initialisierung des Services
  Future<void> initialize() async {
    try {
      await loadProblems();
      print('ProblemDatabaseService erfolgreich initialisiert');
    } catch (e, stackTrace) {
      ErrorLogger.logError('ProblemDatabaseService.initialize', e, stackTrace);
      _problems = [];
    }
  }

  // Lädt alle Probleme aus der Datenbank
  Future<void> loadProblems() async {
    try {
      final problemsData = await databaseService.getFromLocalStorage(PROBLEMS_KEY);
      _problems = problemsData.map((json) => Problem.fromJson(json)).toList();

      // Sortiere nach letztem Auftreten, neueste zuerst
      _problems.sort((a, b) =>
          (b.lastOccurrence ?? b.createdAt).compareTo(a.lastOccurrence ?? a.createdAt)
      );

      notifyListeners();
    } catch (e, stackTrace) {
      ErrorLogger.logError('ProblemDatabaseService.loadProblems', e, stackTrace);
      rethrow;
    }
  }

  // Fügt ein neues Problem hinzu
  Future<void> addProblem(Problem problem) async {
    try {
      final problems = await databaseService.getFromLocalStorage(PROBLEMS_KEY);
      problems.add(problem.toJson());
      await databaseService.saveToLocalStorage(PROBLEMS_KEY, problems);
      await loadProblems();
    } catch (e, stackTrace) {
      ErrorLogger.logError('ProblemDatabaseService.addProblem', e, stackTrace);
      rethrow;
    }
  }

  // Aktualisiert ein bestehendes Problem
  Future<void> updateProblem(Problem problem) async {
    try {
      final problems = await databaseService.getFromLocalStorage(PROBLEMS_KEY);
      final index = problems.indexWhere((p) => p['id'] == problem.id);

      if (index != -1) {
        problems[index] = problem.toJson();
        await databaseService.saveToLocalStorage(PROBLEMS_KEY, problems);
        await loadProblems();
      } else {
        throw Exception('Problem nicht gefunden');
      }
    } catch (e, stackTrace) {
      ErrorLogger.logError('ProblemDatabaseService.updateProblem', e, stackTrace);
      rethrow;
    }
  }

  // Löscht ein Problem
  Future<void> deleteProblem(String problemId) async {
    try {
      final problems = await databaseService.getFromLocalStorage(PROBLEMS_KEY);
      problems.removeWhere((p) => p['id'] == problemId);
      await databaseService.saveToLocalStorage(PROBLEMS_KEY, problems);
      await loadProblems();
    } catch (e, stackTrace) {
      ErrorLogger.logError('ProblemDatabaseService.deleteProblem', e, stackTrace);
      rethrow;
    }
  }

  // Sucht nach Problemen basierend auf verschiedenen Kriterien
  Future<List<Problem>> searchProblems({
    String? searchText,
    ProblemCategory? category,
    String? machineType,
    ProblemStatus? status,
  }) async {
    try {
      await loadProblems();

      return _problems.where((problem) {
        bool matches = true;

        // Textsuche
        if (searchText != null && searchText.isNotEmpty) {
          final searchLower = searchText.toLowerCase();
          matches = matches && (
              problem.title.toLowerCase().contains(searchLower) ||
                  problem.description.toLowerCase().contains(searchLower) ||
                  problem.symptoms.any((s) => s.toLowerCase().contains(searchLower)) ||
                  problem.solutions.any((s) => s.toLowerCase().contains(searchLower))
          );
        }

        // Kategoriefilter
        if (category != null) {
          matches = matches && problem.category == category;
        }

        // Maschinentyp-Filter
        if (machineType != null) {
          matches = matches && problem.machineType == machineType;
        }

        // Status-Filter
        if (status != null) {
          matches = matches && problem.status == status;
        }

        return matches;
      }).toList();
    } catch (e, stackTrace) {
      ErrorLogger.logError('ProblemDatabaseService.searchProblems', e, stackTrace);
      return [];
    }
  }

  // Inkrementiert den Zähler für das Auftreten eines Problems
  Future<void> incrementOccurrence(String problemId) async {
    try {
      final problem = _problems.firstWhere((p) => p.id == problemId);
      final updatedProblem = problem.copyWith(
        occurrences: problem.occurrences + 1,
        lastOccurrence: DateTime.now(),
      );
      await updateProblem(updatedProblem);
    } catch (e, stackTrace) {
      ErrorLogger.logError('ProblemDatabaseService.incrementOccurrence', e, stackTrace);
      rethrow;
    }
  }

  // Speichert eine neue Lösung für ein Problem
  Future<void> addSolution(String problemId, String solution) async {
    try {
      final problem = _problems.firstWhere((p) => p.id == problemId);
      if (!problem.solutions.contains(solution)) {
        final updatedSolutions = List<String>.from(problem.solutions)..add(solution);
        final updatedProblem = problem.copyWith(
          solutions: updatedSolutions,
          status: ProblemStatus.solved,
        );
        await updateProblem(updatedProblem);
      }
    } catch (e, stackTrace) {
      ErrorLogger.logError('ProblemDatabaseService.addSolution', e, stackTrace);
      rethrow;
    }
  }

  // Holt ähnliche Probleme basierend auf Symptomen und Maschinentyp
  List<Problem> getSimilarProblems(Problem problem) {
    try {
      return _problems.where((p) {
        if (p.id == problem.id) return false;

        // Gleicher Maschinentyp
        if (p.machineType != problem.machineType) return false;

        // Prüfe auf übereinstimmende Symptome
        final commonSymptoms = p.symptoms.where(
                (s) => problem.symptoms.contains(s)
        ).length;

        // Mindestens ein gemeinsames Symptom
        return commonSymptoms > 0;
      }).toList();
    } catch (e, stackTrace) {
      ErrorLogger.logError('ProblemDatabaseService.getSimilarProblems', e, stackTrace);
      return [];
    }
  }
}