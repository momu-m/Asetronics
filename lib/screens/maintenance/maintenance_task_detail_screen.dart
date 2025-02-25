import 'package:flutter/material.dart';
import '../../models/maintenance_schedule.dart';
import '../tasks/personal/task_form.dart';

class MaintenanceTaskDetailScreen extends StatelessWidget {
  final MaintenanceTask task;

  const MaintenanceTaskDetailScreen({
    Key? key,
    required this.task,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wartungsdetails'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TaskForm(existingTask: task),
                ),
              );
              if (result == true) {
                Navigator.pop(context, true);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(context),
            const SizedBox(height: 16),
            _buildDescriptionCard(),
            const SizedBox(height: 16),
            _buildRequirementsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Divider(),
            _buildInfoRow('Status:', _getStatusText(task.status)),
            _buildInfoRow('Nächste Wartung:', _formatDate(task.nextDue)),
            if (task.lastCompleted != null)
              _buildInfoRow('Letzte Wartung:', _formatDate(task.lastCompleted!)),
            _buildInfoRow('Geschätzte Dauer:', _formatDuration(task.estimatedDuration)),
            if (task.assignedTo != null)
              _buildInfoRow('Zugewiesen an:', task.assignedTo!),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Beschreibung',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(task.description),
          ],
        ),
      ),
    );
  }

  Widget _buildRequirementsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Anforderungen',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            if (task.requiredTools.isNotEmpty) ...[
              const Text(
                'Benötigte Werkzeuge:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              ...task.requiredTools.map((tool) => Text('• $tool')),
              const SizedBox(height: 8),
            ],
            if (task.requiredParts.isNotEmpty) ...[
              const Text(
                'Benötigte Ersatzteile:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              ...task.requiredParts.map((part) => Text('• $part')),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _getStatusText(MaintenanceTaskStatus status) {
    return switch (status) {
      MaintenanceTaskStatus.pending => 'Ausstehend',
      MaintenanceTaskStatus.inProgress => 'In Bearbeitung',
      MaintenanceTaskStatus.completed => 'Abgeschlossen',
      MaintenanceTaskStatus.overdue => 'Überfällig',
      MaintenanceTaskStatus.deleted => 'Gelöscht',
    };
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) {
      return '$hours Std ${minutes > 0 ? '$minutes Min' : ''}';
    }
    return '$minutes Min';
  }
}