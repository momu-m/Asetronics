// error_report_dialog.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import '../../utils/machine_constants.dart';
import '../../main.dart' show databaseService;

class ErrorReportDialog extends StatefulWidget {
  final Map<String, dynamic> machineInfo;

  const ErrorReportDialog({
    Key? key,
    required this.machineInfo,
  }) : super(key: key);

  @override
  State<ErrorReportDialog> createState() => _ErrorReportDialogState();
}

class _ErrorReportDialogState extends State<ErrorReportDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  bool _isUrgent = false;
  String _selectedProblemCategory = 'Basis';

  // Hole die Probleme für den aktuellen Maschinentyp
  Map<String, List<String>> get _problems =>
      MachineCategories.getCommonProblems(widget.machineInfo['type']);

  void _addProblemToDescription(String problem) {
    final currentText = _descriptionController.text;
    final newText = currentText.isEmpty ? problem : '$currentText\n$problem';
    _descriptionController.text = newText;
  }

  Future<void> _saveErrorReport() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final now = DateTime.now();
      final report = {
        'id': now.millisecondsSinceEpoch.toString(),
        'machineId': widget.machineInfo['id'],
        'machineName': widget.machineInfo['name'],
        'machineType': widget.machineInfo['type'],
        'serialNumber': widget.machineInfo['serialNumber'],
        'line': widget.machineInfo['line'],
        'description': _descriptionController.text,
        'isUrgent': _isUrgent,
        'status': 'Neu',
        'createdAt': now.toIso8601String(),
        'createdBy': 'current_user', // Später durch echten Benutzer ersetzen
      };

      await databaseService.saveErrorReport(report);

      if (!mounted) return;

      // Zeige Erfolgsmeldung und schließe Dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Erfolg'),
          content: const Text('Die Fehlermeldung wurde erfolgreich gespeichert.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      Navigator.of(context).pop(true);

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Speichern: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Titel und Maschineninfo
                Text(
                  'Fehler melden',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold
                  ),
                ),
                const SizedBox(height: 16),
                _buildMachineInfoCard(),
                const SizedBox(height: 16),

                // Problemeauswahl
                Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          'Häufige Probleme',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      // Kategorie-Tabs
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _problems.keys.map((category) =>
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: ChoiceChip(
                                  label: Text(category),
                                  selected: _selectedProblemCategory == category,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() => _selectedProblemCategory = category);
                                    }
                                  },
                                ),
                              ),
                          ).toList(),
                        ),
                      ),
                      // Problem-Chips
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: (_problems[_selectedProblemCategory] ?? []).map((problem) =>
                              ActionChip(
                                label: Text(problem),
                                onPressed: () => _addProblemToDescription(problem),
                              ),
                          ).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Beschreibungsfeld
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Problembeschreibung',
                    border: OutlineInputBorder(),
                    hintText: 'Beschreiben Sie das Problem im Detail...',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Bitte beschreiben Sie das Problem';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),

                // Dringlichkeit
                Card(
                  child: SwitchListTile(
                    title: const Text('Dringend'),
                    subtitle: const Text('Sofortige Aufmerksamkeit erforderlich'),
                    value: _isUrgent,
                    onChanged: (value) => setState(() => _isUrgent = value),
                  ),
                ),
                const SizedBox(height: 16),

                // Aktionsbuttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Abbrechen'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _saveErrorReport,
                      child: const Text('Fehler melden'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMachineInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.precision_manufacturing),
              title: Text(widget.machineInfo['name']),
              subtitle: Text(widget.machineInfo['type']),
            ),
            const Divider(),
            _buildInfoRow('Seriennummer:', widget.machineInfo['serialNumber']),
            _buildInfoRow('Linie:', widget.machineInfo['line']),
            if (widget.machineInfo['location'] != null)
              _buildInfoRow('Standort:', widget.machineInfo['location']),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }
}