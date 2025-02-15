// main.dart

// Import-Sektion
import "package:asetronics_ag_app/screens/tasks/personal/improved_task_service.dart";
import 'package:asetronics_ag_app/screens/tasks/planner/planner_form.dart';
import 'package:asetronics_ag_app/screens/tasks/planner/planner_screen.dart';

import 'models/maintenance_schedule.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import für .env
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/error_report_service.dart';

// Screen-Imports
import 'screens/problem/problem_database_screen.dart';
import 'screens/test/database_test_screen.dart';
import 'screens/test/mysql_connection_test.dart';
import 'screens/test/mysql_test_screen.dart';
import 'screens/test/test_mysql_service.dart';
import 'services/in_app_notification_service.dart';
import 'settings_model.dart';
import 'screens/manual/manual_screen.dart';
import 'screens/tasks/planner/task_detail_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/error/error_report_screen.dart';
import 'screens/error/error_list_screen.dart';
import 'screens/maintenance/maintenance_report_screen.dart';
import 'screens/maintenance/maintenance_list_screen.dart';
import 'screens/tasks/personal/task_screen.dart';
import 'screens/auth/user_management_screen.dart';
import 'screens/machine/qr_scanner_screen.dart';
import 'settings_screen.dart';
import 'screens/tasks/planner/planner_screen.dart';
import 'screens/tasks/personal/task_screen.dart';

// Service-Imports
import 'services/mysql_service.dart';
import 'services/database_service.dart';
import 'services/user_service.dart';
import 'services/notification_service.dart';
import 'services/task_service.dart';
import 'services/maintenance_schedule_service.dart';
import 'services/problem_database_service.dart';
import 'services/settings_service.dart';
import 'services/theme_service.dart';
import 'services/manual_service.dart';
import 'services/ai_service.dart';
import 'services/task_assignment_service.dart';

// Model-Imports
import 'models/task_model.dart';

export 'services/task_service.dart';
export 'services/task_assignment_service.dart';

// Globale Service-Instanzen
final mysqlService = MySQLService();
final databaseService = DatabaseService();
final userService = UserService();
final notificationService = NotificationService();
final taskService = TaskService();
final maintenanceScheduleService = MaintenanceScheduleService();
final problemDatabaseService = ProblemDatabaseService();
final settingsService = SettingsService();
final taskAssignmentService = TaskAssignmentService();
final manualService = ManualService();
final aiService = AIService();
final inAppNotificationService = InAppNotificationService();

// Hauptfunktion der App
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Versuche, die .env-Datei zu laden und gib das Ergebnis in der Konsole aus
  try {
    await dotenv.load(fileName: "assets/.env");

    print("Umgebungsvariablen geladen: ${dotenv.env}");
  } catch (e) {
    print("Fehler beim Laden der .env Datei: $e");
  }

  // Lade App-Einstellungen
  final themeService = ThemeService();
  final appSettings = await settingsService.loadSettings();
  final errorReportService = ErrorReportService();
  final improvedTaskService = ImprovedTaskService();

  // Führe einen einfachen Verbindungstest zur Datenbank durch
  try {
    final mysqlService = MySQLService();
    final isConnected = await mysqlService.testConnection();
    print('Datenbankverbindung: ${isConnected ? "Erfolgreich" : "Fehlgeschlagen"}');

    if (!isConnected) {
      print('Versuche erneuten Verbindungsaufbau...');
      await Future.delayed(const Duration(seconds: 2));
      await mysqlService.testConnection();
      await inAppNotificationService.initialize();
    }
  } catch (e) {
    print('Fehler beim Verbindungstest: $e');
  }

  // Starte die App
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => themeService),
        ChangeNotifierProvider(create: (_) => MySQLService()),  // Wichtig!
        ChangeNotifierProvider(create: (_) => ErrorReportService()),  // Neu hinzugefügt
        ChangeNotifierProvider(create: (_) => errorReportService),
        ChangeNotifierProvider(create: (_) => userService),
        ChangeNotifierProvider(create: (_) => ImprovedTaskService()),
        ChangeNotifierProvider(create: (_) => InAppNotificationService()),
        ChangeNotifierProvider(create: (_) => AIService()),
      ],
      child: MyApp(initialSettings: appSettings),
    ),
  );
}

// Hilfsfunktionen (Testen der Verbindung, Initialisierung, etc.) bleiben unverändert

Future<void> testConnection() async {
  final mysqlService = MySQLService();

  try {
    print('Teste Datenbankverbindung...');
    await mysqlService.testConnection();

    // Beispielabfrage ausführen
    final results = await mysqlService.query('SELECT * FROM users LIMIT 1');

    if (results.isNotEmpty) {
      print('Beispielabfrage erfolgreich. Erster Benutzer:');
      print(results.first);
    } else {
      print('Keine Benutzer in der Datenbank gefunden.');
    }
  } catch (e) {
    print('Datenbanktest fehlgeschlagen: $e');
  } finally {
    await mysqlService.close();
  }
}

Future<void> initializeDatabase() async {
  try {
    await databaseService.initialize();

    // Admin-Benutzer erstellen
    await _initializeAdminUser();

    // Test-Benutzer erstellen
    await _createTestUser();

    // Tasks initialisieren
    await databaseService.initializeTasks();

    print('Datenbank erfolgreich initialisiert');
  } catch (e) {
    print('Fehler bei der Datenbank-Initialisierung: $e');
    rethrow;
  }
}

Future<void> _initializeAdminUser() async {
  try {
    final users = await mysqlService.query('SELECT * FROM users');
    if (users.isEmpty) {
      await mysqlService.query(
        'INSERT INTO users (id, name, email, password, role, department, created_at, is_active) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [
          'admin-${DateTime.now().millisecondsSinceEpoch}',
          'Administrator',
          'admin@asetronics.ch',
          'admin123',
          'admin',
          'IT',
          DateTime.now().toIso8601String(),
          true,
        ],
      );
      print('Admin-Benutzer erfolgreich erstellt');
    }
  } catch (e) {
    print('Fehler beim Erstellen des Admin-Benutzers: $e');
    rethrow;
  }
}

Future<void> _createTestUser() async {
  try {
    await mysqlService.query(
      'INSERT INTO users (id, name, email, password, role, department, created_at, is_active) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [
        'tech-${DateTime.now().millisecondsSinceEpoch}',
        'Test Techniker',
        'techniker@asetronics.ch',
        'test123',
        'technician',
        'Service',
        DateTime.now().toIso8601String(),
        true,
      ],
    );
    print('Test-Techniker erfolgreich erstellt');
  } catch (e) {
    print('Fehler beim Erstellen des Test-Benutzers: $e');
  }
}

class MyApp extends StatelessWidget {
  final AppSettings initialSettings;

  const MyApp({Key? key, required this.initialSettings}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final isDarkMode = themeService.currentThemeMode == AppThemeMode.dark;

    return MaterialApp(
      title: 'Asetronics Wartungs-App',
      debugShowCheckedModeBanner: false,
      // Wichtig für Tablet-Unterstützung
      builder: (context, child) {
        return MediaQuery(
          // Passt Schriftgrößen und Layout an
          data: MediaQuery.of(context).copyWith(
            textScaleFactor: calculateTextScaleFactor(context),
          ),
          child: child!,
        );
      },
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: isDarkMode ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: isDarkMode ? Colors.grey[900] : Colors.grey[50],
        appBarTheme: AppBarTheme(
          backgroundColor: isDarkMode ? Colors.grey[900] : Colors.blue[800],
          foregroundColor: Colors.white,
          elevation: isDarkMode ? 0 : 4,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: isDarkMode ? Colors.blue[700] : Colors.blue[800],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/error/new': (context) => const ErrorReportScreen(),
        '/error/list': (context) => const ErrorListScreen(),
        '/tasks/planner': (context) => const PlannerScreen(),
        '/reports/new': (context) => const MaintenanceReportScreen(),
        '/tasks/planner/new': (context) => const PlannerFormScreen(),
        '/tasks/planner/edit': (context) => PlannerFormScreen(
          existingTask: ModalRoute.of(context)!.settings.arguments as MaintenanceTask,
        ),
        '/tasks/personal': (context) => const TaskScreen(),
        '/tasks/reports': (context) => const MaintenanceListScreen(),
        '/users': (context) => const UserManagementScreen(),
        '/scanner': (context) => const QRScannerScreen(),
        '/problems': (context) => const ProblemDatabaseScreen(),
        '/manual': (context) => const ManualScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/test/mysql': (context) => TestMySQLScreen(),
        '/tasks/detail': (context) => TaskDetailScreen(
          task: ModalRoute.of(context)!.settings.arguments as Task,
        ),
      },
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('Fehler')),
            body: Center(
              child: Text('Route ${settings.name} wurde nicht gefunden'),
            ),
          ),
        );
      },
    );
  }

  // Berechnet Textgröße basierend auf Bildschirmgröße
  double calculateTextScaleFactor(BuildContext context) {
    var width = MediaQuery.of(context).size.width;
    if (width >= 1100) return 1.2;  // Tablet
    if (width >= 800) return 1.1;   // Large Tablet
    return 1.0;  // Standard
  }
}

class MainScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 600) {
            return TabletLayout();
          } else {
            return MobileLayout();
          }
        },
      ),
    );
  }
}

class TabletLayout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Seitenmenü für Tablets
          Container(
            width: 250,
            color: Colors.blue[100],
            child: ListView(
              children: [
                // Menüpunkte
              ],
            ),
          ),
          // Hauptinhalt
          Expanded(
            child: Container(
              color: Colors.white,
              child: Center(
                child: Text('Tablet Hauptansicht'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MobileLayout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Mobile Ansicht'),
      ),
    );
  }
}