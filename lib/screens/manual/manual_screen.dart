// manual_screen.dart
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'dart:convert';
import '../../models/user_role.dart';
import '../../services/ai_service.dart';
import '../../services/manual_service.dart';
import 'pdf_viewer_screen.dart';
import '../../main.dart' show manualService, aiService, userService;
import 'manual_upload_dialog.dart';
import 'package:provider/provider.dart';

class ManualScreen extends StatefulWidget {
  const ManualScreen({Key? key}) : super(key: key);

  @override
  State<ManualScreen> createState() => _ManualScreenState();
}

class _ManualScreenState extends State<ManualScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedMachineType;
  bool _isDownloading = false;
  final PdfViewerController _pdfViewerController = PdfViewerController();
  late AIService _aiService;

  @override
  void initState() {
    super.initState();
    _aiService = Provider.of<AIService>(context, listen: false);
    _loadManuals();
  }

  // Lädt die Anleitungen
  Future<void> _loadManuals() async {
    await manualService.loadManuals();
  }

  // KI-Vorschläge anzeigen
  void _showAISuggestions() {
    if (_searchQuery.isEmpty) return;

    final suggestions = aiService.suggestManualSections(_searchQuery, manualService.manuals);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('KI-Vorschläge'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: suggestions.length,
            itemBuilder: (context, index) => ListTile(
              title: Text(suggestions[index]['title']),
              subtitle: Text(suggestions[index]['machineType']),
              onTap: () {
                Navigator.pop(context);
                _openManual(suggestions[index]);
              },
            ),
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

  // QR-Code Verarbeitung
  Future<void> _handleQRScan() async {
    final result = await Navigator.pushNamed(context, '/scanner');
    if (result != null) {
      try {
        final qrData = json.decode(result.toString());
        if (qrData['type'] == 'machine') {
          final manual = await manualService.getManualForMachine(qrData['type']);
          if (manual != null && mounted) {
            _openManual(manual);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Keine passende Anleitung gefunden')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ungültiger QR-Code')),
          );
        }
      }
    }
  }

  // Suchleiste bauen
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Suchen',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
                    : null,
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          if (_searchQuery.isNotEmpty) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.psychology),
              tooltip: 'KI-Vorschläge',
              onPressed: _showAISuggestions,
            ),
          ],
        ],
      ),
    );
  }

  // Anleitung öffnen
  void _openManual(Map<String, dynamic> manual) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImprovedPdfViewerScreen(
          pdfUrl: manual['url'],
          title: manual['title'] ?? 'PDF Anzeige',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = userService.currentUser?.role == UserRole.admin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Maschinenanleitungen'),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.upload_file),
              tooltip: 'Neue Anleitung hochladen',
              onPressed: () async {
                final result = await showDialog<bool>(
                  context: context,
                  builder: (context) => const ManualUploadDialog(),
                );
                if (result == true) {
                  _loadManuals();
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _handleQRScan,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadManuals,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: Consumer<ManualService>(
              builder: (context, service, child) {
                if (service.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (service.manuals.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.menu_book_outlined, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          'Keine Anleitungen vorhanden',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (isAdmin) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.upload_file),
                            label: const Text('Anleitung hochladen'),
                            onPressed: () async {
                              final result = await showDialog<bool>(
                                context: context,
                                builder: (context) => const ManualUploadDialog(),
                              );
                              if (result == true) {
                                _loadManuals();
                              }
                            },
                          ),
                        ],
                      ],
                    ),
                  );
                }

                final filteredManuals = service.searchManuals(_searchQuery);

                if (filteredManuals.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          'Keine Anleitungen für "$_searchQuery" gefunden',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredManuals.length,
                  itemBuilder: (context, index) => _buildManualCard(filteredManuals[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Anleitung als Karte darstellen
  Widget _buildManualCard(Map<String, dynamic> manual) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
        title: Text(manual['title']),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Maschinentyp: ${manual['machine_type'] ?? 'Nicht angegeben'}'),
            if (manual['category'] != null)
              Text('Kategorie: ${manual['category']}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Herunterladen',
              onPressed: _isDownloading ? null : () => _downloadManual(manual),
            ),
            const Icon(Icons.arrow_forward_ios),
          ],
        ),
        onTap: () => _openManual(manual),
      ),
    );
  }

  // Download-Funktion (Platzhalter für jetzt)
  Future<void> _downloadManual(Map<String, dynamic> manual) async {
    // Implementiere Download-Logik
    setState(() => _isDownloading = true);

    try {
      // Implementiere hier den tatsächlichen Download
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download erfolgreich')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Download: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pdfViewerController.dispose();
    super.dispose();
  }
}

class _PdfViewerScreen extends StatefulWidget {
  final String pdfUrl;

  const _PdfViewerScreen({Key? key, required this.pdfUrl}) : super(key: key);

  @override
  State<_PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<_PdfViewerScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    // Stellen sicher, dass die URL absolut ist und mit http/https beginnt
    String fixedUrl = widget.pdfUrl;
    if (widget.pdfUrl.startsWith('/')) {
      // URL ist relativ, machen wir sie absolut
      fixedUrl = 'https://nsylelsq.ddns.net:443${widget.pdfUrl}';
    }

    print('PDF-URL (original): ${widget.pdfUrl}');
    print('PDF-URL (korrigiert): $fixedUrl');

    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Anzeige'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
                _errorMessage = null;
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          SfPdfViewer.network(
            fixedUrl,
            canShowScrollHead: true,
            onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
              setState(() {
                _isLoading = false;
                _errorMessage = 'Fehler beim Laden: ${details.error}';
              });
              print('PDF-Ladefehler: ${details.error}');
            },
            onDocumentLoaded: (PdfDocumentLoadedDetails details) {
              setState(() {
                _isLoading = false;
              });
              print('PDF erfolgreich geladen');
            },
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
          if (_errorMessage != null)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isLoading = true;
                        _errorMessage = null;
                      });
                    },
                    child: const Text('Erneut versuchen'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}