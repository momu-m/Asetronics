import 'package:flutter/material.dart';
import '../../models/user_role.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'user_dialog.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({Key? key}) : super(key: key);

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  // Benutzer von der API laden
  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('http://nsylelsq.ddns.net:5004/api/users'),
        headers: {
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          // Filtere deaktivierte Benutzer aus
          _users = List<Map<String, dynamic>>.from(
            data.where((user) => user['is_active'] == 1),
          );
          _isLoading = false;
        });
      } else {
        throw Exception('Fehler beim Laden der Benutzer: ${response.statusCode}');
      }
    } catch (e) {
      print('Fehler beim Laden der Benutzer: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Laden: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  // Benutzer nach Suchbegriff filtern
  List<Map<String, dynamic>> _getFilteredUsers() {
    if (_searchQuery.isEmpty) return _users;

    return _users.where((user) {
      final username = user['username'].toString().toLowerCase();
      final role = user['role'].toString().toLowerCase();
      final searchLower = _searchQuery.toLowerCase();
      return username.contains(searchLower) || role.contains(searchLower);
    }).toList();
  }

  // Benutzerkarte erstellen
  Widget _buildUserCard(Map<String, dynamic> user) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(user['username'][0].toUpperCase()),
        ),
        title: Text(user['username']),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rolle: ${_formatRole(user['role'])}'),
            Text('Status: ${user['is_active'] == 1 ? 'Aktiv' : 'Inaktiv'}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bearbeiten-Button
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _showEditDialog(user),
              tooltip: 'Bearbeiten',
            ),
            // Löschen/Deaktivieren-Button
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _showDeleteConfirmation(user),
              tooltip: 'Deaktivieren',
            ),
          ],
        ),
      ),
    );
  }

  // Formatiert die Rolle für die Anzeige
  String _formatRole(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return 'Administrator';
      case 'teamlead':
        return 'Teamleiter';
      case 'technician':
        return 'Techniker';
      case 'operator':
        return 'Bediener';
      default:
        return role;
    }
  }

  // Dialog zum Bearbeiten eines Benutzers
  Future<void> _showEditDialog(Map<String, dynamic> user) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => UserDialog(user: user),
    );

    if (result == true) {
      _loadUsers(); // Liste neu laden nach Bearbeitung
    }
  }

  // Dialog zur Bestätigung des Löschens/Deaktivierens
  Future<void> _showDeleteConfirmation(Map<String, dynamic> user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Benutzer deaktivieren'),
        content: Text('Möchten Sie ${user['username']} wirklich deaktivieren?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Deaktivieren'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final response = await http.delete(
          Uri.parse('http://nsylelsq.ddns.net:5004/api/users/${user['id']}'),
          headers: {
            'Accept': 'application/json',
          },
        );

        if (response.statusCode == 200) {
          // Entferne den Benutzer aus der lokalen Liste
          setState(() {
            _users.removeWhere((u) => u['id'] == user['id']);
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Benutzer wurde deaktiviert'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          throw Exception('Fehler beim Deaktivieren');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fehler: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = _getFilteredUsers().where((user) => user['is_active'] == 1).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Benutzerverwaltung'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
            tooltip: 'Aktualisieren',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Suchen',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredUsers.isEmpty
                ? const Center(child: Text('Keine aktiven Benutzer gefunden'))
                : ListView.builder(
              itemCount: filteredUsers.length,
              itemBuilder: (context, index) =>
                  _buildUserCard(filteredUsers[index]),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await showDialog<bool>(
            context: context,
            builder: (context) => const UserDialog(),
          );
          if (result == true) {
            _loadUsers();
          }
        },
        child: const Icon(Icons.add),
        tooltip: 'Benutzer hinzufügen',
      ),
    );
  }
}