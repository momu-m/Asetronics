// problem_database_screen.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../../config/api_config.dart';
import '../../models/user_role.dart';
import '../../main.dart' show userService, databaseService;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'package:universal_html/html.dart' as html;
import 'package:path_provider/path_provider.dart';



class ProblemDatabaseScreen extends StatefulWidget {
  const ProblemDatabaseScreen({Key? key}) : super(key: key);

  @override
  State<ProblemDatabaseScreen> createState() => _ProblemDatabaseScreenState();
}

class _ProblemDatabaseScreenState extends State<ProblemDatabaseScreen> {
  bool _isLoading = true;
  String _selectedFilter = 'all';
  List<Map<String, dynamic>> _problems = [];
  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> _maintenanceReports = [];
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = userService.currentUser;
    _loadData();
    _loadReports();
  }

  // Sichere Datumskonvertierung
  DateTime? _parseDate(String? dateStr) {
    if (dateStr == null) return null;

    try {
      // Versuche verschiedene Datumsformate

      // Format: "Sat, 01 Feb 2025 10:42:55 GMT"
      if (dateStr.contains('GMT')) {
        return DateFormat("EEE, dd MMM yyyy HH:mm:ss 'GMT'", 'en_US').parse(dateStr);
      }

      // Format: "2025-02-01T10:42:55"
      if (dateStr.contains('T')) {
        return DateTime.parse(dateStr);
      }

      // Format: "2025-02-01 10:42:55"
      return DateFormat("yyyy-MM-dd HH:mm:ss").parse(dateStr);

    } catch (e) {
      print('Fehler beim Parsen des Datums $dateStr: $e');
      return null;
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Lade Fehlermeldungen
      final errorResponse = await ApiConfig.sendRequest(
        url: '${ApiConfig.errorsUrl}',
        method: 'GET',
      );

      final reportResponse = await ApiConfig.sendRequest(
        url: '${ApiConfig.maintenanceTasksUrl}',
        method: 'GET',
      );

      if (errorResponse.statusCode == 200) {
        _problems = List<Map<String, dynamic>>.from(jsonDecode(errorResponse.body));
      }

      if (reportResponse.statusCode == 200) {
        _reports = List<Map<String, dynamic>>.from(jsonDecode(reportResponse.body));
      }

    } catch (e) {
      print('Fehler beim Laden der Daten: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Laden: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    try {
      // Laden von Wartungsberichten
      _maintenanceReports = await databaseService.getMaintenanceReports();
      // Optional: Laden von anderen Berichten

      setState(() {
        _reports = [
          ..._maintenanceReports,
          // Hier können weitere Berichtstypen hinzugefügt werden
        ];
        // Sortieren nach Datum
        _reports.sort((a, b) =>
            DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));
      });
    } catch (e) {
      _showErrorMessage('Fehler beim Laden der Berichte: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<Map<String, dynamic>> _getFilteredData() {
    switch (_selectedFilter) {
      case 'errors':
        return _problems.where((p) =>
        p['status'] == 'resolved' || p['status'] == 'closed'
        ).toList();
      case 'reports':
        return _reports;
      default:
        final allData = [..._problems, ..._reports];
        allData.sort((a, b) {
          final dateA = _parseDate(a['created_at']);
          final dateB = _parseDate(b['created_at']);
          if (dateA == null || dateB == null) return 0;
          return dateB.compareTo(dateA);
        });
        return allData;
    }
  }

  Widget _buildErrorList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final solvedErrors = _problems.where((error) =>
    error['status'] == 'resolved' || error['status'] == 'closed'
    ).toList();

    if (solvedErrors.isEmpty) {
      return const Center(child: Text('Keine gelösten Fehlermeldungen vorhanden'));
    }

    return ListView.builder(
      itemCount: solvedErrors.length,
      itemBuilder: (context, index) => _buildErrorCard(solvedErrors[index]),
    );
  }

  Widget _buildReportList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_reports.isEmpty) {
      return const Center(child: Text('Keine Wartungsberichte vorhanden'));
    }

    return ListView.builder(
      itemCount: _reports.length,
      itemBuilder: (context, index) => _buildReportCard(_reports[index]),
    );
  }

  Widget _buildAllReportsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final allReports = [..._problems, ..._reports];
    if (allReports.isEmpty) {
      return const Center(child: Text('Keine Berichte vorhanden'));
    }

    return ListView.builder(
      itemCount: allReports.length,
      itemBuilder: (context, index) => _buildItemCard(allReports[index]),
    );
  }

  Widget _buildErrorCard(Map<String, dynamic> error) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: ListTile(
        title: Text(error['title'] ?? 'Keine Bezeichnung'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Maschinentyp: ${error['machine_type'] ?? 'Nicht angegeben'}'),
            Text('Status: ${error['status'] ?? 'Unbekannt'}'),
            Text('Gelöst am: ${_formatDate(error['resolved_at'])}'),
          ],
        ),
        onTap: () => _showErrorDetails(error),
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: ListTile(
        title: Text(report['title'] ?? 'Kein Titel'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Maschinentyp: ${report['machine_type'] ?? 'Nicht angegeben'}'),
            Text('Datum: ${_formatDate(report['date'])}'),
            Text('Arbeitszeit: ${report['worked_time']} Minuten'),
          ],
        ),
        onTap: () => _showReportDetails(report),
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final bool isReport = item.containsKey('worked_time');
    final DateTime? createdAt = _parseDate(item['created_at']);

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Icon(
          isReport ? Icons.assignment : Icons.warning,
          color: isReport ? Colors.blue : Colors.orange,
        ),
        title: Text(
          item['title'] ?? 'Kein Titel',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Maschinentyp: ${item['machine_type'] ?? 'Nicht angegeben'}'),
            if (createdAt != null)
              Text('Erstellt am: ${_formatDate(createdAt)}'),
            if (!isReport)
              Text('Status: ${_getStatusText(item['status'])}'),
            if (isReport)
              Text('Arbeitszeit: ${item['worked_time']} Minuten'),
            FutureBuilder<String>(
              future: userService.getUserName(item['created_by'] ?? ''),
              builder: (context, snapshot) {
                return Text(
                  'Erstellt von: ${snapshot.data ?? 'Wird geladen...'}',
                  style: const TextStyle(fontStyle: FontStyle.italic),
                );
              },
            ),
          ],
        ),

        trailing: IconButton(
          icon: const Icon(Icons.arrow_forward_ios),
          onPressed: () => _showDetailsDialog(item, isReport),
        ),
      ),
    );
  }

  void _showDetailsDialog(Map<String, dynamic> item, bool isReport) {
    final DateTime? resolvedAt = _parseDate(item['resolved_at']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item['title'] ?? 'Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Beschreibung:',
                  style: Theme.of(context).textTheme.titleSmall),
              Text(item['description'] ?? 'Keine Beschreibung'),
              const Divider(),
              if (isReport) ...[
                Text('Verwendete Teile:',
                    style: Theme.of(context).textTheme.titleSmall),
                Text(item['parts_used'] ?? 'Keine Teile verwendet'),
              ] else ...[
                Text('Status: ${_getStatusText(item['status'])}'),
                if (resolvedAt != null)
                  Text('Gelöst am: ${_formatDate(resolvedAt)}'),
              ],
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

  String _getStatusText(String? status) {
    switch (status) {
      case 'resolved':
        return 'Gelöst';
      case 'closed':
        return 'Geschlossen';
      default:
        return status ?? 'Unbekannt';
    }
  }

  String _formatDate(dynamic dateInput) {
    if (dateInput == null) return 'Kein Datum';

    try {
      DateTime date;
      if (dateInput is DateTime) {
        date = dateInput;
      } else if (dateInput is String) {
        if (dateInput.contains('GMT')) {
          date = DateFormat("EEE, dd MMM yyyy HH:mm:ss 'GMT'", 'en_US').parse(dateInput);
        } else if (dateInput.contains('T')) {
          // Entferne das 'T' und behandle es als normales Datum
          date = DateTime.parse(dateInput.replaceAll(' T', 'T'));
        } else {
          date = DateTime.parse(dateInput);
        }
      } else {
        return 'Ungültiges Datumsformat';
      }
      return DateFormat('dd.MM.yyyy HH:mm').format(date);
    } catch (e) {
      print('Fehler beim Formatieren des Datums: $e');
      return 'Ungültiges Datum';
    }
  }

  void _showErrorDetails(Map<String, dynamic> error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(error['title'] ?? 'Fehlermeldung'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Beschreibung:', style: Theme.of(context).textTheme.titleSmall),
              Text(error['description'] ?? 'Keine Beschreibung'),
              const Divider(),
              Text('Lösung:', style: Theme.of(context).textTheme.titleSmall),
              Text(error['solution'] ?? 'Keine Lösung dokumentiert'),
              if (error['images'] != null && (error['images'] as List).isNotEmpty) ...[
                const Divider(),
                Text('Bilder:', style: Theme.of(context).textTheme.titleSmall),
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: (error['images'] as List).length,
                    itemBuilder: (context, index) {
                      final imageStr = error['images'][index];
                      return Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: InkWell(
                          onTap: () => _showFullImage(imageStr),
                          child: Image.memory(
                            base64Decode(imageStr.split(',').last),
                            height: 100,
                            width: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Schließen'),
          ),
          TextButton(
            onPressed: () => _exportSingleReport(error),
            child: const Text('Exportieren'),
          ),
        ],
      ),
    );
  }

  void _showReportDetails(Map<String, dynamic> report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(report['title'] ?? 'Wartungsbericht'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Durchgeführte Arbeiten:',
                  style: Theme.of(context).textTheme.titleSmall),
              Text(report['description'] ?? 'Keine Beschreibung'),
              const Divider(),
              Text('Verwendete Teile:',
                  style: Theme.of(context).textTheme.titleSmall),
              Text(report['parts_used'] ?? 'Keine Teile verwendet'),
              Text('Arbeitszeit: ${report['worked_time']} Minuten'),
              if (report['images'] != null && (report['images'] as List).isNotEmpty) ...[
                const Divider(),
                Text('Bilder:', style: Theme.of(context).textTheme.titleSmall),
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: (report['images'] as List).length,
                    itemBuilder: (context, index) {
                      final imageStr = report['images'][index];
                      return Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: InkWell(
                          onTap: () => _showFullImage(imageStr),
                          child: Image.memory(
                            base64Decode(imageStr.split(',').last),
                            height: 100,
                            width: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Schließen'),
          ),
          TextButton(
            onPressed: () => _exportSingleReport(report),
            child: const Text('Exportieren'),
          ),
        ],
      ),
    );
  }

  void _showFullImage(String imageStr) {
    try {
      // Entferne Header von Base64-String wenn vorhanden
      final imageData = imageStr.contains(',') ?
      imageStr.split(',')[1] : imageStr;

      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: Stack(
            fit: StackFit.loose,
            children: [
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.8,
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.memory(
                    base64Decode(imageData),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      print('Bildfehler: $error');
                      return const Center(
                        child: Text('Bild konnte nicht geladen werden'),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      print('Fehler beim Anzeigen des Bildes: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Laden des Bildes: $e')),
      );
    }
  }

  Future<void> _exportSingleReport(Map<String, dynamic> data) async {
    try {
      // Hole den Benutzernamen
      final createdByName = await userService.getUserName(data['created_by'] ?? '');

      // Bestimme den Berichtstyp
      final isErrorReport = !data.containsKey('worked_time');

      // HTML-Template für das Formular
      String content = '''
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <style>
        body { 
          font-family: Arial, sans-serif; 
          padding: 20px;
          max-width: 800px;
          margin: 0 auto;
        }
        .header { 
          text-align: center; 
          margin-bottom: 30px;
          border-bottom: 2px solid #0056b3;
          padding-bottom: 20px;
        }
        table { 
          width: 100%; 
          border-collapse: collapse; 
          margin-top: 20px;
        }
        th { 
          background-color: #f5f5f5;
          width: 200px;
        }
        th, td { 
          border: 1px solid #ddd; 
          padding: 12px; 
          text-align: left; 
        }
        .status-resolved {
          color: green;
          font-weight: bold;
        }
        .images-section {
          margin-top: 20px;
        }
        .images-section img {
          max-width: 200px;
          margin: 10px;
          border: 1px solid #ddd;
        }
      </style>
    </head>
    <body>
      <div class="header">
        <h2>${isErrorReport ? 'Fehlermeldung' : 'Wartungsbericht'}</h2>
        <p>Erstellt am: ${_formatDate(data['created_at'])}</p>
      </div>
      
      <table>
        <tr>
          <th>Titel</th>
          <td>${data['title'] ?? ''}</td>
        </tr>
        <tr>
          <th>Maschinentyp</th>
          <td>${data['machine_type'] ?? ''}</td>
        </tr>
        <tr>
          <th>Datum</th>
          <td>${_formatDate(data['date'] ?? data['created_at'])}</td>
        </tr>
        <tr>
          <th>Erstellt von</th>
          <td>$createdByName</td>
        </tr>
    ''';

      // Füge fehlermeldungsspezifische Felder hinzu
      if (isErrorReport) {
        content += '''
        <tr>
          <th>Status</th>
          <td class="status-resolved">${_getStatusText(data['status'])}</td>
        </tr>
        <tr>
          <th>Gelöst am</th>
          <td>${_formatDate(data['resolved_at'])}</td>
        </tr>
        <tr>
          <th>Lösung</th>
          <td>${data['solution'] ?? 'Keine Lösung dokumentiert'}</td>
        </tr>
      ''';
      } else {
        // Wartungsberichtspezifische Felder
        content += '''
        <tr>
          <th>Arbeitszeit</th>
          <td>${data['worked_time']} Minuten</td>
        </tr>
        <tr>
          <th>Verwendete Teile</th>
          <td>${data['parts_used'] ?? 'Keine Teile verwendet'}</td>
        </tr>
      ''';
      }

      content += '''
        <tr>
          <th>Beschreibung</th>
          <td>${data['description'] ?? ''}</td>
        </tr>
      </table>
    ''';

      // Füge Bilder hinzu, falls vorhanden
      if (data['images'] != null && (data['images'] as List).isNotEmpty) {
        content += '''
        <div class="images-section">
          <h3>Bilder</h3>
          <div class="images-container">
      ''';

        for (var imageStr in data['images']) {
          content += '''
          <img src="data:image/jpeg;base64,${imageStr.split(',').last}" alt="Bild">
        ''';
        }

        content += '''
          </div>
        </div>
      ''';
      }

      content += '''
      </body>
    </html>
    ''';

      // Download als HTML-Datei
      final bytes = utf8.encode(content);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', '${isErrorReport ? 'fehlermeldung' : 'wartungsbericht'}_${DateTime.now().millisecondsSinceEpoch}.html')
        ..click();

      html.Url.revokeObjectUrl(url);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Export erfolgreich'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Export-Fehler: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Export: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportData() async {
    try {
      final content = 'Ihre Export-Daten hier'; // Ihr bestehender Content-Code

      if (kIsWeb) {
        final bytes = content.codeUnits;
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);

        final anchor = html.AnchorElement()
          ..href = url
          ..download = 'export_${DateTime.now().toIso8601String()}.txt'
          ..style.display = 'none';

        html.document.body?.children.add(anchor);
        anchor.click();
        anchor.remove();
        html.Url.revokeObjectUrl(url);
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/export_${DateTime.now().toIso8601String()}.txt');
        await file.writeAsString(content);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Export erfolgreich')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export fehlgeschlagen: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Problemdatenbank'),
          bottom: TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.check_circle),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'Gelöste Fehlermeldungen',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              Tab(
                icon: Icon(Icons.description),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'Wartungsberichte',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              Tab(
                icon: Icon(Icons.list_alt),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'Alle Berichte',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
            indicatorColor: Colors.blue,
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.file_download),
              tooltip: 'Exportieren',
              onPressed: _exportData,
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadData,
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _buildErrorList(),
            _buildReportList(),
            _buildAllReportsList(),
          ],
        ),
      ),
    );
  }
}