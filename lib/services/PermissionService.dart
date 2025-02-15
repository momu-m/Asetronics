// lib/services/permission_service.dart

import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  Future<bool> requestCameraPermission(BuildContext context) async {
    final status = await Permission.camera.request();
    if (status.isPermanentlyDenied) {
      if (!context.mounted) return false;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Kamera-Berechtigung'),
          content: const Text(
            'Die Kamera-Berechtigung wird für den QR-Scanner benötigt. '
                'Bitte aktivieren Sie die Berechtigung in den Einstellungen.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await openAppSettings();
              },
              child: const Text('Einstellungen öffnen'),
            ),
          ],
        ),
      );
      return false;
    }
    return status.isGranted;
  }

  Future<bool> requestStoragePermission(BuildContext context) async {
    final status = await Permission.storage.request();
    if (status.isPermanentlyDenied) {
      if (!context.mounted) return false;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Speicher-Berechtigung'),
          content: const Text(
            'Die Speicher-Berechtigung wird für das Speichern von Bildern und '
                'Dokumenten benötigt. Bitte aktivieren Sie die Berechtigung in den Einstellungen.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await openAppSettings();
              },
              child: const Text('Einstellungen öffnen'),
            ),
          ],
        ),
      );
      return false;
    }
    return status.isGranted;
  }

  Future<Map<Permission, PermissionStatus>> requestAllPermissions() async {
    return await [
      Permission.camera,
      Permission.storage,
    ].request();
  }

  Future<bool> checkAndRequestPermissions(BuildContext context) async {
    bool cameraGranted = await requestCameraPermission(context);
    bool storageGranted = await requestStoragePermission(context);

    return cameraGranted && storageGranted;
  }
}