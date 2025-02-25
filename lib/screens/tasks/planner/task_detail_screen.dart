// task_detail_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../config/api_config.dart';
import '../../../models/task_model.dart';
import '../../../models/user_role.dart';
import '../../../main.dart' show maintenanceScheduleService, taskService, userService, notificationService;
import '../../../models/maintenance_schedule.dart';

import '../../../widgets/status_timeline_widget.dart';

class TaskDetailScreen extends StatefulWidget {
  final dynamic task; // Kann Task oder MaintenanceTask sein

  const TaskDetailScreen({
    Key? key,
    required this.task,
  }) : super(key: key);

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final _feedbackController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  dynamic _task; // Kann Task oder MaintenanceTask sein
  User? _currentUser;
  final ImagePicker _imagePicker = ImagePicker();
  List<XFile> _selectedImages = [];
  final List<TaskFeedback> _localFeedback = []; // Für neue Feedback-Einträge

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _currentUser = userService.currentUser;
    _loadTaskDetails();

    // Lokales Feedback mit dem vom Server synchronisieren
    if (_task is Task && _task.feedback.isNotEmpty) {
      _localFeedback.addAll(_task.feedback);
    }
  }

  // Aktualisierte Methode zum Laden der Aufgabendetails
  Future<void> _loadTaskDetails() async {
    try {
      setState(() => _isLoading = true);

      // Je nach Aufgabentyp verschiedene API-Endpunkte verwenden
      String endpoint;
      if (_task is Task) {
        endpoint = '${ApiConfig.baseUrl}/tasks/${_task.id}';
      } else if (_task is MaintenanceTask) {
        endpoint = '${ApiConfig.baseUrl}/maintenance/tasks/${_task.id}';
      } else {
        throw Exception('Unbekannter Aufgabentyp');
      }

      final response = await ApiConfig.sendRequest(
        url: endpoint,
        method: 'GET',
      );

      if (response.statusCode == 200) {
        setState(() {
          if (_task is Task) {
            _task = Task.fromJson(jsonDecode(response.body));
            _localFeedback.clear();
            _localFeedback.addAll(_task.feedback);
          } else if (_task is MaintenanceTask) {
            _task = MaintenanceTask.fromJson(jsonDecode(response.body));
          }
          _isLoading = false;
        });
      } else {
        throw Exception('Fehler beim Laden der Aufgabe: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  // Aktualisierter Status mit Benachrichtigung
  Future<void> _updateTaskStatus(dynamic newStatus) async {
    setState(() => _isLoading = true);
    try {
      if (_task is Task) {
        await taskService.updateTaskStatus(_task.id, newStatus);
        setState(() {
          _task = _task.copyWith(status: newStatus);
        });

        // Benachrichtigung senden
        await notificationService.showErrorNotification(
            'Status aktualisiert',
            'Die Aufgabe "${_task.title}" wurde auf ${_getStatusText(newStatus)}" gesetzt'
        );
      } else if (_task is MaintenanceTask) {
        final updatedTask = _task.copyWith(status: newStatus);
        await maintenanceScheduleService.updateTask(updatedTask);
        setState(() {
          _task = updatedTask;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Status wurde aktualisiert'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Automatisch Feedback mit Statusänderung erstellen
      if (_currentUser != null) {
        final statusFeedback = TaskFeedback(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          userId: _currentUser!.id,
          message: 'Status geändert zu: ${_getStatusText(newStatus)}',
          createdAt: DateTime.now(),
        );

        if (_task is Task) {
          await taskService.addFeedback(_task.id, statusFeedback);
          setState(() {
            _localFeedback.add(statusFeedback);
          });
        }
      }

    } catch (e) {
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

  // Verbesserte Feedback-Funktion mit optionalen Bildern
  Future<void> _addFeedback() async {
    if (_feedbackController.text.trim().isEmpty && _selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte geben Sie Text ein oder fügen Sie ein Bild hinzu')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Bilder in Base64 konvertieren
      List<String> imageStrings = [];
      for (var image in _selectedImages) {
        final bytes = await image.readAsBytes();
        final base64Image = base64Encode(bytes);
        imageStrings.add(base64Image);
      }

      final feedback = TaskFeedback(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: _currentUser!.id,
        message: _feedbackController.text.trim(),
        createdAt: DateTime.now(),
        images: imageStrings,
      );

      if (_task is Task) {
        await taskService.addFeedback(_task.id, feedback);
        setState(() {
          _localFeedback.add(feedback);
        });
      } else if (_task is MaintenanceTask) {
        // Implementiere Feedback für MaintenanceTask wenn nötig
        // Die API muss entsprechend angepasst werden
      }

      if (mounted) {
        _feedbackController.clear();
        setState(() {
          _selectedImages = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Feedback wurde hinzugefügt'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
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

  // Bild aufnehmen
  Future<void> _takePicture() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
      );

      if (image != null) {
        setState(() {
          _selectedImages.add(image);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Aufnehmen des Bildes: $e')),
        );
      }
    }
  }

  // Bild aus Galerie auswählen
  Future<void> _pickImage() async {
    try {
      final List<XFile>? images = await _imagePicker.pickMultiImage(
        imageQuality: 70,
      );

      if (images != null && images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Auswählen des Bildes: $e')),
        );
      }
    }
  }

  // Status-Dialog mit verbesserter UI
  Future<void> _showStatusDialog() async {
    if (_task is Task) {
      final newStatus = await showDialog<TaskStatus>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Status ändern'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: TaskStatus.values.map((status) =>
                  RadioListTile<TaskStatus>(
                    title: Text(_getStatusText(status)),
                    subtitle: Text(_getStatusDescription(status)),
                    value: status,
                    groupValue: _task.status,
                    activeColor: _getStatusColor(status),
                    onChanged: (value) => Navigator.pop(context, value),
                  ),
              ).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, _task.status),
              child: const Text('Speichern'),
            ),
          ],
        ),
      );

      if (newStatus != null && newStatus != _task.status) {
        await _updateTaskStatus(newStatus);
      }
    } else if (_task is MaintenanceTask) {
      final newStatus = await showDialog<MaintenanceTaskStatus>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Status ändern'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: MaintenanceTaskStatus.values.map((status) =>
                  RadioListTile<MaintenanceTaskStatus>(
                    title: Text(_getMaintenanceStatusText(status)),
                    subtitle: Text(_getMaintenanceStatusDescription(status)),
                    value: status,
                    groupValue: _task.status,
                    activeColor: _getMaintenanceStatusColor(status),
                    onChanged: (value) => Navigator.pop(context, value),
                  ),
              ).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, _task.status),
              child: const Text('Speichern'),
            ),
          ],
        ),
      );

      if (newStatus != null && newStatus != _task.status) {
        await _updateTaskStatus(newStatus);
      }
    }
  }

  // UI-Hilfsmethoden für Status
  String _getStatusText(TaskStatus status) {
    switch (status) {
      case TaskStatus.pending:
        return 'Ausstehend';
      case TaskStatus.in_progress:
        return 'In Bearbeitung';
      case TaskStatus.completed:
        return 'Abgeschlossen';
      case TaskStatus.blocked:
        return 'Blockiert';
    }
  }

  String _getStatusDescription(TaskStatus status) {
    switch (status) {
      case TaskStatus.pending:
        return 'Aufgabe wurde noch nicht begonnen';
      case TaskStatus.in_progress:
        return 'Aufgabe wird aktuell bearbeitet';
      case TaskStatus.completed:
        return 'Aufgabe wurde erfolgreich abgeschlossen';
      case TaskStatus.blocked:
        return 'Aufgabe ist blockiert und kann nicht fortgesetzt werden';
    }
  }

  String _getMaintenanceStatusText(MaintenanceTaskStatus status) {
    switch (status) {
      case MaintenanceTaskStatus.pending:
        return 'Ausstehend';
      case MaintenanceTaskStatus.inProgress:
        return 'In Bearbeitung';
      case MaintenanceTaskStatus.completed:
        return 'Abgeschlossen';
      case MaintenanceTaskStatus.overdue:
        return 'Überfällig';
      case MaintenanceTaskStatus.deleted:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
  }

  String _getMaintenanceStatusDescription(MaintenanceTaskStatus status) {
    switch (status) {
      case MaintenanceTaskStatus.pending:
        return 'Wartung steht noch aus';
      case MaintenanceTaskStatus.inProgress:
        return 'Wartung wird aktuell durchgeführt';
      case MaintenanceTaskStatus.completed:
        return 'Wartung wurde erfolgreich abgeschlossen';
      case MaintenanceTaskStatus.overdue:
        return 'Wartung ist überfällig und muss dringend durchgeführt werden';
      case MaintenanceTaskStatus.deleted:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
  }

  Color _getStatusColor(dynamic status) {
    if (status is TaskStatus) {
      switch (status) {
        case TaskStatus.pending:
          return Colors.orange;
        case TaskStatus.in_progress:
          return Colors.blue;
        case TaskStatus.completed:
          return Colors.green;
        case TaskStatus.blocked:
          return Colors.red;
      }
    } else if (status is MaintenanceTaskStatus) {
      return _getMaintenanceStatusColor(status);
    }
    return Colors.grey;
  }

  Color _getMaintenanceStatusColor(MaintenanceTaskStatus status) {
    switch (status) {
      case MaintenanceTaskStatus.pending:
        return Colors.orange;
      case MaintenanceTaskStatus.inProgress:
        return Colors.blue;
      case MaintenanceTaskStatus.completed:
        return Colors.green;
      case MaintenanceTaskStatus.overdue:
        return Colors.red;
      case MaintenanceTaskStatus.deleted:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd.MM.yyyy HH:mm').format(date);
  }

  // Prioritätstext formatieren
  String _getPriorityText(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return 'Niedrig';
      case TaskPriority.medium:
        return 'Mittel';
      case TaskPriority.high:
        return 'Hoch';
      case TaskPriority.urgent:
        return 'DRINGEND';
      case TaskPriority.normal:
        return 'Normal';
    }
  }

  // Prioritätsfarbe
  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return Colors.green;
      case TaskPriority.medium:
        return Colors.blue;
      case TaskPriority.high:
        return Colors.orange;
      case TaskPriority.urgent:
        return Colors.red;
      case TaskPriority.normal:
        return Colors.blue;
    }
  }

  // Interval-Text für Wartungsintervalle
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

  // Dauer formatieren
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) {
      return '$hours h ${minutes > 0 ? '$minutes min' : ''}';
    }
    return '$minutes min';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Fehler')),
        body: Center(child: Text(_errorMessage!)),
      );
    }

    final bool canModifyTask = _task is Task ?
    taskService.canUserModifyTask(_currentUser!.id, _currentUser!.role, _task) :
    true;  // Für MaintenanceTask anpassen wenn nötig

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aufgabendetails'),
        actions: [
          // Nur für berechtigte Benutzer
          if (canModifyTask)
            IconButton(
              icon: const Icon(Icons.edit_note),
              tooltip: 'Status ändern',
              onPressed: _showStatusDialog,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadTaskDetails,
        child: CustomScrollView(
          slivers: [
            // Header-Bereich mit Status
            SliverToBoxAdapter(
              child: _buildHeaderSection(),
            ),

            // Details-Bereich
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Details-Karte
                    _buildDetailsCard(),
                    const SizedBox(height: 16),

                    // Zeitleiste für den Status-Verlauf
                    if (_task is Task) ...[
                      const Text(
                        'Status-Verlauf',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      StatusTimelineWidget(feedback: _localFeedback),
                      const SizedBox(height: 16),
                    ],

                    // Bilder-Galerie (nur für Task)
                    if (_task is Task && _task.images.isNotEmpty) ...[
                      const Text(
                        'Bilder',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const SizedBox(height: 16),
                    ],

                    // Feedback-Eingabe (nur für Task)
                    if (_task is Task && canModifyTask)
                      _buildFeedbackSection(),

                    // Feedback-Liste
                    if (_task is Task && _localFeedback.isNotEmpty)
                      _buildFeedbackList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      // Floating Action Button für schnelle Aktionen
      floatingActionButton: canModifyTask ? _buildSpeedDial() : null,
    );
  }
// Füge diese Methode zur _TaskDetailScreenState Klasse hinzu
  Widget _buildFeedbackSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Neues Feedback hinzufügen',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _feedbackController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Ihre Rückmeldung hier eingeben...',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),

        // Ausgewählte Bilder anzeigen
        if (_selectedImages.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Ausgewählte Bilder:'),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      Image.file(
                        File(_selectedImages[index].path),
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedImages.removeAt(index);
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],

        const SizedBox(height: 8),
        Row(
          children: [
            // Foto-Buttons
            IconButton(
              icon: const Icon(Icons.camera_alt),
              tooltip: 'Foto aufnehmen',
              onPressed: _takePicture,
            ),
            IconButton(
              icon: const Icon(Icons.photo_library),
              tooltip: 'Aus Galerie auswählen',
              onPressed: _pickImage,
            ),
            const Spacer(),
            // Senden-Button
            ElevatedButton.icon(
              icon: const Icon(Icons.send),
              label: const Text('Feedback senden'),
              onPressed: _addFeedback,
            ),
          ],
        ),
      ],
    );
  }
  // Header mit Statuskarte
  Widget _buildHeaderSection() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final dynamic status = _task is Task ? _task.status : _task.status;
    final Color statusColor = _getStatusColor(status);
    final String statusText = _task is Task ?
    _getStatusText(_task.status) :
    _getMaintenanceStatusText(_task.status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusColor.withOpacity(0.8),
            isDarkMode ? Colors.grey[900]! : Colors.white,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titel mit Prioritätsmarkierung
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_task is Task && _task.priority == TaskPriority.urgent)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'DRINGEND',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(
                    _task.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Status-Chip
            Chip(
              label: Text(
                statusText,
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: statusColor.withOpacity(0.2),
              side: BorderSide(color: statusColor),
              avatar: CircleAvatar(
                backgroundColor: statusColor,
                radius: 12,
                child: Icon(
                  _getStatusIcon(status),
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),

            // Fälligkeitsdatum und Priorität
            if (_task is Task) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Fällig: ${_formatDate(_task.deadline)}',
                    style: TextStyle(
                      color: _task.deadline.isBefore(DateTime.now()) &&
                          _task.status != TaskStatus.completed ?
                      Colors.red : null,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.flag, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Priorität: ${_getPriorityText(_task.priority)}',
                    style: TextStyle(
                      color: _getPriorityColor(_task.priority),
                      fontWeight: _task.priority == TaskPriority.urgent ?
                      FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ],

            // Fälligkeitsdatum für Wartungsaufgaben
            if (_task is MaintenanceTask) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Nächste Fälligkeit: ${_formatDate(_task.nextDue)}',
                    style: TextStyle(
                      color: _task.isOverdue() &&
                          _task.status != MaintenanceTaskStatus.completed ?
                      Colors.red : null,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Icon für den Status
  IconData _getStatusIcon(dynamic status) {
    if (status is TaskStatus) {
      switch (status) {
        case TaskStatus.pending:
          return Icons.watch_later;
        case TaskStatus.in_progress:
          return Icons.engineering;
        case TaskStatus.completed:
          return Icons.check_circle;
        case TaskStatus.blocked:
          return Icons.block;
      }
    } else if (status is MaintenanceTaskStatus) {
      switch (status) {
        case MaintenanceTaskStatus.pending:
          return Icons.watch_later;
        case MaintenanceTaskStatus.inProgress:
          return Icons.engineering;
        case MaintenanceTaskStatus.completed:
          return Icons.check_circle;
        case MaintenanceTaskStatus.overdue:
          return Icons.warning;
        case MaintenanceTaskStatus.deleted:
          // TODO: Handle this case.
          throw UnimplementedError();
      }
    }
    return Icons.help_outline;
  }

  // Detailkarte
  Widget _buildDetailsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            const SizedBox(height: 8),

            // Beschreibung
            const Text(
              'Beschreibung:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(_task.description),
            const SizedBox(height: 16),

            // Zugewiesen an
            Row(
              children: [
                const Icon(Icons.person, size: 16),
                const SizedBox(width: 4),
                const Text(
                  'Zugewiesen an:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                FutureBuilder<String>(
                  future: userService.getUserName(_task is Task ?
                  _task.assignedToId :
                  _task.assignedTo ?? ''),
                  builder: (context, snapshot) {
                    return Text(snapshot.data ?? 'Laden...');
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Erstellt von
            if (_task is Task) ...[
              Row(
                children: [
                  const Icon(Icons.person_add, size: 16),
                  const SizedBox(width: 4),
                  const Text(
                    'Erstellt von:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  FutureBuilder<String>(
                    future: userService.getUserName(_task.createdById),
                    builder: (context, snapshot) {
                      return Text(snapshot.data ?? 'Laden...');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Erstellungsdatum
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16),
                  const SizedBox(width: 4),
                  const Text(
                    'Erstellt am:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Text(_formatDate(_task.createdAt)),
                ],
              ),
            ],

            // Wartungsspezifische Details
            if (_task is MaintenanceTask) ...[
              const SizedBox(height: 8),

              // Intervall
              Row(
                children: [
                  const Icon(Icons.repeat, size: 16),
                  const SizedBox(width: 4),
                  const Text(
                    'Intervall:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Text(_getIntervalText(_task.interval)),
                ],
              ),
              const SizedBox(height: 8),

              // Geschätzte Dauer
              Row(
                children: [
                  const Icon(Icons.timer, size: 16),
                  const SizedBox(width: 4),
                  const Text(
                    'Geschätzte Dauer:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Text(_formatDuration(_task.estimatedDuration)),
                ],
              ),

              // Letzte Durchführung
              if (_task.lastCompleted != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.history, size: 16),
                    const SizedBox(width: 4),
                    const Text(
                      'Letzte Durchführung:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Text(_formatDate(_task.lastCompleted!)),
                  ],
                ),
              ],

              // Benötigte Werkzeuge
              if (_task.requiredTools.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Benötigte Werkzeuge:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: _task.requiredTools.map((tool) =>
                      Chip(
                        label: Text(tool),
                        avatar: const Icon(Icons.build, size: 16),
                      )
                  ).toList(),
                ),
              ],

              // Benötigte Ersatzteile
              if (_task.requiredParts.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Benötigte Ersatzteile:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: _task.requiredParts.map((part) =>
                      Chip(
                        label: Text(part),
                        avatar: const Icon(Icons.settings, size: 16),
                      )
                  ).toList(),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
// Feedback-Liste anzeigen
  Widget _buildFeedbackList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Rückmeldungen',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: _localFeedback.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final feedback = _localFeedback[index];
            return _buildFeedbackItem(feedback);
          },
        ),
      ],
    );
  }

  // Einzelner Feedback-Eintrag
  Widget _buildFeedbackItem(TaskFeedback feedback) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Benutzer-Avatar
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.blue[100],
                  child: const Icon(Icons.person, size: 20, color: Colors.blue),
                ),
                const SizedBox(width: 8),

                // Benutzer und Zeitstempel
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FutureBuilder<String>(
                        future: userService.getUserName(feedback.userId),
                        builder: (context, snapshot) {
                          return Text(
                            snapshot.data ?? 'Unbekannter Benutzer',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          );
                        },
                      ),
                      Text(
                        _formatDate(feedback.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Nachricht
            if (feedback.message.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(feedback.message),
            ],

            // Bilder, falls vorhanden
            if (feedback.images.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: feedback.images.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () => _showFullScreenImage(feedback.images[index]),
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: MemoryImage(base64Decode(feedback.images[index])),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Vollbild-Anzeige für Bilder
  void _showFullScreenImage(String base64Image) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: EdgeInsets.zero,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            // Interaktives Bild mit Zoom
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.memory(
                base64Decode(base64Image),
                fit: BoxFit.contain,
              ),
            ),

            // Schließen-Button
            Positioned(
              top: 20,
              right: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Speed Dial für schnelle Aktionen
  Widget _buildSpeedDial() {
    return FloatingActionButton.extended(
      icon: const Icon(Icons.play_arrow),
      label: const Text('Starten'),
      onPressed: () {
        if (_task is Task) {
          _updateTaskStatus(TaskStatus.in_progress);
        } else if (_task is MaintenanceTask) {
          _updateTaskStatus(MaintenanceTaskStatus.inProgress);
        }
      },
      backgroundColor: Colors.green,
    );
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }
}
