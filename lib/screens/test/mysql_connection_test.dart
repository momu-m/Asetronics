// lib/screens/test/mysql_test_screen.dart

import 'package:flutter/material.dart';
import '../../services/mysql_service.dart';

class MySQLTestScreen extends StatelessWidget {
  final _mysql = MySQLService();

  MySQLTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('MySQL Test'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            try {
              final success = await _mysql.testConnection();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      success ? 'Verbindung erfolgreich!' : 'Verbindung fehlgeschlagen'
                  ),
                  backgroundColor: success ? Colors.green : Colors.red,
                ),
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Fehler: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: Text('Verbindung testen'),
        ),
      ),
    );
  }
}