import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../main.dart' show userService;
import '../../utils/error_categories.dart';
import '../../utils/machine_constants.dart';

class MaintenanceReportScreen extends StatefulWidget {
  const MaintenanceReportScreen({Key? key}) : super(key: key);

  @override
  _MaintenanceReportScreenState createState() => _MaintenanceReportScreenState();
}

class _MaintenanceReportScreenState extends State<MaintenanceReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _workedTimeController = TextEditingController();
  final _partsUsedController = TextEditingController();
  final List<String> _machineLines = ProductionLines.getAllLines();
  final ImagePicker _imagePicker = ImagePicker();
  List<XFile> _imageFiles = [];
  bool _isLoading = false;
  bool _isUrgent = false;
  DateTime _dateTime = DateTime.now();
  String? _selectedMachineType;
  String? _selectedCategory;
  String? _selectedSubcategory;
  String? _selectedMachineLine;
  String? _selectedMainCategory;

  final List<String> _machineTypes = [
    ...MachineCategories.placerTypes,
    ...MachineCategories.printerTypes,
    ...MachineCategories.ovenTypes,
    ...MachineCategories.inspectionTypes,
  ];

  final List<String> _mainCategories = ErrorCategories.getMainCategories();

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (photo != null) {
        setState(() {
          _imageFiles.add(photo);
        });
      }
    } catch (e) {
      _showErrorMessage('Fehler beim Aufnehmen des Fotos: $e');
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (image != null) {
        setState(() {
          _imageFiles.add(image);
        });
      }
    } catch (e) {
      _showErrorMessage('Fehler beim Auswählen des Bildes: $e');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _imageFiles.removeAt(index);
    });
  }

  Future<void> _saveMaintenanceReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      List<String> imageBase64List = [];
      for (var image in _imageFiles) {
        final bytes = await image.readAsBytes();
        final base64 = base64Encode(bytes);
        imageBase64List.add(base64);
      }

      final currentUser = userService.currentUser;

      final reportData = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'machine_type': _selectedMachineType,
        'worked_time': int.tryParse(_workedTimeController.text) ?? 0,
        'parts_used': _partsUsedController.text.trim(),
        'date': _dateTime.toIso8601String(),
        'created_by': currentUser?.id ?? 'unknown',
        'images': imageBase64List,
        'is_urgent': _isUrgent ? 1 : 0,
        'category': _selectedMainCategory,
        'subcategory': _selectedSubcategory,
        'line': _selectedMachineLine,
      };

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/maintenance/reports'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(reportData),
      );

      if (response.statusCode == 201) {
        _showSuccessMessage('Bericht erfolgreich gespeichert');
        Navigator.pop(context, true);
      } else {
        _showErrorMessage('Fehler beim Speichern: ${response.body}');
      }
    } catch (e) {
      _showErrorMessage('Fehler: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorMessage(String message) {
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
        title: const Text('Wartungsbericht erstellen'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Titel des Berichts',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Bitte Titel eingeben';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
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
                            lastDate: DateTime.now(),
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

              DropdownButtonFormField<String>(
                value: _selectedMachineType,
                decoration: const InputDecoration(
                  labelText: 'Maschinentyp',
                  border: OutlineInputBorder(),
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

              DropdownButtonFormField<String>(
                value: _selectedMainCategory,
                decoration: const InputDecoration(
                  labelText: 'Wartungskategorie',
                  border: OutlineInputBorder(),
                ),
                items: _mainCategories.map((category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                validator: (value) {
                  if (value == null) {
                    return 'Bitte Kategorie wählen';
                  }
                  return null;
                },
                onChanged: (value) {
                  setState(() {
                    _selectedMainCategory = value;
                    _selectedSubcategory = null;
                  });
                },
              ),
              const SizedBox(height: 16),

              if (_selectedMainCategory != null)
                DropdownButtonFormField<String>(
                  value: _selectedSubcategory,
                  decoration: const InputDecoration(
                    labelText: 'Unterkategorie',
                    border: OutlineInputBorder(),
                  ),
                  items: ErrorCategories.getSubcategories(_selectedMainCategory!).map((subcategory) {
                    return DropdownMenuItem<String>(
                      value: subcategory,
                      child: Text(subcategory),
                    );
                  }).toList(),
                  validator: (value) {
                    if (value == null) {
                      return 'Bitte Unterkategorie wählen';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    setState(() => _selectedSubcategory = value);
                  },
                ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Beschreibung der Arbeiten',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Bitte Beschreibung eingeben';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _workedTimeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Arbeitszeit (Minuten)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Bitte Arbeitszeit eingeben';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Bitte gültige Zahl eingeben';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _partsUsedController,
                decoration: const InputDecoration(
                  labelText: 'Verwendete Ersatzteile',
                  border: OutlineInputBorder(),
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
              const SizedBox(height: 16),

              if (_imageFiles.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ausgewählte Bilder:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _imageFiles.length,
                        itemBuilder: (context, index) {
                          return Stack(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Image.file(
                                  File(_imageFiles[index].path),
                                  height: 100,
                                  width: 100,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: IconButton(
                                  icon: const Icon(Icons.remove_circle, color: Colors.red),
                                  onPressed: () => _removeImage(index),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),

              SwitchListTile(
                title: const Text('Dringend'),
                subtitle: const Text('Markieren Sie dies als dringenden Bericht'),
                value: _isUrgent,
                onChanged: (bool value) {
                  setState(() => _isUrgent = value);
                },
              ),
              const SizedBox(height: 16),

              ElevatedButton(
                onPressed: _isLoading ? null : _saveMaintenanceReport,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Bericht speichern'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _workedTimeController.dispose();
    _partsUsedController.dispose();
    super.dispose();
  }
}