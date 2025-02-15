// machine_constants.dart
// Diese Datei enthält alle wichtigen Konstanten für die Maschinen-Kategorisierung

class ProductionLines {


  // Hauptproduktionslinien
  static const String xLine = 'X-Linie';
  static const String dLine = 'D-Linie';
  static const String sLine = 'S-Linie';

  // Spezialzellen
  static const String trennzelle1 = 'Trennzelle 1';
  static const String trennzelle2 = 'Trennzelle 2';
  static const String trennzelle3 = 'Trennzelle 3';
  static const String trennzelle4 = 'Trennzelle 4';
  static const String offlineTrennzelle = 'Offline Trennzelle';
  static const String laser1 = 'Laser 1';
  static const String laser2 = 'Laser 2';
  static const String axi = 'AXI';

  // Liste aller Produktionslinien für Dropdown-Menüs
  static List<String> getAllLines() => [
    xLine, dLine, sLine,
    trennzelle1, trennzelle2, trennzelle3, trennzelle4,
    offlineTrennzelle, laser1, laser2, axi
  ];
}

class MachineCategories {
  // Bestückungsautomaten
  static const String placer = 'Bestücker';
  static const List<String> placerTypes = [
    'SIPLACE SX2',
    'Siplace D2i',
    'Siplace D1'
  ];

  // Drucker
  static const String printer = 'Schablonendruck';
  static const List<String> printerTypes = [
    'Ekra X5 Prof',
    'X5 Prof'
  ];

  // Öfen
  static const String oven = 'Reflowofen';
  static const List<String> ovenTypes = [
    'Rehm VXP+nitro 3855',
    'Rehm VXP+nitro 4900'
  ];

  // Inspektionssysteme
  static const String inspection = 'Inspektion';
  static const List<String> inspectionTypes = [
    'Parmi SPIHS70I',
    'Koh Young Zenith',
    'Göppel LS181-03'
  ];

  // Transportbänder
  static const String transport = 'Transport';
  static const List<String> transportTypes = [
    'TRM01',
    'TRM03',
    'STM03D-2.1'
  ];

  // Mapping von Maschinentyp zu häufigen Problemen
  static Map<String, List<String>> getCommonProblems(String machineType) {
    // Basis-Probleme die für alle Maschinen gelten
    final baseProblems = [
      'Mechanisches Problem',
      'Elektrisches Problem',
      'Software-Problem',
      'Kalibrierung erforderlich'
    ];

    // Spezifische Probleme je nach Maschinentyp
    final specificProblems = {
      'Bestücker': [
        'Feeder-Problem',
        'Pick & Place Fehler',
        'Nozzle verstopft/beschädigt',
        'Vision-System Fehler',
        'Komponenten falsch bestückt',
        'Feeder leer'
      ],
      'Schablonendruck': [
        'Paste zu dünn/dick',
        'Schablone verstopft',
        'Rakel beschädigt',
        'Pastenviskosität nicht optimal',
        'Druckversatz'
      ],
      'Reflowofen': [
        'Temperaturabweichung',
        'Transportproblem',
        'Stickstoffversorgung gestört',
        'Kühlzone-Problem',
        'Temperatursensor defekt'
      ],
      'Inspektion': [
        'Kamera-Problem',
        'Beleuchtungsfehler',
        'Falsche Erkennung',
        'Kalibrierung notwendig',
        'Programmierproblem'
      ],
      'Transport': [
        'Band läuft nicht',
        'Leiterplatte klemmt',
        'Sensor defekt',
        'Antrieb gestört'
      ]
    };

    // Finde die passende Kategorie für den Maschinentyp
    String? category;
    if (placerTypes.contains(machineType)) category = 'Bestücker';
    else if (printerTypes.contains(machineType)) category = 'Schablonendruck';
    else if (ovenTypes.contains(machineType)) category = 'Reflowofen';
    else if (inspectionTypes.contains(machineType)) category = 'Inspektion';
    else if (transportTypes.contains(machineType)) category = 'Transport';

    // Kombiniere basis und spezifische Probleme
    return {
      'Basis': baseProblems,
      'Spezifisch': category != null ? specificProblems[category] ?? [] : []
    };
  }
}