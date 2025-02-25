// lib/screens/tasks/personal/task_screen.dart

import 'package:flutter/material.dart';
import '../../../models/task_model.dart';
import '../../../models/maintenance_schedule.dart';
import '../../../models/user_role.dart';
import '../../../main.dart' show taskService, maintenanceScheduleService, userService;
import 'task_feedback_screen.dart';

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

      // Prüfe ob a oder b eine MaintenanceTask mit urgent Priorität ist
      if (a is MaintenanceTask && b is Task) {
        if (a.priority == MaintenancePriority.urgent && b.priority != TaskPriority.urgent) {
          return -1;
        }
      }
      if (a is Task && b is MaintenanceTask) {
        if (a.priority == TaskPriority.urgent && b.priority != MaintenancePriority.urgent) {
          return -1;
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
          if (task is MaintenanceTask) {
            return task.priority == MaintenancePriority.urgent;
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

  // Diese Methode öffnet den Feedback-Bildschirm für eine Aufgabe
  void _openTaskFeedback(dynamic task) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskFeedbackScreen(task: task),
      ),
    ).then((result) {
      // Wenn Änderungen vorgenommen wurden (result == true), lade die Aufgaben neu
      if (result == true) {
        _loadTasks();
      }
    });
  }

  Widget _buildTaskCard(dynamic task) {
    final bool isTask = task is Task;
    final String title = isTask ? task.title : (task as MaintenanceTask).title;
    final DateTime date = isTask ? task.deadline : task.nextDue;
    final bool isOverdue = date.isBefore(DateTime.now());
    final bool isUrgent = isTask
        ? task.priority == TaskPriority.urgent
        : task.priority == MaintenancePriority.urgent;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isOverdue ? Colors.red.shade200 : Colors.transparent,
          width: isOverdue ? 1 : 0,
        ),
      ),
      // Hinzufügen von InkWell, um einen Ripple-Effekt zu erzeugen
      child: InkWell(
        onTap: () => _openTaskFeedback(task), // Öffne Feedback-Bildschirm bei Tap
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header mit Titel und Icon
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isUrgent ? Colors.red.shade50 : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isTask ? Icons.assignment : Icons.build,
                      color: isUrgent ? Colors.red : Colors.blue,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isUrgent ? Colors.red.shade700 : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: isOverdue ? Colors.red : Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Fällig: ${_formatDate(date)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isOverdue ? Colors.red : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Zusätzliche Informationen
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Status
                  Chip(
                    label: Text(
                      _getStatusText(task),
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: _getStatusColor(task).withOpacity(0.2),
                    side: BorderSide(color: _getStatusColor(task)),
                    visualDensity: VisualDensity.compact,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  // Priorität / Intervall
                  isTask
                      ? Chip(
                    label: Text(
                      _getPriorityText(task.priority),
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: _getPriorityColor(task.priority).withOpacity(0.2),
                    side: BorderSide(color: _getPriorityColor(task.priority)),
                    visualDensity: VisualDensity.compact,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                  )
                      : Chip(
                    label: Text(
                      _getIntervalText(task.interval),
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: Colors.teal.shade50,
                    side: BorderSide(color: Colors.teal.shade200),
                    visualDensity: VisualDensity.compact,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  // "Mehr" Button
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => _showTaskOptions(task),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 24,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(dynamic task) {
    if (task is Task) {
      return switch (task.status) {
        TaskStatus.pending => Colors.orange,
        TaskStatus.in_progress => Colors.blue,
        TaskStatus.completed => Colors.green,
        TaskStatus.blocked => Colors.red,
      };
    } else if (task is MaintenanceTask) {
      return switch (task.status) {
        MaintenanceTaskStatus.pending => Colors.orange,
        MaintenanceTaskStatus.inProgress => Colors.blue,
        MaintenanceTaskStatus.completed => Colors.green,
        MaintenanceTaskStatus.overdue => Colors.red,
        MaintenanceTaskStatus.deleted => Colors.grey,
      };
    }
    return Colors.grey;
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

  String _getPriorityText(TaskPriority priority) {
    return switch (priority) {
      TaskPriority.low => 'Niedrig',
      TaskPriority.medium => 'Mittel',
      TaskPriority.high => 'Hoch',
      TaskPriority.urgent => 'Dringend',
      TaskPriority.normal => 'Normal',
    };
  }

  Color _getPriorityColor(TaskPriority priority) {
    return switch (priority) {
      TaskPriority.low => Colors.green,
      TaskPriority.medium => Colors.blue,
      TaskPriority.high => Colors.orange,
      TaskPriority.urgent => Colors.red,
      TaskPriority.normal => Colors.blue,
    };
  }

  String _getIntervalText(MaintenanceInterval interval) {
    return switch (interval) {
      MaintenanceInterval.daily => 'Täglich',
      MaintenanceInterval.weekly => 'Wöchentlich',
      MaintenanceInterval.monthly => 'Monatlich',
      MaintenanceInterval.quarterly => 'Vierteljährlich',
      MaintenanceInterval.yearly => 'Jährlich',
    };
  }

  void _showTaskOptions(dynamic task) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Titelleiste
            Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              child: Text(
                task is Task ? task.title : task.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const Divider(),

            // Beschreibung
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                task is Task ? task.description : task.description,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(height: 16),

            // Optionen
            ListTile(
              leading: const Icon(Icons.assignment_turned_in, color: Colors.green),
              title: const Text('Aufgabe abschließen'),
              subtitle: const Text('Rückmeldung geben und als erledigt markieren'),
              onTap: () {
                Navigator.pop(context);
                _openTaskFeedback(task);
              },
            ),
            ListTile(
              leading: const Icon(Icons.play_arrow, color: Colors.blue),
              title: const Text('Mit Bearbeitung beginnen'),
              onTap: () async {
                Navigator.pop(context);
                await _startTask(task);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _selectedFilter == 'all'
                  ? Icons.assignment_turned_in
                  : Icons.search_off,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              _selectedFilter == 'all'
                  ? 'Keine Aufgaben vorhanden'
                  : 'Keine ${_selectedFilter.toLowerCase()} Aufgaben',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedFilter == 'all'
                  ? 'Alle Ihre Aufgaben werden hier angezeigt'
                  : 'Passen Sie die Filter an, um andere Aufgaben zu sehen',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadTasks,
        child: ListView.builder(
          itemCount: filteredTasks.length,
          itemBuilder: (context, index) => _buildTaskCard(filteredTasks[index]),
        ),
      ),
      // Floating Action Button für Schnellzugriff
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  // Floating Action Button mit erweiterten Funktionen
  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: () => _showStartTaskDialog(),
      icon: const Icon(Icons.play_arrow),
      label: const Text('Mit Aufgabe beginnen'),
      backgroundColor: Colors.green,
    );
  }

  // Dialog zum Starten einer Aufgabe
  void _showStartTaskDialog() {
    // Filtere nur ausstehende Aufgaben
    final pendingTasks = _allTasks.where((task) =>
    task is Task ? task.status == TaskStatus.pending :
    task is MaintenanceTask ? task.status == MaintenanceTaskStatus.pending : false
    ).toList();

    if (pendingTasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Keine ausstehenden Aufgaben vorhanden'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aufgabe starten'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: pendingTasks.length > 5 ? 5 : pendingTasks.length,
            itemBuilder: (context, index) {
              final task = pendingTasks[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: task is Task ? Colors.blue.shade50 : Colors.orange.shade50,
                  child: Icon(
                    task is Task ? Icons.assignment : Icons.build,
                    color: task is Task ? Colors.blue : Colors.orange,
                    size: 20,
                  ),
                ),
                title: Text(task is Task ? task.title : task.title),
                subtitle: Text(
                  'Fällig: ${_formatDate(task is Task ? task.deadline : task.nextDue)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: (task is Task && task.deadline.isBefore(DateTime.now())) ||
                        (task is MaintenanceTask && task.nextDue.isBefore(DateTime.now()))
                        ? Colors.red
                        : Colors.grey,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _startTask(task);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/tasks/planner');
            },
            child: const Text('Alle Aufgaben anzeigen'),
          ),
        ],
      ),
    );
  }
}