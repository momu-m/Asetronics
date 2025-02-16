// in_app_notification_service.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_role.dart';
import '../main.dart' show userService;
import 'package:http/http.dart' as http;
import 'dart:convert';

class InAppNotification {
  final String id;
  final String taskId;
  final String message;
  final String type;
  final DateTime createdAt;
  bool isRead;

  InAppNotification({
    required this.id,
    required this.taskId,
    required this.message,
    required this.type,
    required this.createdAt,
    this.isRead = false,
  });

  factory InAppNotification.fromJson(Map<String, dynamic> json) {
    return InAppNotification(
      id: json['id'],
      taskId: json['task_id'],
      message: json['message'],
      type: json['type'],
      createdAt: DateTime.parse(json['created_at']),
      isRead: json['read_at'] != null,
    );
  }
}

class InAppNotificationService extends ChangeNotifier {
  List<InAppNotification> _notifications = [];
  final String _apiUrl = 'https://nsylelsq.ddns.net:443/api';
  Timer? _refreshTimer;
  final User? _currentUser = userService.currentUser;

  // Getter für ungelesene Benachrichtigungen
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  // Initialisierung des Services
  Future<void> initialize() async {
    await loadNotifications();
    // Starte regelmäßige Aktualisierung
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 1),
          (_) => loadNotifications(),
    );
  }

  // Lädt Benachrichtigungen vom Server
  Future<void> loadNotifications() async {
    try {
      final response = await http.get(
        Uri.parse('$_apiUrl/task_notifications'),
        headers: {'User-Id': _currentUser?.id ?? ''},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _notifications = data
            .map((json) => InAppNotification.fromJson(json))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      print('Fehler beim Laden der Benachrichtigungen: $e');
    }
  }

  // Erstellt eine neue Benachrichtigung
  Future<void> createNotification({
    required String taskId,
    required String message,
    required String type,
  }) async {
    try {
      final notification = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'task_id': taskId,
        'message': message,
        'type': type,
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await http.post(
        Uri.parse('$_apiUrl/task_notifications'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(notification),
      );

      if (response.statusCode == 201) {
        await loadNotifications();
      }
    } catch (e) {
      print('Fehler beim Erstellen der Benachrichtigung: $e');
    }
  }

  // Markiert eine Benachrichtigung als gelesen
  Future<void> markAsRead(String notificationId) async {
    try {
      final response = await http.patch(
        Uri.parse('$_apiUrl/task_notifications/$notificationId/read'),
      );

      if (response.statusCode == 200) {
        final notification = _notifications.firstWhere(
              (n) => n.id == notificationId,
        );
        notification.isRead = true;
        notifyListeners();
      }
    } catch (e) {
      print('Fehler beim Markieren der Benachrichtigung: $e');
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}

// notification_badge.dart
class NotificationBadge extends StatelessWidget {
  final InAppNotificationService notificationService;
  final Widget child;

  const NotificationBadge({
    Key? key,
    required this.notificationService,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (notificationService.unreadCount > 0)
          Positioned(
            right: -5,
            top: -5,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(
                minWidth: 20,
                minHeight: 20,
              ),
              child: Text(
                notificationService.unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

// notification_screen.dart
class NotificationScreen extends StatelessWidget {
  final InAppNotificationService notificationService;

  const NotificationScreen({
    Key? key,
    required this.notificationService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Benachrichtigungen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => notificationService.loadNotifications(),
          ),
        ],
      ),
      body: Consumer<InAppNotificationService>(
        builder: (context, service, child) {
          if (service._notifications.isEmpty) {
            return const Center(
              child: Text('Keine Benachrichtigungen'),
            );
          }

          return ListView.builder(
            itemCount: service._notifications.length,
            itemBuilder: (context, index) {
              final notification = service._notifications[index];
              return ListTile(
                leading: Icon(
                  _getNotificationIcon(notification.type),
                  color: notification.isRead ? Colors.grey : Colors.blue,
                ),
                title: Text(
                  notification.message,
                  style: TextStyle(
                    fontWeight: notification.isRead ?
                    FontWeight.normal :
                    FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  _formatDate(notification.createdAt),
                  style: TextStyle(
                    color: notification.isRead ?
                    Colors.grey :
                    Theme.of(context).primaryColor,
                  ),
                ),
                onTap: () {
                  if (!notification.isRead) {
                    service.markAsRead(notification.id);
                  }
                  // Navigiere zur entsprechenden Aufgabe
                  Navigator.pushNamed(
                    context,
                    '/tasks/detail',
                    arguments: notification.taskId,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'task_completed':
        return Icons.check_circle;
      case 'task_overdue':
        return Icons.warning;
      case 'task_assigned':
        return Icons.assignment_ind;
      case 'task_updated':
        return Icons.update;
      default:
        return Icons.notifications;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 60) {
      return 'Vor ${difference.inMinutes} Minuten';
    } else if (difference.inHours < 24) {
      return 'Vor ${difference.inHours} Stunden';
    } else {
      return '${date.day}.${date.month}.${date.year}';
    }
  }
}