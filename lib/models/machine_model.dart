// machine_model.dart
import 'dart:convert'; // Wichtig: Import für jsonEncode hinzugefügt

class Machine {
  final String id;
  final String name;
  final String type;
  final String serialNumber;
  final String line;
  final String location;
  final String status;
  final DateTime lastMaintenance;

  String get qrData => jsonEncode({
    'id': id,
    'type': 'machine',
    'serialNumber': serialNumber,
    'line': line
  });

  Machine({
    required this.id,
    required this.name,
    required this.type,
    required this.serialNumber,
    required this.line,
    required this.location,
    required this.status,
    required this.lastMaintenance,
  });

  factory Machine.fromJson(Map<String, dynamic> json) {
    return Machine(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      serialNumber: json['serialNumber'] as String,
      line: json['line'] as String,
      location: json['location'] as String,
      status: json['status'] as String,
      lastMaintenance: DateTime.parse(json['lastMaintenance'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'serialNumber': serialNumber,
      'line': line,
      'location': location,
      'status': status,
      'lastMaintenance': lastMaintenance.toIso8601String(),
    };
  }
}