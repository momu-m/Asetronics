// pdf_viewer_screen.dart - Finale Version
// Diese Version verzichtet auf JavaScript-Interop und nutzt nur grundlegende Flutter-Funktionen

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;

class ImprovedPdfViewerScreen extends StatefulWidget {
  final String pdfUrl;
  final String title;

  const ImprovedPdfViewerScreen({
    Key? key,
    required this.pdfUrl,
    this.title = 'PDF Anzeige'
  }) : super(key: key);

  @override
  State<ImprovedPdfViewerScreen> createState() => _ImprovedPdfViewerScreenState();
}

class _ImprovedPdfViewerScreenState extends State<ImprovedPdfViewerScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Uint8List? _pdfData;
  bool _showUrlInfo = false;
  String _fixedUrl = '';
  final PdfViewerController _pdfViewerController = PdfViewerController();

  @override
  void initState() {
    super.initState();
    _fixUrl();
    _loadPdfData();
  }

  // URL korrigieren
  void _fixUrl() {
    _fixedUrl = widget.pdfUrl;
    if (widget.pdfUrl.startsWith('/')) {
      _fixedUrl = 'https://nsylelsq.ddns.net:443${widget.pdfUrl}';
    }
    print('PDF URL: $_fixedUrl');
  }

  // Lade PDF-Daten
  Future<void> _loadPdfData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _showUrlInfo = false;
      });

      print('PDF wird geladen von: $_fixedUrl');

      // HTTP-Anfrage mit benutzerdefinierten Headern
      final response = await http.get(
        Uri.parse(_fixedUrl),
        headers: {
          'Accept': 'application/pdf',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        setState(() {
          _pdfData = response.bodyBytes;
          _isLoading = false;
        });
        print('PDF erfolgreich geladen: ${_pdfData?.length ?? 0} Bytes');
      } else {
        throw Exception('Server antwortete mit Status: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Fehler beim Laden des PDFs: $e';
      });
      print('PDF-Ladefehler: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          // Web: Option zum Anzeigen der URL-Info
          if (kIsWeb)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () {
                setState(() {
                  _showUrlInfo = !_showUrlInfo;
                });
              },
              tooltip: 'PDF-URL Info',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPdfData,
            tooltip: 'Neu laden',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Lade-Indikator
          if (_isLoading)
            const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('PDF wird geladen...', style: TextStyle(fontSize: 16)),
                  ],
                )
            ),

          // Fehlermeldung
          if (!_isLoading && _errorMessage != null)
            _buildErrorWidget(),

          // URL-Info im Web anzeigen
          if (kIsWeb && _showUrlInfo)
            _buildUrlInfoOverlay(),

          // PDF anzeigen wenn vorhanden
          if (!_isLoading && _errorMessage == null && _pdfData != null && !_showUrlInfo)
            SfPdfViewer.memory(
              _pdfData!,
              controller: _pdfViewerController,
              canShowScrollHead: true,
              onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                print('PDF-Rendering-Fehler: ${details.error}');

                setState(() {
                  if (kIsWeb) {
                    // Im Web: Zeige URL-Info an
                    _showUrlInfo = true;
                  } else {
                    _errorMessage = 'Fehler beim Rendern: ${details.error}';
                  }
                });
              },
              onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                print('PDF erfolgreich gerendert mit SfPdfViewer');
              },
            ),
        ],
      ),
    );
  }

  // Widget für Fehleranzeige
  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadPdfData,
            child: const Text('Erneut versuchen'),
          ),

          // Für Web-Anwendungen: PDF-URL anzeigen
          if (kIsWeb) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.info_outline),
              label: const Text('PDF-URL anzeigen'),
              onPressed: () => setState(() => _showUrlInfo = true),
            ),
          ],
        ],
      ),
    );
  }

  // Widget zum Anzeigen der URL-Info im Web
  Widget _buildUrlInfoOverlay() {
    return Container(
      color: Colors.white,
      child: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.picture_as_pdf, size: 64, color: Colors.blue),
                const SizedBox(height: 20),
                const Text(
                  'PDF-URL Information',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Das PDF kann im Browser direkt geöffnet werden:',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PDF-URL:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        _fixedUrl,
                        style: const TextStyle(color: Colors.blue),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  '1. Kopiere die URL durch Auswählen und STRG+C / CMD+C\n'
                      '2. Öffne einen neuen Tab im Browser\n'
                      '3. Füge die URL ein und drücke Enter',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 32),
                TextButton.icon(
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Zurück zum PDF-Viewer'),
                  onPressed: () {
                    setState(() {
                      _showUrlInfo = false;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pdfViewerController.dispose();
    super.dispose();
  }
}