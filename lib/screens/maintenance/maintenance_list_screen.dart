import 'package:flutter/material.dart';
import '../../main.dart' show databaseService;

class MaintenanceListScreen extends StatefulWidget {
  const MaintenanceListScreen({Key? key}) : super(key: key);

  @override
  _MaintenanceListScreenState createState() => _MaintenanceListScreenState();
}

class _MaintenanceListScreenState extends State<MaintenanceListScreen> {
  // Liste für alle Wartungsberichte
  List<Map<String, dynamic>> _maintenanceReports = [];
  // Filter-Optionen
  String? _selectedMachineType;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMaintenanceReports();
  }

  // Lädt die Wartungsberichte aus der Datenbank
  Future<void> _loadMaintenanceReports() async {
    setState(() => _isLoading = true);
    try {
      final reports = await databaseService.getMaintenanceReports();
      setState(() {
        _maintenanceReports = reports;
        // Sortiere nach Datum, neueste zuerst
        _maintenanceReports.sort((a, b) =>
            DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));
      });
    } catch (e) {
      print('Fehler beim Laden der Wartungsberichte: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Laden: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Formatiert das Datum für die Anzeige
  String _formatDate(String dateString) {
    final date = DateTime.parse(dateString);
    return '${date.day}.${date.month}.${date.year}';
  }

  // Formatiert die Arbeitszeit
  String _formatWorkTime(int minutes) {
    if (minutes < 60) {
      return '$minutes Minuten';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (remainingMinutes == 0) {
      return '$hours Stunden';
    }
    return '$hours Stunden $remainingMinutes Minuten';
  }

  // Erstellt eine Karte für einen einzelnen Wartungsbericht
  Widget _buildMaintenanceCard(Map<String, dynamic> report) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ListTile(
        title: Text(
          report['title'],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Maschinentyp: ${report['machineType'] ?? 'Nicht angegeben'}'),
            Text('Datum: ${_formatDate(report['date'])}'),
            Text('Arbeitszeit: ${_formatWorkTime(report['workedTime'] ?? 0)}'),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.arrow_forward_ios),
          onPressed: () => _showDetailsDialog(report),
        ),
      ),
    );
  }

  // Zeigt einen Dialog mit den Details des Wartungsberichts
  void _showDetailsDialog(Map<String, dynamic> report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(report['title']),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Durchgeführte Arbeiten:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(report['description'] ?? 'Keine Beschreibung'),
              const Divider(),
              const Text(
                'Verwendete Ersatzteile:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(report['partsUsed']?.isNotEmpty == true
                  ? report['partsUsed']
                  : 'Keine Ersatzteile verwendet'),
              const Divider(),
              Text(
                'Arbeitszeit: ${_formatWorkTime(report['workedTime'] ?? 0)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Datum: ${_formatDate(report['date'])}'),
              Text('Erstellt von: ${report['createdBy']}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wartungsberichte'),
        actions: [
          // Aktualisieren Button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMaintenanceReports,
          ),
          // Filter Button
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (String? value) {
              setState(() {
                _selectedMachineType = value;
              });
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String?>(
                value: null,
                child: Text('Alle anzeigen'),
              ),
              ...List.generate(
                _maintenanceReports.length,
                    (index) => PopupMenuItem<String>(
                  value: _maintenanceReports[index]['machineType'],
                  child: Text(_maintenanceReports[index]['machineType'] ?? 'Unbekannt'),
                ),
              )
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _maintenanceReports.isEmpty
          ? const Center(
        child: Text('Keine Wartungsberichte vorhanden'),
      )
          : ListView.builder(
        itemCount: _maintenanceReports.length,
        itemBuilder: (context, index) {
          final report = _maintenanceReports[index];
          if (_selectedMachineType != null &&
              report['machineType'] != _selectedMachineType) {
            return const SizedBox.shrink();
          }
          return _buildMaintenanceCard(report);
        },
      ),

      // Floating Action Button zum Erstellen eines neuen Berichts
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.pushNamed(context, '/maintenance/new');
          _loadMaintenanceReports(); // Aktualisiere die Liste nach Erstellung
        },
        child: const Icon(Icons.add),
        tooltip: 'Neuen Wartungsbericht erstellen',
      ),
    );
  }
}
