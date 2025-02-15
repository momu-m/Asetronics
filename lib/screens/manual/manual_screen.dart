// manual_screen.dart
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'dart:convert';
import '../../models/user_role.dart';
import '../../services/manual_service.dart';
import '../../main.dart' show manualService, aiService, userService;
import 'manual_upload_dialog.dart';
import 'package:provider/provider.dart';
import '../../services/ai_service.dart';

class ManualScreen extends StatefulWidget {
  const ManualScreen({Key? key}) : super(key: key);

  @override
  State<ManualScreen> createState() => _ManualScreenState();
}

class _ManualScreenState extends State<ManualScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  String _searchQuery = '';
  String? _selectedMachineType;
  List<Map<String, dynamic>> _manuals = [];
  final PdfViewerController _pdfViewerController = PdfViewerController();
  late AIService _aiService;


  @override
  void initState() {
    super.initState();
    _aiService = Provider.of<AIService>(context, listen: false);
    _loadManuals();
  }

  // KI-Vorschläge anzeigen
  void _showAISuggestions() {
    if (_searchQuery.isEmpty) return;

    final suggestions = aiService.suggestManualSections(_searchQuery, _manuals);

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
          final manual = manualService.getManualForMachine(qrData['machineType']);
          if (manual != null && mounted) {
            _openManual(manual);
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

  // Anleitungen laden
  Future<void> _loadManuals() async {
    try {
      setState(() => _isLoading = true);
      await manualService.loadManuals();
      setState(() {
        _manuals = manualService.manuals;
        _isLoading = false;
      });
    } catch (e) {
      print('Fehler beim Laden der Anleitungen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Laden: $e')),
        );
      }
      setState(() => _isLoading = false);
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

  // Liste der Anleitungen bauen
  Widget _buildManualList() {
    final filteredManuals = manualService.searchManuals(_searchQuery);

    if (filteredManuals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.menu_book_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Keine Anleitungen gefunden für "$_searchQuery"'
                  : 'Keine Anleitungen vorhanden',
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
  }

  // Anleitung als Karte darstellen
  Widget _buildManualCard(Map<String, dynamic> manual) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.description),
        title: Text(manual['title']),
        subtitle: Text(manual['machineType']),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () => _openManual(manual),
      ),
    );
  }

  // Anleitung öffnen
  void _openManual(Map<String, dynamic> manual) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _PdfViewerScreen(pdfUrl: manual['url']),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = userService.currentUser?.role == UserRole.admin;  // Neue Zeile

    return Scaffold(
      appBar: AppBar(
        title: const Text('Maschinenanleitungen'),
        actions: [
          if (isAdmin)  // Neue Zeile
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
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pdfViewerController.dispose();
    super.dispose();
  }
}

class _PdfViewerScreen extends StatelessWidget {
  final String pdfUrl;

  const _PdfViewerScreen({required this.pdfUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Anzeige'),
      ),
      body: SfPdfViewer.network(
        pdfUrl,
        canShowScrollHead: true,
      ),
    );
  }
}