// dashboard_screen.dart
import 'package:flutter/material.dart';
import '../../../models/user_role.dart';
import '../../../services/user_service.dart';
import '../../widgets/ai_assistant_widget.dart';
import 'animated_dashboard_tile.dart';
import 'package:provider/provider.dart';
import '../../../services/theme_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  void _showLogoutConfirmDialog(BuildContext context) {
    final userService = UserService();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abmelden'),
        content: const Text('Möchten Sie sich wirklich abmelden?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              userService.logout();
              // Alle gespeicherten Anmeldedaten löschen
              const FlutterSecureStorage().deleteAll();
              Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
            },
            child: const Text('Abmelden'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userService = UserService();
    final currentUser = userService.currentUser;
    final themeService = context.watch<ThemeService>();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (currentUser == null) {
      return const Center(child: Text('Nicht eingeloggt'));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: Row(
          children: [
            const Text('Dashboard'),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Chip(
                avatar: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Text(
                    currentUser.username[0].toUpperCase(),
                    style: TextStyle(color: Theme.of(context).colorScheme.primary),
                  ),
                ),
                label: Text(
                  '${currentUser.username} (${UserPermissions.getRoleDisplayName(currentUser.role)})',
                  style: const TextStyle(color: Colors.white),
                ),
                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.8),
              ),
            ),
          ],
        ),
        actions: [
          // Im Benutzermenü in dashboard_screen.dart - Ergänzung des Profilmenüpunkts
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle, color: Colors.white),
            tooltip: 'Benutzermenü',
            onSelected: (value) {
              if (value == 'logout') {
                _showLogoutConfirmDialog(context);
              } else if (value == 'profile') {
                Navigator.of(context).pushNamed('/profile');
              } else if (value == 'settings') {
                Navigator.of(context).pushNamed('/settings');
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'profile',
                child: ListTile(
                  leading: Icon(Icons.person),
                  title: Text('Mein Profil'),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('Einstellungen'),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout, color: Colors.red),
                  title: Text('Abmelden', style: TextStyle(color: Colors.red)),
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ImprovedAIAssistantWidget(),
            ),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              padding: const EdgeInsets.all(16),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                if (currentUser.hasPermission('create_error_reports'))
                  const AnimatedDashboardTile(
                    icon: Icons.bug_report,
                    title: 'Fehlermeldung',
                    delay: 100,
                  ),
                if (currentUser.hasPermission('view_all_reports'))
                  const AnimatedDashboardTile(
                    icon: Icons.list,
                    title: 'Fehlerübersicht',
                    delay: 200,
                  ),
                if (currentUser.hasPermission('manage_maintenance'))
                  const AnimatedDashboardTile(
                    icon: Icons.event_note,
                    title: 'Planer',
                    delay: 300,
                  ),
                const AnimatedDashboardTile(
                  icon: Icons.assignment_ind,
                  title: 'Aufgaben',
                  delay: 400,
                ),
                const AnimatedDashboardTile(
                  icon: Icons.description,
                  title: 'Bericht schreiben',
                  delay: 900,
                ),
                const AnimatedDashboardTile(
                  icon: Icons.menu_book,
                  title: 'Anleitung',
                  delay: 700,
                ),
                const AnimatedDashboardTile(
                  icon: Icons.storage,
                  title: 'Problem-Datenbank',
                  delay: 500,
                ),
                if (currentUser.role == UserRole.admin)
                  const AnimatedDashboardTile(
                    icon: Icons.people,
                    title: 'Benutzerverwaltung',
                    delay: 600,
                  ),

              ],
            ),
          ],
        ),
      ),
    );
  }
}