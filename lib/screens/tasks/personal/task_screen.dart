// lib/screens/tasks/personal/task_screen.dart

import 'package:flutter/material.dart';
import '../../../models/task_model.dart';
import '../../../models/maintenance_schedule.dart';
import '../../../models/user_role.dart';
import '../../../main.dart' show taskService, maintenanceScheduleService, userService;

class TaskScreen extends StatefulWidget {
  const TaskScreen({Key? key}) : super(key: key);

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  bool _isLoading = true;
  List<dynamic> _allTasks = []; // Kombinierte Liste aus Tasks und MaintenanceTasks
  String _selectedFilter = 'all';
  final User? _currentUser = userService.currentUser;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    try {
      // Lade normale Aufgaben
      await taskService.loadTasks();
      final normalTasks = taskService.tasks.where((task) =>
      task.assignedToId == _currentUser?.id).toList();

      // Lade Wartungsaufgaben
      await maintenanceScheduleService.loadTasks();
      final maintenanceTasks = maintenanceScheduleService.tasks.where((task) =>
      task.assignedTo == _currentUser?.id).toList();

      setState(() {
        _allTasks = [...normalTasks, ...maintenanceTasks];
        _sortTasks();
        _isLoading = false;
      });
    } catch (e) {
      print('Fehler beim Laden der Aufgaben: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Laden: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  void _sortTasks() {
    _allTasks.sort((a, b) {
      // Prüfe zuerst auf Dringlichkeit
      if (a is Task && b is Task) {
        if (a.priority == TaskPriority.urgent && b.priority != TaskPriority.urgent) {
          return -1;
        }
        if (b.priority == TaskPriority.urgent && a.priority != TaskPriority.urgent) {
          return 1;
        }
      }

      // Dann nach Datum
      final dateA = a is Task ? a.deadline : (a as MaintenanceTask).nextDue;
      final dateB = b is Task ? b.deadline : (b as MaintenanceTask).nextDue;
      return dateA.compareTo(dateB);
    });
  }

  List<dynamic> _getFilteredTasks() {
    return _allTasks.where((task) {
      switch (_selectedFilter) {
        case 'today':
          final date = task is Task ? task.deadline : (task as MaintenanceTask).nextDue;
          final today = DateTime.now();
          return date.year == today.year &&
              date.month == today.month &&
              date.day == today.day;
        case 'urgent':
          if (task is Task) {
            return task.priority == TaskPriority.urgent;
          }
          return false;
        case 'overdue':
          final date = task is Task ? task.deadline : (task as MaintenanceTask).nextDue;
          return date.isBefore(DateTime.now());
        case 'pending':
          if (task is Task) {
            return task.status == TaskStatus.pending;
          }
          if (task is MaintenanceTask) {
            return task.status == MaintenanceTaskStatus.pending;
          }
          return false;
        default:
          return true;
      }
    }).toList();
  }

  Widget _buildTaskCard(dynamic task) {
    final bool isTask = task is Task;
    final String title = isTask ? task.title : (task as MaintenanceTask).title;
    final DateTime date = isTask ? task.deadline : task.nextDue;
    final bool isOverdue = date.isBefore(DateTime.now());
    final bool isUrgent = isTask ? task.priority == TaskPriority.urgent : false;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Icon(
          isTask ? Icons.assignment : Icons.build,
          color: isUrgent ? Colors.red : Colors.blue,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isUrgent || isOverdue ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fällig am: ${_formatDate(date)}'),
            Text('Status: ${_getStatusText(task)}'),
            if (isTask) Text('Priorität: ${_getPriorityText(task.priority)}'),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () => _showTaskOptions(task),
        ),
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
      };
    }
    return 'Unbekannt';
  }

  String _getPriorityText(TaskPriority priority) {
    return switch (priority) {
      TaskPriority.low => 'Niedrig',
      TaskPriority.medium => 'Mittel',
      TaskPriority.high => 'Hoch',
      TaskPriority.urgent => 'Dringend',
      // TODO: Handle this case.
      TaskPriority.normal => throw UnimplementedError(),
    };
  }

  void _showTaskOptions(dynamic task) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.check),
            title: const Text('Als erledigt markieren'),
            onTap: () async { // Geändert von onPressed zu onTap
              Navigator.pop(context);
              await _markTaskAsCompleted(task);
            },
          ),
          ListTile(
            leading: const Icon(Icons.play_arrow),
            title: const Text('Mit Bearbeitung beginnen'),
            onTap: () async { // Geändert von onPressed zu onTap
              Navigator.pop(context);
              await _startTask(task);
            },
          ),
        ],
      ),
    );
  }
  Future<void> _markTaskAsCompleted(dynamic task) async {
    try {
      if (task is Task) {
        await taskService.updateTaskStatus(task.id, TaskStatus.completed);
      } else if (task is MaintenanceTask) {
        await maintenanceScheduleService.completeTask(task.id);
      }
      _loadTasks();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  Future<void> _startTask(dynamic task) async {
    try {
      if (task is Task) {
        await taskService.updateTaskStatus(task.id, TaskStatus.in_progress);
      } else if (task is MaintenanceTask) {
        final updatedTask = task.copyWith(status: MaintenanceTaskStatus.inProgress);
        await maintenanceScheduleService.updateTask(updatedTask);
      }
      _loadTasks();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final filteredTasks = _getFilteredTasks();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meine Aufgaben'),
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
                value: 'urgent',
                child: Text('Dringende Aufgaben'),
              ),
              const PopupMenuItem(
                value: 'overdue',
                child: Text('Überfällige Aufgaben'),
              ),
              const PopupMenuItem(
                value: 'pending',
                child: Text('Ausstehende Aufgaben'),
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
          ? Center(
        child: Text(
          _selectedFilter == 'all'
              ? 'Keine Aufgaben vorhanden'
              : 'Keine ${_selectedFilter.toLowerCase()} Aufgaben',
        ),
      )
          : ListView.builder(
        itemCount: filteredTasks.length,
        itemBuilder: (context, index) =>
            _buildTaskCard(filteredTasks[index]),
      ),
    );
  }
}