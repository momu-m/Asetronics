// lib/widgets/status_timeline_widget.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../models/task_model.dart';
import '../main.dart' show userService;

class StatusTimelineWidget extends StatelessWidget {
  final List<TaskFeedback> feedback;

  const StatusTimelineWidget({
    Key? key,
    required this.feedback,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Sortiere Feedback nach Erstellungsdatum
    final sortedFeedback = List<TaskFeedback>.from(feedback)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (sortedFeedback.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Keine Status-Updates vorhanden',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: sortedFeedback.length,
      itemBuilder: (context, index) {
        final item = sortedFeedback[index];
        final bool isLastItem = index == sortedFeedback.length - 1;

        // Prüfe, ob die Nachricht eine Statusänderung enthält
        final bool isStatusChange = item.message.contains('Status geändert zu:');

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Zeitleiste mit Verbindungslinien
            Column(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isStatusChange ? Colors.blue : Colors.grey[400],
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isStatusChange ? Colors.blue[700]! : Colors.grey[600]!,
                      width: 2,
                    ),
                  ),
                  child: isStatusChange
                      ? const Icon(Icons.sync, size: 12, color: Colors.white)
                      : const SizedBox(),
                ),
                if (!isLastItem)
                  Container(
                    width: 2,
                    height: 40,
                    color: Colors.grey[400],
                  ),
              ],
            ),
            const SizedBox(width: 12),
            // Inhalt des Zeitpunkts
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Zeitpunkt und Benutzer
                  Row(
                    children: [
                      Text(
                        DateFormat('dd.MM.yyyy HH:mm').format(item.createdAt),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isStatusChange ? Colors.blue[700] : Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 8),
                      FutureBuilder<String>(
                        future: userService.getUserName(item.userId),
                        builder: (context, snapshot) {
                          return Text(
                            'von ${snapshot.data ?? "..."}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Nachricht
                  Text(
                    item.message,
                    style: TextStyle(
                      fontWeight: isStatusChange ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),

                  // Bilder anzeigen, falls vorhanden
                  if (item.images.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 60,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: item.images.length,
                        itemBuilder: (context, imgIndex) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.memory(
                                base64Decode(item.images[imgIndex]),
                                height: 60,
                                width: 60,
                                fit: BoxFit.cover,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}