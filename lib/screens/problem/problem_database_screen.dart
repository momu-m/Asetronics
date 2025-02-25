// problem_database_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../config/api_config.dart';
import '../../models/user_role.dart';
import '../../main.dart' show userService, problemDatabaseService, databaseService;
import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'dart:io';
import 'package:universal_html/html.dart' as html;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/problem_model.dart';
import 'problem_detail_screen.dart';
import 'problem_form_screen.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:logger/logger.dart';

class ProblemDatabaseScreen extends StatefulWidget {
  const ProblemDatabaseScreen({super.key});

  @override
  State<ProblemDatabaseScreen> createState() => _ProblemDatabaseScreenState();
}

class _ProblemDatabaseScreenState extends State<ProblemDatabaseScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String _searchQuery = '';

  // Separate Listen für jeden Tab
  List<Map<String, dynamic>> _closedErrors = [];    // Nur geschlossene Fehler
  List<Map<String, dynamic>> _closedTasks = [];     // Nur abgeschlossene Aufgaben
  List<Map<String, dynamic>> _maintenanceReports = []; // Alle Berichte
  List<Map<String, dynamic>> _filteredErrors = [];
  List<Map<String, dynamic>> _filteredTasks = [];
  List<Map<String, dynamic>> _filteredReports = [];

  // Neue Controller und Filteroptionen
  final TextEditingController _searchController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  String _sortField = 'created_at';
  bool _sortAscending = false;
  User? _currentUser = userService.currentUser;
  final logger = Logger();

  // Filteroptionen
  String? _selectedMachineType;
  List<String> _availableMachineTypes = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _currentUser = userService.currentUser;
    _loadAllData();

    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  // Suchfunktion
  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _filterData();
    });
  }

  // Filtern nach allen Kriterien
  void _filterData() {
    setState(() {
      // Filtern der Fehler
      _filteredErrors = _closedErrors.where((error) {
        // Prüfen ob der Text in Titel oder Beschreibung enthalten ist
        bool matchesSearch = _searchQuery.isEmpty ||
            error['title']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) == true ||
            error['description']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) == true;

        // Datum-Filter
        bool matchesDate = true;
        if (_startDate != null && _endDate != null) {
          try {
            final date = DateTime.parse(error['created_at'] ?? DateTime.now().toIso8601String());
            matchesDate = date.isAfter(_startDate!) && date.isBefore(_endDate!.add(Duration(days: 1)));
          } catch (e) {
            matchesDate = false;
          }
        }

        // Maschinentyp-Filter
        bool matchesMachineType = _selectedMachineType == null ||
            error['machine_type']?.toString() == _selectedMachineType;

        return matchesSearch && matchesDate && matchesMachineType;
      }).toList();

      // Filtern der Tasks
      _filteredTasks = _closedTasks.where((task) {
        bool matchesSearch = _searchQuery.isEmpty ||
            task['title']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) == true ||
            task['description']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) == true;

        bool matchesDate = true;
        if (_startDate != null && _endDate != null) {
          try {
            final date = DateTime.parse(task['created_at'] ?? DateTime.now().toIso8601String());
            matchesDate = date.isAfter(_startDate!) && date.isBefore(_endDate!.add(Duration(days: 1)));
          } catch (e) {
            matchesDate = false;
          }
        }

        bool matchesMachineType = _selectedMachineType == null ||
            task['machine_type']?.toString() == _selectedMachineType;

        return matchesSearch && matchesDate && matchesMachineType;
      }).toList();

      // Filtern der Berichte
      _filteredReports = _maintenanceReports.where((report) {
        bool matchesSearch = _searchQuery.isEmpty ||
            report['title']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) == true ||
            report['description']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) == true;

        bool matchesDate = true;
        if (_startDate != null && _endDate != null) {
          try {
            final date = DateTime.parse(report['created_at'] ?? report['date'] ?? DateTime.now().toIso8601String());
            matchesDate = date.isAfter(_startDate!) && date.isBefore(_endDate!.add(Duration(days: 1)));
          } catch (e) {
            matchesDate = false;
          }
        }

        bool matchesMachineType = _selectedMachineType == null ||
            report['machine_type']?.toString() == _selectedMachineType;

        return matchesSearch && matchesDate && matchesMachineType;
      }).toList();

      // Sortieren der gefilterten Listen
      _sortFilteredLists();
    });
  }

  // Sortieren basierend auf aktuellem Sortierfeld und -richtung
  void _sortFilteredLists() {
    try {
      final int Function(Map<String, dynamic>, Map<String, dynamic>) sortFunction =
          (Map<String, dynamic> a, Map<String, dynamic> b) {        try {
        // Prüfen ob der Schlüssel existiert
        if (!a.containsKey(_sortField) || !b.containsKey(_sortField)) {
          // Fallback auf ein sicheres Feld
          String fallbackField = 'id';
          if (a.containsKey('created_at') && b.containsKey('created_at')) {
            fallbackField = 'created_at';
          } else if (a.containsKey('title') && b.containsKey('title')) {
            fallbackField = 'title';
          }

          // Debug-Information
          print('Sortierfeld "$_sortField" nicht gefunden, verwende $fallbackField');

          dynamic fallbackA = a[fallbackField];
          dynamic fallbackB = b[fallbackField];

          if (fallbackA == null && fallbackB == null) return 0;
          if (fallbackA == null) return _sortAscending ? -1 : 1;
          if (fallbackB == null) return _sortAscending ? 1 : -1;

          return _sortAscending
              ? fallbackA.toString().compareTo(fallbackB.toString())
              : fallbackB.toString().compareTo(fallbackA.toString());
        }

        dynamic valueA = a[_sortField];
        dynamic valueB = b[_sortField];

        // Konvertieren zu vergleichbaren Typen
        if (valueA is String && valueB is String) {
          if (_sortField.contains('date') || _sortField.contains('at')) {
            try {
              valueA = DateTime.parse(valueA);
              valueB = DateTime.parse(valueB);
            } catch (e) {
              // Fallback bei Parsing-Fehler auf String-Vergleich
              return _sortAscending ? valueA.compareTo(valueB) : valueB.compareTo(valueA);
            }
          }
        }

        // Null-Werte handhaben
        if (valueA == null && valueB == null) return 0;
        if (valueA == null) return _sortAscending ? -1 : 1;
        if (valueB == null) return _sortAscending ? 1 : -1;

        // Vergleich mit richtiger Sortierrichtung
        int result = 0;
        if (valueA is DateTime && valueB is DateTime) {
          result = valueA.compareTo(valueB);
        } else {
          result = valueA.toString().compareTo(valueB.toString());
        }

        return _sortAscending ? result : -result;
      } catch (e) {
        print('Fehler beim Vergleichen von Objekten während der Sortierung: $e');
        return 0; // Neutrale Rückgabe bei Fehler
      }
      };

      // Sortierung mit try-catch für jede Liste
      try {
        if (_filteredErrors.isNotEmpty) {
          _filteredErrors.sort(sortFunction);
        }
      } catch (e) {
        debugPrint('Fehler beim Sortieren der Fehler: $e');
      }

      try {
        if (_filteredTasks.isNotEmpty) {
          _filteredTasks.sort(sortFunction);
        }
      } catch (e) {
        print('Fehler beim Sortieren der Tasks: $e');
      }

      try {
        if (_filteredReports.isNotEmpty) {
          _filteredReports.sort(sortFunction);
        }
      } catch (e) {
        print('Fehler beim Sortieren der Berichte: $e');
      }
    } catch (e) {
      print('Allgemeiner Sortierungsfehler: $e');
    }
  }
  Future<Uint8List?> decodeImage(String base64String) async {
    if (base64String.isEmpty) return null;

    try {
      // Entferne den Header, falls vorhanden (z.B. "data:image/jpeg;base64,")
      final String sanitizedString = base64String.contains(',')
          ? base64String.split(',').last
          : base64String;

      return base64Decode(sanitizedString);
    } catch (e) {
      print('Fehler beim Decodieren des Bildes: $e');
      return null;
    }
  }
  // Datumsbereich-Auswahl
  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Colors.blue,
              surface: Theme.of(context).colorScheme.surface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _filterData();
      });
    }
  }

  // Methode zum Zurücksetzen aller Filter
  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _startDate = null;
      _endDate = null;
      _selectedMachineType = null;
      _sortField = 'created_at';
      _sortAscending = false;
      _filteredErrors = List.from(_closedErrors);
      _filteredTasks = List.from(_closedTasks);
      _filteredReports = List.from(_maintenanceReports);
      _sortFilteredLists();
    });
    _showSuccessMessage('Filter zurückgesetzt');
  }

  // Sortieren der Listen
  void _changeSorting(String field) {
    setState(() {
      // Wenn das gleiche Feld erneut ausgewählt wird, ändere die Sortierreihenfolge
      if (_sortField == field) {
        _sortAscending = !_sortAscending;
      } else {
        _sortField = field;
        _sortAscending = true;
      }
      _sortFilteredLists();
    });
  }

  // Lädt die Daten für alle Tabs mit verbesserten Fehlerbehandlung
  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);

    try {
      // Lade geschlossene Fehlermeldungen (versuche zuerst den neuen Endpunkt)
      http.Response errorsResponse;
      try {
        errorsResponse = await ApiConfig.sendRequest(
          url: '${ApiConfig.baseUrl}/problems?status=closed,resolved',
          method: 'GET',
        );
      } catch (e) {
        print('Neuer Endpunkt nicht verfügbar, verwende Fallback: $e');
        // Fallback auf alten Endpunkt
        errorsResponse = await ApiConfig.sendRequest(
          url: '${ApiConfig.baseUrl}/errors?status=closed,resolved',
          method: 'GET',
        );
      }

      // Lade abgeschlossene Wartungsaufgaben (versuche zuerst den neuen Endpunkt)
      http.Response tasksResponse;
      try {
        tasksResponse = await ApiConfig.sendRequest(
          url: '${ApiConfig.baseUrl}/completed_tasks',
          method: 'GET',
        );
      } catch (e) {
        print('Neuer Endpunkt nicht verfügbar, verwende Fallback: $e');
        // Fallback auf alten Endpunkt
        tasksResponse = await ApiConfig.sendRequest(
          url: '${ApiConfig.baseUrl}/maintenance/tasks?status=completed',
          method: 'GET',
        );
      }

      // Lade alle Wartungsberichte (versuche zuerst den neuen Endpunkt)
      http.Response reportsResponse;
      try {
        reportsResponse = await ApiConfig.sendRequest(
          url: '${ApiConfig.baseUrl}/maintenance_reports',
          method: 'GET',
        );
      } catch (e) {
        print('Neuer Endpunkt nicht verfügbar, verwende Fallback: $e');
        // Fallback auf alten Endpunkt
        reportsResponse = await ApiConfig.sendRequest(
          url: '${ApiConfig.baseUrl}/maintenance/reports',
          method: 'GET',
        );
      }

      if (mounted) {
        setState(() {
          // Daten parsen
          _closedErrors = List<Map<String, dynamic>>.from(jsonDecode(errorsResponse.body));
          _closedTasks = List<Map<String, dynamic>>.from(jsonDecode(tasksResponse.body));
          _maintenanceReports = List<Map<String, dynamic>>.from(jsonDecode(reportsResponse.body));

          // Initialisiere gefilterte Listen
          _filteredErrors = List.from(_closedErrors);
          _filteredTasks = List.from(_closedTasks);
          _filteredReports = List.from(_maintenanceReports);

          // Sortieren nach Erstellungsdatum, neueste zuerst
          _sortField = 'created_at';
          _sortAscending = false;
          _sortFilteredLists();

          // Verfügbare Maschinentypen extrahieren
          Set<String> machineTypes = {};
          for (var error in _closedErrors) {
            if (error['machine_type'] != null) {
              machineTypes.add(error['machine_type'].toString());
            }
          }
          for (var task in _closedTasks) {
            if (task['machine_type'] != null) {
              machineTypes.add(task['machine_type'].toString());
            }
          }
          for (var report in _maintenanceReports) {
            if (report['machine_type'] != null) {
              machineTypes.add(report['machine_type'].toString());
            }
          }
          _availableMachineTypes = machineTypes.toList()..sort();

          _isLoading = false;
        });
      }
    } catch (e) {
      print('Fehler beim Laden der Daten: $e');
      _showErrorMessage('Fehler beim Laden der Daten: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // PDF-Export Funktion
  Future<void> _exportToPdf(Map<String, dynamic> data, String type) async {
    try {
      setState(() => _isLoading = true);

      // PDF-Dokument erstellen
      final pdf = pw.Document();
      final logo = await _getLogoBytes();

      // Titel für den Export basierend auf Typ
      String reportTitle = 'Asetronics AG - ';
      switch (type) {
        case 'error':
          reportTitle += 'Fehlermeldungsbericht';
          break;
        case 'task':
          reportTitle += 'Wartungsaufgabenbericht';
          break;
        case 'report':
          reportTitle += 'Wartungsbericht';
          break;
      }

      // PDF-Seite erstellen
      pdf.addPage(
          pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
        // Header mit Logo
        pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  reportTitle,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  'Erstellt am: ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
            logo != null && logo.isNotEmpty
                ? pw.Image(pw.MemoryImage(logo), width: 80)
                : pw.Container(),
          ],
        ),
    pw.SizedBox(height: 20),

    // Bericht-Informationen
    pw.Container(
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
    border: pw.Border.all(),
    borderRadius: pw.BorderRadius.circular(5),
    ),
    child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        'Titel: ${data['title'] ?? 'Nicht angegeben'}',
        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 10),
      pw.Text('Erstellt von: ${data['created_by_name'] ?? 'Unbekannt'}'),
      pw.Text('Erstellt am: ${_formatDate(data['created_at'])}'),
      pw.Text('Maschinentyp: ${data['machine_type'] ?? 'Nicht angegeben'}'),
      if (data['machine_id'] != null)
        pw.Text('Maschinen-ID: ${data['machine_id']}'),
      if (data['location'] != null)
        pw.Text('Standort: ${data['location']}'),

      // Spezifische Informationen je nach Typ
      if (type == 'error') ...[
        pw.SizedBox(height: 5),
        pw.Text('Status: ${data['status'] ?? 'Unbekannt'}'),
        if (data['is_urgent'] == 1 || data['is_urgent'] == true)
          pw.Text('Dringlichkeit: Dringend',
              style: pw.TextStyle(color: PdfColors.red)),
        if (data['resolved_at'] != null)
          pw.Text('Gelöst am: ${_formatDate(data['resolved_at'])}'),
      ],

      if (type == 'task') ...[
        pw.SizedBox(height: 5),
        pw.Text('Wartungsintervall: ${data['maintenance_int'] ?? 'Nicht angegeben'}'),
        pw.Text('Geschätzte Dauer: ${data['estimated_duration'] ?? 0} Minuten'),
        if (data['last_completed'] != null)
          pw.Text('Letzter Abschluss: ${_formatDate(data['last_completed'])}'),
        if (data['completed_at'] != null)
          pw.Text('Abgeschlossen am: ${_formatDate(data['completed_at'])}'),
      ],

      if (type == 'report') ...[
        pw.SizedBox(height: 5),
        pw.Text('Arbeitszeit: ${data['worked_time'] ?? 0} Minuten'),
        pw.Text('Verwendete Teile: ${data['parts_used'] ?? 'Keine'}'),
      ],
    ],
    ),
    ),

            pw.SizedBox(height: 20),

            // Beschreibung
            pw.Text(
              'Beschreibung:',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 5),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(5),
              ),
              child: pw.Text(data['description'] ?? 'Keine Beschreibung vorhanden'),
            ),

            // Bilder
            if (data['images'] != null && data['images'].toString() != '[]') ...[
              pw.SizedBox(height: 20),
              pw.Text(
                'Beigefügte Bilder:',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              _buildPdfImageSection(data['images']),
            ],

            // Footer
            pw.Spacer(),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Asetronics AG - Vertrauliches Dokument',
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey),
                ),
                pw.Text(
                  'Seite 1/1',
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey),
                ),
              ],
            ),
          ],
        );
          },
          ),
      );

      final bytes = await pdf.save();

      // PDF-Ausgabe
      if (kIsWeb) {
        final blob = html.Blob([bytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.document.createElement('a') as html.AnchorElement
          ..href = url
          ..style.display = 'none'
          ..download = '${_getFileName(data, type)}.pdf';
        html.document.body?.children.add(anchor);
        anchor.click();
        html.document.body?.children.remove(anchor);
        html.Url.revokeObjectUrl(url);
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/${_getFileName(data, type)}.pdf');
        await file.writeAsBytes(bytes);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDF gespeichert unter: ${file.path}'),
              action: SnackBarAction(
                label: 'Öffnen',
                onPressed: () => OpenFile.open(file.path),
              ),
            ),
          );
        }
      }

      _showSuccessMessage('PDF-Export erfolgreich');
    } catch (e) {
      print('Fehler beim PDF-Export: $e');
      _showErrorMessage('Fehler beim PDF-Export: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Logo für PDF laden
  Future<Uint8List> _getLogoBytes() async {
    try {
      final ByteData data = await rootBundle.load('assets/IMG_4945.PNG');
      return data.buffer.asUint8List();
    } catch (e) {
      print('Fehler beim Laden des Logos: $e');
      return Uint8List(0);
    }
  }

  // Dateiname für den PDF-Export generieren
  String _getFileName(Map<String, dynamic> data, String type) {
    final date = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final title = (data['title'] ?? 'bericht')
        .toString()
        .replaceAll(RegExp(r'[^\w\s-]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
    return 'Asetronics_${type}_${date}_$title';
  }

  // Bilder für PDF aufbereiten
  pw.Widget _buildPdfImageSection(dynamic images) {
    try {
      List<dynamic> imageList = [];
      if (images is List) {
        imageList = images;
      } else if (images is String) {
        imageList = json.decode(images) ?? [];
      }

      if (imageList.isEmpty) return pw.Container();

      // Maximal 4 Bilder anzeigen (PDF Performance)
      final displayImages = imageList.length > 4 ? imageList.sublist(0, 4) : imageList;

      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < displayImages.length; i++)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 10),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Bild ${i + 1}:', style: pw.TextStyle(fontSize: 10)),
                  pw.SizedBox(height: 5),
                  _buildPdfImage(displayImages[i]),
                ],
              ),
            ),
          if (imageList.length > 4)
            pw.Text('... und ${imageList.length - 4} weitere Bilder',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey))
        ],
      );
    } catch (e) {
      print('PDF Bildergalerie Fehler: $e');
      return pw.Container(
        padding: const pw.EdgeInsets.all(5),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey200,
          borderRadius: pw.BorderRadius.circular(5),
        ),
        child: pw.Text('Fehler beim Laden der Bilder: $e',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.red)),
      );
    }
  }

  // Einzelnes Bild für PDF
  pw.Widget _buildPdfImage(String imageStr) {
    try {
      final imageBytes = base64Decode(imageStr.split(',').last);
      return pw.Image(
        pw.MemoryImage(imageBytes),
        height: 200,
        fit: pw.BoxFit.contain,
      );
    } catch (e) {
      return pw.Container(
        height: 50,
        padding: const pw.EdgeInsets.all(5),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey200,
          borderRadius: pw.BorderRadius.circular(5),
        ),
        child: pw.Text('Bild konnte nicht geladen werden',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.red)),
      );
    }
  }

  // Formatierung und Hilfsmethoden
  String _formatDate(dynamic date) {
    if (date == null) return 'Nicht verfügbar';
    try {
      if (date is String) {
        return DateFormat('dd.MM.yyyy HH:mm').format(DateTime.parse(date));
      }
      return DateFormat('dd.MM.yyyy HH:mm').format(date);
    } catch (e) {
      return 'Ungültiges Datum';
    }
  }

  // Baut die Liste für geschlossene Fehlermeldungen
  Widget _buildErrorsList() {
    if (_filteredErrors.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 48, color: Colors.black87),
            const SizedBox(height: 16),
            Text(
              'Keine geschlossenen Fehlermeldungen gefunden',
              style: TextStyle(color: Colors.grey[600]),
            ),
            if (_searchQuery.isNotEmpty || _startDate != null || _selectedMachineType != null)
              TextButton.icon(
                icon: const Icon(Icons.filter_alt_off),
                label: const Text('Filter zurücksetzen'),
                onPressed: _resetFilters,
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _filteredErrors.length,
      itemBuilder: (context, index) {
        final error = _filteredErrors[index];
        return Card(
          margin: const EdgeInsets.all(8),
          child: ListTile(
            title: Text(error['title'] ?? 'Keine Bezeichnung'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Geschlossen am: ${_formatDate(error['resolved_at'] ?? error['closed_at'])}'),
                Text('Erstellt von: ${error['created_by_name'] ?? 'Unbekannt'}'),
                Text('Maschine: ${error['machine_type'] ?? 'Nicht angegeben'}'),
              ],
            ),
            // Bildvorschau
            leading: error['images'] != null && error['images'] != '[]'
                ? _buildImagePreview(error['images'])
                : CircleAvatar(
              backgroundColor: Colors.red[100],
              child: const Icon(Icons.bug_report, color: Colors.red),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Export-Button
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf),
                  onPressed: () => _exportToPdf(error, 'error'),
                  tooltip: 'Als PDF exportieren',
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => _showDetailsDialog(error, 'error'),
          ),
        );
      },
    );
  }

  // Baut die Liste für abgeschlossene Wartungsaufgaben
  Widget _buildTasksList() {
    if (_filteredTasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 48, color: Colors.black87),
            const SizedBox(height: 16),
            Text(
              'Keine abgeschlossenen Wartungsaufgaben gefunden',
              style: TextStyle(color: Colors.grey[600]),
            ),
            if (_searchQuery.isNotEmpty || _startDate != null || _selectedMachineType != null)
              TextButton.icon(
                icon: const Icon(Icons.filter_alt_off),
                label: const Text('Filter zurücksetzen'),
                onPressed: _resetFilters,
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _filteredTasks.length,
      itemBuilder: (context, index) {
        final task = _filteredTasks[index];
        return Card(
          margin: const EdgeInsets.all(8),
          child: ListTile(
            title: Text(task['title'] ?? 'Keine Bezeichnung'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Abgeschlossen am: ${_formatDate(task['completed_at'])}'),
                Text('Durchgeführt von: ${task['assigned_to_name'] ?? 'Unbekannt'}'),
                Text('Maschine: ${task['machine_type'] ?? 'Nicht angegeben'}'),
                Text('Intervall: ${task['maintenance_int'] ?? 'Nicht angegeben'}'),
              ],
            ),
            leading: CircleAvatar(
              backgroundColor: Colors.blue[100],
              child: const Icon(Icons.build, color: Colors.blue),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf),
                  onPressed: () => _exportToPdf(task, 'task'),
                  tooltip: 'Als PDF exportieren',
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => _showDetailsDialog(task, 'task'),
          ),
        );
      },
    );
  }

  // Baut die Liste für Wartungsberichte
  Widget _buildReportsList() {
    if (_filteredReports.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 48, color: Colors.black87),
            const SizedBox(height: 16),
            Text(
              'Keine Wartungsberichte gefunden',
              style: TextStyle(color: Colors.grey[600]),
            ),
            if (_searchQuery.isNotEmpty || _startDate != null || _selectedMachineType != null)
              TextButton.icon(
                icon: const Icon(Icons.filter_alt_off),
                label: const Text('Filter zurücksetzen'),
                onPressed: _resetFilters,
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _filteredReports.length,
      itemBuilder: (context, index) {
        final report = _filteredReports[index];
        return Card(
          margin: const EdgeInsets.all(8),
          child: ListTile(
            title: Text(report['title'] ?? 'Keine Bezeichnung'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Erstellt am: ${_formatDate(report['created_at'] ?? report['date'])}'),
                Text('Erstellt von: ${report['created_by_name'] ?? 'Unbekannt'}'),
                Text('Maschine: ${report['machine_type'] ?? 'Nicht angegeben'}'),
                Text('Arbeitszeit: ${report['worked_time'] ?? 0} Minuten'),
              ],
            ),
            leading: report['images'] != null && report['images'] != '[]'
                ? _buildImagePreview(report['images'])
                : CircleAvatar(
              backgroundColor: Colors.green[100],
              child: const Icon(Icons.assignment_turned_in, color: Colors.green),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf),
                  onPressed: () => _exportToPdf(report, 'report'),
                  tooltip: 'Als PDF exportieren',
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => _showDetailsDialog(report, 'report'),
          ),
        );
      },
    );
  }

  // Details-Dialog für alle Eintragstypen
  void _showDetailsDialog(Map<String, dynamic> item, String type) {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(item['title'] ?? 'Details')),
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf),
                  onPressed: () {
                    Navigator.pop(context);
                    _exportToPdf(item, type);
                  },
                  tooltip: 'Als PDF exportieren',
                ),
              ],
            ),
            content: SingleChildScrollView(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    Text('Beschreibung:',
                    style: Theme.of(context).textTheme.titleSmall),
                Text(item['description'] ?? 'Keine Beschreibung'),
                const Divider(),
                Text('Erstellt von: ${item['created_by_name'] ?? 'Unbekannt'}'),
                Text('Datum: ${_formatDate(item['created_at'] ?? item['date'])}'),
                if (type == 'error' && item['resolved_at'] != null)
            Text('Gelöst am: ${_formatDate(item['resolved_at'])}'),
    if (type == 'task' && item['completed_at'] != null)
    Text('Abgeschlossen am: ${_formatDate(item['completed_at'])}'),

    if (item['images'] != null && item['images'] != '[]')
    _buildImageGallery(item['images']),

    // Zusätzliche spezifische Informationen je nach Typ
    if (type == 'task') ...[
    const Divider(),
    Text('Wartungsintervall: ${item['maintenance_int'] ?? 'Nicht angegeben'}'),
    Text('Geschätzte Dauer: ${item['estimated_duration'] ?? 0} Minuten'),
      if (item['machine_name'] != null)
        Text('Maschine: ${item['machine_name']}'),
    ],
                      if (type == 'report') ...[
                        const Divider(),
                        Text('Verwendete Teile: ${item['parts_used'] ?? 'Keine'}'),
                        Text('Tatsächliche Arbeitszeit: ${item['worked_time'] ?? 0} Minuten'),
                        if (item['category'] != null)
                          Text('Kategorie: ${item['category']}'),
                        if (item['subcategory'] != null)
                          Text('Unterkategorie: ${item['subcategory']}'),
                      ],
                      if (type == 'error') ...[
                        const Divider(),
                        Text('Status: ${item['status'] ?? 'Unbekannt'}'),
                        if (item['is_urgent'] == 1 || item['is_urgent'] == true)
                          Text('Dringlichkeit: Dringend',
                              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        if (item['category'] != null)
                          Text('Kategorie: ${item['category']}'),
                        if (item['subcategory'] != null)
                          Text('Unterkategorie: ${item['subcategory']}'),
                        if (item['line'] != null)
                          Text('Produktionslinie: ${item['line']}'),
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

  // Bildergalerie Widget
  Widget _buildImageGallery(dynamic images) {
    List<dynamic> imageList = [];

    try {
      // Konvertiere verschiedene Datentypen zur Liste
      if (images is List) {
        imageList = images;
      } else if (images is String) {
        try {
          final decoded = json.decode(images);
          if (decoded != null) {
            imageList = decoded;
          }
        } catch (e) {
          print('JSON-Decodierungsfehler: $e');
          return const Text('Fehler beim Laden der Bilder',
              style: TextStyle(color: Colors.red));
        }
      }

      if (imageList.isEmpty) {
        return const SizedBox.shrink();
      }

      // Limitiere auf 4 Bilder in der Vorschau
      final displayImages = imageList.length > 4 ? imageList.sublist(0, 4) : imageList;

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
              itemCount: displayImages.length,
              itemBuilder: (context, index) {
                final imageStr = displayImages[index];

                // Sichere Überprüfung des Bildformats
                bool isValid = false;
                try {
                  final parts = imageStr.split(',');
                  isValid = parts.length > 1 && isValidBase64(parts.last);
                } catch (e) {
                  isValid = isValidBase64(imageStr);
                }

                if (!isValid) {
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    height: 120,
                    width: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  );
                }

                return FutureBuilder<Uint8List?>(
                  future: decodeImage(imageStr),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        height: 120,
                        width: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }

                    if (snapshot.hasError || snapshot.data == null || snapshot.data!.isEmpty) {
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        height: 120,
                        width: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Icon(Icons.error_outline, color: Colors.grey),
                        ),
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () => _showFullImage(imageStr),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            snapshot.data!,
                            height: 120,
                            width: 120,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 120,
                                width: 120,
                                color: Colors.grey[200],
                                child: const Icon(Icons.error, color: Colors.red),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          if (imageList.length > 4)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '... und ${imageList.length - 4} weitere Bilder',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
        ],
      );
    } catch (e) {
      print('Allgemeiner Fehler in _buildImageGallery: $e');
      return Text(
        'Fehler beim Laden der Bilder: $e',
        style: const TextStyle(color: Colors.red),
      );
    }
  }

  // Vollbildanzeige für Bilder
  void _showFullImage(String imageStr) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullScreenImagePage(imageBase64: imageStr),
      ),
    );
  }

  // Überprüft, ob Base64-Daten gültig sind
  bool isValidBase64(String base64String) {
    if (base64String.isEmpty) return false;

    try {
      // Behandle Header in Base64-Strings
      final String sanitizedString = base64String.contains(',')
          ? base64String.split(',').last
          : base64String;

      // Wir prüfen nur die ersten 100 Zeichen um Performanceprobleme zu vermeiden
      final testString = sanitizedString.length > 100
          ? sanitizedString.substring(0, 100)
          : sanitizedString;

      // Versuche die Decodierung
      base64Decode(testString);
      return true;
    } catch (e) {
      print('Base64-Validierungsfehler: $e');
      return false;
    }
  }

  // Vollbildanzeige für Bilder
  Widget _buildFullscreenImageViewer(String imageStr) {
    return FutureBuilder<Uint8List?>(
      future: decodeImage(imageStr),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || snapshot.data == null || snapshot.data!.isEmpty) {
          return Container(
            color: Colors.grey[200],
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.broken_image, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text('Bild konnte nicht geladen werden: ${snapshot.error ?? "Ungültiges Bildformat"}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Schließen'),
                )
              ],
            ),
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.memory(
                snapshot.data!,
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.black.withOpacity(0.5),
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildImagePreview(dynamic images) {
    try {
      List<dynamic> imageList = [];

      // Konvertiere verschiedene Datentypen zur Liste
      if (images is List) {
        imageList = images;
      } else if (images is String) {
        try {
          final decoded = json.decode(images);
          if (decoded != null) {
            imageList = decoded;
          }
        } catch (e) {
          print('JSON-Decodierungsfehler: $e');
          return _buildErrorPreview();
        }
      }

      if (imageList.isEmpty) {
        return _buildErrorPreview();
      }

      // Ersten Bildstring holen und validieren
      final firstImage = imageList.first;
      if (!isValidBase64(firstImage.split(',').last)) {
        return _buildErrorPreview();
      }

      return FutureBuilder<Uint8List?>(
        future: decodeImage(firstImage),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: const CircularProgressIndicator(strokeWidth: 2),
            );
          }

          if (snapshot.hasError || snapshot.data == null || snapshot.data!.isEmpty) {
            return _buildErrorPreview();
          }

          return Container(
            height: 50,
            width: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: Image.memory(
                    snapshot.data!,
                    height: 50,
                    width: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 50,
                        width: 50,
                        color: Colors.grey[200],
                        child: const Icon(Icons.error, size: 20),
                      );
                    },
                  ),
                ),
                if (imageList.length > 1)
                  Positioned(
                    right: -5,
                    bottom: -5,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '+${imageList.length - 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      print('Fehler in _buildImagePreview: $e');
      return _buildErrorPreview();
    }
  }

  Widget _buildErrorPreview() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.image_not_supported, size: 24, color: Colors.grey),
    );
  }

  // UI für Filteroptionen
  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Suchfeld
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Suchen...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),

              // Datums-Filter Button
              IconButton(
                icon: Icon(
                  Icons.date_range,
                  color: _startDate != null ? Colors.blue : null,
                ),
                onPressed: _selectDateRange,
                tooltip: 'Nach Datum filtern',
              ),

              // Mehr-Optionen Menü
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                tooltip: 'Weitere Filteroptionen',
                onSelected: (value) {
                  if (value == 'reset') {
                    _resetFilters();
                  } else if (value.startsWith('sort_')) {
                    final field = value.substring(5);
                    _changeSorting(field);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'sort_created_at',
                    child: Text('Sortieren nach Erstelldatum'),
                  ),
                  const PopupMenuItem(
                    value: 'sort_title',
                    child: Text('Sortieren nach Titel'),
                  ),
                  const PopupMenuItem(
                    value: 'sort_machine_type',
                    child: Text('Sortieren nach Maschinentyp'),
                  ),
                  const PopupMenuItem(
                    value: 'reset',
                    child: Text('Filter zurücksetzen'),
                  ),
                ],
              ),
            ],
          ),

          // Aktive Filter anzeigen
          if (_startDate != null || _selectedMachineType != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                children: [
                  if (_startDate != null)
                    Chip(
                      label: Text(
                        'Zeitraum: ${DateFormat('dd.MM.yyyy').format(_startDate!)} - ${DateFormat('dd.MM.yyyy').format(_endDate!)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      onDeleted: () {
                        setState(() {
                          _startDate = null;
                          _endDate = null;
                          _filterData();
                        });
                      },
                      backgroundColor: Colors.blue[50],
                    ),

                  if (_selectedMachineType != null)
                    Chip(
                      label: Text(
                        'Maschine: $_selectedMachineType',
                        style: const TextStyle(fontSize: 12),
                      ),
                      onDeleted: () {
                        setState(() {
                          _selectedMachineType = null;
                          _filterData();
                        });
                      },
                      backgroundColor: Colors.blue[50],
                    ),
                ],
              ),
            ),

          // Maschinentyp-Filter
          if (_availableMachineTypes.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Text('Maschinentyp: ', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Alle'),
                    selected: _selectedMachineType == null,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedMachineType = null;
                          _filterData();
                        });
                      }
                    },
                  ),
                  const SizedBox(width: 4),
                  ...List.generate(
                    _availableMachineTypes.length > 5 ? 5 : _availableMachineTypes.length,
                        (index) => Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: ChoiceChip(
                        label: Text(_availableMachineTypes[index]),
                        selected: _selectedMachineType == _availableMachineTypes[index],
                        onSelected: (selected) {
                          setState(() {
                            _selectedMachineType = selected ? _availableMachineTypes[index] : null;
                            _filterData();
                          });
                        },
                      ),
                    ),
                  ),
                  if (_availableMachineTypes.length > 5)
                    PopupMenuButton<String>(
                      tooltip: 'Weitere Maschinentypen',
                      icon: const Icon(Icons.more_horiz, size: 20),
                      onSelected: (value) {
                        setState(() {
                          _selectedMachineType = value;
                          _filterData();
                        });
                      },
                      itemBuilder: (context) => _availableMachineTypes
                          .skip(5)
                          .map((type) => PopupMenuItem(
                        value: type,
                        child: Text(type),
                      ))
                          .toList(),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
        title: const Text('Archiv & Berichte'),
    bottom: TabBar(
    controller: _tabController,
    labelColor: Colors.white, // Hier wird die Textfarbe der aktiven Tabs auf Weiß gesetzt
    unselectedLabelColor: Colors.white70, // Hier wird die Textfarbe der inaktiven Tabs auf halbtransparentes Weiß gesetzt
    labelStyle: const TextStyle(fontWeight: FontWeight.bold), // Optional: macht den aktiven Tab fett
    indicatorColor: Colors.white, // Setzt die Farbe des Indikators auf Weiß
    tabs: const [
    Tab(text: 'Geschlossene Fehler'),
    Tab(text: 'Erledigte Wartungen'),
      Tab(text: 'Wartungsberichte'),
    ],
    ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadAllData,
              tooltip: 'Aktualisieren',
            ),
          ],
        ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Filter-Bar
          _buildFilterBar(),

          // Tab-Inhalte
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildErrorsList(),
                _buildTasksList(),
                _buildReportsList(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Vollbildansicht für Bilder
class _FullScreenImagePage extends StatelessWidget {
  final String imageBase64;

  const _FullScreenImagePage({Key? key, required this.imageBase64}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Bildansicht', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: Center(
          child: _buildImageWidget(context),
        ),
      ),
    );
  }

  Widget _buildImageWidget(BuildContext context) {
    try {
      // Entferne den Header, falls vorhanden
      final String sanitizedString = imageBase64.contains(',')
          ? imageBase64.split(',').last
          : imageBase64;

      if (!_isValidBase64Simple(sanitizedString)) {
        return _buildErrorWidget(context, 'Ungültiges Bildformat');
      }

      return FutureBuilder<Uint8List?>(
        future: _decodeSafely(sanitizedString),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            );
          }

          if (snapshot.hasError || snapshot.data == null || snapshot.data!.isEmpty) {
            return _buildErrorWidget(
              context,
              'Fehler beim Laden des Bildes: ${snapshot.error}',
            );
          }

          // Ein einfaches Image-Widget mit Fehlerbehandlung
          return SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.memory(
                  snapshot.data!,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    print('Fehler beim Anzeigen des Bildes: $error');
                    return _buildErrorWidget(
                      context,
                      'Bild konnte nicht angezeigt werden: $error',
                    );
                  },
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      print('Allgemeiner Fehler in _buildImageWidget: $e');
      return _buildErrorWidget(context, 'Ein unerwarteter Fehler ist aufgetreten: $e');
    }
  }

  // Vereinfachte Version der Base64-Validierung
  bool _isValidBase64Simple(String input) {
    try {
      if (input.isEmpty) return false;

      // Prüfe Länge und Zeichen
      final RegExp validBase64Regex = RegExp(r'^[A-Za-z0-9+/]*={0,2}$');
      return validBase64Regex.hasMatch(input);
    } catch (e) {
      return false;
    }
  }

  // Sichere Dekodierung ohne compute für einfachere Fehlerbehandlung
  Future<Uint8List?> _decodeSafely(String input) async {
    try {
      return base64Decode(input);
    } catch (e) {
      print('Fehler beim Dekodieren: $e');
      return null;
    }
  }

  // Widget für Fehleranzeige
  Widget _buildErrorWidget(BuildContext context, String message) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.broken_image,
          size: 64,
          color: Colors.white70,
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            message,
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          icon: const Icon(Icons.arrow_back),
          label: const Text('Zurück'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}