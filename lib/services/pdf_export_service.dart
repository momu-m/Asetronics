// pdf_export_service.dart
import 'package:flutter/cupertino.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:universal_html/html.dart' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';

class PdfExportService {
  // Hauptmethode zum Generieren des PDFs
  static Future<Uint8List> generatePdf({
    required Map<String, dynamic> data,
    required String type,
    required BuildContext context,
    required Uint8List logo,
  }) async {
    final pdf = pw.Document();

    // PDF erstellen
    pdf.addPage(
      pw.Page(
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
                        'Asetronics AG',
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())),
                    ],
                  ),
                  pw.Image(
                    pw.MemoryImage(logo),
                    width: 100,
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Titel
              pw.Text(
                _getReportTitle(type),
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Divider(),

              // Hauptinformationen
              pw.Text('Titel: ${data['title'] ?? 'Nicht angegeben'}'),
              pw.Text('Erstellt von: ${data['created_by_name'] ?? 'Unbekannt'}'),
              pw.Text('Datum: ${_formatDate(data['created_at'])}'),
              pw.Text('Maschine: ${data['machine_type'] ?? 'Nicht angegeben'}'),

              pw.SizedBox(height: 10),
              pw.Text(
                'Beschreibung:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(data['description'] ?? 'Keine Beschreibung'),

              // Spezifische Informationen je nach Typ
              ..._getTypeSpecificInfo(data, type),

              // Bilder
              if (data['images'] != null && data['images'].toString() != '[]') ...[
                pw.SizedBox(height: 20),
                pw.Text(
                  'Beigefügte Bilder:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                _buildImageSection(data['images']),
              ],

              // Footer
              pw.Positioned(
                bottom: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Asetronics AG - Wartungsdokumentation'),
                    pw.Text('Seite 1/1'),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // Hilfsmethoden bleiben unverändert
  static String _getReportTitle(String type) {
    switch (type) {
      case 'error':
        return 'Fehlermeldungsbericht';
      case 'task':
        return 'Wartungsaufgabenbericht';
      case 'report':
        return 'Wartungsbericht';
      default:
        return 'Bericht';
    }
  }

  static String _formatDate(dynamic date) {
    if (date == null) return 'Kein Datum';
    try {
      if (date is String) {
        return DateFormat('dd.MM.yyyy HH:mm').format(DateTime.parse(date));
      }
      return DateFormat('dd.MM.yyyy HH:mm').format(date);
    } catch (e) {
      return 'Ungültiges Datum';
    }
  }

  static List<pw.Widget> _getTypeSpecificInfo(Map<String, dynamic> data, String type) {
    final widgets = <pw.Widget>[];

    switch (type) {
      case 'task':
        widgets.addAll([
          pw.SizedBox(height: 10),
          pw.Text('Wartungsdetails:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text('Intervall: ${data['maintenance_int'] ?? 'Nicht angegeben'}'),
          pw.Text('Geschätzte Dauer: ${data['estimated_duration'] ?? 0} Minuten'),
          if (data['completed_at'] != null)
            pw.Text('Abgeschlossen am: ${_formatDate(data['completed_at'])}'),
        ]);
        break;

      case 'report':
        widgets.addAll([
          pw.SizedBox(height: 10),
          pw.Text('Wartungsdetails:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text('Arbeitszeit: ${data['worked_time'] ?? 0} Minuten'),
          pw.Text('Verwendete Teile: ${data['parts_used'] ?? 'Keine'}'),
        ]);
        break;

      case 'error':
        widgets.addAll([
          pw.SizedBox(height: 10),
          pw.Text('Fehlerdetails:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text('Status: ${data['status'] ?? 'Unbekannt'}'),
          if (data['resolved_at'] != null)
            pw.Text('Gelöst am: ${_formatDate(data['resolved_at'])}'),
        ]);
        break;
    }

    return widgets;
  }

  static pw.Widget _buildImageSection(dynamic images) {
    try {
      List<dynamic> imageList = [];
      if (images is List) {
        imageList = images;
      } else if (images is String) {
        imageList = json.decode(images) ?? [];
      }

      if (imageList.isEmpty) return pw.Container();

      return pw.Column(
        children: [
          for (var imageStr in imageList)
            pw.Image(
              pw.MemoryImage(base64Decode(imageStr.split(',').last)),
              height: 200,
              fit: pw.BoxFit.contain,
            ),
        ],
      );
    } catch (e) {
      return pw.Container();
    }
  }
}