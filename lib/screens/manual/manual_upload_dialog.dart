import 'dart:io';
import 'dart:typed_data';  // Für Uint8List
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;

class ManualUploadDialog extends StatefulWidget {
  const ManualUploadDialog({super.key});  // Korrigiert den super parameter

  @override
  State<ManualUploadDialog> createState() => _ManualUploadDialogState();
}

class _ManualUploadDialogState extends State<ManualUploadDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _machineTypeController = TextEditingController();

  String? _selectedFileName;
  String? _selectedCategory;
  String? _selectedLine;
  String? _serialNumber;
  Uint8List? _fileBytes;  // Korrigierte Deklaration
  bool _showPreview = false;
  bool _isLoading = false;

  Future<void> _pickFile() async {
    try {
      if (kIsWeb) {
        final input = html.FileUploadInputElement();
        input.accept = '.pdf';
        input.click();

        await input.onChange.first;
        if (input.files!.isNotEmpty) {
          final file = input.files![0];
          final reader = html.FileReader();
          reader.readAsArrayBuffer(file);

          await reader.onLoad.first;
          setState(() {
            _selectedFileName = file.name;
            _fileBytes = reader.result as Uint8List;  // Korrigierte Variable
            _showPreview = true;
          });
        }
      } else {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
        );

        if (result != null) {
          setState(() {
            _selectedFileName = result.files.single.name;
            _fileBytes = result.files.single.bytes;  // Korrigierte Variable
            _showPreview = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Dateiauswahl: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _machineTypeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Anleitung hochladen',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Titel',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Bitte geben Sie einen Titel ein';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.upload_file),
                label: const Text('PDF auswählen'),
              ),
              if (_selectedFileName != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_selectedFileName!),
                ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Abbrechen'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveManual,
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
    );
  }

  Future<void> _saveManual() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte wählen Sie eine PDF-Datei aus')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Hier Ihre Speicherlogik implementieren
      // z.B. API-Aufruf oder lokale Speicherung

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Anleitung erfolgreich hochgeladen')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Hochladen: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}