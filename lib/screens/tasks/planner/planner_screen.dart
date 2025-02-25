// lib/screens/tasks/planner/planner_screen.dart

import 'package:flutter/material.dart';
import '../../../models/maintenance_schedule.dart';
import '../../../models/user_role.dart';
import '../../../config/api_config.dart';
import '../../../main.dart' show maintenanceScheduleService, userService;
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({Key? key}) : super(key: key);

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  // Status-Variablen
  bool _isLoading = true;
  String _selectedFilter = 'all';
  List<MaintenanceTask> _tasks = [];
  final User? _currentUser = userService.currentUser;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  // Lädt alle Wartungsaufgaben
  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);

    try {
      final response = await ApiConfig.sendRequest(
        url: '${ApiConfig.baseUrl}/maintenance/tasks',
        method: 'GET',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _tasks = data.map((json) => MaintenanceTask.fromJson(json)).toList();
          // Sortiere nach Fälligkeit
          _tasks.sort((a, b) => a.nextDue.compareTo(b.nextDue));
        });
      } else {
        _showErrorMessage('Fehler beim Laden der Aufgaben');
      }
    } catch (e) {
      _showErrorMessage('Netzwerkfehler: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Filtered die Aufgaben basierend auf dem ausgewählten Filter
  // Filtered die Aufgaben basierend auf dem ausgewählten Filter
  List<MaintenanceTask> _getFilteredTasks() {
    // Zuerst alle gelöschten Aufgaben ausschließen
    final activeTasks = _tasks.where((task) =>
    task.status != MaintenanceTaskStatus.deleted
    ).toList();

    // Dann den ausgewählten Filter anwenden
    switch (_selectedFilter) {
      case 'today':
        return activeTasks.where((task) {
          final now = DateTime.now();
          return task.nextDue.year == now.year &&
              task.nextDue.month == now.month &&
              task.nextDue.day == now.day;
        }).toList();
      case 'overdue':
        final now = DateTime.now();
        return activeTasks.where((task) =>
        task.status != MaintenanceTaskStatus.completed &&
            task.nextDue.isBefore(now)
        ).toList();
      case 'upcoming':
        final now = DateTime.now();
        return activeTasks.where((task) =>
        task.status == MaintenanceTaskStatus.pending &&
            task.nextDue.isAfter(now)
        ).toList();
      default:
        return activeTasks;
    }
  }
  Future<void> _showDeleteConfirmation(MaintenanceTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aufgabe permanent löschen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ACHTUNG: Diese Aktion kann nicht rückgängig gemacht werden!',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text('Möchten Sie die Aufgabe "${task.title}" wirklich permanent aus der Datenbank löschen?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Permanent löschen'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deletePermanently(task);
    }
  }

// Implementierung der permanenten Löschfunktion
  Future<void> _deletePermanently(MaintenanceTask task) async {
    try {
      setState(() => _isLoading = true);

      final success = await maintenanceScheduleService.permanentlyDeleteTask(task.id);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aufgabe wurde permanent gelöscht'),
            backgroundColor: Colors.green,
          ),
        );
        _loadTasks(); // Liste aktualisieren
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
  // Zeigt die Details einer Aufgabe
  void _showTaskDetails(MaintenanceTask task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(task.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Beschreibung:', style: Theme.of(context).textTheme.titleSmall),
              Text(task.description),
              const Divider(),
              Text('Status: ${_getStatusText(task.status)}'),
              Text('Fällig am: ${_formatDate(task.nextDue)}'),
              if (task.assignedTo != null)
                FutureBuilder<String>(
                  future: userService.getUserName(task.assignedTo!),
                  builder: (context, snapshot) {
                    return Text(
                        'Zugewiesen an: ${snapshot.data ?? "Wird geladen..."}'
                    );
                  },
                ),

              // Weitere Aufgabendetails
              if (task.machineType != null)
                Text('Maschinentyp: ${task.machineType}'),
              if (task.line != null)
                Text('Produktionslinie: ${task.line}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Schließen'),
          ),
          if (_canModifyTask(task))
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _editTask(task);
              },
              child: const Text('Bearbeiten'),
            ),
          // Nur für Admins: Permanent löschen Button
          if (_currentUser?.role == UserRole.admin)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showDeleteConfirmation(task);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Permanent löschen'),
            ),
        ],
      ),
    );
  }


  // Öffnet den Editor für eine Aufgabe
  void _editTask(MaintenanceTask task) async {
    final result = await Navigator.pushNamed(
      context,
      '/tasks/planner/edit',
      arguments: task,
    );

    if (result == true) {
      _loadTasks();
    }
  }

  // Erstellt eine neue Aufgabe
  void _createNewTask() async {
    final result = await Navigator.pushNamed(context, '/tasks/planner/new');
    if (result == true) {
      _loadTasks();
    }
  }

  // Prüft ob der aktuelle Benutzer eine Aufgabe bearbeiten darf
  bool _canModifyTask(MaintenanceTask task) {
    if (_currentUser == null) return false;
    return _currentUser!.role == UserRole.admin ||
        _currentUser!.role == UserRole.teamlead;
  }

  // Erstellt eine Karte für eine einzelne Aufgabe
  Widget _buildTaskCard(MaintenanceTask task) {
    final bool isOverdue = task.isOverdue();
    final Color statusColor = _getStatusColor(task.status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Icon(
          Icons.engineering,
          color: statusColor,
        ),
        title: Text(
          task.title,
          style: TextStyle(
            fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fällig am: ${_formatDate(task.nextDue)}'),
            Text('Status: ${_getStatusText(task.status)}'),
            if (task.assignedTo != null)
              FutureBuilder<String>(
                future: userService.getUserName(task.assignedTo!),
                builder: (context, snapshot) {
                  return Text('Zugewiesen an: ${snapshot.data ?? "..."}');
                },
              ),
          ],
        ),
        onTap: () => _showTaskDetails(task),
      ),
    );
  }

  // Hilfsmethoden für die UI
  String _formatDate(DateTime date) {
    return DateFormat('dd.MM.yyyy').format(date);
  }

  String _getStatusText(MaintenanceTaskStatus status) {
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
        return 'Gelöscht';
        throw UnimplementedError();
    }
  }

  Color _getStatusColor(MaintenanceTaskStatus status) {
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
        return Colors.deepOrange;
        throw UnimplementedError();
    }
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
    final filteredTasks = _getFilteredTasks();
    final bool canCreateTasks = _currentUser?.role == UserRole.teamlead ||
        _currentUser?.role == UserRole.admin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wartungsplaner'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() => _selectedFilter = value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'all',
                child: Text('Alle Aufgaben'),
              ),
              const PopupMenuItem(
                value: 'today',
                child: Text('Heute fällig'),
              ),
              const PopupMenuItem(
                value: 'overdue',
                child: Text('Überfällig'),
              ),
              const PopupMenuItem(
                value: 'upcoming',
                child: Text('Anstehend'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTasks,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : filteredTasks.isEmpty
          ? const Center(
        child: Text('Keine Aufgaben gefunden'),
      )
          : ListView.builder(
        itemCount: filteredTasks.length,
        itemBuilder: (context, index) =>
            _buildTaskCard(filteredTasks[index]),
      ),
      floatingActionButton: canCreateTasks
          ? FloatingActionButton(
        onPressed: _createNewTask,
        child: const Icon(Icons.add),
        tooltip: 'Neue Wartungsaufgabe',
      )
          : null,
    );
  }
}