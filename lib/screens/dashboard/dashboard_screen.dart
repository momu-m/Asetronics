// dashboard_screen.dart
import 'package:flutter/material.dart';
import '../../../models/user_role.dart';
import '../../../services/user_service.dart';
import '../../widgets/ai_assistant_widget.dart';
import 'animated_dashboard_tile.dart';
import 'package:provider/provider.dart';
import '../../../services/theme_service.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({Key? key}) : super(key: key);

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
        backgroundColor: Colors.blue[800],
        title: Row(
          children: [
            const Text('Dashboard'),
            const Spacer(),
            // Benutzerinfos in der AppBar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Chip(
                avatar: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Text(
                    currentUser.username[0].toUpperCase(),
                    style: TextStyle(color: Colors.blue[800]),
                  ),
                ),
                label: Text(
                  '${currentUser.username} (${UserPermissions.getRoleDisplayName(currentUser.role)})',
                  style: const TextStyle(color: Colors.white),
                ),
                backgroundColor: Colors.blue[600],
              ),
            ),
          ],
        ),
        actions: [
          // Optional: Logo in der AppBar statt im Body
          /*
          Wenn Sie das Logo in der AppBar möchten, entfernen Sie die Kommentare:
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Image.asset(
              'assets/IMG_4945.PNG',
              height: 40,
              errorBuilder: (context, error, stackTrace) {
                return const SizedBox(
                  height: 40,
                  child: Center(
                    child: Text('Logo konnte nicht geladen werden'),
                  ),
                );
              },
            ),
          ),
          */

          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              userService.logout();
              Navigator.of(context).pushReplacementNamed('/');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // KI-Assistent
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: AIAssistantWidget(),
            ),

            // Optional: Logo im Body belassen
            /*
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Image.asset(
                'assets/IMG_4945.PNG',
                height: 60,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox(
                    height: 60,
                    child: Center(
                      child: Text('Logo konnte nicht geladen werden'),
                    ),
                  );
                },
              ),
            ),
            */

            // Grid mit Funktionskacheln
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
                    title: 'Planer', // Geändert von 'Wartungsplaner'
                    delay: 300,
                  ),
                const AnimatedDashboardTile(
                  icon: Icons.assignment_ind,
                  title: 'Aufgaben',
                  delay: 400,
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
                  icon: Icons.settings,
                  title: 'Einstellungen',
                  delay: 800,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}