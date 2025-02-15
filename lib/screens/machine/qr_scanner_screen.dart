// qr_scanner_screen.dart
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'dart:convert';
import '../../utils/machine_constants.dart';
import '../error/error_report_screen.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({Key? key}) : super(key: key);

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final availableLines = ProductionLines.getAllLines();
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool _isProcessing = false;
  bool _isFlashOn = false;
  bool _isFrontCamera = false;

  // Methode zur intelligenten QR-Code-Verarbeitung
  Future<Map<String, dynamic>> _processQRData(String rawData) async {
    try {
      // Versuch 1: Als JSON zu parsen
      try {
        return json.decode(rawData);
      } catch (e) {
        // Wenn kein valides JSON, weitermachen
      }

      // Versuch 2: Als Base64 decodieren
      try {
        final decoded = utf8.decode(base64.decode(rawData));
        return {'decoded_data': decoded, 'type': 'base64'};
      } catch (e) {
        // Wenn keine Base64, weitermachen
      }

      // Versuch 3: URL erkennen
      if (rawData.startsWith('http://') || rawData.startsWith('https://')) {
        return {
          'type': 'url',
          'url': rawData,
        };
      }

      // Versuch 4: Seriennummer/ID erkennen
      final alphanumericPattern = RegExp(r'^[A-Za-z0-9-]+$');
      if (alphanumericPattern.hasMatch(rawData)) {
        return {
          'type': 'serial_number',
          'serial': rawData,
        };
      }

      // Fallback: Unbekanntes Format als Text behandeln
      return {
        'type': 'unknown',
        'raw_data': rawData,
        'possible_machine_id': rawData.replaceAll(RegExp(r'[^A-Za-z0-9-]'), '')
      };
    } catch (e) {
      return {
        'type': 'error',
        'error': e.toString(),
        'raw_data': rawData
      };
    }
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) async {
      if (_isProcessing || scanData.code == null) return;

      setState(() => _isProcessing = true);

      try {
        await controller.pauseCamera();
        final processedData = await _processQRData(scanData.code!);

        if (!mounted) return;

        // Dialog mit Optionen anzeigen
        await _showOptionsDialog(processedData);

      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler beim Verarbeiten des QR-Codes: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isProcessing = false);
          await controller.resumeCamera();
        }
      }
    });
  }

  Future<void> _showOptionsDialog(Map<String, dynamic> data) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('QR-Code erkannt'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Typ: ${_getReadableType(data['type'])}'),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              _buildDataPreview(data),
              const SizedBox(height: 16),
              const Text(
                'Was möchten Sie tun?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _createErrorReport(data);
            },
            child: const Text('Fehler melden'),
          ),
        ],
      ),
    );
  }

  String _getReadableType(String type) {
    switch (type) {
      case 'machine':
        return 'Maschine';
      case 'url':
        return 'Web-Adresse';
      case 'serial_number':
        return 'Seriennummer';
      case 'base64':
        return 'Kodierte Daten';
      case 'unknown':
        return 'Unbekanntes Format';
      default:
        return type;
    }
  }

  Widget _buildDataPreview(Map<String, dynamic> data) {
    final type = data['type'];

    switch (type) {
      case 'machine':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Maschinen-ID: ${data['id'] ?? 'Nicht verfügbar'}'),
            if (data['serial'] != null) Text('Seriennummer: ${data['serial']}'),
            if (data['line'] != null) Text('Linie: ${data['line']}'),
          ],
        );
      case 'url':
        return Text('URL: ${data['url']}');
      case 'serial_number':
        return Text('Seriennummer: ${data['serial']}');
      case 'unknown':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nicht erkanntes Format:'),
            Text(data['raw_data'] ?? 'Keine Daten',
                style: const TextStyle(fontFamily: 'Monospace')),
          ],
        );
      default:
        return Text('Daten: ${data.toString()}');
    }
  }

  void _createErrorReport(Map<String, dynamic> data) {
    // Holen Sie die verfügbaren Linien aus ProductionLines
    final availableLines = ProductionLines.getAllLines();

    // Erstelle ein standardisiertes Maschinen-Info-Objekt
    final machineInfo = {
      'id': data['id'] ?? data['possible_machine_id'] ?? 'UNKNOWN',
      'type': data['type'] ?? 'Unbekannt',
      'name': _generateMachineName(data),
      'location': data['location'] ?? 'Unbekannt',
      // Wenn eine Linie im QR-Code ist und diese in den verfügbaren Linien existiert
      'line': data['line'] != null && availableLines.contains(data['line'])
          ? data['line']
          : ProductionLines.xLine, // Default zur X-Linie als Fallback
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ErrorReportScreen(machineInfo: machineInfo),
      ),
    );
  }

  String _generateMachineName(Map<String, dynamic> data) {
    if (data['name'] != null) return data['name'];
    if (data['type'] == 'serial_number') return 'Gerät ${data['serial']}';
    if (data['type'] == 'machine') return 'Maschine ${data['id']}';
    return 'Unbekanntes Gerät';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR-Code Scanner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelpDialog,
          ),
        ],
      ),
      body: Stack(
        children: [
          QRView(
            key: qrKey,
            onQRViewCreated: _onQRViewCreated,
            overlay: QrScannerOverlayShape(
              borderColor: Colors.blue,
              borderRadius: 10,
              borderLength: 30,
              borderWidth: 10,
              cutOutSize: MediaQuery.of(context).size.width * 0.8,
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildControlButton(
                    icon: _isFlashOn ? Icons.flash_on : Icons.flash_off,
                    label: _isFlashOn ? 'Blitz aus' : 'Blitz an',
                    onPressed: () async {
                      await controller?.toggleFlash();
                      setState(() => _isFlashOn = !_isFlashOn);
                    },
                  ),
                  _buildControlButton(
                    icon: _isFrontCamera ? Icons.camera_front : Icons.camera_rear,
                    label: 'Kamera wechseln',
                    onPressed: () async {
                      await controller?.flipCamera();
                      setState(() => _isFrontCamera = !_isFrontCamera);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon, color: Colors.white),
          onPressed: onPressed,
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scanner Hilfe'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'So verwenden Sie den Scanner:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('1. Halten Sie die Kamera über einen beliebigen QR-Code'),
              Text('2. Der Code wird automatisch erkannt'),
              Text('3. Wählen Sie die gewünschte Aktion aus'),
              Text('4. Bei Bedarf können Sie eine Fehlermeldung erstellen'),
              SizedBox(height: 16),
              Text(
                'Unterstützte QR-Code-Typen:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Maschinen-QR-Codes'),
              Text('• Seriennummern'),
              Text('• Web-Adressen'),
              Text('• Andere Formate'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Verstanden'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}