// lib/screens/profile/profile_screen.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../models/user_role.dart';
import '../../services/user_service.dart';
import '../../config/api_config.dart';
import '../../utils/error_logger.dart';
import '../auth/password_reset_dialog.dart';
import 'change_password_dialog.dart';
import 'profile_edit_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  User? _userProfile;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  // Profilinformationen laden
  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userService = Provider.of<UserService>(context, listen: false);
      final currentUser = userService.currentUser;

      if (currentUser == null) {
        setState(() {
          _errorMessage = 'Kein angemeldeter Benutzer gefunden';
          _isLoading = false;
        });
        return;
      }

      final userProfile = await userService.getUserProfile(currentUser.id);

      if (mounted) {
        setState(() {
          _userProfile = userProfile;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorLogger.logError('Fehler beim Laden des Benutzerprofils', e, stackTrace);
        setState(() {
          _errorMessage = 'Fehler beim Laden: $e';
          _isLoading = false;
        });
      }
    }
  }

  // Passwort-Änderungsdialog anzeigen
  Future<void> _showChangePasswordDialog() async {
    if (_userProfile == null) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => PasswordResetDialog( // Benutze PasswordResetDialog statt ChangePasswordDialog
        userId: _userProfile!.id,
        username: _userProfile!.username,  // Falls der Username benötigt wird
      ),
    );

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwort wurde erfolgreich geändert')),
      );
    }
  }

  // Bearbeitungsscreen anzeigen
  Future<void> _navigateToEditScreen() async {
    if (_userProfile == null) return;

    final updatedUser = await Navigator.push<User?>(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileEditScreen(user: _userProfile!),
      ),
    );

    if (updatedUser != null) {
      setState(() {
        _userProfile = updatedUser;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil wurde erfolgreich aktualisiert')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mein Profil'),
        actions: [
          // Aktualisierungsbutton
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUserProfile,
            tooltip: 'Aktualisieren',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? _buildErrorView()
          : _userProfile == null
          ? _buildNoProfileView()
          : _buildProfileView(isDarkMode),
    );
  }

  // Fehleransicht
  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 60),
          const SizedBox(height: 16),
          Text(
            'Fehler beim Laden des Profils',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(_errorMessage ?? 'Unbekannter Fehler'),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadUserProfile,
            child: const Text('Erneut versuchen'),
          ),
        ],
      ),
    );
  }

  // Ansicht, wenn kein Profil vorhanden ist
  Widget _buildNoProfileView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.account_circle, color: Colors.grey, size: 80),
          const SizedBox(height: 16),
          Text(
            'Kein Profil gefunden',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zurück zum Dashboard'),
          ),
        ],
      ),
    );
  }

  // Hauptprofilansicht
  Widget _buildProfileView(bool isDarkMode) {
    final user = _userProfile!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Profil-Header mit Bild
          _buildProfileHeader(user, isDarkMode),

          const SizedBox(height: 24),

          // Aktionsbuttons
          _buildActionButtons(),

          const SizedBox(height: 24),

          // Persönliche Informationen
          _buildInfoCard(
            title: 'Persönliche Informationen',
            icon: Icons.person,
            content: _buildPersonalInfo(user),
          ),

          const SizedBox(height: 16),

          // Kontaktinformationen
          _buildInfoCard(
            title: 'Kontaktinformationen',
            icon: Icons.contact_mail,
            content: _buildContactInfo(user),
          ),

          const SizedBox(height: 16),

          // Zugriffsinformationen
          _buildInfoCard(
            title: 'Zugriffsinformationen',
            icon: Icons.security,
            content: _buildAccessInfo(user),
          ),
        ],
      ),
    );
  }

  // Profilheader mit Bild
  Widget _buildProfileHeader(User user, bool isDarkMode) {
    final profileImage = user.profileImageBase64 != null
        ? MemoryImage(base64Decode(user.profileImageBase64!))
        : user.profileImageUrl != null
        ? NetworkImage(user.profileImageUrl!)
        : null;

    return Column(
      children: [
        // Profilbild
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
            image: profileImage != null
                ? DecorationImage(
              image: profileImage as ImageProvider,
              fit: BoxFit.cover,
            )
                : null,
          ),
          child: profileImage == null
              ? Icon(
            Icons.account_circle,
            size: 120,
            color: isDarkMode ? Colors.grey[500] : Colors.grey[400],
          )
              : null,
        ),

        const SizedBox(height: 16),

        // Benutzername
        Text(
          user.fullName ?? user.username,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 4),

        // Rolle
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            UserPermissions.getRoleDisplayName(user.role),
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // Aktionsbuttons
  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Bearbeiten-Button
        ElevatedButton.icon(
          onPressed: _navigateToEditScreen,
          icon: const Icon(Icons.edit),
          label: const Text('Bearbeiten'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),

        const SizedBox(width: 16),

        // Passwort ändern
        OutlinedButton.icon(
          onPressed: _showChangePasswordDialog,
          icon: const Icon(Icons.lock),
          label: const Text('Passwort ändern'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ],
    );
  }

  // Informationskarte
  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required Widget content,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kartentitel
            Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const Divider(height: 24),

            // Karteninhalt
            content,
          ],
        ),
      ),
    );
  }

  // Persönliche Informationen
  Widget _buildPersonalInfo(User user) {
    return Column(
      children: [
        _buildInfoItem(
          label: 'Vollständiger Name',
          value: user.fullName ?? 'Nicht angegeben',
          icon: Icons.badge,
        ),
        _buildInfoItem(
          label: 'Benutzername',
          value: user.username,
          icon: Icons.account_circle,
        ),
        _buildInfoItem(
          label: 'Abteilung',
          value: user.department ?? 'Nicht angegeben',
          icon: Icons.business,
        ),
      ],
    );
  }

  // Kontaktinformationen
  Widget _buildContactInfo(User user) {
    return Column(
      children: [
        _buildInfoItem(
          label: 'E-Mail',
          value: user.email ?? 'Nicht angegeben',
          icon: Icons.email,
        ),
        _buildInfoItem(
          label: 'Telefon',
          value: user.phone ?? 'Nicht angegeben',
          icon: Icons.phone,
        ),
      ],
    );
  }

  // Zugriffsinformationen
  Widget _buildAccessInfo(User user) {
    return Column(
      children: [
        _buildInfoItem(
          label: 'Rolle',
          value: UserPermissions.getRoleDisplayName(user.role),
          icon: Icons.admin_panel_settings,
        ),
        _buildInfoItem(
          label: 'Benutzerstatus',
          value: user.isActive ? 'Aktiv' : 'Inaktiv',
          icon: Icons.check_circle,
          valueColor: user.isActive ? Colors.green : Colors.red,
        ),
        _buildInfoItem(
          label: 'Letzte Anmeldung',
          value: user.lastLogin != null
              ? '${_formatDate(user.lastLogin!)} ${_formatTime(user.lastLogin!)}'
              : 'Keine Informationen',
          icon: Icons.access_time,
        ),
      ],
    );
  }

  // Einzelnes Informationselement
  Widget _buildInfoItem({
    required String label,
    required String value,
    required IconData icon,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Datums-Formatierung
  String _formatDate(DateTime dateTime) {
    return '${dateTime.day}.${dateTime.month}.${dateTime.year}';
  }

  // Zeit-Formatierung
  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}