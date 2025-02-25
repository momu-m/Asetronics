// lib/screens/tasks/personal/task_feedback_screen.dart

import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../models/task_model.dart';
import '../../../models/maintenance_schedule.dart';
import '../../../main.dart' show taskService, maintenanceScheduleService, userService;

class TaskFeedbackScreen extends StatefulWidget {
  final dynamic task; // Kann Task oder MaintenanceTask sein

  const TaskFeedbackScreen({
    Key? key,
    required this.task,
  }) : super(key: key);

  @override
  State<TaskFeedbackScreen> createState() => _TaskFeedbackScreenState();
}

class _TaskFeedbackScreenState extends State<TaskFeedbackScreen> {
  final _feedbackController = TextEditingController();
  bool _isLoading = false;
  dynamic _task; // Lokale Kopie der Aufgabe
  final ImagePicker _imagePicker = ImagePicker();
  XFile? _selectedImage;

  @override
  void initState() {
    super.initState();
    _task = widget.task;
  }

  // Bild aufnehmen
  Future<void> _takePicture() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70, // Reduzierte Qualität für kleinere Dateigröße
      );

      if (image != null) {
        setState(() {
          _selectedImage = image;
        });
      }
    } catch (e) {
      _showErrorMessage('Fehler beim Aufnehmen des Bildes: $e');
    }
  }

  // Bild aus Galerie wählen
  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (image != null) {
        setState(() {
          _selectedImage = image;
        });
      }
    } catch (e) {
      _showErrorMessage('Fehler beim Auswählen des Bildes: $e');
    }
  }

  // Feedback speichern und Status aktualisieren
  Future<void> _saveFeedbackAndComplete() async {
    if (_feedbackController.text.trim().isEmpty && _selectedImage == null) {
      _showErrorMessage('Bitte geben Sie einen Kommentar ein oder fügen Sie ein Bild hinzu');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Bild in Base64 konvertieren, falls vorhanden
      String? base64Image;
      if (_selectedImage != null) {
        final bytes = await _selectedImage!.readAsBytes();
        base64Image = base64Encode(bytes);
      }

      final currentUser = userService.currentUser;
      if (currentUser == null) {
        throw Exception('Kein angemeldeter Benutzer');
      }

      // Feedback erstellen
      final feedback = TaskFeedback(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: currentUser.id,
        message: _feedbackController.text.trim(),
        createdAt: DateTime.now(),
        images: base64Image != null ? [base64Image] : [],
      );

      // Je nach Aufgabentyp unterschiedliche Service-Methoden aufrufen
      if (_task is Task) {
        // 1. Feedback hinzufügen
        await taskService.addFeedback(_task.id, feedback);

        // 2. Status auf "completed" setzen
        await taskService.updateTaskStatus(_task.id, TaskStatus.completed);

        _showSuccessMessage('Aufgabe abgeschlossen und Rückmeldung gespeichert');
      }
      else if (_task is MaintenanceTask) {
        // Bei Wartungsaufgaben nur den Status aktualisieren
        await maintenanceScheduleService.completeTask(_task.id);
        _showSuccessMessage('Wartungsaufgabe abgeschlossen');
      }

      // Zurück zum vorherigen Bildschirm
      if (mounted) {
        Navigator.pop(context, true); // true bedeutet, dass eine Aktualisierung nötig ist
      }
    } catch (e) {
      _showErrorMessage('Fehler: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Hilfsmethoden für UI
  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _getStatusText(dynamic task) {
    if (task is Task) {
      return switch (task.status) {
        TaskStatus.pending => 'Ausstehend',
        TaskStatus.in_progress => 'In Bearbeitung',
        TaskStatus.completed => 'Abgeschlossen',
        TaskStatus.blocked => 'Blockiert',
      };
    } else if (task is MaintenanceTask) {
      return switch (task.status) {
        MaintenanceTaskStatus.pending => 'Ausstehend',
        MaintenanceTaskStatus.inProgress => 'In Bearbeitung',
        MaintenanceTaskStatus.completed => 'Abgeschlossen',
        MaintenanceTaskStatus.overdue => 'Überfällig',
        MaintenanceTaskStatus.deleted => 'Gelöscht',
      };
    }
    return 'Unbekannt';
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aufgabe abschließen'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Aufgabeninformationen
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _task is Task ? _task.title : _task.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _task is Task ? _task.description : _task.description,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const Divider(),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Fällig: ${_formatDate(_task is Task ? _task.deadline : _task.nextDue)}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.assignment_turned_in, size: 16),
                        const SizedBox(width: 4),
                        Text('Status: ${_getStatusText(_task)}'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Rückmeldungsabschnitt
            const Text(
              'Rückmeldung',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _feedbackController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Ihr Kommentar',
                hintText: 'Beschreiben Sie die durchgeführten Arbeiten...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Bildbereich
            if (_selectedImage != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Image.file(
                      File(_selectedImage!.path),
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete,
                        color: Colors.red,
                      ),
                      onPressed: () {
                        setState(() {
                          _selectedImage = null;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _takePicture,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Foto aufnehmen'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Aus Galerie'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 32),

            // Abschließen-Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveFeedbackAndComplete,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                  'Aufgabe abschließen',
                  style: TextStyle(fontSize: 16),
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
    _feedbackController.dispose();
    super.dispose();
  }
}