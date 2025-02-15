// notification_service.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/maintenance_schedule.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

// Abstrakte Basis-Klasse für verschiedene Plattform-Implementierungen
abstract class BasePlatformNotification {
  Future<void> initialize();
  Future<void> showNotification(String title, String body);
  Future<void> requestPermission();
}

// Web-spezifische Implementierung
class WebNotification implements BasePlatformNotification {
  @override
  Future<void> initialize() async {
    // Web-spezifische Initialisierung
  }

  @override
  Future<void> showNotification(String title, String body) async {
    // Implementierung für Web-Benachrichtigungen
    // Diese wird später hinzugefügt, wenn Sie Web-Support benötigen
  }

  @override
  Future<void> requestPermission() async {
    // Web-spezifische Berechtigungsanfrage
  }
}

// Native Plattform Implementierung (iOS, Android, macOS)
class NativeNotification implements BasePlatformNotification {
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  @override
  Future<void> initialize() async {
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Implementieren Sie hier die Navigation
  }

  @override
  Future<void> showNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'error_channel',
      'Fehlermeldungen',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      platformDetails,
    );
  }

  @override
  Future<void> requestPermission() async {
    // Berechtigungen werden bereits in initialize() angefordert
  }

  // Zusätzliche Methoden für native Plattformen
  Future<void> scheduleMaintenance(MaintenanceTask task) async {
    final scheduledDate = task.nextDue.subtract(const Duration(days: 1));

    await _notifications.zonedSchedule(
      task.id.hashCode,
      'Wartung fällig',
      'Die Wartung für ${task.title} ist morgen fällig',
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'maintenance_channel',
          'Wartungsbenachrichtigungen',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}

// Haupt-Service-Klasse
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  late final BasePlatformNotification _platformNotification;

  NotificationService._internal() {
    _platformNotification = kIsWeb ? WebNotification() : NativeNotification();
  }

  Future<void> initialize() async {
    await _platformNotification.initialize();
  }

  Future<void> showErrorNotification(String title, String body) async {
    try {
      await _platformNotification.showNotification(title, body);
    } catch (e) {
      debugPrint('Fehler beim Senden der Benachrichtigung: $e');
    }
  }

  // Wrapper-Methoden für native Funktionen
  Future<void> scheduleMaintenance(MaintenanceTask task) async {
    if (_platformNotification is NativeNotification) {
      await (_platformNotification as NativeNotification).scheduleMaintenance(task);
    }
  }

  Future<void> cancelNotification(int id) async {
    if (_platformNotification is NativeNotification) {
      await (_platformNotification as NativeNotification).cancelNotification(id);
    }
  }

  Future<void> cancelAllNotifications() async {
    if (_platformNotification is NativeNotification) {
      await (_platformNotification as NativeNotification).cancelAllNotifications();
    }
  }
}