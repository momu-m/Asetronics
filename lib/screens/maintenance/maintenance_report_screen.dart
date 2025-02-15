// maintenance_report_screen.dart
import 'package:flutter/material.dart';
import '../../config/api_config.dart';
import '../../main.dart' show databaseService, userService;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';



class MaintenanceReportScreen extends StatefulWidget {
  const MaintenanceReportScreen({Key? key}) : super(key: key);

  @override
  _MaintenanceReportScreenState createState() => _MaintenanceReportScreenState();
}

class _MaintenanceReportScreenState extends State<MaintenanceReportScreen> {
  // Formular-Key für Validierung
  final _formKey = GlobalKey<FormState>();

  // Controller für die Eingabefelder
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _workedTimeController = TextEditingController();
  final _partsUsedController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  List<XFile> _selectedImages = [];

  // Status-Variablen
  String? _selectedMachineType;
  bool _isSaving = false;
  DateTime _dateTime = DateTime.now();

  // Liste der Maschinentypen
  final List<String> _machineTypes = [
    'Bestückungsautomat',
    'Lötofen',
    'ICT Testsystem',
    'AOI System',
    'Andere'
  ];

  // Speichert den Wartungsbericht
  Future<void> _saveMaintenanceReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // Bilder in Base64 konvertieren
      List<String> imageBase64List = [];
      for (var image in _selectedImages) {
        final bytes = await image.readAsBytes();
        final base64 = base64Encode(bytes);
        imageBase64List.add(base64);
      }

      // Berichtsdaten vorbereiten
      final reportData = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'title': _titleController.text.trim(),
        'machine_type': _selectedMachineType,
        'description': _descriptionController.text.trim(),
        'worked_time': int.tryParse(_workedTimeController.text) ?? 0,
        'parts_used': _partsUsedController.text.trim(),
        'date': _dateTime.toIso8601String(),
        'created_by': userService.currentUser?.id ?? 'unknown',
        'images': imageBase64List,
      };

      // Verwendung von ApiConfig für den Request
      final response = await ApiConfig.sendRequest(
        url: '${ApiConfig.baseUrl}/maintenance/reports',
        method: 'POST',
        body: jsonEncode(reportData),
      );

      if (response.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bericht wurde erfolgreich gespeichert'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        throw Exception('Fehler beim Speichern: ${response.body}');
      }
    } catch (e) {
      print('Fehler beim Speichern des Berichts: $e');
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
        setState(() => _isSaving = false);
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wartungsbericht erstellen'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Datum Auswahl
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today),
                      const SizedBox(width: 16),
                      Text(
                        'Datum: ${_dateTime.day}.${_dateTime.month}.${_dateTime.year}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _dateTime,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2025),
                          );
                          if (date != null) {
                            setState(() => _dateTime = date);
                          }
                        },
                        child: const Text('Ändern'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Titel
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Titel des Berichts',
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

              // Maschinentyp
              DropdownButtonFormField<String>(
                value: _selectedMachineType,
                decoration: const InputDecoration(
                  labelText: 'Maschinentyp',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.precision_manufacturing),
                ),
                items: _machineTypes.map((String type) {
                  return DropdownMenuItem(
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
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedMachineType = newValue;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Beschreibung der durchgeführten Arbeiten
              TextFormField(
                controller: _descriptionController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Beschreibung der durchgeführten Arbeiten',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Bitte beschreiben Sie die durchgeführten Arbeiten';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Arbeitszeit
              TextFormField(
                controller: _workedTimeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Arbeitszeit (in Minuten)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.timer),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Bitte geben Sie die Arbeitszeit ein';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Bitte geben Sie eine gültige Zahl ein';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Verwendete Ersatzteile
              TextFormField(
                controller: _partsUsedController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Verwendete Ersatzteile',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.build),
                  alignLabelWithHint: true,
                ),
              ),

              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _takePhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Foto aufnehmen'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Aus Galerie'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Speichern Button
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveMaintenanceReport,
                  icon: _isSaving
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Icon(Icons.save),
                  label: Text(
                    _isSaving ? 'Wird gespeichert...' : 'Bericht speichern',
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
// Foto aufnehmen
  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
      );

      if (photo != null) {
        setState(() {
          _selectedImages.add(photo);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Aufnehmen des Fotos: $e')),
      );
    }
  }

// Foto aus Galerie auswählen
  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (image != null) {
        setState(() {
          _selectedImages.add(image);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Auswählen des Bildes: $e')),
      );
    }
  }
  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _workedTimeController.dispose();
    _partsUsedController.dispose();
    super.dispose();
  }
}