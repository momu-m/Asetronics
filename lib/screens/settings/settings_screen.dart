// settings_screen.dart
import 'package:flutter/material.dart';
import '../../services/theme_service.dart';
import '../../services/settings_service.dart';
import 'settings_model.dart';
import 'package:provider/provider.dart';
import '../../services/biometric_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settingsService = SettingsService();
  late ThemeService _themeService;
  late AppSettings _currentSettings;
  bool _isLoading = true;
  final BiometricService _biometricService = BiometricService();
  bool _isBiometricsAvailable = false;
  bool _themeChanged = false;

  @override
  void initState() {
    super.initState();
    _themeService = Provider.of<ThemeService>(context, listen: false);
    _checkBiometrics();
    _loadSettings();
  }

  Future<void> _checkBiometrics() async {
    final available = await _biometricService.isBiometricsAvailable();
    setState(() {
      _isBiometricsAvailable = available;
    });
  }

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

  // Methode zum Aktualisieren der Einstellungen mit sofortiger UI-Aktualisierung
  Future<void> _updateSettings(AppSettings newSettings) async {
    try {
      setState(() => _isLoading = true);
      await _settingsService.saveSettings(newSettings);

      // Theme-Änderung erkennen
      bool themeChanged = newSettings.themeMode != _currentSettings.themeMode;

      setState(() {
        _currentSettings = newSettings;
        _themeChanged = themeChanged;
      });

      // Aktualisiere das Theme sofort
      if (themeChanged) {
        _themeService.setThemeMode(newSettings.themeMode);
      }
    } catch (e) {
      print('Fehler beim Speichern der Einstellungen: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Fehler beim Speichern der Einstellungen')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Consumer für sofortige Theme-Updates
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
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
                      // Theme-Info-Banner, wenn Theme geändert wurde
                      if (_themeChanged)
                        Card(
                          color: Colors.amber.withOpacity(0.2),
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline,
                                    color: Colors.amber),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Das Theme wurde geändert. Einige Änderungen werden eventuell erst nach einem App-Neustart vollständig sichtbar.',
                                    style: TextStyle(color: Colors.amber[800]),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Bestehende Theme-Einstellungen
                      _buildThemeSection(),
                      const SizedBox(height: 16),
                      _buildBiometricSection(),
                      const SizedBox(height: 16),
                      _buildNotificationSection(),
                      const SizedBox(height: 16),
                      _buildLanguageSection(),
                      const SizedBox(height: 16),
                      _buildAppDataSection(),
                    ],
                  ),
                ),
        );
      },
    );
  }

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
              subtitle:
                  const Text('Entsperren mit Fingerabdruck/Gesichtserkennung'),
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

            // Verbesserte Theme-Optionen mit Beschreibungen
            _buildThemeOptionTile(
              icon: Icons.brightness_auto,
              title: 'System-Theme',
              description:
                  'Passt sich automatisch an deine Systemeinstellungen an',
              selected: _currentSettings.themeMode == AppThemeMode.system,
              onTap: () => _updateSettings(
                _currentSettings.copyWith(themeMode: AppThemeMode.system),
              ),
            ),
            const SizedBox(height: 8),

            _buildThemeOptionTile(
              icon: Icons.light_mode,
              title: 'Helles Theme',
              description: 'Helle Farben mit blauer Akzentfarbe',
              selected: _currentSettings.themeMode == AppThemeMode.light,
              onTap: () => _updateSettings(
                _currentSettings.copyWith(themeMode: AppThemeMode.light),
              ),
            ),
            const SizedBox(height: 8),

            _buildThemeOptionTile(
              icon: Icons.dark_mode,
              title: 'Dunkles Theme',
              description:
                  'Dunkle Farben mit blauer Akzentfarbe, schont die Augen',
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

  Widget _buildThemeOptionTile({
    required IconData icon,
    required String title,
    required bool selected,
    required VoidCallback onTap,
    String? description,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: selected
              ? (isDarkMode ? Colors.blue[900] : Colors.blue[50])
              : Colors.transparent,
          border: Border.all(
            color: selected
                ? (isDarkMode ? Colors.blue[700]! : Colors.blue[300]!)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            // Icon mit Animation
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: selected
                    ? (isDarkMode ? Colors.blue[700] : Colors.blue[100])
                    : (isDarkMode ? Colors.grey[800] : Colors.grey[200]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: selected
                    ? (isDarkMode ? Colors.white : Colors.blue[700])
                    : (isDarkMode ? Colors.grey[400] : Colors.grey[700]),
                size: 20,
              ),
            ),
            const SizedBox(width: 16),

            // Titel und Beschreibung
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: selected
                          ? (isDarkMode ? Colors.white : Colors.blue[700])
                          : (isDarkMode ? Colors.grey[300] : Colors.grey[800]),
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 16,
                    ),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Auswahlindikator
            if (selected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDarkMode ? Colors.blue[700] : Colors.blue[600],
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Benachrichtigungseinstellungen Sektion
  Widget _buildNotificationSection() {
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
              'Benachrichtigungen',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: isDarkMode ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
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
              const ListTile(
                title: Text('Benachrichtigungsart'),
              ),
              RadioListTile<NotificationPreference>(
                title: const Text('Alle Benachrichtigungen'),
                subtitle: const Text(
                    'Erhalte Benachrichtigungen zu allen Ereignissen'),
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
                subtitle: const Text(
                    'Nur bei dringenden Ereignissen benachrichtigt werden'),
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
              RadioListTile<NotificationPreference>(
                title: const Text('Keine Benachrichtigungen'),
                subtitle: const Text('Alle Benachrichtigungen deaktivieren'),
                value: NotificationPreference.none,
                groupValue: _currentSettings.notificationLevel,
                onChanged: (value) {
                  if (value != null) {
                    _updateSettings(
                      _currentSettings.copyWith(notificationLevel: value),
                    );
                  }
                },
              ),

              const Divider(),
              ListTile(
                leading: const Icon(Icons.email),
                title: const Text('E-Mail-Benachrichtigungen'),
                subtitle:
                    const Text('Konfigurieren Sie E-Mail-Benachrichtigungen'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pushNamed(context, '/settings/email_notifications');
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
              'Sprache',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: isDarkMode ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
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
                      children: const [
                        Text('🇩🇪 '), // Emoji für deutsche Flagge
                        Text('Deutsch'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'en',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
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

  // Neue Sektion: App-Daten-Management
  Widget _buildAppDataSection() {
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
              'App-Daten',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: isDarkMode ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            ListTile(
              leading: Icon(Icons.delete_outline,
                  color: isDarkMode ? Colors.red[300] : Colors.red[700]),
              title: const Text('Cache leeren'),
              subtitle: const Text(
                  'Temporäre Daten entfernen, um Speicherplatz freizugeben'),
              onTap: () => _showCacheClearDialog(),
            ),

            ListTile(
              leading: Icon(Icons.system_update,
                  color: isDarkMode ? Colors.blue[300] : Colors.blue[700]),
              title: const Text('Nach Updates suchen'),
              subtitle:
                  const Text('Prüfen, ob eine neue Version verfügbar ist'),
              onTap: () => _checkForUpdates(),
            ),

            const Divider(),

            ListTile(
              leading: Icon(Icons.refresh,
                  color: isDarkMode ? Colors.orange[300] : Colors.orange[700]),
              title: const Text('Einstellungen zurücksetzen'),
              subtitle: const Text(
                  'Alle Einstellungen auf Standardwerte zurücksetzen'),
              onTap: () => _showResetSettingsDialog(),
            ),

            const SizedBox(height: 8),

            // Info-Text für App-Version
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'App-Version: 1.0.0',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Dialog zum Leeren des Caches
  Future<void> _showCacheClearDialog() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cache leeren'),
        content: const Text(
            'Möchtest du wirklich den Cache leeren? Die App wird dadurch '
            'möglicherweise kurzzeitig langsamer, da Daten neu geladen werden müssen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cache leeren'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Implementiere hier die Cache-Leerung
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cache wurde geleert')),
      );
    }
  }

  // Methode zum Prüfen auf Updates
  void _checkForUpdates() {
    // Hier würdest du einen API-Aufruf implementieren
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Du verwendest bereits die neueste Version')),
    );
  }

  // Dialog zum Zurücksetzen der Einstellungen
  Future<void> _showResetSettingsDialog() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Einstellungen zurücksetzen'),
        content: const Text(
            'Möchtest du wirklich alle Einstellungen auf die Standardwerte zurücksetzen? '
            'Diese Aktion kann nicht rückgängig gemacht werden.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Zurücksetzen'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        setState(() => _isLoading = true);
        await _settingsService.resetSettings();
        _loadSettings(); // Lade Standardeinstellungen neu

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Einstellungen wurden zurückgesetzt')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler: $e')),
          );
        }
      }
    }
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
