import 'package:flutter/material.dart';
import 'dart:convert';
import '../../../models/maintenance_schedule.dart';
import '../../../models/user_role.dart';
import '../../../config/api_config.dart';
import '../../../main.dart' show userService;
import '../../../utils/machine_constants.dart';

class PlannerFormScreen extends StatefulWidget {
  final MaintenanceTask? existingTask;

  const PlannerFormScreen({
    Key? key,
    this.existingTask,
  }) : super(key: key);

  @override
  State<PlannerFormScreen> createState() => _PlannerFormScreenState();
}

class _PlannerFormScreenState extends State<PlannerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedMachineLine;
  String? _selectedMachineType;


  // Text Controller
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Status Variablen
  bool _isLoading = false;
  String? _selectedMachineId;
  String? _selectedTechnician;
  MaintenanceInterval _selectedInterval = MaintenanceInterval.monthly;
  DateTime _nextDueDate = DateTime.now().add(const Duration(days: 1));
  int _estimatedHours = 1;
  int _estimatedMinutes = 0;
  MaintenancePriority _priority = MaintenancePriority.medium;

  // Listen für Dropdown-Menüs
  List<Map<String, dynamic>> _machines = [];
  List<Map<String, dynamic>> _technicians = [];
  List<String> get _machineLines => ProductionLines.getAllLines();

  List<String> get _machineTypes {
    if (_selectedMachineLine == ProductionLines.xLine) {
      return [
        ...MachineCategories.placerTypes,
        ...MachineCategories.printerTypes
      ];
    } else if (_selectedMachineLine == ProductionLines.dLine) {
      return [
        ...MachineCategories.placerTypes,
        ...MachineCategories.ovenTypes
      ];
    }

    // Fallback: Alle Maschinentypen
    return [
      ...MachineCategories.placerTypes,
      ...MachineCategories.printerTypes,
      ...MachineCategories.ovenTypes,
      ...MachineCategories.inspectionTypes,
    ];
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() => _isLoading = true);

      // Lade Maschinen
      await _loadMachines();

      // Lade Techniker
      await _loadTechnicians();

      // Initialisiere existierende Task-Daten falls vorhanden
      if (widget.existingTask != null) {
        _initializeExistingTask();
      }
    } catch (e) {
      print('Fehler beim Laden der Daten: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTechnicians() async {
    try {
      print('🔄 Starte Laden der Techniker...');

      final response = await ApiConfig.sendRequest(
        url: '${ApiConfig.baseUrl}/users?role=technician',
        method: 'GET',
      );

      print('🔧 Response Status: ${response.statusCode}');
      print('🔧 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        print('🔧 Dekodierte Daten: $data');

        if (mounted) {
          setState(() {
            _technicians = List<Map<String, dynamic>>.from(data);
            print('🔧 Techniker geladen: ${_technicians.length}');

            // Setze den ersten Techniker als Standard, falls vorhanden
            if (_technicians.isNotEmpty && _selectedTechnician == null) {
              _selectedTechnician = _technicians[0]['id'].toString();
              print('🔧 Erster Techniker ausgewählt: $_selectedTechnician');
            }
          });
        }
      } else {
        throw Exception('Server antwortete mit Statuscode ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Fehler beim Laden der Techniker: $e');
      // Zeige Fehlermeldung im UI
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Laden der Techniker: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _initializeExistingTask() {
    final task = widget.existingTask!;
    _titleController.text = task.title;
    _descriptionController.text = task.description;
    _selectedMachineId = task.machineId;
    _selectedTechnician = task.assignedTo;
    _selectedInterval = task.interval;
    _nextDueDate = task.nextDue;
    _priority = task.priority;
  }

  Future<void> _loadMachines() async {
    try {
      setState(() => _isLoading = true);

      final response = await ApiConfig.sendRequest(
        url: ApiConfig.machinesUrl,
        method: 'GET',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _machines = List<Map<String, dynamic>>.from(
              data.where((m) => m['status'] == 'active')
          );
          _isLoading = false;
        });
        print('Maschinen erfolgreich geladen: ${_machines.length} aktive Maschinen');
      } else {
        throw Exception('Fehler beim Laden der Maschinen: ${response.statusCode}');
      }
    } catch (e) {
      print('Fehler beim Laden der Maschinen: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Laden der Maschinen: $e'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Wiederholen',
              onPressed: _loadMachines,
            ),
          ),
        );
      }
    }
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMachineId == null) {
      _showError('Bitte wählen Sie eine Maschine aus');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Aufgabendaten entsprechend der tatsächlichen Datenbankstruktur
      final taskData = {
        "id": widget.existingTask?.id ?? 'task-${DateTime.now().millisecondsSinceEpoch}',
        "title": _titleController.text.trim(),
        "description": _descriptionController.text.trim(),
        'machine_line': _selectedMachineLine,
        'machine_type': _selectedMachineType,
        "assigned_to": _selectedTechnician,
        "due_date": _nextDueDate.toIso8601String(),
        "status": widget.existingTask?.status.toString().split('.').last ?? "pending",
        "priority": _priority.toString().split('.').last.toLowerCase(),
        "maintenance_int": _selectedInterval.toString().split('.').last.toLowerCase(),
        "estimated_duration": (_estimatedHours * 60) + _estimatedMinutes,  // ✅ Minuten berechnen
        "created_at": DateTime.now().toIso8601String()
      };

      print('Sende Aufgabendaten: ${jsonEncode(taskData)}'); // Debug-Log

      final response = await ApiConfig.sendRequest(
        url: widget.existingTask != null
            ? '${ApiConfig.maintenanceUrl}/tasks/${widget.existingTask!.id}'
            : '${ApiConfig.maintenanceUrl}/tasks',
        method: widget.existingTask != null ? 'PUT' : 'POST',
        body: jsonEncode(taskData),
      );

      print('Server Antwort Status: ${response.statusCode}'); // Debug-Log
      print('Server Antwort: ${response.body}'); // Debug-Log

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aufgabe erfolgreich gespeichert'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        throw Exception('Server-Fehler: ${response.statusCode}\n${response.body}');
      }
    } catch (e) {
      print('Fehler beim Speichern: $e'); // Debug-Log
      _showError('Fehler beim Speichern: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingTask != null ? 'Aufgabe bearbeiten' : 'Neue Aufgabe'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Titel
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Titel',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                value?.isEmpty == true ? 'Bitte Titel eingeben' : null,
              ),
              const SizedBox(height: 16),

              // Maschine
              DropdownButtonFormField<String>(
                value: _selectedMachineLine,
                decoration: const InputDecoration(
                  labelText: 'Produktionslinie',
                  border: OutlineInputBorder(),
                ),
                items: _machineLines.map((line) {
                  return DropdownMenuItem(
                    value: line,
                    child: Text(line),
                  );
                }).toList(),
                validator: (value) {
                  if (value == null) {
                    return 'Bitte Produktionslinie auswählen';
                  }
                  return null;
                },
                onChanged: (value) {
                  setState(() {
                    _selectedMachineLine = value;
                    _selectedMachineType = null; // Zurücksetzen der Maschinentyp-Auswahl
                  });
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedMachineType,
                decoration: const InputDecoration(
                  labelText: 'Maschinentyp',
                  border: OutlineInputBorder(),
                ),
                items: _machineTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                validator: (value) {
                  if (value == null) {
                    return 'Bitte Maschinentyp auswählen';
                  }
                  return null;
                },
                onChanged: (value) {
                  setState(() => _selectedMachineType = value);
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
                ),
                validator: (value) =>
                value?.isEmpty == true ? 'Bitte Beschreibung eingeben' : null,
              ),
              const SizedBox(height: 16),

              // Intervall
              DropdownButtonFormField<MaintenanceInterval>(
                value: _selectedInterval,
                decoration: const InputDecoration(
                  labelText: 'Wartungsintervall',
                  border: OutlineInputBorder(),
                ),
                items: MaintenanceInterval.values.map((interval) {
                  return DropdownMenuItem(
                    value: interval,
                    child: Text(_getIntervalText(interval)),
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
                      ),
                      onChanged: (value) {
                        _estimatedHours = int.tryParse(value) ?? 0;
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
                      ),
                      onChanged: (value) {
                        _estimatedMinutes = int.tryParse(value) ?? 0;
                      },
                      validator: (value) {
                        final minutes = int.tryParse(value ?? '') ?? 0;
                        if (minutes >= 60) {
                          return 'Max. 59 Minuten';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Zuständiger Techniker
              if (_technicians.isNotEmpty) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedTechnician,
                  decoration: const InputDecoration(
                    labelText: "Zuständiger Techniker",
                    border: OutlineInputBorder(),
                  ),
                  items: _technicians.map((tech) {
                    return DropdownMenuItem(
                      value: tech['id'].toString(),
                      child: Text(tech['username'] ?? 'Unbekannt'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedTechnician = value);
                  },
                  validator: (value) =>
                  value == null ? 'Bitte wählen Sie einen Techniker' : null,
                ),
              ] else ...[
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Keine Techniker verfügbar',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],

              // Priorität
              DropdownButtonFormField<MaintenancePriority>(
                value: _priority,
                decoration: const InputDecoration(
                  labelText: 'Priorität',
                  border: OutlineInputBorder(),
                ),
                items: MaintenancePriority.values.map((priority) {
                  return DropdownMenuItem(
                    value: priority,
                    child: Text(_getPriorityText(priority)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _priority = value);
                  }
                },
              ),
              const SizedBox(height: 16),

              // Fälligkeitsdatum
              ListTile(
                title: const Text('Fälligkeitsdatum'),
                subtitle: Text(_formatDate(_nextDueDate)),
                trailing: TextButton(
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
              ),
              const SizedBox(height: 24),

              // Speichern Button
              ElevatedButton(
                onPressed: _isLoading ? null : _saveTask,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _isLoading ? 'Wird gespeichert...' : 'Aufgabe speichern',
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

  String _getIntervalText(MaintenanceInterval interval) {
    switch (interval) {
      case MaintenanceInterval.daily:
        return 'Täglich';
      case MaintenanceInterval.weekly:
        return 'Wöchentlich';
      case MaintenanceInterval.monthly:
        return 'Monatlich';
      case MaintenanceInterval.quarterly:
        return 'Vierteljährlich';
      case MaintenanceInterval.yearly:
        return 'Jährlich';
    }
  }

  String _getPriorityText(MaintenancePriority priority) {
    switch (priority) {
      case MaintenancePriority.low:
        return 'Niedrig';
      case MaintenancePriority.medium:
        return 'Mittel';
      case MaintenancePriority.high:
        return 'Hoch';
      case MaintenancePriority.urgent:
        return 'Dringend';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}