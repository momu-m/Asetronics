// lib/screens/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import '../../main.dart' show userService;
import '../../services/biometric_service.dart';
import '../../services/user_service.dart';
import '../../utils/logo_helper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  // Controller und Status-Variablen
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _biometricService = BiometricService();
  final _secureStorage = FlutterSecureStorage();


  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isBiometricsAvailable = false;
  String? _errorMessage;

  // Animation Controller für visuelle Effekte
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Fokus-Nodes für verbesserte Benutzerführung
  final FocusNode _usernameFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Animation einrichten
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();

    // Prüft, ob biometrische Authentifizierung verfügbar ist
    _checkBiometricAvailability();

    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final rememberMe = await _secureStorage.read(key: 'remember_me');
      if (rememberMe == 'true') {
        final username = await _secureStorage.read(key: 'username');
        final authToken = await _secureStorage.read(key: 'auth_token');

        if (username != null && authToken != null) {
          setState(() {
            _usernameController.text = username;
            _rememberMe = true;
          });

          // Optional: Automatisch anmelden
          if (await _validateSavedToken(authToken)) {
            _performAutomaticLogin();
          }
        }
      }
    } catch (e) {
      debugPrint('Fehler beim Laden gespeicherter Anmeldedaten: $e');
      // Kein Fehler anzeigen, einfach normal fortfahren
    }
  }
  Future<bool> _validateSavedToken(String token) async {
    try {
      // Hier würdest du normalerweise den Token gegen den Server validieren
      // Für Demonstration verwenden wir eine einfache Prüfung
      return token.isNotEmpty && token.startsWith('user_session_');
    } catch (e) {
      return false;
    }
  }

// NEU: Automatische Anmeldung durchführen
  Future<void> _performAutomaticLogin() async {
    setState(() => _isLoading = true);

    try {
      // Hier sollten wir den Token verwenden, um eine automatische Anmeldung durchzuführen
      final success = await userService.loginWithToken(
          await _secureStorage.read(key: 'auth_token') ?? ''
      );

      if (success && mounted) {
        Navigator.pushReplacementNamed(context, '/dashboard');
      } else {
        // Token abgelaufen oder ungültig - nichts tun,
        // Benutzer muss manuell anmelden
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }


  Future<void> _checkBiometricAvailability() async {
    final isAvailable = await _biometricService.isBiometricsAvailable();
    setState(() {
      _isBiometricsAvailable = isAvailable;
    });
  }

  // Biometrische Authentifizierung
  Future<void> _authenticateBiometric() async {
    setState(() => _isLoading = true);

    try {
      final authenticated = await _biometricService.authenticate();
      if (authenticated) {
        // Hier könnten wir einen gespeicherten Benutzer abrufen
        // Für jetzt simulieren wir einen Admin-Login
        if (mounted) {
          final success = await userService.login('admin', 'admin');
          if (success && mounted) {
            Navigator.pushReplacementNamed(context, '/dashboard');
          } else {
            setState(() {
              _errorMessage = 'Biometrische Anmeldung fehlgeschlagen';
              _isLoading = false;
            });
          }
        }
      } else {
        setState(() {
          _errorMessage = 'Biometrische Authentifizierung abgebrochen';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Fehler bei biometrischer Authentifizierung: $e';
        _isLoading = false;
      });
    }
  }
  Future<void> _saveCredentials() async {
    try {
      // Speichere Benutzernamen
      await _secureStorage.write(key: 'username', value: _usernameController.text.trim());

      // Speichere ein Session-Token (in einer echten App würde dieses vom Server kommen)
      final token = 'user_session_${DateTime.now().millisecondsSinceEpoch}';
      await _secureStorage.write(key: 'auth_token', value: token);

      // Speichere die Einstellung "Angemeldet bleiben"
      await _secureStorage.write(key: 'remember_me', value: 'true');

      debugPrint('Anmeldedaten erfolgreich gespeichert');
    } catch (e) {
      debugPrint('Fehler beim Speichern der Anmeldedaten: $e');
      // Hier könnten wir dem Benutzer eine Warnung anzeigen,
      // dass "Angemeldet bleiben" nicht funktioniert hat
    }
  }
  // Hauptauthentifizierungsmethode
// Hauptauthentifizierungsmethode
  Future<void> _authenticateUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userService = Provider.of<UserService>(context, listen: false);
      final success = await userService.login(
        _usernameController.text.trim(),
        _passwordController.text,
      );

      if (success && mounted) {
        final userService = Provider.of<UserService>(context, listen: false);
        // Speichere Anmeldedaten wenn "Angemeldet bleiben" aktiviert ist
        if (_rememberMe) {
          await _saveCredentials();
        } else {
          await const FlutterSecureStorage().deleteAll();
        }

        // Prüfe, ob ein Profil existiert und komplett ist
        final hasProfile = await userService.hasCompletedProfile(userService.currentUser!.id);

        if (mounted) {
          if (hasProfile) {
            Navigator.pushReplacementNamed(context, '/dashboard');
          } else {
            // Zeige den Dialog nur, wenn das Profil wirklich leer ist
            final shouldShowSetup = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: const Text('Profil vervollständigen'),
                content: const Text(
                    'Um die App optimal nutzen zu können, sollten Sie Ihr Profil vervollständigen. '
                        'Möchten Sie das jetzt tun?'
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Später'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Jetzt einrichten'),
                  ),
                ],
              ),
            );

            if (mounted) {
              if (shouldShowSetup == true) {
                Navigator.pushReplacementNamed(context, '/profile/setup');
              } else {
                Navigator.pushReplacementNamed(context, '/dashboard');
              }
            }
          }
        }
      } else {
        setState(() {
          _errorMessage = 'Ungültige Anmeldedaten';
          _isLoading = false;
        });
        _animateError();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Ein Fehler ist aufgetreten: $e';
        _isLoading = false;
      });
    }
  }

  // Animation für Fehler-Feedback
  void _animateError() {
    // Einfache Shake-Animation mit Systemfeedback
    HapticFeedback.mediumImpact();

    // Animationssequenz für Shake-Effekt
    const shakeCount = 3;
    const shakeOffset = 5.0;
    const shakeDuration = Duration(milliseconds: 50);

    for (var i = 0; i < shakeCount; i++) {
      Future.delayed(shakeDuration * (i * 2), () {
        if (mounted) {
          setState(() {
            // Dieser Code würde in einer komplexeren Implementation
            // eine tatsächliche Shake-Animation steuern
          });
        }
      });

      Future.delayed(shakeDuration * (i * 2 + 1), () {
        if (mounted) {
          setState(() {
            // Reset der Animation
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Aktuelle Theme-Farben
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final backgroundColor = isDarkMode
        ? const Color(0xFF0A101C)
        : const Color(0xFFF5F9FF);
    final cardColor = isDarkMode
        ? const Color(0xFF1E2333)
        : Colors.white;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Responsive Design basierend auf Bildschirmgröße
          final isTablet = constraints.maxWidth > 600;
          final contentWidth = isTablet
              ? 500.0
              : constraints.maxWidth * 0.9;

          return Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDarkMode
                    ? [
                  const Color(0xFF101525),
                  const Color(0xFF182033),
                ]
                    : [
                  const Color(0xFFE6F2FF),
                  const Color(0xFFCCE0FF),
                ],
              ),
            ),
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Animierter Logo-Bereich
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                  vertical: isTablet ? 60 : 40
                              ),
                              child: Column(
                                children: [
                                  // Verbessertes Logo mit Theme-Unterstützung
                                  LogoHelper.getThemeAwareLogo(
                                    context: context,
                                    height: isTablet ? 120 : 100,
                                  ),
                                  // Wir entfernen den ursprünglichen Namen, da er bereits im LogoHelper enthalten ist
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Login-Formular mit Animation
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: Container(
                              width: contentWidth,
                              constraints: BoxConstraints(
                                maxWidth: isTablet ? 500 : double.infinity,
                              ),
                              child: Card(
                                elevation: 10,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                color: cardColor,
                                shadowColor: Colors.black26,
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Form(
                                    key: _formKey,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        // Überschrift
                                        Text(
                                          'Anmelden',
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: isDarkMode ? Colors.white : Colors.black87,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 24),

                                        // Fehlermeldung, falls vorhanden
                                        if (_errorMessage != null)
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.red.withOpacity(0.3),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.error_outline,
                                                  color: Colors.red,
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    _errorMessage!,
                                                    style: const TextStyle(
                                                      color: Colors.red,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        if (_errorMessage != null)
                                          const SizedBox(height: 20),

                                        // Benutzername Eingabefeld
                                        TextFormField(
                                          controller: _usernameController,
                                          focusNode: _usernameFocus,
                                          decoration: InputDecoration(
                                            labelText: 'Benutzername',
                                            hintText: 'Geben Sie Ihren Benutzernamen ein',
                                            prefixIcon: const Icon(Icons.person),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                color: isDarkMode
                                                    ? Colors.grey[700]!
                                                    : Colors.grey[300]!,
                                              ),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                color: isDarkMode
                                                    ? Colors.grey[600]!
                                                    : Colors.grey[300]!,
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                color: primaryColor,
                                                width: 2,
                                              ),
                                            ),
                                            filled: true,
                                            fillColor: isDarkMode
                                                ? Colors.grey[800]!.withOpacity(0.2)
                                                : Colors.grey[100]!.withOpacity(0.2),
                                          ),
                                          validator: (value) {
                                            if (value == null || value.trim().isEmpty) {
                                              return 'Bitte Benutzernamen eingeben';
                                            }
                                            if (value.length < 3) {
                                              return 'Benutzername zu kurz';
                                            }
                                            return null;
                                          },
                                          textInputAction: TextInputAction.next,
                                          onFieldSubmitted: (_) {
                                            FocusScope.of(context).requestFocus(_passwordFocus);
                                          },
                                        ),
                                        const SizedBox(height: 20),

                                        // Passwort Eingabefeld
                                        TextFormField(
                                          controller: _passwordController,
                                          focusNode: _passwordFocus,
                                          obscureText: _obscurePassword,
                                          decoration: InputDecoration(
                                            labelText: 'Passwort',
                                            hintText: 'Geben Sie Ihr Passwort ein',
                                            prefixIcon: const Icon(Icons.lock),
                                            suffixIcon: IconButton(
                                              icon: Icon(
                                                _obscurePassword
                                                    ? Icons.visibility_off
                                                    : Icons.visibility,
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  _obscurePassword = !_obscurePassword;
                                                });
                                              },
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                color: isDarkMode
                                                    ? Colors.grey[700]!
                                                    : Colors.grey[300]!,
                                              ),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                color: isDarkMode
                                                    ? Colors.grey[600]!
                                                    : Colors.grey[300]!,
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                color: primaryColor,
                                                width: 2,
                                              ),
                                            ),
                                            filled: true,
                                            fillColor: isDarkMode
                                                ? Colors.grey[800]!.withOpacity(0.2)
                                                : Colors.grey[100]!.withOpacity(0.2),
                                          ),
                                          validator: (value) {
                                            if (value == null || value.trim().isEmpty) {
                                              return 'Bitte Passwort eingeben';
                                            }
                                            return null;
                                          },
                                          textInputAction: TextInputAction.done,
                                          onFieldSubmitted: (_) => _authenticateUser(),
                                        ),

                                        // Angemeldet bleiben Option
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          child: Row(
                                            children: [
                                              SizedBox(
                                                height: 24,
                                                width: 24,
                                                child: Checkbox(
                                                  value: _rememberMe,
                                                  onChanged: (value) {
                                                    setState(() {
                                                      _rememberMe = value ?? false;
                                                    });
                                                  },
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              const Text('Angemeldet bleiben'),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 24),

                                        // Login Button
                                        SizedBox(
                                          height: 50,
                                          child: ElevatedButton(
                                            onPressed: _isLoading ? null : _authenticateUser,
                                            style: ElevatedButton.styleFrom(
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              elevation: 4,
                                              shadowColor: primaryColor.withOpacity(0.4),
                                              backgroundColor: primaryColor,
                                            ),
                                            child: _isLoading
                                                ? const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 3,
                                              ),
                                            )
                                                : const Text(
                                              'Anmelden',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),

                                        // Biometrische Anmeldung, falls verfügbar
                                        if (_isBiometricsAvailable) ...[
                                          const SizedBox(height: 16),
                                          Center(
                                            child: TextButton.icon(
                                              onPressed: _isLoading
                                                  ? null
                                                  : _authenticateBiometric,
                                              icon: const Icon(Icons.fingerprint),
                                              label: const Text('Mit Biometrie anmelden'),
                                              style: TextButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(
                                                  vertical: 12,
                                                  horizontal: 24,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Footer Text
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: Text(
                              '© ${DateTime.now().year} Asetronics AG',
                              style: TextStyle(
                                color: isDarkMode
                                    ? Colors.grey[400]
                                    : Colors.grey[700],
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _animationController.dispose();
    super.dispose();
  }
}