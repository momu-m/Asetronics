import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/user_role.dart';
import 'password_reset_dialog.dart';

class UserDialog extends StatefulWidget {
  final Map<String, dynamic>? user;

  const UserDialog({Key? key, this.user}) : super(key: key);

  @override
  State<UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends State<UserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  UserRole _selectedRole = UserRole.operator;
  bool _showPassword = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.user != null) {
      _usernameController.text = widget.user!['username'] ?? '';
      _selectedRole = _parseUserRole(widget.user!['role'] ?? 'operator');
    }
  }

  UserRole _parseUserRole(String roleStr) {
    switch (roleStr.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'teamlead':
        return UserRole.teamlead;
      case 'technician':
        return UserRole.technician;
      case 'operator':
      default:
        return UserRole.operator;
    }
  }

  // Passwort zurücksetzen Funktion
  Future<void> _resetPassword() async {
    try {
      setState(() => _isLoading = true);

      final response = await http.post(
        Uri.parse('https://nsylelsq.ddns.net:443/api/users/${widget.user!['id']}/reset-password'),
        headers: {'Content-Type': 'application/json'},
      );

      setState(() => _isLoading = false);

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwort wurde zurückgesetzt')),
        );
      } else {
        throw Exception('Fehler beim Zurücksetzen des Passworts');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    }
  }

  // Benutzer speichern
// In UserDialog, die _saveUser Methode aktualisieren:

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userData = {
        'id': widget.user?['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        'username': _usernameController.text.trim(),
        'role': _selectedRole.toString().split('.').last.toLowerCase(),
      };

      if (widget.user == null) {
        // Neuer Benutzer
        userData['password'] = _passwordController.text.trim();
        final response = await http.post(
          Uri.parse('https://nsylelsq.ddns.net:443/api/users'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(userData),
        );

        if (response.statusCode != 201) {
          throw Exception('Fehler beim Erstellen des Benutzers');
        }
      } else {
        // Bestehender Benutzer
        final response = await http.put(
          Uri.parse('https://nsylelsq.ddns.net:443/api/users/${widget.user!['id']}'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(userData),
        );

        if (response.statusCode != 200) {
          throw Exception('Fehler beim Aktualisieren des Benutzers');
        }
      }

      if (!mounted) return;
      Navigator.pop(context, true);

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.user == null ? 'Neuer Benutzer' : 'Benutzer bearbeiten'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Benutzername',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Bitte Benutzername eingeben';
                  }
                  if (value.length < 5) {
                    return 'Mindestens 5 Zeichen';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Passwort-Feld nur bei neuem Benutzer
              if (widget.user == null)
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    labelText: 'Passwort',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _showPassword = !_showPassword),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Bitte Passwort eingeben';
                    }
                    if (value.length < 8) {
                      return 'Mindestens 8 Zeichen';
                    }
                    return null;
                  },
                ),

              if (widget.user != null) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    final result = await showDialog<bool>(
                      context: context,
                      builder: (context) => PasswordResetDialog(
                        userId: widget.user!['id'],
                        username: widget.user!['username'],
                      ),
                    );
                    if (result == true) {
                      Navigator.pop(context, true);
                    }
                  },
                  icon: const Icon(Icons.lock_reset),
                  label: const Text('Passwort zurücksetzen'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                ),
              ],

              const SizedBox(height: 16),
              DropdownButtonFormField<UserRole>(
                value: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Rolle',
                  border: OutlineInputBorder(),
                ),
                items: UserRole.values.map((role) => DropdownMenuItem(
                  value: role,
                  child: Text(_getRoleDisplayName(role)),
                )).toList(),
                onChanged: (role) {
                  if (role != null) setState(() => _selectedRole = role);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveUser,
          child: _isLoading
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : Text(widget.user == null ? 'Erstellen' : 'Speichern'),
        ),
      ],
    );
  }

  String _getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Administrator';
      case UserRole.teamlead:
        return 'Teamleiter';
      case UserRole.technician:
        return 'Techniker';
      case UserRole.operator:
        return 'Bediener';
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}