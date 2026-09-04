Map<String, dynamic> buildCurrentEsMeta({
  bool withRf = false,
  bool withBaumInDerNaehe = false,
}) {
  return {
    'typ': 'ES',
    'evnr': 'E90001',
    'posNr': '1',
    'idNr': withRf ? '12345678' : '',
    'strasse': 'Musterstrasse 1',
    'erfasser': 'Tester',
    'zeitIso': DateTime.now().toIso8601String(),
    'wetter': 'klar',
    'schaeden': withRf ? ['Keine Rückenfreiheit'] : <String>[],
    'keinBefund': !withRf,
    'st1Hoehe': withRf ? '60' : '',
    'st1Rf': withRf ? '40' : '',
    'st2Hoehe': withRf ? '80' : '',
    'st2Rf': withRf ? '60' : '',
    'durchmesser': 'DN 1000',
    'kanalprofil': 'Kreisprofil',
    'oberflaeche': withBaumInDerNaehe ? ['Baum in der Nähe'] : <String>[],
    'obflBem': withBaumInDerNaehe ? '1,20m / D35cm' : '',
    'mediaFotos': withBaumInDerNaehe ? ['data:image/jpeg;base64,AA=='] : <String>[],
    'mediaVideos': <String>[],
    'mediaAudios': <String>[],
    'mediaPdfs': <String>[],
    'abteilungen': ['312_Ost'],
    'verfuegbarkeit': <String>[],
    'statusVorOrt': <String>[],
  };
}

Map<String, dynamic> buildCurrentVsMeta() {
  return {
    'typ': 'VG',
    'evnr': 'E90002',
    'posNr': '2a',
    'idNr': '123456',
    'strasse': 'Musterstrasse 2',
    'erfasser': 'Tester',
    'zeitIso': DateTime.now().toIso8601String(),
    'wetter': 'regen',
    'grubentyp': 'KB-Schacht',
    'tiefe_cm': '120',
    'wasser_cm': '45',
    'anschlussJa': true,
    'anschluss': 'Ja',
    'teller': 'offen',
    'filtersandJa': true,
    'filtersandEigensch': ['locker', 'sickerfaehig'],
    'schaeden': <String>[],
    'keinBefund': true,
    'abteilungen': ['312_Service'],
    'verfuegbarkeit': <String>[],
    'statusVorOrt': <String>[],
    'mediaFotos': <String>[],
    'mediaVideos': <String>[],
    'mediaAudios': <String>[],
    'mediaPdfs': <String>[],
  };
}

Map<String, dynamic> buildCurrentSskMeta({String posNr = '1'}) {
  return {
    'typ': 'SSK',
    'evnr': 'E90003',
    'posNr': posNr,
    'idNr': '87654321',
    'storageKey': 'ssk_$posNr',
    'strasse': 'Musterstrasse 3',
    'erfasser': 'Tester',
    'zeitIso': DateTime.now().toIso8601String(),
    'gruppe': 'SSK Münchner Modell',
    'auspraegung': 'rund',
    'schaeden': <String>[],
    'keinBefund': true,
    'abteilungen': ['312_Ost'],
    'verfuegbarkeit': <String>[],
    'statusVorOrt': <String>[],
  };
}

Map<String, dynamic> buildCurrentSkMeta() {
  return {
    'typ': 'SK',
    'evnr': 'E90004',
    'posNr': '3',
    'idNr': '1234',
    'strasse': 'Musterstrasse 4',
    'erfasser': 'Tester',
    'zeitIso': DateTime.now().toIso8601String(),
    'austauschErforderlich': false,
    'keinBefund': true,
    'schaeden': <String>[],
    'abteilungen': ['313_TU'],
    'verfuegbarkeit': <String>[],
    'statusVorOrt': <String>[],
  };
}

Map<String, dynamic> buildCurrentKanalMeta() {
  return {
    'typ': 'KANAL',
    'evnr': 'E90005',
    'posNr': '4',
    'idNr': '654321',
    'strasse': 'Musterstrasse 5',
    'erfasser': 'Tester',
    'zeitIso': DateTime.now().toIso8601String(),
    'kanalprofil': 'Kreisprofil',
    'keinBefund': true,
    'schaeden': <String>[],
    'abteilungen': ['313_BU'],
    'verfuegbarkeit': <String>[],
    'statusVorOrt': <String>[],
  };
}
