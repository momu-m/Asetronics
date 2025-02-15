// test_mysql_service.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import '../../services/mysql_service.dart';

class TestMySQLScreen extends StatefulWidget {
  const TestMySQLScreen({Key? key}) : super(key: key);

  @override
  _TestMySQLScreenState createState() => _TestMySQLScreenState();
}

class _TestMySQLScreenState extends State<TestMySQLScreen> {
  final MySQLService _mysqlService = MySQLService();
  String _testResult = 'Noch kein Test durchgeführt';
  bool _isLoading = false;

  // Testen der Verbindung
  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
      _testResult = 'Teste Verbindung...';
    });

    try {
      final success = await _mysqlService.testConnection();
      setState(() {
        _testResult = success
            ? 'Verbindungstest erfolgreich'
            : 'Verbindungstest fehlgeschlagen';
      });
    } catch (e) {
      setState(() {
        _testResult = 'Fehler beim Verbindungstest: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Testen des Hinzufügens eines Benutzers
  Future<void> _testAddUser() async {
    setState(() {
      _isLoading = true;
      _testResult = 'Erstelle Testbenutzer...';
    });

    try {
      // Testdaten
      final testUser = {
        "username": "testuser_${DateTime.now().millisecondsSinceEpoch}",
        "password": "test123",
        "name": "Test User",
        "role": "operator",
        "is_active": true
      };

      setState(() {
        _testResult = 'Sende Testdaten: ${jsonEncode(testUser)}';
      });

      // Benutzer erstellen
      final success = await _mysqlService.createUser(testUser);

      setState(() {
        _testResult = success
            ? 'Benutzer wurde erfolgreich erstellt'
            : 'Benutzer konnte nicht erstellt werden';
      });
    } catch (e) {
      setState(() {
        _testResult = 'Fehler beim Erstellen des Benutzers: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MySQL Service Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _isLoading ? null : _testConnection,
              child: const Text('Verbindung testen'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _testAddUser,
              child: const Text('Benutzer erstellen'),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Testergebnis:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (_isLoading)
                      const CircularProgressIndicator()
                    else
                      Text(_testResult),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}