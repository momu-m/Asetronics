// planner_form.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../models/maintenance_schedule.dart';
import '../../../models/user_role.dart';
import '../../../config/api_config.dart';
import '../../../main.dart' show userService, maintenanceScheduleService;
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
  // Form Key
  final _formKey = GlobalKey<FormState>();

  // Text Controller
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Status Variablen
  bool _isLoading = false;
  String? _selectedTechnician;
  String? _selectedMachineId;
  List<User> _technicians = [];
  MaintenanceInterval _selectedInterval = MaintenanceInterval.monthly;
  DateTime _nextDueDate = DateTime.now().add(const Duration(days: 1));
  int _estimatedHours = 1;
  int _estimatedMinutes = 0;
  bool _isUrgent = false;
  MaintenancePriority _priority = MaintenancePriority.medium;

  // Neue Variablen für die Maschinenauswahl
  String? _selectedMachineLine;
  String? _selectedMachineType;

  // Getter für verfügbare Maschinentypen basierend auf der ausgewählten Linie
  List<String> get _machineTypes {
    if (_selectedMachineLine == null) {
      return [];
    }

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

  // Lädt alle benötigten Daten beim Start
  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      // Lade Techniker
      await _loadTechnicians();

      // Wenn existierende Aufgabe, lade deren Daten
      if (widget.existingTask != null) {
        _initializeExistingTask();
      } else {
        // Standardwerte setzen
        setState(() {
          _selectedMachineLine = ProductionLines.xLine;
        });
      }
    } catch (e) {
      print('Fehler beim Laden der Daten: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Lädt die Technikerliste
  Future<void> _loadTechnicians() async {
    try {
      setState(() => _isLoading = true);

      print('Starte Laden der Techniker...'); // Debug

      // Techniker laden
      final technicians = await userService.getUsersByRole(UserRole.technician);

      print('Geladene Techniker: ${technicians.length}'); // Debug

      if (mounted) {
        setState(() {
          _technicians = technicians;
          // Wenn Techniker geladen wurden, den ersten als Standard auswählen
          if (_technicians.isNotEmpty && _selectedTechnician == null) {
            _selectedTechnician = _technicians.first.id;
          }
        });
      }
    } catch (e) {
      print('Fehler beim Laden der Techniker: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Laden der Techniker: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Initialisiert das Formular mit existierenden Daten
  void _initializeExistingTask() {
    final task = widget.existingTask!;
    setState(() {
      _titleController.text = task.title;
      _descriptionController.text = task.description;
      _selectedMachineId = task.machineId;
      _selectedTechnician = task.assignedTo;
      _selectedInterval = task.interval;
      _nextDueDate = task.nextDue;
      _priority = task.priority;
      _isUrgent = task.priority == MaintenancePriority.urgent;
      _estimatedHours = task.estimatedDuration.inHours;
      _estimatedMinutes = task.estimatedDuration.inMinutes % 60;

      // Setze zuerst die Produktionslinie
      _selectedMachineLine = task.line;
      if (_selectedMachineLine == null || !ProductionLines.getAllLines().contains(_selectedMachineLine)) {
        // Fallback: Setze die erste verfügbare Linie
        _selectedMachineLine = ProductionLines.xLine;
        print('Warnung: Für task ${task.id} wurde keine gültige Linie gefunden, verwende Fallback');
      }
    });

    // Dann setze den Maschinentyp, aber erst nachdem setState aufgerufen wurde,
    // damit _machineTypes korrekt aktualisiert wird
    Future.microtask(() {
      setState(() {
        if (task.machineType != null && _machineTypes.contains(task.machineType)) {
          _selectedMachineType = task.machineType;
        } else {
          // Versuche den Typ aus der ID zu extrahieren
          _extractMachineTypeFromId(task.machineId);

          // Wenn immer noch kein Typ gefunden wurde, verwende den ersten verfügbaren
          if (_selectedMachineType == null && _machineTypes.isNotEmpty) {
            _selectedMachineType = _machineTypes.first;
            print('Warnung: Für task ${task.id} wurde kein gültiger Maschinentyp gefunden, verwende Fallback');
          }
        }
      });
    });
  }

  // Hilfsmethode um Maschinentyp aus der ID zu extrahieren
  void _extractMachineTypeFromId(String machineId) {
    // Prüfe alle möglichen Maschinentypen
    for (final type in _machineTypes) {
      if (machineId.toLowerCase().contains(type.toLowerCase())) {
        _selectedMachineType = type;
        return;
      }
    }
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTitleField(),
              const SizedBox(height: 16),
              _buildDescriptionField(),
              const SizedBox(height: 16),

              // Produktionslinie Auswahl
              DropdownButtonFormField<String>(
                value: _selectedMachineLine,
                decoration: const InputDecoration(
                  labelText: 'Produktionslinie',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.linear_scale),
                ),
                items: ProductionLines.getAllLines().map((line) {
                  return DropdownMenuItem<String>(
                    value: line,
                    child: Text(line),
                  );
                }).toList(),
                validator: (value) {
                  if (value == null) {
                    return 'Bitte wählen Sie eine Produktionslinie';
                  }
                  return null;
                },
                onChanged: (value) {
                  setState(() {
                    _selectedMachineLine = value;
                    // Maschinentyp zurücksetzen, weil sich die Liste ändern könnte
                    _selectedMachineType = null;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Maschinentyp Auswahl (basierend auf der Linie)
              if (_selectedMachineLine != null) ... [
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
                      return 'Bitte wählen Sie einen Maschinentyp';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    setState(() => _selectedMachineType = value);
                  },
                ),
                const SizedBox(height: 16),
              ],

              _buildIntervalDropdown(),
              const SizedBox(height: 16),
              _buildDurationFields(),
              const SizedBox(height: 16),
              _buildTechnicianDropdown(),
              const SizedBox(height: 16),
              _buildDatePicker(),
              const SizedBox(height: 16),
              _buildUrgentSwitch(),
              const SizedBox(height: 24),
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  // Widget für das Titelfeld
  Widget _buildTitleField() {
    return TextFormField(
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
    );
  }

  // Widget für das Beschreibungsfeld
  Widget _buildDescriptionField() {
    return TextFormField(
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
    );
  }

  // Widget für die Technikerauswahl
  Widget _buildTechnicianDropdown() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Zuständiger Techniker',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedTechnician,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: _technicians.map((technician) => DropdownMenuItem(
                value: technician.id,
                child: Row(
                  children: [
                    const Icon(Icons.engineering, size: 20),
                    const SizedBox(width: 8),
                    Text(technician.username),
                  ],
                ),
              )).toList(),
              onChanged: (value) {
                setState(() => _selectedTechnician = value);
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Bitte wählen Sie einen Techniker aus';
                }
                return null;
              },
            ),
            if (_technicians.isEmpty) ...[
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange),
                  SizedBox(width: 8),
                  Text(
                    'Keine Techniker verfügbar',
                    style: TextStyle(color: Colors.orange),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Widget für die Intervallauswahl
  Widget _buildIntervalDropdown() {
    return DropdownButtonFormField<MaintenanceInterval>(
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
    );
  }

  // Widget für die Dauerauswahl
  Widget _buildDurationFields() {
    return Row(
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
    );
  }

  // Widget für die Datumsauswahl
  Widget _buildDatePicker() {
    return ListTile(
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
    );
  }

  // Widget für den Dringend-Switch
  Widget _buildUrgentSwitch() {
    return SwitchListTile(
      title: const Text('Dringend'),
      subtitle: const Text('Als dringende Aufgabe markieren'),
      value: _isUrgent,
      onChanged: (value) {
        setState(() => _isUrgent = value);
      },
      secondary: const Icon(Icons.priority_high),
    );
  }

  // Widget für den Speichern-Button
  Widget _buildSaveButton() {
    return SizedBox(
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
    );
  }

  // Hilfsmethode für die Formatierung des Datums
  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }

  // Hilfsmethode für die Intervall-Texte
  String _getIntervalText(MaintenanceInterval interval) {
    return switch (interval) {
      MaintenanceInterval.daily => 'Täglich',
      MaintenanceInterval.weekly => 'Wöchentlich',
      MaintenanceInterval.monthly => 'Monatlich',
      MaintenanceInterval.quarterly => 'Vierteljährlich',
      MaintenanceInterval.yearly => 'Jährlich',
    };
  }

  // Speichern der Aufgabe
  // Änderungen in planner_form.dart
  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) return;

    // Zusätzliche Validierung für Maschinenauswahl
    if (_selectedMachineLine == null) {
      _showError('Bitte wählen Sie eine Produktionslinie aus');
      return;
    }
    if (_selectedMachineType == null) {
      _showError('Bitte wählen Sie einen Maschinentyp aus');
      return;
    }

    // Validiere Technikerauswahl
    if (_selectedTechnician == null) {
      _showError('Bitte wählen Sie einen Techniker aus');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Generiere eine eindeutige Maschinen-ID aus den ausgewählten Werten
      // mit einem Zeitstempel für Eindeutigkeit
      final String machineId = widget.existingTask?.machineId ??
          'machine-${_selectedMachineLine?.replaceAll(' ', '-')}-${_selectedMachineType?.replaceAll(' ', '-')}-${DateTime.now().millisecondsSinceEpoch}';

      // Debug-Ausgabe
      print('Speichere Task mit folgenden Daten:');

      // Eindeutige Task-ID für neue Aufgaben sicherstellen
      final taskId = widget.existingTask?.id ?? 'task-${DateTime.now().millisecondsSinceEpoch}';

      final taskData = {
        "id": taskId,
        "title": _titleController.text.trim(),
        "description": _descriptionController.text.trim(),
        "machine_id": machineId,
        "assigned_to": _selectedTechnician,
        "due_date": _nextDueDate.toIso8601String(),
        "status": widget.existingTask?.status.toString().split('.').last.toLowerCase() ?? "pending",
        "priority": _isUrgent ? "urgent" : "medium", // Vereinfachte Priorität
        "maintenance_int": _selectedInterval.toString().split('.').last.toLowerCase(),
        "estimated_duration": (_estimatedHours * 60) + _estimatedMinutes,
        "created_at": DateTime.now().toIso8601String(),
        "machine_line": _selectedMachineLine,
        "machine_type": _selectedMachineType
      };

      print('Task Daten: $taskData');

      // Verwende korrekte URL basierend auf neuer oder bestehender Aufgabe
      final String url = widget.existingTask != null
          ? '${ApiConfig.baseUrl}/maintenance/tasks/${widget.existingTask!.id}'
          : '${ApiConfig.baseUrl}/maintenance/tasks';

      // Verwende korrekte HTTP-Methode
      final String method = widget.existingTask != null ? 'PUT' : 'POST';

      // API-Aufruf
      final response = await ApiConfig.sendRequest(
        url: url,
        method: method,
        body: jsonEncode(taskData),
      );

      print('Server Antwort Status: ${response.statusCode}');
      print('Server Antwort Body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.existingTask != null
                  ? 'Aufgabe erfolgreich aktualisiert'
                  : 'Aufgabe erfolgreich erstellt'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        final Map<String, dynamic> errorData =
        jsonDecode(response.body);
        throw Exception('Server Error: ${response.statusCode}\n${errorData['error'] ?? 'Unbekannter Fehler'}');
      }
    } catch (e) {
      print('Fehler beim Speichern: $e');
      _showError('Fehler: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Hilfsmethode zum Anzeigen von Fehlern
  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}