// services/biometric_service.dart
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();

  // Prüft, ob biometrische Authentifizierung verfügbar ist
  Future<bool> isBiometricsAvailable() async {
    try {
      // Prüft, ob das Gerät biometrische Hardware hat
      final bool canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      // Prüft, ob biometrische Authentifizierung aktiviert ist
      final bool canAuthenticate = await _localAuth.isDeviceSupported();

      return canAuthenticateWithBiometrics && canAuthenticate;
    } on PlatformException catch (e) {
      print('Fehler bei Biometrie-Check: $e');
      return false;
    }
  }

  // Führt die biometrische Authentifizierung durch
  Future<bool> authenticate() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Bitte authentifizieren Sie sich, um fortzufahren',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } on PlatformException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'NotAvailable':
          errorMessage = 'Biometrische Authentifizierung ist nicht verfügbar';
          break;
        case 'NotEnrolled':
          errorMessage = 'Keine biometrischen Daten hinterlegt';
          break;
        case 'LockedOut':
          errorMessage = 'Zu viele Versuche. Bitte warten Sie einen Moment';
          break;
        default:
          errorMessage = 'Ein Fehler ist aufgetreten: ${e.message}';
      }
      print(errorMessage);
      return false;
    }
  }
}