// lib/widgets/profile/profile_image_picker.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

class ProfileImagePicker extends StatefulWidget {
  final String? initialImageUrl;
  final String? initialImageBase64;
  final Function(Uint8List) onImageSelected;

  const ProfileImagePicker({
    Key? key,
    this.initialImageUrl,
    this.initialImageBase64,
    required this.onImageSelected,
  }) : super(key: key);

  @override
  _ProfileImagePickerState createState() => _ProfileImagePickerState();
}

class _ProfileImagePickerState extends State<ProfileImagePicker> {
  Uint8List? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Wenn ein Base64-Bild vorhanden ist, dekodiere es
    if (widget.initialImageBase64 != null && widget.initialImageBase64!.isNotEmpty) {
      try {
        _selectedImage = base64Decode(widget.initialImageBase64!);
      } catch (e) {
        print('Fehler beim Dekodieren des Initialbildes: $e');
      }
    }
  }

  // Bild aus der Galerie auswählen
  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 85,
      );

      if (image != null) {
        final imageBytes = await image.readAsBytes();
        setState(() {
          _selectedImage = imageBytes;
        });
        widget.onImageSelected(imageBytes);
      }
    } catch (e) {
      print('Fehler bei der Bildauswahl: $e');
    }
  }

  // Bild mit der Kamera aufnehmen
  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 85,
      );

      if (photo != null) {
        final imageBytes = await photo.readAsBytes();
        setState(() {
          _selectedImage = imageBytes;
        });
        widget.onImageSelected(imageBytes);
      }
    } catch (e) {
      print('Fehler bei der Fotoaufnahme: $e');
    }
  }

  // Bild entfernen
  void _removeImage() {
    setState(() {
      _selectedImage = null;
    });
    // Leeres Byte-Array senden, um das Bild zu entfernen
    widget.onImageSelected(Uint8List(0));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: _showImagePickerOptions,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _buildProfileImage(),
              _buildEditButton(),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tippen, um Ihr Profilbild zu ändern',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  // Baut das Profilbild
  Widget _buildProfileImage() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(60),
        child: _getProfileImage(),
      ),
    );
  }

  // Liefert das entsprechende Bild aus verschiedenen Quellen
  Widget _getProfileImage() {
    if (_selectedImage != null) {
      return Image.memory(
        _selectedImage!,
        fit: BoxFit.cover,
        width: 120,
        height: 120,
      );
    } else if (widget.initialImageUrl != null && widget.initialImageUrl!.isNotEmpty) {
      return Image.network(
        widget.initialImageUrl!,
        fit: BoxFit.cover,
        width: 120,
        height: 120,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholderIcon();
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
      );
    } else {
      return _buildPlaceholderIcon();
    }
  }

  // Platzhalter-Icon
  Widget _buildPlaceholderIcon() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Icon(
      Icons.account_circle,
      size: 120,
      color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
    );
  }

  // Bearbeitungsbutton
  Widget _buildEditButton() {
    return Positioned(
      bottom: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(8),
        child: const Icon(
          Icons.camera_alt,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  // Optionen zur Bildauswahl anzeigen
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
                _pickImageFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Foto aufnehmen'),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
            if (_selectedImage != null || widget.initialImageUrl != null || widget.initialImageBase64 != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Profilbild entfernen', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _removeImage();
                },
              ),
          ],
        ),
      ),
    );
  }
}