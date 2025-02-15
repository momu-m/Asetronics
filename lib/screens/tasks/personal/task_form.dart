// task_form.dart
import 'package:flutter/material.dart';
import '../../../models/maintenance_schedule.dart';
import '../../../main.dart' show maintenanceScheduleService, databaseService;


class TaskForm extends StatefulWidget {
  // Ermöglicht das Bearbeiten einer bestehenden Aufgabe
  final MaintenanceTask? existingTask;

  const TaskForm({Key? key, this.existingTask}) : super(key: key);

  @override
  State<TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<TaskForm> {
  // Formular-Schlüssel für die Validierung
  final _formKey = GlobalKey<FormState>();

  // Controller für die Texteingabefelder
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _toolsController = TextEditingController();
  final _partsController = TextEditingController();

  // Status-Variablen zur Verwaltung der Benutzereingaben
  List<Map<String, dynamic>> _machines = [];
  String? _selectedMachineId;
  MaintenanceInterval _selectedInterval = MaintenanceInterval.monthly;
  String? _selectedAssignee;
  List<String> _selectedViewers = [];
  bool _isPublic = true;
  int _estimatedHours = 1;
  int _estimatedMinutes = 0;
  DateTime _nextDueDate = DateTime.now().add(const Duration(days: 1));
  bool _isSaving = false;

  // Liste der verfügbaren Benutzer (später aus der Datenbank)
  final List<Map<String, String>> _users = [
    {'id': '1', 'name': 'Jessie', 'role': 'technician'},
    {'id': '2', 'name': 'Mohamed', 'role': 'technician'},
    {'id': '3', 'name': 'Andreas', 'role': 'teamlead'},
  ];

  // Übersetzungen für die Wartungsintervalle
  final Map<MaintenanceInterval, String> _intervalTexts = {
    MaintenanceInterval.daily: 'Täglich',
    MaintenanceInterval.weekly: 'Wöchentlich',
    MaintenanceInterval.monthly: 'Monatlich',
    MaintenanceInterval.quarterly: 'Vierteljährlich',
    MaintenanceInterval.yearly: 'Jährlich',
  };

  @override
  void initState() {
    super.initState();
    _loadMachines();
    if (widget.existingTask != null) {
      _initializeWithExistingTask();
    }
  }

  Future<void> _loadMachines() async {
    try {
      final machines = await databaseService.getMachines();
      setState(() {
        _machines = machines;
        if (_machines.isNotEmpty && _selectedMachineId == null) {
          _selectedMachineId = _machines[0]['id'].toString();
        }
      });
    } catch (e) {
      print('Fehler beim Laden der Maschinen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Laden der Maschinen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  // Initialisiert das Formular mit den Daten einer bestehenden Aufgabe
  void _initializeWithExistingTask() {
    final task = widget.existingTask!;
    _titleController.text = task.title;
    _descriptionController.text = task.description;
    _toolsController.text = task.requiredTools.join(', ');
    _partsController.text = task.requiredParts.join(', ');
    _selectedMachineId = task.machineId;
    _selectedInterval = task.interval;
    _estimatedHours = task.estimatedDuration.inHours;
    _estimatedMinutes = task.estimatedDuration.inMinutes % 60;
    _nextDueDate = task.nextDue;
    _selectedAssignee = task.assignedTo;
    if (task.viewers != null) {
      _selectedViewers = List<String>.from(task.viewers!);
    }
    _isPublic = task.isPublic ?? true;
  }

  // Speichert die Aufgabe in der Datenbank
  Future<void> _saveTask() async {
    // Prüfe zuerst, ob alle Pflichtfelder ausgefüllt sind
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // Erstelle ein neues MaintenanceTask-Objekt
      final task = MaintenanceTask(
        id: widget.existingTask?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        machineId: _selectedMachineId ?? '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        interval: _selectedInterval,
        estimatedDuration: Duration(
          hours: _estimatedHours,
          minutes: _estimatedMinutes,
        ),
        requiredTools: _toolsController.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        requiredParts: _partsController.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        nextDue: _nextDueDate,
        assignedTo: _selectedAssignee,
        viewers: _isPublic ? null : _selectedViewers,
        isPublic: _isPublic,
        createdBy: 'current_user',
      );
      if (_selectedMachineId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bitte wählen Sie eine Maschine aus')),
        );
        return;
      }


      // Speichere oder aktualisiere die Aufgabe
      if (widget.existingTask != null) {
        await maintenanceScheduleService.updateTask(task);
      } else {
        await maintenanceScheduleService.addTask(task);
      }

      if (!mounted) return;

      // Zeige Erfolgsmeldung
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.existingTask != null
              ? 'Aufgabe wurde aktualisiert'
              : 'Neue Aufgabe wurde erstellt'),
          backgroundColor: Colors.green,
        ),
      );

      // Kehre zum vorherigen Bildschirm zurück
      Navigator.pop(context, true);
    } catch (e) {
      // Fehlerbehandlung
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingTask != null
            ? 'Aufgabe bearbeiten'
            : 'Neue Aufgabe'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Titel
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Titel',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Bitte geben Sie einen Titel ein';
                  }
                  return null;
                },
              ),
              // Nach dem Titel-Feld und vor der Beschreibung einfügen:
              const SizedBox(height: 16),

              // Maschinenauswahl
              if (_machines.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: _selectedMachineId,
                  decoration: const InputDecoration(
                    labelText: 'Maschine',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.precision_manufacturing),
                  ),
                  items: _machines.map((machine) {
                    return DropdownMenuItem(
                      value: machine['id'].toString(),
                      child: Text(machine['name']),
                    );
                  }).toList(),
                  validator: (value) {
                    if (value == null) {
                      return 'Bitte wählen Sie eine Maschine';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    setState(() => _selectedMachineId = value);
                  },
                ),
              const SizedBox(height: 16),

              // Beschreibung
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Beschreibung',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Bitte geben Sie eine Beschreibung ein';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Wartungsintervall
              DropdownButtonFormField<MaintenanceInterval>(
                value: _selectedInterval,
                decoration: const InputDecoration(
                  labelText: 'Wartungsintervall',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.repeat),
                ),
                items: _intervalTexts.entries.map((entry) {
                  return DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedInterval = value);
                  }
                },
              ),
              const SizedBox(height: 16),

              // Geschätzte Dauer
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _estimatedHours.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Stunden',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.timer),
                      ),
                      validator: (value) {
                        if (value == null || int.tryParse(value) == null) {
                          return 'Ungültige Eingabe';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        setState(() => _estimatedHours = int.tryParse(value) ?? 0);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      initialValue: _estimatedMinutes.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Minuten',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.timer),
                      ),
                      validator: (value) {
                        if (value == null ||
                            int.tryParse(value) == null ||
                            int.parse(value) >= 60) {
                          return 'Ungültige Eingabe';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        setState(() => _estimatedMinutes = int.tryParse(value) ?? 0);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Bearbeiter auswählen
              DropdownButtonFormField<String>(
                value: _selectedAssignee,
                decoration: const InputDecoration(
                  labelText: 'Zugewiesen an',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                items: _users.map((user) {
                  return DropdownMenuItem(
                    value: user['id'],
                    child: Text(user['name']!),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedAssignee = value);
                },
              ),
              const SizedBox(height: 16),

              // Werkzeuge
              TextFormField(
                controller: _toolsController,
                decoration: const InputDecoration(
                  labelText: 'Benötigte Werkzeuge (durch Komma getrennt)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.build),
                ),
              ),
              const SizedBox(height: 16),

              // Ersatzteile
              TextFormField(
                controller: _partsController,
                decoration: const InputDecoration(
                  labelText: 'Benötigte Ersatzteile (durch Komma getrennt)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.settings),
                ),
              ),
              const SizedBox(height: 16),

              // Fälligkeitsdatum
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Fälligkeitsdatum',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(_formatDate(_nextDueDate)),
                          const Spacer(),
                          TextButton(
                            onPressed: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _nextDueDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (date != null) {
                                setState(() => _nextDueDate = date);
                              }
                            },
                            child: const Text('Ändern'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Sichtbarkeit
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sichtbarkeit',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SwitchListTile(
                        title: const Text('Öffentlich sichtbar'),
                        value: _isPublic,
                        onChanged: (value) {
                          setState(() => _isPublic = value);
                        },
                      ),
                      if (!_isPublic) ...[
                        const Divider(),
                        const Text('Sichtbar für:'),
                        ...(_users.map((user) => CheckboxListTile(
                          title: Text(user['name']!),
                          value: _selectedViewers.contains(user['id']),
                          onChanged: (bool? value) {
                            setState(() {
                              if (value == true) {
                                _selectedViewers.add(user['id']!);
                              } else {
                                _selectedViewers.remove(user['id']);
                              }
                            });
                          },
                        ))),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Speichern Button
              ElevatedButton(
                onPressed: _isSaving ? null : _saveTask,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _isSaving ? 'Wird gespeichert...' : 'Aufgabe speichern',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Hilfsmethode zum Formatieren des Datums
  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }


  @override
  void dispose() {
    // Aufräumen der Controller
    _titleController.dispose();
    _descriptionController.dispose();
    _toolsController.dispose();
    _partsController.dispose();
    super.dispose();
  }
}