// planner_form.dart
import 'package:flutter/material.dart';
import '../../../config/api_config.dart';
import '../../../models/maintenance_schedule.dart';
import '../../../models/task_model.dart';
import '../../../models/user_role.dart';
import '../../../main.dart' show userService, maintenanceScheduleService;
import 'package:http/http.dart' as http;
import 'dart:convert';




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
  List<Map<String, dynamic>> _machines = [];
  List<User> _technicians = [];
  MaintenanceInterval _selectedInterval = MaintenanceInterval.monthly;
  DateTime _nextDueDate = DateTime.now().add(const Duration(days: 1));
  int _estimatedHours = 1;
  int _estimatedMinutes = 0;
  bool _isUrgent = false;
  TaskPriority _priority = TaskPriority.normal;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  // Lädt alle benötigten Daten beim Start
  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      // Lade Maschinen
      await _loadMachines();
      // Lade Techniker
      await _loadTechnicians();

      // Wenn existierende Aufgabe, lade deren Daten
      if (widget.existingTask != null) {
        _initializeExistingTask();
      }
    } catch (e) {
      print('Fehler beim Laden der Daten: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Lädt die Maschinenliste
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
          SnackBar(
            content: Text('Fehler beim Laden der Techniker: $e'),
            backgroundColor: Colors.red,
          ),
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
      _estimatedHours = task.estimatedDuration.inHours;
      _estimatedMinutes = task.estimatedDuration.inMinutes % 60;
    });
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
              _buildMachineDropdown(),
              const SizedBox(height: 16),
              _buildTechnicianDropdown(),
              const SizedBox(height: 16),
              _buildIntervalDropdown(),
              const SizedBox(height: 16),
              _buildDurationFields(),
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

  // Widget für die Maschinenauswahl
  Widget _buildMachineDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedMachineId,
      decoration: const InputDecoration(
        labelText: 'Maschine',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.precision_manufacturing),
      ),
      items: _machines.map((machine) {
        return DropdownMenuItem(
          value: machine['id'].toString(),
          child: Text('${machine['name']} (${machine['type']})'),
        );
      }).toList(),
      validator: (value) {
        if (value == null) return 'Bitte wählen Sie eine Maschine';
        return null;
      },
      onChanged: (value) {
        setState(() => _selectedMachineId = value);
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
  Widget _buildPriorityDropdown() {
    return DropdownButtonFormField<TaskPriority>(
      value: _priority,
      decoration: const InputDecoration(
        labelText: 'Priorität',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.flag),
      ),
      items: TaskPriority.values.map((priority) {
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
        secondary: Icon(Icons.priority_high),

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

  // Hilfsmethode für die Prioritäts-Texte
  String _getPriorityText(TaskPriority priority) {
    return switch (priority) {
      TaskPriority.low => 'Niedrig',
      TaskPriority.normal => 'Normal',
      TaskPriority.high => 'Hoch',
      TaskPriority.urgent => 'Dringend',
      // TODO: Handle this case.
      TaskPriority.medium => throw UnimplementedError(),
    };
  }

  // Speichern der Aufgabe
// In _saveTask Methode von planner_form.dart
  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Debug-Ausgabe
      print('Speichere Task mit folgenden Daten:');
      final taskData = {
        "id": DateTime.now().millisecondsSinceEpoch.toString(),
        "title": _titleController.text.trim(),
        "description": _descriptionController.text.trim(),
        "machine_id": _selectedMachineId,
        "assigned_to": _selectedTechnician,
        "due_date": _nextDueDate.toIso8601String(),
        "status": "pending",
        "priority": _priority.toString().split('.').last.toLowerCase(),
        "maintenance_int": _selectedInterval.toString().split('.').last.toLowerCase(),
        "estimated_duration": (_estimatedHours * 60) + _estimatedMinutes,
        "created_at": DateTime.now().toIso8601String()
      };

      print('Task Daten: $taskData');

      // API-Aufruf mit korrektem Endpoint
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/maintenance/tasks'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(taskData),
      );

      print('Server Antwort Status: ${response.statusCode}');
      print('Server Antwort Body: ${response.body}');

      if (response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aufgabe erfolgreich erstellt'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        throw Exception('Server Error: ${response.statusCode}');
      }
    } catch (e) {
      print('Fehler beim Speichern: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}