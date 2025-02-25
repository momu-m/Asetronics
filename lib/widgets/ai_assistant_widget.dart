import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/problem_database_service.dart';
import '../../services/manual_service.dart';
import '../../services/ai_service.dart';
import '../../models/problem_model.dart';

class ImprovedAIAssistantWidget extends StatefulWidget {
  const ImprovedAIAssistantWidget({Key? key}) : super(key: key);

  @override
  _ImprovedAIAssistantWidgetState createState() => _ImprovedAIAssistantWidgetState();
}

class _ImprovedAIAssistantWidgetState extends State<ImprovedAIAssistantWidget> {
  final TextEditingController _queryController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  String _searchType = 'problems'; // Default search type

  // Methode zur intelligenten Suche
  Future<void> _performIntelligentSearch() async {
    if (_queryController.text.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _searchResults.clear();
    });

    try {
      final problemService = Provider.of<ProblemDatabaseService>(context, listen: false);
      final manualService = Provider.of<ManualService>(context, listen: false);

      switch (_searchType) {
        case 'problems':
        // Suche in Problemen
          final problems = await problemService.searchProblems(
            searchText: _queryController.text,
          );

          setState(() {
            _searchResults = problems.map((problem) => {
              'type': 'problem',
              'title': problem.title,
              'description': problem.description,
              'category': problem.category.toString().split('.').last,
              'machineType': problem.machineType,
            }).toList();
          });
          break;

        case 'manuals':
        // Suche in Anleitungen
          final manuals = manualService.searchManuals(_queryController.text);

          setState(() {
            _searchResults = manuals.map((manual) => {
              'type': 'manual',
              'title': manual['title'],
              'machineType': manual['machineType'],
              'url': manual['url'],
            }).toList();
          });
          break;

        case 'similar':
        // Suche nach ähnlichen Problemen
          final problemService = Provider.of<ProblemDatabaseService>(context, listen: false);
          final problems = await problemService.searchProblems(
            searchText: _queryController.text,
          );

          final similarProblems = problems
              .expand((problem) => problemService.getSimilarProblems(problem))
              .toSet()
              .toList();

          setState(() {
            _searchResults = similarProblems.map((problem) => {
              'type': 'similar_problem',
              'title': problem.title,
              'description': problem.description,
              'machineType': problem.machineType,
            }).toList();
          });
          break;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler bei der Suche: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Suchkopf
            Row(
              children: [
                const Icon(Icons.search, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Intelligente Suche',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // Suchtyp-Dropdown
                DropdownButton<String>(
                  value: _searchType,
                  items: const [
                    DropdownMenuItem(
                      value: 'problems',
                      child: Text('Probleme'),
                    ),
                    DropdownMenuItem(
                      value: 'manuals',
                      child: Text('Anleitungen'),
                    ),
                    DropdownMenuItem(
                      value: 'similar',
                      child: Text('Ähnliche Probleme'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _searchType = value!;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Sucheingabe
            TextField(
              controller: _queryController,
              decoration: InputDecoration(
                hintText: 'Suchen Sie nach Problemen, Anleitungen...',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _performIntelligentSearch,
                ),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _performIntelligentSearch(),
            ),
            const SizedBox(height: 16),

            // Ladeanzeige
            if (_isLoading)
              const Center(child: CircularProgressIndicator()),

            // Suchergebnisse
            if (!_isLoading && _searchResults.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Suchergebnisse:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final result = _searchResults[index];
                      return Card(
                        child: ListTile(
                          leading: Icon(
                            result['type'] == 'problem'
                                ? Icons.error_outline
                                : result['type'] == 'manual'
                                ? Icons.description
                                : Icons.repeat,
                            color: Colors.blue,
                          ),
                          title: Text(result['title'] ?? 'Kein Titel'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (result['description'] != null)
                                Text(
                                  result['description'],
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              const SizedBox(height: 4),
                              Text(
                                'Typ: ${_mapResultType(result['type'])}',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            // Hier können Sie eine detaillierte Ansicht implementieren
                            _showDetailDialog(result);
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),

            // Keine Ergebnisse
            if (!_isLoading && _searchResults.isEmpty)
              const Center(
                child: Text(
                  'Keine Ergebnisse gefunden.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Hilfsmethode zur Übersetzung von Ergebnistypen
  String _mapResultType(String type) {
    switch (type) {
      case 'problem':
        return 'Problem';
      case 'manual':
        return 'Anleitung';
      case 'similar_problem':
        return 'Ähnliches Problem';
      default:
        return 'Unbekannt';
    }
  }

  // Detaildialog für Suchergebnisse
  void _showDetailDialog(Map<String, dynamic> result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(result['title'] ?? 'Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (result['description'] != null)
                Text('Beschreibung: ${result['description']}'),
              const SizedBox(height: 8),
              Text('Typ: ${_mapResultType(result['type'])}'),
              if (result['machineType'] != null)
                Text('Maschinentyp: ${result['machineType']}'),
              if (result['url'] != null)
                Text('Dokumenten-URL: ${result['url']}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }
}