// lib/screens/error/error_list_screen.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../models/user_role.dart';
import '../../main.dart' show userService;
import 'package:intl/intl.dart';

class ErrorListScreen extends StatefulWidget {
  const ErrorListScreen({Key? key}) : super(key: key);

  @override
  _ErrorListScreenState createState() => _ErrorListScreenState();
}

class _ErrorListScreenState extends State<ErrorListScreen> {
  // Status-Variablen
  bool _isLoading = true;
  List<Map<String, dynamic>> _errorReports = [];
  String _selectedFilter = 'all';

  // Aktuelle Benutzer-Referenz
  final _currentUser = userService.currentUser;

  // Status-Definitionen für Fehlermeldungen
  static const Map<String, String> statusDisplayNames = {
    'new': 'Neu',
    'in_progress': 'In Bearbeitung',
    'resolved': 'Gelöst',
    'closed': 'Geschlossen'
  };

  // Farben für verschiedene Status
  static const Map<String, Color> statusColors = {
    'new': Colors.red,
    'in_progress': Colors.orange,
    'resolved': Colors.green,
    'closed': Colors.grey
  };

  @override
  void initState() {
    super.initState();
    _loadErrorReports();
  }

  // Lädt die Fehlermeldungen von der API
  Future<void> _loadErrorReports() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/errors'),
        headers: {
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _errorReports = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
        // Debug-Ausgabe
        print('Loaded errors: ${_errorReports.length}');
        if (_errorReports.isNotEmpty) {
          print('First error sample: ${_errorReports.first}');
        }
      } else {
        throw Exception('Failed to load error reports');
      }
    } catch (e) {
      print('Error loading reports: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Laden: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  // Zeigt die Details einer Fehlermeldung
  void _showErrorDetails(Map<String, dynamic> error) {
    // Debug-Ausgabe
    print('Opening error details: ${error['id']}');
    print('Error content: $error');
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildErrorHeader(error),
                const Divider(),
                _buildErrorDetails(error),
                if (error['images'] != null &&
                    error['images'] is List &&
                    (error['images'] as List).isNotEmpty)
                  _buildImageGallery(error['images'] as List),
                _buildActionButtons(error),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Erstellt den Kopf der Fehlermeldung
  Widget _buildErrorHeader(Map<String, dynamic> error) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            error['title'] ?? 'Fehlermeldung',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (_currentUser?.role == UserRole.admin) ...[
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _editError(error),
            tooltip: 'Bearbeiten',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _confirmDelete(error),
            tooltip: 'Löschen',
          ),
        ],
      ],
    );
  }

  // Erstellt die Detailinformationen der Fehlermeldung
  Widget _buildErrorDetails(Map<String, dynamic> error) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRow('Status:', _getStatusText(error['status'])),
        _buildDetailRow('Maschine:', error['machine_type'] ?? 'Nicht angegeben'),
        _buildDetailRow('Standort:', error['location'] ?? 'Nicht angegeben'),
        FutureBuilder<String>(
          future: userService.getUserName(error['created_by']),
          builder: (context, snapshot) {
            return _buildDetailRow('Erstellt von:', snapshot.data ?? 'Wird geladen...');
          },
        ),
        _buildDetailRow('Erstellt am:', _formatDate(error['created_at'])),
        const SizedBox(height: 8),
        const Text('Beschreibung:', style: TextStyle(fontWeight: FontWeight.bold)),
        Text(error['description'] ?? 'Keine Beschreibung'),
      ],
    );
  }

  // Erstellt eine Bildergalerie für die Fehlermeldung
  // Erstellt eine Bildergalerie für die Fehlermeldung
  Widget _buildImageGallery(dynamic imagesData) {
    // Konvertiere die Bilddaten in eine Liste
    List<dynamic> images = [];
    if (imagesData is List) {
      images = imagesData;
    } else if (imagesData is String) {
      try {
        // Versuche String als JSON zu parsen, falls es als JSON-String gespeichert wurde
        images = json.decode(imagesData) ?? [];
      } catch (e) {
        print('Fehler beim Parsen der Bilddaten: $e');
        return const SizedBox.shrink();
      }
    }

    if (images.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text('Bilder:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: images.length,
            itemBuilder: (context, index) {
              final imageStr = images[index];
              try {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => _showFullImage(imageStr),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        base64Decode(imageStr.split(',').last),
                        height: 120,
                        width: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          print('Fehler beim Laden des Bildes: $error');
                          return Container(
                            height: 120,
                            width: 120,
                            color: Colors.grey[300],
                            child: const Icon(Icons.error),
                          );
                        },
                      ),
                    ),
                  ),
                );
              } catch (e) {
                print('Fehler bei der Bildverarbeitung: $e');
                return const SizedBox.shrink();
              }
            },
          ),
        ),
      ],
    );
  }
  // Erstellt Aktionsschaltflächen für die Fehlermeldung
  Widget _buildActionButtons(Map<String, dynamic> error) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Schließen'),
        ),
      ],
    );
  }

  // Bearbeitet eine Fehlermeldung
  Future<void> _editError(Map<String, dynamic> error) async {
    // Debug-Ausgabe
    print('Editing error: ${error['id']}');
    try {
      final result = await Navigator.pushNamed(
        context,
        '/error/edit',
        arguments: error,
      );
      if (result == true) {
        _loadErrorReports();
      }
    } catch (e) {
      print('Error while editing: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Bearbeiten: $e')),
        );
      }
    }
  }

  // Bestätigt das Löschen einer Fehlermeldung
  Future<void> _confirmDelete(Map<String, dynamic> error) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fehlermeldung löschen'),
        content: const Text('Möchten Sie diese Fehlermeldung wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _deleteError(error);
    }
  }

  // Löscht eine Fehlermeldung
  Future<void> _deleteError(Map<String, dynamic> error) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/errors/${error['id']}'),
      );
      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.pop(context); // Dialog schließen
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fehlermeldung wurde gelöscht')),
          );
          _loadErrorReports();
        }
      } else {
        throw Exception('Failed to delete error report');
      }
    } catch (e) {
      print('Error while deleting: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Löschen: $e')),
        );
      }
    }
  }

  // Zeigt ein Bild in voller Größe an
  void _showFullImage(String imageStr) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.memory(
                base64Decode(imageStr.split(',').last),
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Hilfsfunktion zum Erstellen eines Detail-Reihen-Widgets
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
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

  // Formatiert ein Datum
  // In error_list_screen.dart die Methode _formatDate verbessern:
  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Nicht verfügbar';
    try {
      // Versuche verschiedene Datumsformate
      DateTime? date;

      // Format: "Sat, 01 Feb 2025 10:42:55 GMT"
      if (dateStr.contains('GMT')) {
        date = DateFormat("EEE, dd MMM yyyy HH:mm:ss 'GMT'", 'en_US').parse(dateStr);
      }
      // Format: "2025-02-01T10:42:55"
      else if (dateStr.contains('T')) {
        date = DateTime.parse(dateStr);
      }
      // Format: "2025-02-01 10:42:55"
      else {
        date = DateFormat("yyyy-MM-dd HH:mm:ss").parse(dateStr);
      }

      // Formatiere das Datum in deutsches Format
      return DateFormat('dd.MM.yyyy HH:mm').format(date);
    } catch (e) {
      print('Fehler beim Parsen des Datums $dateStr: $e');
      return 'Ungültiges Datum';
    }
  }

  // Gibt den Status-Text zurück
  String _getStatusText(String? status) {
    return statusDisplayNames[status] ?? status ?? 'Unbekannt';
  }

  // Filtert die Fehlermeldungen basierend auf dem ausgewählten Filter
  List<Map<String, dynamic>> _getFilteredErrors() {
    // Zuerst alle gelöschten Einträge ausfiltern
    final activeErrors = _errorReports.where((error) =>
    error['status'] != 'deleted'
    ).toList();

    // Dann den ausgewählten Filter anwenden
    if (_selectedFilter == 'all') return activeErrors;
    return activeErrors.where((error) =>
    error['status'] == _selectedFilter
    ).toList();
  }

  // Baut eine Karte für eine einzelne Fehlermeldung
  // In error_list_screen.dart die Widget-Methode anpassen

  Widget _buildErrorCard(Map<String, dynamic> error) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        // Titel mit Dringlichkeitsindikator
        title: Row(
          children: [
            if (error['is_urgent'] == 1)
              const Icon(Icons.warning, color: Colors.red, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                error['title'] ?? 'Keine Bezeichnung',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        // Basisinformationen
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Kategorie:', error['category'] ?? 'Nicht kategorisiert'),
            _buildInfoRow('Linie:', error['line'] ?? 'Nicht zugeordnet'),
            _buildInfoRow('Status:', _getStatusWithIcon(error['status'])),
            _buildInfoRow('Erstellt:', _formatDate(error['created_at'])),
            // Benutzerinformation direkt anzeigen
            if (error['creator_info'] != null)
              _buildInfoRow('Erstellt von:', error['creator_info']['name'] ?? 'Unbekannt'),
          ],
        ),
        // Erweiterte Details
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Detaillierte Informationen
                const Text(
                  'Details:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                _buildDetailSection('Standort:', error['location']),
                _buildDetailSection('Maschinentyp:', error['machine_type']),
                _buildDetailSection('Unterkategorie:', error['subcategory']),

                const Divider(),

                // Beschreibung
                const Text(
                  'Problembeschreibung:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(error['description'] ?? 'Keine Beschreibung vorhanden'),

                // Bilder-Sektion
                if (error['images'] != null) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Bilder:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _buildImageGallery(error['images']),
                ],

                // Aktionsbuttons
                if (_currentUser?.role == UserRole.admin ||
                    _currentUser?.role == UserRole.technician)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.edit),
                          label: const Text('Status ändern'),
                          onPressed: () => _showStatusDialog(error),
                        ),
                        const SizedBox(width: 8),
                        if (_currentUser?.role == UserRole.admin)
                          OutlinedButton.icon(
                            icon: const Icon(Icons.delete),
                            label: const Text('Löschen'),
                            onPressed: () => _confirmDelete(error),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

// Hilfsmethode zum Bauen von Informationszeilen
  Widget _buildInfoRow(String label, dynamic content) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: content is Widget
                ? content
                : Text(
              content?.toString() ?? 'Nicht verfügbar',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // Aktualisiert den Status einer Fehlermeldung
  Future<void> _updateErrorStatus(String errorId, String newStatus) async {
    try {
      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/errors/$errorId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': newStatus}),
      );
      if (response.statusCode == 200) {
        if (newStatus == 'resolved') {
          await _updateResolvedTime(errorId);
        }
        _showSuccessMessage('Status erfolgreich aktualisiert');
        _loadErrorReports();
      } else {
        _showErrorMessage('Fehler beim Aktualisieren: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorMessage('Fehler: $e');
    }
  }

  // Setzt den Zeitstempel für gelöste Fehlermeldungen
  Future<void> _updateResolvedTime(String errorId) async {
    try {
      await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/errors/$errorId/resolve'),
      );
    } catch (e) {
      debugPrint('Fehler beim Setzen des Resolved-Zeitstempels: $e');
    }
  }

  // Zeigt eine Fehlermeldung an
  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  // Zeigt eine Erfolgsnachricht an
  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }
// In der _ErrorListScreenState Klasse folgende Methoden hinzufügen:

// Status mit Icon anzeigen
  Widget _getStatusWithIcon(String? status) {
    final statusText = _getStatusText(status);
    final color = _getStatusColor(status);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _getStatusIcon(status),
          size: 16,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          statusText,
          style: TextStyle(color: color, fontSize: 12),
        ),
      ],
    );
  }

// Icon für den Status
  IconData _getStatusIcon(String? status) {
    switch(status) {
      case 'new':
        return Icons.fiber_new;
      case 'in_progress':
        return Icons.pending;
      case 'resolved':
        return Icons.check_circle;
      case 'closed':
        return Icons.done_all;
      default:
        return Icons.help_outline;
    }
  }

// Farbe für den Status
  Color _getStatusColor(String? status) {
    switch(status) {
      case 'new':
        return Colors.red;
      case 'in_progress':
        return Colors.orange;
      case 'resolved':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

// Detail-Sektion bauen
  Widget _buildDetailSection(String label, dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(value.toString()),
          ),
        ],
      ),
    );
  }

// Status-Dialog anzeigen
  Future<void> _showStatusDialog(Map<String, dynamic> error) async {
    final newStatus = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Status ändern'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: statusDisplayNames.entries.map((entry) =>
              RadioListTile<String>(
                title: Text(entry.value),
                value: entry.key,
                groupValue: error['status'],
                onChanged: (value) => Navigator.pop(context, value),
              ),
          ).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
        ],
      ),
    );

    if (newStatus != null && newStatus != error['status']) {
      await _updateErrorStatus(error['id'], newStatus);
    }
  }
  @override
  Widget build(BuildContext context) {
    final filteredErrors = _getFilteredErrors();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fehlermeldungen'),
        actions: [
          // Filter-Button
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() => _selectedFilter = value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'all',
                child: Text('Alle Fehlermeldungen'),
              ),
              ...statusDisplayNames.entries.map((entry) => PopupMenuItem(
                value: entry.key,
                child: Text(entry.value),
              )),
            ],
          ),
          // Aktualisieren-Button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadErrorReports,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : filteredErrors.isEmpty
          ? const Center(
        child: Text('Keine Fehlermeldungen vorhanden'),
      )
          : ListView.builder(
        itemCount: filteredErrors.length,
        itemBuilder: (context, index) =>
            _buildErrorCard(filteredErrors[index]),
      ),
    );
  }
}