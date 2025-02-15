// problem_form_screen.dart
import 'package:flutter/material.dart';
import '../../models/problem_model.dart';
import '../../main.dart';
import '../../utils/machine_constants.dart';

class ProblemFormScreen extends StatefulWidget {
  final Problem? existingProblem; // Null für neues Problem

  const ProblemFormScreen({
    Key? key,
    this.existingProblem
  }) : super(key: key);

  @override
  State<ProblemFormScreen> createState() => _ProblemFormScreenState();
}

class _ProblemFormScreenState extends State<ProblemFormScreen> {
  // Formular-Key für Validierung
  final _formKey = GlobalKey<FormState>();

  // Text-Controller
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _symptomController = TextEditingController();
  final _solutionController = TextEditingController();
  final _partsController = TextEditingController();

  // Status-Variablen
  ProblemCategory _selectedCategory = ProblemCategory.mechanical;
  String? _selectedMachineType;
  List<String> _symptoms = [];
  List<String> _solutions = [];
  List<String> _relatedParts = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingProblem != null) {
      _initializeWithExistingProblem();
    }
  }

  // Initialisiert das Formular mit einem existierenden Problem
  void _initializeWithExistingProblem() {
    final problem = widget.existingProblem!;
    _titleController.text = problem.title;
    _descriptionController.text = problem.description;
    _selectedCategory = problem.category;
    _selectedMachineType = problem.machineType;
    _symptoms = List.from(problem.symptoms);
    _solutions = List.from(problem.solutions);
    _relatedParts = List.from(problem.relatedParts);
  }

  // Fügt ein Symptom zur Liste hinzu
  void _addSymptom() {
    final symptom = _symptomController.text.trim();
    if (symptom.isNotEmpty && !_symptoms.contains(symptom)) {
      setState(() {
        _symptoms.add(symptom);
        _symptomController.clear();
      });
    }
  }

  // Fügt eine Lösung zur Liste hinzu
  void _addSolution() {
    final solution = _solutionController.text.trim();
    if (solution.isNotEmpty && !_solutions.contains(solution)) {
      setState(() {
        _solutions.add(solution);
        _solutionController.clear();
      });
    }
  }

  // Fügt ein Ersatzteil zur Liste hinzu
  void _addPart() {
    final part = _partsController.text.trim();
    if (part.isNotEmpty && !_relatedParts.contains(part)) {
      setState(() {
        _relatedParts.add(part);
        _partsController.clear();
      });
    }
  }

  // Speichert das Problem
  Future<void> _saveProblem() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMachineType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte wählen Sie einen Maschinentyp')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final problem = Problem(
        id: widget.existingProblem?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        machineType: _selectedMachineType!,
        symptoms: _symptoms,
        solutions: _solutions,
        relatedParts: _relatedParts,
        createdAt: widget.existingProblem?.createdAt ?? DateTime.now(),
        createdBy: widget.existingProblem?.createdBy ??
            userService.currentUser?.id ?? 'unknown',
        status: widget.existingProblem?.status ?? ProblemStatus.active,
        occurrences: widget.existingProblem?.occurrences ?? 1,
        lastOccurrence: widget.existingProblem?.lastOccurrence,
      );

      if (widget.existingProblem != null) {
        await problemDatabaseService.updateProblem(problem);
      } else {
        await problemDatabaseService.addProblem(problem);
      }

      if (!mounted) return;

      Navigator.pop(context, true);

    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Speichern: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // Baut eine Chip-Liste mit Hinzufügen-Funktion
  Widget _buildChipList({
    required String label,
    required List<String> items,
    required TextEditingController controller,
    required VoidCallback onAdd,
    required void Function(int) onDelete,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ...items.asMap().entries.map((entry) {
              return Chip(
                label: Text(entry.value),
                onDeleted: () => onDelete(entry.key),
              );
            }),
            SizedBox(
              width: 200,
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Hinzufügen...',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: onAdd,
                  ),
                ),
                onSubmitted: (_) => onAdd(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingProblem != null ?
        'Problem bearbeiten' :
        'Neues Problem'
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Titel
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Titel',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Bitte geben Sie einen Titel ein';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Kategorie
              DropdownButtonFormField<ProblemCategory>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Kategorie',
                  border: OutlineInputBorder(),
                ),
                items: ProblemCategory.values.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category.toString().split('.').last),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedCategory = value);
                  }
                },
              ),
              const SizedBox(height: 16),

              // Maschinentyp
              DropdownButtonFormField<String>(
                value: _selectedMachineType,
                decoration: const InputDecoration(
                  labelText: 'Maschinentyp',
                  border: OutlineInputBorder(),
                ),
                items: [
                  ...MachineCategories.placerTypes,
                  ...MachineCategories.printerTypes,
                  ...MachineCategories.ovenTypes,
                  ...MachineCategories.inspectionTypes,
                ].map((type) {
                  return DropdownMenuItem(value: type, child: Text(type));
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedMachineType = value);
                },
              ),
              const SizedBox(height: 16),

              // Beschreibung
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Beschreibung',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Bitte geben Sie eine Beschreibung ein';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Symptome
              _buildChipList(
                label: 'Symptome',
                items: _symptoms,
                controller: _symptomController,
                onAdd: _addSymptom,
                onDelete: (index) {
                  setState(() => _symptoms.removeAt(index));
                },
              ),
              const SizedBox(height: 16),

              // Lösungen
              _buildChipList(
                label: 'Lösungen',
                items: _solutions,
                controller: _solutionController,
                onAdd: _addSolution,
                onDelete: (index) {
                  setState(() => _solutions.removeAt(index));
                },
              ),
              const SizedBox(height: 16),

              // Ersatzteile
              _buildChipList(
                label: 'Betroffene Ersatzteile',
                items: _relatedParts,
                controller: _partsController,
                onAdd: _addPart,
                onDelete: (index) {
                  setState(() => _relatedParts.removeAt(index));
                },
              ),
              const SizedBox(height: 24),

              // Speichern-Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProblem,
                  child: _isSaving
                      ? const CircularProgressIndicator()
                      : const Text('Speichern'),
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
    _symptomController.dispose();
    _solutionController.dispose();
    _partsController.dispose();
    super.dispose();
  }
}