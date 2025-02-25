// lib/services/biometric_service.dart
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();

  // Speichern des letzten Authentifizierungsstatus
  bool _isAuthenticated = false;

  // Gibt zurück, ob der Benutzer bereits authentifiziert ist
  bool get isAuthenticated => _isAuthenticated;

  // Prüft, ob biometrische Authentifizierung verfügbar ist
  Future<bool> isBiometricsAvailable() async {
    try {
      // Prüft, ob das Gerät biometrische Hardware hat
      final bool canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;

      // Prüft, ob biometrische Authentifizierung aktiviert ist
      final bool canAuthenticate = await _localAuth.isDeviceSupported();

      return canAuthenticateWithBiometrics && canAuthenticate;
    } on PlatformException catch (e) {
      debugPrint('Fehler bei Biometrie-Check: $e');
      return false;
    }
  }

  // Führt die biometrische Authentifizierung durch
  Future<bool> authenticate({String reason = 'Bitte authentifizieren Sie sich'}) async {
    try {
      // Prüfen, ob bereits authentifiziert
      if (_isAuthenticated) {
        return true;
      }

      // Verfügbare Biometrie-Typen abrufen
      final availableBiometrics = await _localAuth.getAvailableBiometrics();

      // Anzeige des geeigneten Authentifizierungstexts
      String localizedReason = reason;
      if (availableBiometrics.contains(BiometricType.face)) {
        localizedReason = 'Bitte authentifizieren Sie sich mit Gesichtserkennung';
      } else if (availableBiometrics.contains(BiometricType.fingerprint)) {
        localizedReason = 'Bitte authentifizieren Sie sich mit Ihrem Fingerabdruck';
      }

      _isAuthenticated = await _localAuth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          stickyAuth: true,      // Bleibt aktiv, wenn App in den Hintergrund geht
          biometricOnly: false,  // Erlaubt auch PIN/Passwort als Fallback
          useErrorDialogs: true, // Zeigt Systemdialoge bei Fehlern an
        ),
      );

      return _isAuthenticated;
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
        case 'PermanentlyLockedOut':
          errorMessage = 'Biometrische Authentifizierung ist dauerhaft gesperrt';
          break;
        default:
          errorMessage = 'Ein Fehler ist aufgetreten: ${e.message}';
      }
      debugPrint(errorMessage);
      return false;
    }
  }

  // Löscht den Authentifizierungsstatus (z.B. beim Abmelden)
  void resetAuthentication() {
    _isAuthenticated = false;
  }

  // Prüft die verfügbaren Biometrie-Typen
  Future<List<BiometricType>> getAvailableBiometricTypes() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException catch (e) {
      debugPrint('Fehler beim Abrufen der Biometrie-Typen: $e');
      return [];
    }
  }

  // Gibt einen benutzerfreundlichen String für den Biometrie-Typ zurück
  String getBiometricTypeDisplayName(BiometricType type) {
    switch (type) {
      case BiometricType.face:
        return 'Gesichtserkennung';
      case BiometricType.fingerprint:
        return 'Fingerabdruck';
      case BiometricType.iris:
        return 'Iris-Scan';
      case BiometricType.strong:
        return 'Starke Biometrie';
      case BiometricType.weak:
        return 'Einfache Biometrie';
      default:
        return 'Biometrie';
    }
  }
}