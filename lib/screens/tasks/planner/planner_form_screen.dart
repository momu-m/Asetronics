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
  bool _isUrgent = false;

  // Neue Variablen für die Produktionslinie und den Maschinentyp
  String? _selectedMachineLine;
  String? _selectedMachineType;

  // Listen für Dropdown-Menüs
  List<Map<String, dynamic>> _technicians = [];
  List<String> get _machineLines => ProductionLines.getAllLines();

  // Getter für Maschinentypen basierend auf der ausgewählten Linie
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
    setState(() => _isLoading = true);
    try {
      // Lade Techniker
      await _loadTechnicians();

      // Initialisiere existierende Task-Daten falls vorhanden
      if (widget.existingTask != null) {
        _initializeExistingTask();
      } else {
        // Standardwert für Produktionslinie falls keine existierende Aufgabe
        _selectedMachineLine = ProductionLines.xLine;
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

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        print('🔧 Geladene Techniker: ${data.length}');

        if (mounted) {
          setState(() {
            _technicians = List<Map<String, dynamic>>.from(data);

            // Setze den ersten Techniker als Standard, falls vorhanden
            if (_technicians.isNotEmpty && _selectedTechnician == null) {
              _selectedTechnician = _technicians[0]['id'].toString();
            }
          });
        }
      } else {
        throw Exception('Server antwortete mit Statuscode ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Fehler beim Laden der Techniker: $e');
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
    _isUrgent = task.priority == MaintenancePriority.urgent;

    // Produktionslinie und Maschinentyp initialisieren
    _selectedMachineLine = task.line;
    _selectedMachineType = task.machineType;

    // Falls diese nicht gesetzt sind, versuche sie aus der MachineID zu extrahieren
    if (_selectedMachineLine == null || _selectedMachineType == null) {
      _extractMachineInfoFromId(task.machineId);
    }

    // Schätzung der Stunden und Minuten
    _estimatedHours = task.estimatedDuration.inHours;
    _estimatedMinutes = task.estimatedDuration.inMinutes % 60;
  }

  // Hilfsmethode zur Extraktion von Linie und Typ aus der MachineID
  void _extractMachineInfoFromId(String machineId) {
    if (machineId.contains('-')) {
      final parts = machineId.split('-');
      if (parts.length >= 2) {
        // Suche nach Produktionslinie
        for (final line in _machineLines) {
          if (machineId.toLowerCase().contains(line.toLowerCase())) {
            setState(() => _selectedMachineLine = line);
            break;
          }
        }

        // Wenn wir eine Linie gefunden haben, suche nach dem Maschinentyp
        if (_selectedMachineLine != null) {
          // Verzögert ausführen, damit die _machineTypes-Liste korrekt aktualisiert wird
          Future.microtask(() {
            for (final type in _machineTypes) {
              if (machineId.toLowerCase().contains(type.toLowerCase())) {
                setState(() => _selectedMachineType = type);
                break;
              }
            }
          });
        }
      }
    }
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) return;

    // Zusätzliche Validierungen
    if (_selectedMachineLine == null) {
      _showError('Bitte wählen Sie eine Produktionslinie aus');
      return;
    }
    if (_selectedMachineType == null) {
      _showError('Bitte wählen Sie einen Maschinentyp aus');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Generiere eine Maschinen-ID aus den ausgewählten Werten wenn keine vorhanden ist
      final machineId = _selectedMachineId ??
          'machine-${_selectedMachineLine}-${_selectedMachineType}-${DateTime.now().millisecondsSinceEpoch}';

      // Aufgabendaten vorbereiten
      final taskData = {
        "id": widget.existingTask?.id ?? 'task-${DateTime.now().millisecondsSinceEpoch}',
        "title": _titleController.text.trim(),
        "description": _descriptionController.text.trim(),
        "machine_id": machineId,
        "machine_line": _selectedMachineLine,
        "machine_type": _selectedMachineType,
        "assigned_to": _selectedTechnician,
        "due_date": _nextDueDate.toIso8601String(),
        "status": widget.existingTask?.status.toString().split('.').last ?? "pending",
        "priority": _isUrgent ? "urgent" : _priority.toString().split('.').last.toLowerCase(),
        "maintenance_int": _selectedInterval.toString().split('.').last.toLowerCase(),
        "estimated_duration": (_estimatedHours * 60) + _estimatedMinutes,
        "created_at": DateTime.now().toIso8601String()
      };

      print('Sende Aufgabendaten: ${jsonEncode(taskData)}');

      final response = await ApiConfig.sendRequest(
        url: widget.existingTask != null
            ? '${ApiConfig.maintenanceUrl}/tasks/${widget.existingTask!.id}'
            : '${ApiConfig.maintenanceUrl}/tasks',
        method: widget.existingTask != null ? 'PUT' : 'POST',
        body: jsonEncode(taskData),
      );

      print('Server Antwort Status: ${response.statusCode}');

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
      print('Fehler beim Speichern: $e');
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
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Bitte geben Sie einen Titel ein';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Produktionslinie Dropdown
              DropdownButtonFormField<String>(
                value: _selectedMachineLine,
                decoration: const InputDecoration(
                  labelText: 'Produktionslinie',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.linear_scale),
                ),
                items: _machineLines.map((line) {
                  return DropdownMenuItem<String>(
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
                    // Zurücksetzen des Maschinentyps, da sich die verfügbaren Typen ändern können
                    _selectedMachineType = null;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Maschinentyp Dropdown (abhängig von der ausgewählten Linie)
              DropdownButtonFormField<String>(
                value: _selectedMachineType,
                decoration: const InputDecoration(
                  labelText: 'Maschinentyp',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.precision_manufacturing),
                ),
                items: _machineTypes.map((type) {
                  return DropdownMenuItem<String>(
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
                  prefixIcon: Icon(Icons.description),
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Bitte geben Sie eine Beschreibung ein';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Intervall
              DropdownButtonFormField<MaintenanceInterval>(
                value: _selectedInterval,
                decoration: const InputDecoration(
                  labelText: 'Wartungsintervall',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.repeat),
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
                        prefixIcon: Icon(Icons.timer),
                      ),
                      validator: (value) {
                        if (value == null || int.tryParse(value) == null) {
                          return 'Ungültige Eingabe';
                        }
                        return null;
                      },
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
                        prefixIcon: Icon(Icons.timer),
                      ),
                      validator: (value) {
                        if (value == null || int.tryParse(value) == null || int.parse(value) >= 60) {
                          return 'Ungültige Eingabe';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        _estimatedMinutes = int.tryParse(value) ?? 0;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Zuständiger Techniker
              Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Zuständiger Techniker',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (_technicians.isNotEmpty)
                        DropdownButtonFormField<String>(
                          value: _selectedTechnician,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
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
                        )
                      else
                        const Text(
                          'Keine Techniker verfügbar',
                          style: TextStyle(color: Colors.red),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Fälligkeitsdatum
              ListTile(
                title: const Text('Fällig am'),
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
              const SizedBox(height: 16),

              // Dringend-Switch
              SwitchListTile(
                title: const Text('Dringend'),
                subtitle: const Text('Als dringende Aufgabe markieren'),
                value: _isUrgent,
                onChanged: (value) {
                  setState(() => _isUrgent = value);
                },
                secondary: const Icon(Icons.priority_high),
              ),
              const SizedBox(height: 24),

              // Speichern Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveTask,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                    widget.existingTask != null ? 'Aufgabe aktualisieren' : 'Aufgabe erstellen',
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
    return switch (interval) {
      MaintenanceInterval.daily => 'Täglich',
      MaintenanceInterval.weekly => 'Wöchentlich',
      MaintenanceInterval.monthly => 'Monatlich',
      MaintenanceInterval.quarterly => 'Vierteljährlich',
      MaintenanceInterval.yearly => 'Jährlich',
    };
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