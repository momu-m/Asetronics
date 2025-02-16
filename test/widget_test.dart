// test/widget_test.dart
import 'package:asetronics_ag_app/screens/tasks/personal/improved_task_service.dart';
import 'package:asetronics_ag_app/services/ai_service.dart';
import 'package:asetronics_ag_app/services/in_app_notification_service.dart';
import 'package:asetronics_ag_app/services/mysql_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:asetronics_ag_app/main.dart';
import 'package:asetronics_ag_app/screens/settings/settings_model.dart';
import 'package:asetronics_ag_app/services/theme_service.dart';
import 'package:asetronics_ag_app/services/error_report_service.dart';
import 'package:asetronics_ag_app/services/user_service.dart';
import 'package:asetronics_ag_app/services/maintenance_schedule_service.dart';
import 'package:asetronics_ag_app/services/problem_database_service.dart';
import 'package:asetronics_ag_app/services/task_service.dart';

void main() {
  setUp(() async {
    // Initialisiere alle benötigten Services
    WidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('App startet korrekt', (WidgetTester tester) async {
    // Erstelle die notwendigen Settings
    final initialSettings = AppSettings(
      themeMode: AppThemeMode.system,
      enableNotifications: true,
      notificationLevel: NotificationPreference.important,
      language: 'de',
      enableBiometricLogin: false,
      enableBiometrics: false,
    );

    // Erstelle die App mit allen notwendigen Providern
    await tester.pumpWidget(
      MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeService()),
            ChangeNotifierProvider(create: (_) => MySQLService()),
            ChangeNotifierProvider(create: (_) => ErrorReportService()),
            ChangeNotifierProvider(create: (_) => UserService()),
            ChangeNotifierProvider(create: (_) => ImprovedTaskService()),
            ChangeNotifierProvider(create: (_) => InAppNotificationService()),
            ChangeNotifierProvider(create: (_) => AIService()),
          ],
          child: MyApp(initialSettings: initialSettings)
      ),
    );

    // Warte bis alle Animationen abgeschlossen sind
    await tester.pumpAndSettle();

    // Überprüfe ob der Login-Screen angezeigt wird
    expect(find.text('Asetronics Login'), findsOneWidget);
  });
}