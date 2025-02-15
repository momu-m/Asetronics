// animated_dashboard_tile.dart
import 'package:flutter/material.dart';
import '../error/error_report_screen.dart';
import '../error/error_list_screen.dart';
import '../maintenance/maintenance_report_screen.dart';
import '../machine/qr_scanner_screen.dart';

class AnimatedDashboardTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final int delay;
  final VoidCallback? onTap;

  const AnimatedDashboardTile({
    Key? key,
    required this.icon,
    required this.title,
    required this.delay,
    this.onTap,
  }) : super(key: key);

  // Diese Funktion bestimmt, welcher Screen geöffnet werden soll
  void _handleNavigation(BuildContext context) {
    switch (title) {
      case 'Bericht schreiben':
        Navigator.pushNamed(context, '/reports/new');
        break;
      case 'Planer':
        Navigator.pushNamed(context, '/tasks/planner');
        break;
      case 'Aufgaben':
        Navigator.pushNamed(context, '/tasks/personal');
        break;
      case 'Fehlermeldung':
        Navigator.pushNamed(context, '/error/new');
        break;
      case 'Fehlerübersicht':
        Navigator.pushNamed(context, '/error/list');
        break;
      case 'Problem-Datenbank':
        Navigator.pushNamed(context, '/problems');
        break;
      case 'Anleitung':
        Navigator.pushNamed(context, '/manual');
        break;
      case 'Einstellungen':
        Navigator.pushNamed(context, '/settings');
        break;
      case 'Benutzerverwaltung':
        Navigator.pushNamed(context, '/users');
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$title wird noch implementiert'),
            duration: const Duration(seconds: 2),
          ),
        );
    }
  }
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 500 + delay),
      builder: (context, double opacity, child) {
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, 50 * (1 - opacity)),
            child: child,
          ),
        );
      },
      child: Card(
        elevation: 8,
        shadowColor: Colors.blue.withOpacity(0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: () => _handleNavigation(context),
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 50, color: Colors.blue[400]),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}