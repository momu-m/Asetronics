// Füge diese Klasse zu deiner Anwendung hinzu (z.B. in utils/logo_helper.dart)

import 'package:flutter/material.dart';

class LogoHelper {
  // Logo mit automatischer Theme-Anpassung
  static Widget getThemeAwareLogo({
    required BuildContext context,
    double height = 120,
    bool showTag = true,  // "Advanced Swiss Electronics" anzeigen
    bool showAppName = true,  // "Asetronics Wartungs-App" anzeigen
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final scale = MediaQuery.of(context).size.width > 600 ? 1.2 : 1.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo mit angepasster Größe
        Image.asset(
          isDarkMode ? 'assets/logo-w.png' : 'assets/logo.png',
          height: height * scale,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            // Fallback, falls das Asset nicht existiert
            return Container(
              height: height * scale,
              width: height * scale * 2.5,
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.blue[900] : Colors.blue[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'ase',
                        style: TextStyle(
                          color: Colors.blue[400],
                          fontSize: 28 * scale,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(
                        text: 'tronics',
                        style: TextStyle(
                          color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                          fontSize: 28 * scale,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),

        // Tagline (optional)
        if (showTag)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Advanced Swiss Electronics',
              style: TextStyle(
                fontSize: 16 * scale,
                color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

        // App-Name (optional)
        if (showAppName)
          Padding(
            padding: const EdgeInsets.only(top: 6.0),
            child: Text(
              'Asetronics Wartungs-App',
              style: TextStyle(
                fontSize: 18 * scale,
                color: isDarkMode ? Colors.grey[100] : Colors.grey[800],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}