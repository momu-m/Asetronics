// lib/screens/settings/email_notification_settings.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/email_notification_service.dart';
import '../../services/user_service.dart';
import '../../utils/error_logger.dart';

class EmailNotificationSettingsScreen extends StatefulWidget {
  const EmailNotificationSettingsScreen({Key? key}) : super(key: key);

  @override
  _EmailNotificationSettingsScreenState createState() => _EmailNotificationSettingsScreenState();
}

class _EmailNotificationSettingsScreenState extends State<EmailNotificationSettingsScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage;
  String? _successMessage;
  Map<String, dynamic> _preferences = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final userService = Provider.of<UserService>(context, listen: false);
      final emailService = Provider.of<EmailNotificationService>(context, listen: false);
      final currentUser = userService.currentUser;

      if (currentUser == null) {
        throw Exception('Kein angemeldeter Benutzer');
      }

      // Lade Benutzerprofil für E-Mail-Adresse
      final userProfile = await userService.getUserProfile(currentUser.id);
      if (userProfile != null && userProfile.email != null) {
        _emailController.text = userProfile.email!;
      }

      // Lade Benachrichtigungspräferenzen
      final prefs = await emailService.loadPreferences(currentUser.id);

      if (mounted) {
        setState(() {
          _preferences = prefs;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      ErrorLogger.logError('EmailNotificationSettingsScreen._loadData', e, stackTrace);
      if (mounted) {
        setState(() {
          _errorMessage = 'Fehler beim Laden der Einstellungen: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveEmail() async {
    if (_emailController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Bitte geben Sie eine E-Mail-Adresse ein';
      });
      return;
    }

    if (!_isValidEmail(_emailController.text.trim())) {
      setState(() {
        _errorMessage = 'Bitte geben Sie eine gültige E-Mail-Adresse ein';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final userService = Provider.of<UserService>(context, listen: false);
      final currentUser = userService.currentUser;

      if (currentUser == null) {
        throw Exception('Kein angemeldeter Benutzer');
      }

      // Aktualisiere Benutzerprofil
      final updatedUser = currentUser.copyWith(
        email: _emailController.text.trim(),
      );

      final success = await userService.updateUserProfile(updatedUser);

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (success) {
            _successMessage = 'E-Mail-Adresse erfolgreich aktualisiert';
          } else {
            _errorMessage = 'Fehler beim Aktualisieren der E-Mail-Adresse';
          }
        });
      }
    } catch (e, stackTrace) {
      ErrorLogger.logError('EmailNotificationSettingsScreen._saveEmail', e, stackTrace);
      if (mounted) {
        setState(() {
          _errorMessage = 'Fehler: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _sendTestEmail() async {
    if (_emailController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Bitte geben Sie eine E-Mail-Adresse ein';
      });
      return;
    }

    if (!_isValidEmail(_emailController.text.trim())) {
      setState(() {
        _errorMessage = 'Bitte geben Sie eine gültige E-Mail-Adresse ein';
      });
      return;
    }

    setState(() {
      _isSending = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final emailService = Provider.of<EmailNotificationService>(context, listen: false);
      final success = await emailService.sendTestEmail(_emailController.text.trim());

      if (mounted) {
        setState(() {
          _isSending = false;
          if (success) {
            _successMessage = 'Test-E-Mail erfolgreich gesendet';
          } else {
            _errorMessage = emailService.lastError ?? 'Fehler beim Senden der Test-E-Mail';
          }
        });
      }
    } catch (e, stackTrace) {
      ErrorLogger.logError('EmailNotificationSettingsScreen._sendTestEmail', e, stackTrace);
      if (mounted) {
        setState(() {
          _errorMessage = 'Fehler: $e';
          _isSending = false;
        });
      }
    }
  }

  Future<void> _updatePreferences() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final userService = Provider.of<UserService>(context, listen: false);
      final emailService = Provider.of<EmailNotificationService>(context, listen: false);
      final currentUser = userService.currentUser;

      if (currentUser == null) {
        throw Exception('Kein angemeldeter Benutzer');
      }

      final success = await emailService.updatePreferences(currentUser.id, _preferences);

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (success) {
            _successMessage = 'Benachrichtigungseinstellungen aktualisiert';
          } else {
            _errorMessage = 'Fehler beim Aktualisieren der Einstellungen';
          }
        });
      }
    } catch (e, stackTrace) {
      ErrorLogger.logError('EmailNotificationSettingsScreen._updatePreferences', e, stackTrace);
      if (mounted) {
        setState(() {
          _errorMessage = 'Fehler: $e';
          _isLoading = false;
        });
      }
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('E-Mail-Benachrichtigungen'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Fehlermeldung oder Erfolgsmeldung
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),

            if (_successMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _successMessage!,
                        style: const TextStyle(color: Colors.green),
                      ),
                    ),
                  ],
                ),
              ),

            // E-Mail-Einstellung
            Card(
              elevation: isDarkMode ? 0 : 2,
              color: isDarkMode ? Colors.grey[850] : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isDarkMode ? Colors.grey[700]! : Colors.grey[200]!,
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'E-Mail-Adresse',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: isDarkMode ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Geben Sie Ihre E-Mail-Adresse ein, um Benachrichtigungen zu erhalten',
                      style: TextStyle(
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: 'E-Mail-Adresse',
                              hintText: 'beispiel@asetronics.ch',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _saveEmail,
                          child: const Text('Speichern'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isSending ? null : _sendTestEmail,
                      icon: const Icon(Icons.email),
                      label: Text(_isSending ? 'Wird gesendet...' : 'Test-E-Mail senden'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Benachrichtigungseinstellungen
            Card(
              elevation: isDarkMode ? 0 : 2,
              color: isDarkMode ? Colors.grey[850] : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isDarkMode ? Colors.grey[700]! : Colors.grey[200]!,
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Benachrichtigungseinstellungen',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: isDarkMode ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('E-Mail-Benachrichtigungen aktivieren'),
                      subtitle: const Text('Aktiviert oder deaktiviert alle E-Mail-Benachrichtigungen'),
                      value: _preferences['email_enabled'] ?? true,
                      onChanged: (value) {
                        setState(() {
                          _preferences['email_enabled'] = value;
                        });
                      },
                    ),
                    const Divider(),
                    SwitchListTile(
                      title: const Text('Aufgabenbenachrichtigungen'),
                      subtitle: const Text('Erhalte E-Mails bei neuen Aufgabenzuweisungen'),
                      value: _preferences['task_notify'] ?? true,
                      onChanged: _preferences['email_enabled'] == true
                          ? (value) {
                        setState(() {
                          _preferences['task_notify'] = value;
                        });
                      }
                          : null,
                    ),
                    SwitchListTile(
                      title: const Text('Fehlermeldungsbenachrichtigungen'),
                      subtitle: const Text('Erhalte E-Mails bei Statusänderungen von Fehlermeldungen'),
                      value: _preferences['error_notify'] ?? true,
                      onChanged: _preferences['email_enabled'] == true
                          ? (value) {
                        setState(() {
                          _preferences['error_notify'] = value;
                        });
                      }
                          : null,
                    ),
                    SwitchListTile(
                      title: const Text('Wartungserinnerungen'),
                      subtitle: const Text('Erhalte E-Mails als Erinnerung für anstehende Wartungsarbeiten'),
                      value: _preferences['maintenance_notify'] ?? true,
                      onChanged: _preferences['email_enabled'] == true
                          ? (value) {
                        setState(() {
                          _preferences['maintenance_notify'] = value;
                        });
                      }
                          : null,
                    ),
                    SwitchListTile(
                      title: const Text('Systembenachrichtigungen'),
                      subtitle: const Text('Erhalte E-Mails für wichtige Systemmeldungen'),
                      value: _preferences['system_notify'] ?? true,
                      onChanged: _preferences['email_enabled'] == true
                          ? (value) {
                        setState(() {
                          _preferences['system_notify'] = value;
                        });
                      }
                          : null,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _updatePreferences,
                      child: _isLoading
                          ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : const Text('Einstellungen speichern'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
}