// test_screen.dart
import 'package:flutter/material.dart';
import '../../services/mysql_service.dart';

class TestScreen extends StatefulWidget {

  @override
  _TestScreenState createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  final MySQLService _mysql = MySQLService();
  String _testResult = '';

  Future<void> _runTests() async {
    setState(() => _testResult = 'Tests werden ausgeführt...\n');

    // Test 1: Verbindungstest
    try {
      final connected = await _mysql.testConnection();
      _addResult('Verbindungstest: ${connected ? "✅" : "❌"}');
    } catch (e) {
      _addResult('Verbindungstest fehlgeschlagen: $e');
    }

    // Test 2: Login Test
    try {
      final user = await _mysql.login('testuser', 'testpass');
      _addResult('Login Test: ${user != null ? "✅" : "❌"}');
    } catch (e) {
      _addResult('Login Test fehlgeschlagen: $e');
    }

    // Test 3: Benutzer abrufen
    try {
      final users = await _mysql.getUsers();
      _addResult('Benutzer abrufen: ${users.isNotEmpty ? "✅" : "❌"}');
      _addResult('Anzahl Benutzer: ${users.length}');
    } catch (e) {
      _addResult('Benutzer abrufen fehlgeschlagen: $e');
    }
  }

  void _addResult(String result) {
    setState(() => _testResult += '$result\n');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('API Tests')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _runTests,
              child: Text('Tests ausführen'),
            ),
            SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Text(_testResult),
              ),
            ),
          ],
        ),
      ),
    );
  }
}