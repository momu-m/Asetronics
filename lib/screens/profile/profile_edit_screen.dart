// lib/screens/profile/profile_edit_screen.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/user_role.dart';
import '../../services/user_service.dart';
import '../../utils/error_logger.dart';
import '../widgets/profile_image_picker.dart';

class ProfileEditScreen extends StatefulWidget {
  final User user;

  const ProfileEditScreen({
    Key? key,
    required this.user,
  }) : super(key: key);

  @override
  _ProfileEditScreenState createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _fullNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _departmentController;

  Uint8List? _newProfileImage;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    // Initialisiere die Controller mit den bestehenden Werten
    _fullNameController = TextEditingController(text: widget.user.fullName ?? '');
    _emailController = TextEditingController(text: widget.user.email ?? '');
    _phoneController = TextEditingController(text: widget.user.phone ?? '');
    _departmentController = TextEditingController(text: widget.user.department ?? '');
  }

  @override
  void dispose() {
    // Controller freigeben
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  // Profilbild auswählen
  Future<void> _selectProfileImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final imageBytes = await pickedFile.readAsBytes();
        setState(() {
          _newProfileImage = imageBytes;
        });
      }
    } catch (e, stackTrace) {
      ErrorLogger.logError('Fehler beim Auswählen des Profilbilds', e, stackTrace);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Auswählen des Bildes: $e')),
      );
    }
  }

  // Profilbild mit der Kamera aufnehmen
  Future<void> _takeProfilePicture() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final imageBytes = await pickedFile.readAsBytes();
        setState(() {
          _newProfileImage = imageBytes;
        });
      }
    } catch (e, stackTrace) {
      ErrorLogger.logError('Fehler beim Aufnehmen des Profilbilds', e, stackTrace);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Aufnehmen des Bildes: $e')),
      );
    }
  }

  // Profil speichern
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userService = Provider.of<UserService>(context, listen: false);

      // Erstelle aktualisiertes Benutzerobjekt
      User updatedUser = widget.user.copyWith(
        fullName: _fullNameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        department: _departmentController.text.trim(),
      );

      // Wenn ein neues Bild ausgewählt wurde, lade es hoch
      if (_newProfileImage != null) {
        final success = await userService.uploadProfileImage(
          widget.user.id,
          _newProfileImage!,
        );

        if (!success) {
          throw Exception('Fehler beim Hochladen des Profilbilds');
        }

        // Da wir das Bild nicht direkt haben (es kommt vom Server),
        // verwenden wir das lokale Bild als Base64
        updatedUser = updatedUser.copyWith(
          profileImageBase64: base64Encode(_newProfileImage!),
        );
      }

      // Aktualisiere das Profil
      final success = await userService.updateUserProfile(updatedUser);

      if (success) {
        if (mounted) {
          Navigator.pop(context, updatedUser);
        }
      } else {
        throw Exception('Fehler beim Aktualisieren des Profils');
      }
    } catch (e, stackTrace) {
      ErrorLogger.logError('Fehler beim Speichern des Profils', e, stackTrace);
      setState(() {
        _errorMessage = 'Fehler beim Speichern: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil bearbeiten'),
        actions: [
          // Speichern-Button
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveProfile,
            tooltip: 'Speichern',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Fehlermeldung anzeigen, falls vorhanden
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),

              // Profilbild-Auswahl
              _buildProfileImagePicker(isDarkMode),

              const SizedBox(height: 24),

              // Profilformular
              _buildProfileForm(),

              const SizedBox(height: 24),

              // Speichern-Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Speichern'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Profilbild-Auswahl Widget
  Widget _buildProfileImagePicker(bool isDarkMode) {
    // Aktuelles Profilbild oder neue Auswahl
    ImageProvider? profileImage;

    if (_newProfileImage != null) {
      profileImage = MemoryImage(_newProfileImage!);
    } else if (widget.user.profileImageBase64 != null) {
      profileImage = MemoryImage(base64Decode(widget.user.profileImageBase64!));
    } else if (widget.user.profileImageUrl != null) {
      profileImage = NetworkImage(widget.user.profileImageUrl!);
    }

    return Column(
        children: [
        Stack(
        children: [
        // Profilbild
        Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          // Fortsetzung von _buildProfileImagePicker
          shape: BoxShape.circle,
          color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
          image: profileImage != null
              ? DecorationImage(
            image: profileImage,
            fit: BoxFit.cover,
          )
              : null,
        ),
          child: profileImage == null
              ? Icon(
            Icons.account_circle,
            size: 120,
            color: isDarkMode ? Colors.grey[500] : Colors.grey[400],
          )
              : null,
        ),

          // Bearbeitungs-Button overlay
          Positioned(
            right: 0,
            bottom: 0,
            child: Material(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(20),
              elevation: 4,
              child: InkWell(
                onTap: () => _showImagePickerOptions(),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ],
        ),

          const SizedBox(height: 12),

          // Hinweistext
          Text(
            'Tippen Sie auf das Kamerasymbol, um Ihr Profilbild zu ändern',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
    );
  }

  // Zeigt Optionen für die Bildauswahl an
  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Profilbild ändern',
                style: TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Aus Galerie auswählen'),
              onTap: () {
                Navigator.pop(context);
                _selectProfileImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Foto aufnehmen'),
              onTap: () {
                Navigator.pop(context);
                _takeProfilePicture();
              },
            ),
            if (widget.user.profileImageUrl != null || widget.user.profileImageBase64 != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Profilbild entfernen', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _newProfileImage = Uint8List(0); // Leeres Bild zum Entfernen
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  // Profilformular
  Widget _buildProfileForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Vollständiger Name
        TextFormField(
          controller: _fullNameController,
          decoration: const InputDecoration(
            labelText: 'Vollständiger Name',
            hintText: 'Geben Sie Ihren vollständigen Namen ein',
            prefixIcon: Icon(Icons.person),
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            // Optional: Name kann leer sein
            return null;
          },
        ),
        const SizedBox(height: 16),

        // E-Mail
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'E-Mail',
            hintText: 'Geben Sie Ihre E-Mail-Adresse ein',
            prefixIcon: Icon(Icons.email),
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value != null && value.isNotEmpty) {
              // Einfache E-Mail-Validierung
              final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
              if (!emailRegex.hasMatch(value)) {
                return 'Bitte geben Sie eine gültige E-Mail-Adresse ein';
              }
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Telefon
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Telefonnummer',
            hintText: 'Geben Sie Ihre Telefonnummer ein',
            prefixIcon: Icon(Icons.phone),
            border: OutlineInputBorder(),
          ),
          // Eingabeformat für Telefonnummer
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]')),
          ],
          validator: (value) {
            // Optional: Telefon kann leer sein
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Abteilung
        TextFormField(
          controller: _departmentController,
          decoration: const InputDecoration(
            labelText: 'Abteilung',
            hintText: 'Geben Sie Ihre Abteilung ein',
            prefixIcon: Icon(Icons.business),
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            // Optional: Abteilung kann leer sein
            return null;
          },
        ),
      ],
    );
  }
}