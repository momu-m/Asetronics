// manual_upload_dialog.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../../services/manual_service.dart';
import '../../utils/machine_constants.dart';
import 'package:universal_html/html.dart' as html;

class ManualUploadDialog extends StatefulWidget {
  const ManualUploadDialog({Key? key}) : super(key: key);

  @override
  State<ManualUploadDialog> createState() => _ManualUploadDialogState();
}

class _ManualUploadDialogState extends State<ManualUploadDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedFileName;
  String? _selectedCategory;
  String? _selectedMachineType;
  String? _selectedLine;
  String? _serialNumber;
  Uint8List? _fileBytes;
  bool _isLoading = false;
  bool _fileSelected = false;
  String? _errorMessage;

  // Liste der möglichen Kategorien
  final List<String> _categories = [
    'Bedienungsanleitung',
    'Wartungshandbuch',
    'Fehlerdiagnose',
    'Schaltpläne',
    'Sonstiges',
  ];

  @override
  void initState() {
    super.initState();
    // Kategorien initialisieren
  }

  Future<void> _pickFile() async {
    try {
      setState(() {
        _errorMessage = null;
        _fileSelected = false;
      });

      if (kIsWeb) {
        // Web-Implementierung
        final input = html.FileUploadInputElement();
        input.accept = '.pdf';
        input.click();

        await input.onChange.first;
        if (input.files != null && input.files!.isNotEmpty) {
          final file = input.files![0];
          if (!file.name.toLowerCase().endsWith('.pdf')) {
            setState(() {
              _errorMessage = 'Bitte nur PDF-Dateien auswählen';
            });
            return;
          }

          final reader = html.FileReader();
          reader.readAsArrayBuffer(file);

          await reader.onLoad.first;
          setState(() {
            _selectedFileName = file.name;
            _fileBytes = reader.result as Uint8List;
            _fileSelected = true;
          });
        }
      } else {
        // Mobile/Desktop-Implementierung
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
        );

        if (result != null) {
          if (result.files.single.path != null) {
            // Mobil/Desktop: Datei aus Pfad lesen
            final path = result.files.single.path!;
            final file = File(path);
            setState(() {
              _selectedFileName = result.files.single.name;
              _fileBytes = file.readAsBytesSync();
              _fileSelected = true;
            });
          } else if (result.files.single.bytes != null) {
            // Web-Fallback
            setState(() {
              _selectedFileName = result.files.single.name;
              _fileBytes = result.files.single.bytes!;
              _fileSelected = true;
            });
          }
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Fehler beim Dateiauswahl: $e';
      });
    }
  }

  Future<void> _saveManual() async {
    // Formularvalidierung
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_fileBytes == null || _selectedFileName == null) {
      setState(() {
        _errorMessage = 'Bitte wählen Sie eine PDF-Datei aus';
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final manualService = Provider.of<ManualService>(context, listen: false);

      final success = await manualService.uploadManual(
        title: _titleController.text,
        description: _descriptionController.text,
        machineType: _selectedMachineType ?? '',
        fileBytes: _fileBytes!,
        fileName: _selectedFileName!,
        category: _selectedCategory,
        line: _selectedLine,
        serialNumber: _serialNumber,
      );

      if (success) {
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Anleitung erfolgreich hochgeladen'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = manualService.errorMessage ?? 'Unbekannter Fehler beim Hochladen';
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Fehler beim Hochladen: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Titel
                Center(
                  child: Text(
                    'Anleitung hochladen',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 24),

                // Fehlermeldung
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade700)),
                        ),
                      ],
                    ),
                  ),

                // Titel-Feld
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Titel der Anleitung*',
                    hintText: 'z.B. Bedienungshandbuch SIPLACE SX2',
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

                // Beschreibung-Feld
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Beschreibung',
                    hintText: 'Kurze Beschreibung des Inhalts...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                  ),
                ),
                const SizedBox(height: 16),

                // Maschinentyp-Feld
                DropdownButtonFormField<String>(
                  value: _selectedMachineType,
                  decoration: const InputDecoration(
                    labelText: 'Maschinentyp*',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.precision_manufacturing),
                  ),
                  items: [
                    ...MachineCategories.placerTypes,
                    ...MachineCategories.printerTypes,
                    ...MachineCategories.ovenTypes,
                    ...MachineCategories.inspectionTypes,
                  ].map((type) => DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  )).toList(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Bitte wählen Sie einen Maschinentyp';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    setState(() {
                      _selectedMachineType = value;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Kategorie-Feld
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Kategorie',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: _categories.map((category) => DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  )).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Linie-Feld
                DropdownButtonFormField<String>(
                  value: _selectedLine,
                  decoration: const InputDecoration(
                    labelText: 'Produktionslinie',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.linear_scale),
                  ),
                  items: ProductionLines.getAllLines().map((line) => DropdownMenuItem(
                    value: line,
                    child: Text(line),
                  )).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedLine = value;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Seriennummer-Feld
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Seriennummer',
                    hintText: 'Optionale Angabe der Seriennummer',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.confirmation_number),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _serialNumber = value;
                    });
                  },
                ),
                const SizedBox(height: 24),

                // Dateiauswahl-Bereich
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PDF-Datei*',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      // Status der ausgewählten Datei
                      if (_fileSelected && _selectedFileName != null)
                        Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Datei ausgewählt:',
                                      style: TextStyle(
                                        color: Colors.green.shade700,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      _selectedFileName!,
                                      style: TextStyle(color: Colors.green.shade700),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    _selectedFileName = null;
                                    _fileBytes = null;
                                    _fileSelected = false;
                                  });
                                },
                                tooltip: 'Datei entfernen',
                              ),
                            ],
                          ),
                        ),
                      // Datei-Upload-Button
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: _pickFile,
                          icon: const Icon(Icons.upload_file),
                          label: Text(_fileSelected ? 'Andere Datei wählen' : 'PDF auswählen'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            minimumSize: const Size(200, 45),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      child: const Text('Abbrechen'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveManual,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Text('Hochladen'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}