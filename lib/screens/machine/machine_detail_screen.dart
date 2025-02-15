// machine_detail_screen.dart
import 'package:flutter/material.dart';
import '../../utils/machine_constants.dart';
import '../error/error_report_dialog.dart';
import '../../main.dart' show databaseService;

class MachineDetailScreen extends StatefulWidget {
  final String machineId;
  final String scannedFrom;

  const MachineDetailScreen({
    Key? key,
    required this.machineId,
    this.scannedFrom = 'scanner', // 'scanner' oder 'list'
  }) : super(key: key);

  @override
  State<MachineDetailScreen> createState() => _MachineDetailScreenState();
}

class _MachineDetailScreenState extends State<MachineDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _machineInfo;
  List<Map<String, dynamic>> _maintenanceHistory = [];
  List<Map<String, dynamic>> _errorReports = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadMachineData();
  }

  Future<void> _loadMachineData() async {
    setState(() => _isLoading = true);
    try {
      // Lade Maschinendaten
      final machines = await databaseService.getMachines();
      final machineData = machines.firstWhere(
            (m) => m['id'] == widget.machineId,
        orElse: () => throw Exception('Maschine nicht gefunden'),
      );

      // Lade Wartungshistorie
      final allReports = await databaseService.getMaintenanceReports();
      final machineReports = allReports
          .where((report) => report['machineId'] == widget.machineId)
          .toList();

      // Lade Fehlermeldungen
      final allErrors = await databaseService.getErrorReports();
      final machineErrors = allErrors
          .where((error) => error['machineId'] == widget.machineId)
          .toList();

      setState(() {
        _machineInfo = machineData;
        _maintenanceHistory = machineReports;
        _errorReports = machineErrors;
        _isLoading = false;
      });
    } catch (e) {
      print('Fehler beim Laden der Maschinendaten: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Laden: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  // Zeigt den Dialog zum Melden eines neuen Fehlers
  Future<void> _showErrorReportDialog() async {
    if (_machineInfo == null) return;

    final result = await showDialog(
      context: context,
      builder: (context) => ErrorReportDialog(
        machineInfo: _machineInfo!,
      ),
    );

    if (result == true) {
      _loadMachineData(); // Aktualisiere die Daten
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_machineInfo == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Fehler')),
        body: const Center(child: Text('Maschine nicht gefunden')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_machineInfo!['name']),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Details'),
            Tab(text: 'Wartung'),
            Tab(text: 'Fehler'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMachineData,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDetailsTab(),
          _buildMaintenanceTab(),
          _buildErrorsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showErrorReportDialog,
        icon: const Icon(Icons.warning),
        label: const Text('Fehler melden'),
      ),
    );
  }

  // Tab für Maschinendetails
  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('Maschinentyp:', _machineInfo!['type']),
                  _buildInfoRow('Seriennummer:', _machineInfo!['serialNumber']),
                  _buildInfoRow('Produktionslinie:', _machineInfo!['line']),
                  _buildInfoRow('Status:', _getStatusText(_machineInfo!['status'])),
                  if (_machineInfo!['lastMaintenance'] != null)
                    _buildInfoRow(
                      'Letzte Wartung:',
                      _formatDate(_machineInfo!['lastMaintenance']),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildStatusCard(),
          const SizedBox(height: 16),
          _buildQuickActionsCard(),
        ],
      ),
    );
  }

  // Tab für Wartungshistorie
  Widget _buildMaintenanceTab() {
    if (_maintenanceHistory.isEmpty) {
      return const Center(
        child: Text('Keine Wartungseinträge vorhanden'),
      );
    }

    return ListView.builder(
      itemCount: _maintenanceHistory.length,
      itemBuilder: (context, index) {
        final report = _maintenanceHistory[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            title: Text(report['title']),
            subtitle: Text(
              'Datum: ${_formatDate(report['date'])}\n'
                  'Durchgeführt von: ${report['createdBy']}',
            ),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // TODO: Implementiere Wartungsdetailansicht
            },
          ),
        );
      },
    );
  }

  // Tab für Fehlermeldungen
  Widget _buildErrorsTab() {
    if (_errorReports.isEmpty) {
      return const Center(
        child: Text('Keine Fehlermeldungen vorhanden'),
      );
    }

    return ListView.builder(
      itemCount: _errorReports.length,
      itemBuilder: (context, index) {
        final error = _errorReports[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: Icon(
              error['isUrgent'] == true ? Icons.warning : Icons.info,
              color: error['isUrgent'] == true ? Colors.red : Colors.blue,
            ),
            title: Text(error['description']),
            subtitle: Text(
              'Status: ${error['status']}\n'
                  'Gemeldet: ${_formatDate(error['createdAt'])}',
            ),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // TODO: Implementiere Fehlerdetailansicht
            },
          ),
        );
      },
    );
  }

  // Hilfsmethoden für die UI
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Aktuelle Statistiken',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _buildStatRow(
              'Offene Fehler',
              _errorReports.where((e) => e['status'] == 'Neu').length.toString(),
              Icons.warning,
              Colors.orange,
            ),
            _buildStatRow(
              'Wartungen in 30 Tagen',
              _maintenanceHistory
                  .where((m) {
                final date = DateTime.parse(m['date']);
                final daysAgo = DateTime.now().difference(date).inDays;
                return daysAgo <= 30;
              })
                  .length
                  .toString(),
              Icons.build,
              Colors.blue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Schnellzugriff',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildActionChip(
                  'Neue Wartung',
                  Icons.build,
                      () {
                    // TODO: Implementiere neue Wartung
                  },
                ),
                _buildActionChip(
                  'Dokumentation',
                  Icons.description,
                      () {
                    // TODO: Implementiere Dokumentationsanzeige
                  },
                ),
                _buildActionChip(
                  'Historie exportieren',
                  Icons.download,
                      () {
                    // TODO: Implementiere Export-Funktion
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(label),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildActionChip(String label, IconData icon, VoidCallback onTap) {
    return ActionChip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      onPressed: onTap,
    );
  }

  String _formatDate(String dateStr) {
    final date = DateTime.parse(dateStr);
    return '${date.day}.${date.month}.${date.year}';
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'aktiv':
        return 'Aktiv';
      case 'maintenance':
      case 'wartung':
        return 'In Wartung';
      case 'error':
      case 'fehler':
        return 'Fehlerhaft';
      default:
        return status;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}