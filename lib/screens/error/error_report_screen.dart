// error_report_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:universal_html/html.dart' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../utils/machine_constants.dart';
import '../../utils/error_categories.dart';
import '../../services/notification_service.dart';
import '../../services/theme_service.dart';
import '../../services/error_report_service.dart';
import '../../services/user_service.dart';
import '../../main.dart' show userService;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class ErrorReportScreen extends StatefulWidget {
  const ErrorReportScreen({
    Key? key,
    this.machineInfo,
  }) : super(key: key);

  final Map<String, dynamic>? machineInfo;

  @override
  State<ErrorReportScreen> createState() => _ErrorReportScreenState();
}

class _ErrorReportScreenState extends State<ErrorReportScreen> {
  late final UserService _userService;

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _errorReportService = ErrorReportService();
  final ImagePicker _imagePicker = ImagePicker();
  List<XFile> _imageFiles = [];

  bool _isLoading = false;
  bool _isUrgent = false;
  String? _selectedMachineLine;
  String? _selectedMachineType;
  String? _selectedMainCategory;
  String? _selectedSubcategory;

  List<String> _comments = [];

  Future<bool> _checkAndRequestPermission(Permission permission) async {
    final status = await permission.status;
    if (status.isGranted) {
      return true;
    }

    final result = await permission.request();
    return result.isGranted;
  }
  // Getter für Produktionslinien und Kategorien
  List<String> get _machineLines => ProductionLines.getAllLines();

  List<String> get _subcategories =>
      _selectedMainCategory != null
          ? ErrorCategories.getSubcategories(_selectedMainCategory!)
          : [];

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
    if (widget.machineInfo != null) {
      final availableLines = ProductionLines.getAllLines();

      setState(() {
        // Setze als Default die erste verfügbare Linie
        _selectedMachineLine = widget.machineInfo!['line'] != null &&
            availableLines.contains(widget.machineInfo!['line'])
            ? widget.machineInfo!['line']
            : ProductionLines.xLine;  // Immer einen gültigen Default-Wert verwenden

        _titleController.text = widget.machineInfo!['name'] ??
            'Problem mit: ${widget.machineInfo!['type'] ?? 'Unbekannte Maschine'}';
        _locationController.text = widget.machineInfo!['location'] ?? '';
      });
    } else {
      // Wenn keine Maschineninformationen vorhanden sind, setze Default-Werte
      setState(() {
        _selectedMachineLine = ProductionLines.xLine;
      });
    }
  }
  Future<void> _pickImage() async {
    try {
      // Prüfe Galerie-Berechtigung
      if (!kIsWeb) {  // Nicht nötig für Web
        final hasPermission = await _checkAndRequestPermission(Permission.storage);
        if (!hasPermission) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Galerie-Berechtigung erforderlich')),
            );
          }
          return;
        }
      }

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Auswählen des Bildes: $e')),
        );
      }
    }
  }

  // Bild aus der Liste entfernen
  void _removeImage(int index) {
    setState(() {
      _imageFiles.removeAt(index);
    });
  }

  Future<void> _takePhoto() async {
    try {
      // Prüfe Kamera-Berechtigung
      if (!kIsWeb) {  // Nicht nötig für Web
        final hasPermission = await _checkAndRequestPermission(Permission.camera);
        if (!hasPermission) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Kamera-Berechtigung erforderlich')),
            );
          }
          return;
        }
      }

      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70, // Komprimierung für bessere Performance
        maxWidth: 1920,   // Maximale Breite begrenzen
        maxHeight: 1080,  // Maximale Höhe begrenzen
      );

      if (photo != null) {
        setState(() {
          _imageFiles.add(photo);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Aufnehmen des Fotos: $e')),
        );
      }
    }
  }
  Future<void> _saveErrorReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    List<String> imageBase64List = [];
    for (var image in _imageFiles) {
      final bytes = await image.readAsBytes();
      final base64 = base64Encode(bytes);
      imageBase64List.add(base64);
    }

    try {
      final currentUser = userService.currentUser;
      final errorReport = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'machine_id': widget.machineInfo?['id'] ?? 'UNKNOWN',
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'machine_type': _selectedMachineType,
        'line': _selectedMachineLine,
        'category': _selectedMainCategory,
        'subcategory': _selectedSubcategory,
        'location': _locationController.text.trim(),
        'isUrgent': _isUrgent,
        'status': 'new',
        'created_by': currentUser?.id ?? 'UNKNOWN_USER',
        'createdAt': DateTime.now().toIso8601String(),
        'images': imageBase64List,
      };

      final success = await _errorReportService.saveErrorReport(errorReport);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fehlermeldung wurde erfolgreich gespeichert'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
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
  Widget _buildImagePreview() {
    if (_imageFiles.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ausgewählte Bilder:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _imageFiles.length,
            itemBuilder: (context, index) {
              return Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: kIsWeb
                        ? Image.network(
                      _imageFiles[index].path,
                      height: 100,
                      width: 100,
                      fit: BoxFit.cover,
                    )
                        : Image.file(
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
                      icon: const Icon(Icons.remove_circle),
                      color: Colors.red,
                      onPressed: () => _removeImage(index),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }




  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fehler melden'),
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.blue[800],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.pushNamed(context, '/scanner');
                  if (result != null && mounted) {
                    setState(() {
                      final machineInfo = result as Map<String, dynamic>;
                      _selectedMachineLine = machineInfo['line'];
                      _selectedMachineType = machineInfo['type'];
                      _locationController.text = machineInfo['location'] ?? '';
                      _titleController.text =
                      'Problem mit: ${machineInfo['name']}';
                    });
                  }
                },
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('QR-Code scannen'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Titel der Fehlermeldung',
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
              DropdownButtonFormField<String>(
                value: _selectedMachineLine,
                decoration: const InputDecoration(
                  labelText: 'Produktionslinie',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.linear_scale),
                ),
                items: _machineLines.map((String line) {
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
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedMachineLine = newValue;
                    _selectedMachineType = null;
                  });
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedMachineType,
                decoration: const InputDecoration(
                  labelText: 'Maschinentyp',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.precision_manufacturing),
                ),
                items: _machineTypes.map((String type) {
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
                onChanged: (String? newValue) {
                  setState(() => _selectedMachineType = newValue);
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedMainCategory,
                decoration: const InputDecoration(
                  labelText: 'Fehlerkategorie',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: ErrorCategories.getMainCategories().map((String category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                validator: (value) {
                  if (value == null) {
                    return 'Bitte wählen Sie eine Kategorie';
                  }
                  return null;
                },
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedMainCategory = newValue;
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
                    prefixIcon: Icon(Icons.subdirectory_arrow_right),
                  ),
                  items: _subcategories.map((String subcategory) {
                    return DropdownMenuItem<String>(
                      value: subcategory,
                      child: Text(subcategory),
                    );
                  }).toList(),
                  validator: (value) {
                    if (value == null) {
                      return 'Bitte wählen Sie eine Unterkategorie';
                    }
                    return null;
                  },
                  onChanged: (String? newValue) {
                    setState(() => _selectedSubcategory = newValue);
                  },
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Standort',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Bitte geben Sie einen Standort ein';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Beschreibung des Problems',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Bitte beschreiben Sie das Problem';
                  }
                  return null;
                },
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
              _buildImagePreview(),

              const SizedBox(height: 16),
              if (_imageFiles.isNotEmpty)
                Column(
                  children: [
                    const Text(
                      'Aufgenommene Bilder:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _imageFiles.length,
                        itemBuilder: (context, index) =>
                            _buildImagePreview(),
                      ),
                    ),
                  ],
                ),
              Card(
                child: SwitchListTile(
                  title: const Text('Dringend'),
                  subtitle: const Text('Markieren Sie dies als dringenden Fall'),
                  value: _isUrgent,
                  activeColor: Colors.red,
                  onChanged: (bool value) {
                    setState(() => _isUrgent = value);
                  },
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveErrorReport,
                icon: _isLoading
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
                  _isLoading ? 'Wird gespeichert...' : 'Fehlermeldung speichern',
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
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
    super.dispose();
  }
}