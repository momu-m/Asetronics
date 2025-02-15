// task_detail_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../config/api_config.dart';
import '../../../models/task_model.dart';
import '../../../models/user_role.dart';
import '../../../main.dart' show maintenanceScheduleService, taskService, userService;
import '../../../models/maintenance_schedule.dart';  // Neu hinzugefügt

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
  dynamic _task;  // Kann Task oder MaintenanceTask sein
  User? _currentUser;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _currentUser = userService.currentUser;
    assert(taskService != null, 'taskService ist nicht initialisiert');
  }

  // Aktualisiert den Status einer Aufgabe
  Future<void> _updateTaskStatus(dynamic newStatus) async {
    setState(() => _isLoading = true);
    try {
      if (_task is Task) {
        await taskService.updateTaskStatus(_task.id, newStatus);
        setState(() {
          _task = _task.copyWith(status: newStatus);
        });
      } else if (_task is MaintenanceTask) {
        final updatedTask = _task.copyWith(status: newStatus);
        await maintenanceScheduleService.updateTask(updatedTask);
        setState(() {
          _task = updatedTask;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status wurde aktualisiert')),
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
  Future<void> _loadTaskDetails() async {
    try {
      setState(() => _isLoading = true);
      final response = await ApiConfig.sendRequest(
        url: '${ApiConfig.baseUrl}/tasks/${widget.task.id}',
        method: 'GET',
      );

      if (response.statusCode == 200) {
        setState(() {
          _task = Task.fromJson(jsonDecode(response.body));
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString(); // Fehler in Variable speichern
        _isLoading = false;
      });
    }
  }
  // Fügt ein Feedback hinzu
  Future<void> _addFeedback() async {
    if (_feedbackController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final feedback = TaskFeedback(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: _currentUser!.id,
        message: _feedbackController.text.trim(),
        createdAt: DateTime.now(),
      );

      if (_task is Task) {
        await taskService.addFeedback(_task.id, feedback);
      } else if (_task is MaintenanceTask) {
        // Implementiere Feedback für MaintenanceTask wenn nötig
      }

      if (mounted) {
        _feedbackController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Feedback wurde hinzugefügt')),
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

  // Bild aufnehmen oder auswählen
  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
      );

      if (image != null) {
        if (_task is Task) {
          await taskService.addImage(_task.id, image.path);
          setState(() {
            _task = _task.copyWith(
              images: List.from(_task.images)..add(image.path),
            );
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Bildupload: $e')),
        );
      }
    }
  }

  // Status-Auswahl-Dialog
  Future<void> _showStatusDialog() async {
    if (_task is Task) {
      final newStatus = await showDialog<TaskStatus>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Status ändern'),
          children: TaskStatus.values.map((status) => SimpleDialogOption(
            onPressed: () => Navigator.pop(context, status),
            child: Text(_getStatusText(status)),
          )).toList(),
        ),
      );

      if (newStatus != null && newStatus != _task.status) {
        await _updateTaskStatus(newStatus);
      }
    } else if (_task is MaintenanceTask) {
      final newStatus = await showDialog<MaintenanceTaskStatus>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Status ändern'),
          children: MaintenanceTaskStatus.values.map((status) => SimpleDialogOption(
            onPressed: () => Navigator.pop(context, status),
            child: Text(_getMaintenanceStatusText(status)),
          )).toList(),
        ),
      );

      if (newStatus != null && newStatus != _task.status) {
        await _updateTaskStatus(newStatus);
      }
    }
  }

  // UI-Hilfsmethoden
  String _getStatusText(TaskStatus status) {
    return switch (status) {
      TaskStatus.pending => 'Ausstehend',
      TaskStatus.in_progress => 'In Bearbeitung',
      TaskStatus.completed => 'Abgeschlossen',
      TaskStatus.blocked => 'Blockiert',
    };
  }

  String _getMaintenanceStatusText(MaintenanceTaskStatus status) {
    return switch (status) {
      MaintenanceTaskStatus.pending => 'Ausstehend',
      MaintenanceTaskStatus.inProgress => 'In Bearbeitung',
      MaintenanceTaskStatus.completed => 'Abgeschlossen',
      MaintenanceTaskStatus.overdue => 'Überfällig',
    };
  }

  Color _getStatusColor(dynamic status) {
    if (status is TaskStatus) {
      return switch (status) {
        TaskStatus.pending => Colors.orange,
        TaskStatus.in_progress => Colors.blue,
        TaskStatus.completed => Colors.green,
        TaskStatus.blocked => Colors.red,
      };
    } else if (status is MaintenanceTaskStatus) {
      return switch (status) {
        MaintenanceTaskStatus.pending => Colors.orange,
        MaintenanceTaskStatus.inProgress => Colors.blue,
        MaintenanceTaskStatus.completed => Colors.green,
        MaintenanceTaskStatus.overdue => Colors.red,
      };
    }
    return Colors.grey;
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!));
    }
    final bool canModifyTask = _task is Task ?
    taskService.canUserModifyTask(_currentUser!.id, _currentUser!.role, _task) :
    true;  // Für MaintenanceTask anpassen wenn nötig

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aufgabendetails'),
        actions: [
          if (canModifyTask) ...[
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: _showStatusDialog,
            ),
          ],
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
                  Icons.flag,
                  color: _getStatusColor(_task.status),
                ),
                title: const Text('Status'),
                subtitle: Text(_task is Task ?
                _getStatusText(_task.status) :
                _getMaintenanceStatusText(_task.status)
                ),
                trailing: _task is Task ? Text(
                  _task.priority == TaskPriority.urgent
                      ? 'DRINGEND'
                      : _task.priority.toString().split('.').last,
                  style: TextStyle(
                    color: _task.priority == TaskPriority.urgent
                        ? Colors.red
                        : null,
                    fontWeight: _task.priority == TaskPriority.urgent
                        ? FontWeight.bold
                        : null,
                  ),
                ) : null,
              ),
            ),
            const SizedBox(height: 16),

            // Details-Karte
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _task.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(_task.description),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16),
                        const SizedBox(width: 8),
                        Text('Fällig: ${_formatDate(_task is Task ? _task.deadline : _task.nextDue)}'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Bilder-Galerie (nur für Task)
            if (_task is Task && _task.images.isNotEmpty) ...[
              Text(
                'Bilder',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _task.images.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Image.network(
                      _task.images[index],
                      height: 100,
                      width: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Feedback-Sektion (nur für Task)
            if (_task is Task) ...[
              Text(
                'Feedback',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _feedbackController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Ihr Feedback',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Foto'),
                            onPressed: _pickImage,
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _addFeedback,
                            child: const Text('Feedback senden'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Feedback-Liste
              ..._task.feedback.map((feedback) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person),
                          const SizedBox(width: 8),
                          Text(
                            feedback.userId,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          Text(
                            _formatDate(feedback.createdAt),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(feedback.message),
                      if (feedback.images.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 100,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: feedback.images.length,
                            itemBuilder: (context, index) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Image.network(
                                feedback.images[index],
                                height: 100,
                                width: 100,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              )).toList(),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }
}