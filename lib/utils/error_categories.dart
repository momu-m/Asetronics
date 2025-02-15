// error_categories.dart
class ErrorCategories {
  static const Map<String, List<String>> categories = {
    'Mechanisch': [
      'Motorausfall',
      'Antriebsprobleme',
      'Verschleißteile',
      'Mechanische Blockade'
    ],
    'Elektronisch': [
      'Sensorausfall',
      'Steuerungsfehler',
      'Displayprobleme',
      'Kommunikationsfehler'
    ],
    'Software': [
      'Systemabsturz',
      'Kalibrierungsfehler',
      'Datenübertragungsfehler',
      'Update fehlgeschlagen'
    ],
    'Material': [
      'Materialstau',
      'Fehleinzug',
      'Qualitätsprobleme',
      'Materialbruch'
    ]
  };

  static List<String> getMainCategories() {
    return categories.keys.toList();
  }

  static List<String> getSubcategories(String mainCategory) {
    return categories[mainCategory] ?? [];
  }
}