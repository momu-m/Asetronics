
// Füge diese neue Datei hinzu: lib/services/mailjet_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class MailjetService {
  final String apiKey;
  final String secretKey;
  final String senderEmail;
  final String senderName;

  MailjetService({
    required this.apiKey,
    required this.secretKey,
    required this.senderEmail,
    required this.senderName,
  });

  Future<bool> sendEmail({
    required String to,
    required String subject,
    required String htmlContent,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.mailjet.com/v3.1/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic ${base64Encode(utf8.encode('$apiKey:$secretKey'))}',
        },
        body: jsonEncode({
          'Messages': [
            {
              'From': {
                'Email': senderEmail,
                'Name': senderName,
              },
              'To': [
                {
                  'Email': to,
                  'Name': to.split('@')[0],
                }
              ],
              'Subject': subject,
              'HTMLPart': htmlContent,
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        print('E-Mail erfolgreich gesendet');
        return true;
      } else {
        print('Fehler beim Senden: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Fehler: $e');
      return false;
    }
  }
}