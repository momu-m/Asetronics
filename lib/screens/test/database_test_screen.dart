// lib/screens/test/database_test_screen.dart
import 'package:flutter/material.dart';
import '../../services/database_service.dart';

class DatabaseTestScreen extends StatelessWidget {
  const DatabaseTestScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final database = DatabaseService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Datenbank Test'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            try {
              await database.initialize();
              if (!context.mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Datenbank erfolgreich initialisiert'),
                  backgroundColor: Colors.green,
                ),
              );
            } catch (e) {
              if (!context.mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Fehler: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: const Text('Datenbank initialisieren'),
        ),
      ),
    );
  }
}