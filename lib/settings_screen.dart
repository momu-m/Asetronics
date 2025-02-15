// settings_screen.dart
import 'package:flutter/material.dart';
import 'services/theme_service.dart';
import 'services/settings_service.dart';
import 'settings_model.dart';
import 'package:provider/provider.dart';
import 'services/biometric_service.dart';


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settingsService = SettingsService();
  final ThemeService _themeService = ThemeService();
  late AppSettings _currentSettings;
  bool _isLoading = true;
  final BiometricService _biometricService = BiometricService();
  bool _isBiometricsAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
    _loadSettings();
  }

  Future<void> _checkBiometrics() async {
    final available = await _biometricService.isBiometricsAvailable();
    setState(() {
      _isBiometricsAvailable = available;
    });
  }

// settings_screen.dart (Fortsetzung)
  Future<void> _loadSettings() async {
    try {
      setState(() => _isLoading = true);
      _currentSettings = await _settingsService.loadSettings();
      // Synchronisiere das Theme mit den geladenen Einstellungen
      _themeService.setThemeMode(_currentSettings.themeMode);
    } catch (e) {
      print('Fehler beim Laden der Einstellungen: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Methode zum Aktualisieren der Einstellungen
  Future<void> _updateSettings(AppSettings newSettings) async {
    try {
      setState(() => _isLoading = true);
      await _settingsService.saveSettings(newSettings);
      setState(() => _currentSettings = newSettings);

      // Aktualisiere das Theme wenn es sich geändert hat
      if (newSettings.themeMode != _currentSettings.themeMode) {
        _themeService.setThemeMode(newSettings.themeMode);
      }
    } catch (e) {
      print('Fehler beim Speichern der Einstellungen: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Speichern der Einstellungen')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Einstellungen'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildThemeSection(),
            const SizedBox(height: 16),
            _buildBiometricSection(), // Hier fügen wir die biometrische Sektion ein
            const SizedBox(height: 16),
            _buildNotificationSection(),
            const SizedBox(height: 16),
            _buildLanguageSection(),
          ],
        ),
      ),
    );
  }
// Füge diese neue Build-Methode hinzu
  Widget _buildBiometricSection() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Wenn keine Biometrie verfügbar ist, zeige nichts an
    if (!_isBiometricsAvailable) return const SizedBox.shrink();

    return Card(
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
              'Biometrische Anmeldung',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: isDarkMode ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Biometrische Entsperrung'),
              subtitle: const Text(
                  'Entsperren mit Fingerabdruck/Gesichtserkennung'
              ),
              value: _currentSettings.enableBiometrics,
              onChanged: (bool value) async {
                if (value) {
                  // Beim Aktivieren erst authentifizieren
                  final authenticated = await _biometricService.authenticate();
                  if (authenticated) {
                    _updateSettings(
                      _currentSettings.copyWith(enableBiometrics: value),
                    );
                  }
                } else {
                  // Beim Deaktivieren direkt umschalten
                  _updateSettings(
                    _currentSettings.copyWith(enableBiometrics: value),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeSection() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Card(
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
              'Erscheinungsbild',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: isDarkMode ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildThemeOptionTile(
              icon: Icons.brightness_auto,
              title: 'System-Theme',
              selected: _currentSettings.themeMode == AppThemeMode.system,
              onTap: () => _updateSettings(
                _currentSettings.copyWith(themeMode: AppThemeMode.system),
              ),
            ),
            _buildThemeOptionTile(
              icon: Icons.light_mode,
              title: 'Helles Theme',
              selected: _currentSettings.themeMode == AppThemeMode.light,
              onTap: () => _updateSettings(
                _currentSettings.copyWith(themeMode: AppThemeMode.light),
              ),
            ),
            _buildThemeOptionTile(
              icon: Icons.dark_mode,
              title: 'Dunkles Theme',
              selected: _currentSettings.themeMode == AppThemeMode.dark,
              onTap: () => _updateSettings(
                _currentSettings.copyWith(themeMode: AppThemeMode.dark),
              ),
            ),
          ],
        ),
      ),
    );
  }

// Neue Methode für die Theme-Auswahl Tiles
  Widget _buildThemeOptionTile({
    required IconData icon,
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: selected
                ? (isDarkMode ? Colors.blue[700] : Colors.blue[50])
                : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected
                    ? (isDarkMode ? Colors.white : Colors.blue[700])
                    : (isDarkMode ? Colors.grey[400] : Colors.grey[700]),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  color: selected
                      ? (isDarkMode ? Colors.white : Colors.blue[700])
                      : (isDarkMode ? Colors.grey[300] : Colors.grey[800]),
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              if (selected) ...[
                const Spacer(),
                Icon(
                  Icons.check,
                  color: isDarkMode ? Colors.white : Colors.blue[700],
                  size: 20,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  // Benachrichtigungseinstellungen Sektion
  Widget _buildNotificationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Benachrichtigungen',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            // Hauptschalter für Benachrichtigungen
            SwitchListTile(
              title: const Text('Benachrichtigungen aktivieren'),
              subtitle: const Text('Erhalte wichtige Mitteilungen zur Wartung'),
              value: _currentSettings.enableNotifications,
              onChanged: (bool value) {
                _updateSettings(
                  _currentSettings.copyWith(enableNotifications: value),
                );
              },
            ),
            // Weitere Benachrichtigungsoptionen (nur sichtbar wenn aktiviert)
            if (_currentSettings.enableNotifications) ...[
              const Divider(),
              ListTile(
                title: const Text('Benachrichtigungsart'),
                subtitle: Text(_getNotificationLevelText(
                    _currentSettings.notificationLevel)),
              ),
              RadioListTile<NotificationPreference>(
                title: const Text('Alle Benachrichtigungen'),
                value: NotificationPreference.all,
                groupValue: _currentSettings.notificationLevel,
                onChanged: (value) {
                  if (value != null) {
                    _updateSettings(
                      _currentSettings.copyWith(notificationLevel: value),
                    );
                  }
                },
              ),
              RadioListTile<NotificationPreference>(
                title: const Text('Nur wichtige Benachrichtigungen'),
                value: NotificationPreference.important,
                groupValue: _currentSettings.notificationLevel,
                onChanged: (value) {
                  if (value != null) {
                    _updateSettings(
                      _currentSettings.copyWith(notificationLevel: value),
                    );
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Spracheinstellungen Sektion
  Widget _buildLanguageSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sprache',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Sprache auswählen'),
              subtitle: Text(_getLanguageText(_currentSettings.language)),
              trailing: DropdownButton<String>(
                value: _currentSettings.language,
                items: [
                  DropdownMenuItem(
                    value: 'de',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('🇩🇪 '), // Emoji für deutsche Flagge
                        Text('Deutsch'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'en',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('🇬🇧 '), // Emoji für englische Flagge
                        Text('English'),
                      ],
                    ),
                  ),
                ],
                onChanged: (String? value) {
                  if (value != null) {
                    _updateSettings(
                      _currentSettings.copyWith(language: value),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Hilfsmethode für Benachrichtigungstext
  String _getNotificationLevelText(NotificationPreference level) {
    switch (level) {
      case NotificationPreference.all:
        return 'Alle Benachrichtigungen';
      case NotificationPreference.important:
        return 'Nur wichtige Benachrichtigungen';
      case NotificationPreference.none:
        return 'Keine Benachrichtigungen';
    }
  }

  // Hilfsmethode für Sprachtext
  String _getLanguageText(String languageCode) {
    switch (languageCode) {
      case 'de':
        return 'Deutsch';
      case 'en':
        return 'English';
      default:
        return 'Unbekannt';
    }
  }
}
