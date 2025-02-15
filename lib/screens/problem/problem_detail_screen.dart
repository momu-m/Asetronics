// problem_detail_screen.dart
import 'package:flutter/material.dart';
import '../../models/problem_model.dart';
import '../../main.dart';
import 'problem_form_screen.dart';

class ProblemDetailScreen extends StatefulWidget {
  final Problem problem;

  const ProblemDetailScreen({
    Key? key,
    required this.problem,
  }) : super(key: key);

  @override
  State<ProblemDetailScreen> createState() => _ProblemDetailScreenState();
}

class _ProblemDetailScreenState extends State<ProblemDetailScreen> {
  late Problem _problem;
  final TextEditingController _solutionController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _problem = widget.problem;
  }

  // Formatiert ein Datum für die Anzeige
  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }

  // Zeigt den Dialog zum Hinzufügen einer Lösung
  Future<void> _showAddSolutionDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Neue Lösung hinzufügen'),
        content: TextField(
          controller: _solutionController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Beschreiben Sie die Lösung',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () {
              final solution = _solutionController.text.trim();
              if (solution.isNotEmpty) {
                Navigator.pop(context, solution);
              }
            },
            child: const Text('Hinzufügen'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        setState(() => _isLoading = true);
        await problemDatabaseService.addSolution(_problem.id, result);
        // Aktualisiere das Problem
        final problems = await problemDatabaseService.searchProblems();
        _problem = problems.firstWhere((p) => p.id == _problem.id);
        setState(() => _isLoading = false);
      } catch (e) {
        print('Fehler beim Hinzufügen der Lösung: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler: $e')),
          );
        }
      }
    }
  }

  // Zeigt den Dialog zum Ändern des Status
  Future<void> _showChangeStatusDialog() async {
    final result = await showDialog<ProblemStatus>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Status ändern'),
        content: DropdownButtonFormField<ProblemStatus>(
          value: _problem.status,
          items: ProblemStatus.values.map((status) {
            return DropdownMenuItem(
              value: status,
              child: Text(status.toString().split('.').last),
            );
          }).toList(),
          onChanged: (value) => Navigator.pop(context, value),
        ),
      ),
    );

    if (result != null && result != _problem.status) {
      try {
        setState(() => _isLoading = true);
        final updatedProblem = _problem.copyWith(status: result);
        await problemDatabaseService.updateProblem(updatedProblem);
        setState(() => _problem = updatedProblem);
      } catch (e) {
        print('Fehler beim Ändern des Status: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  // Zeigt den Dialog zum Löschen des Problems
  Future<void> _showDeleteDialog() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Problem löschen'),
        content: const Text('Möchten Sie dieses Problem wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        await problemDatabaseService.deleteProblem(_problem.id);
        if (mounted) {
          Navigator.pop(context, true);
        }
      } catch (e) {
        print('Fehler beim Löschen: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Problem Details'),
        actions: [
          // Status ändern
          IconButton(
            icon: const Icon(Icons.update),
            tooltip: 'Status ändern',
            onPressed: _showChangeStatusDialog,
          ),
          // Bearbeiten
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Bearbeiten',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProblemFormScreen(
                    existingProblem: _problem,
                  ),
                ),
              );
              if (result == true) {
                Navigator.pop(context, true);
              }
            },
          ),
          // Löschen
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Löschen',
            onPressed: _showDeleteDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status-Karte
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.info_outline,
                  color: switch (_problem.status) {
                    ProblemStatus.active => Colors.orange,
                    ProblemStatus.solved => Colors.green,
                    ProblemStatus.inProgress => Colors.blue,
                    ProblemStatus.archived => Colors.grey,
                  },
                ),
                title: const Text('Status'),
                subtitle: Text(
                  _problem.status.toString().split('.').last,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Hauptinformationen
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _problem.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Divider(),
                    Text('Maschinentyp: ${_problem.machineType}'),
                    Text('Kategorie: ${_problem.category.toString().split('.').last}'),
                    Text('Erstellt am: ${_formatDate(_problem.createdAt)}'),
                    Text('Aufgetreten: ${_problem.occurrences}x'),
                    if (_problem.lastOccurrence != null)
                      Text('Zuletzt am: ${_formatDate(_problem.lastOccurrence!)}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Beschreibung
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Beschreibung',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_problem.description),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Symptome
            if (_problem.symptoms.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Symptome',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: _problem.symptoms
                            .map((symptom) => Chip(label: Text(symptom)))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Lösungen
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Lösungen',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Lösung hinzufügen'),
                          onPressed: _showAddSolutionDialog,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_problem.solutions.isEmpty)
                      const Text('Noch keine Lösungen vorhanden')
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _problem.solutions.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.check, color: Colors.green),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(_problem.solutions[index]),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Ersatzteile
            if (_problem.relatedParts.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Betroffene Ersatzteile',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: _problem.relatedParts
                            .map((part) => Chip(label: Text(part)))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _solutionController.dispose();
    super.dispose();
  }
}