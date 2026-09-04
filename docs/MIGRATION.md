Migration: Meta-first Export API

Ziel
----
Dieses Projekt verwendet jetzt ein "meta-first" Persistenz- und Export-Pattern:
- Screens speichern JSON-Meta-Objekte in `SharedPreferences`.
- Der Export liest die Meta-Objekte und erzeugt PDFs/ZIPs direkt aus diesen Daten.

Migration: Meta-first Export API

Ziel
----
Dieses Projekt verwendet jetzt ein "meta-first" Persistenz- und Export-Pattern:
- Screens speichern JSON-Meta-Objekte in `SharedPreferences`.
- Der Export liest die Meta-Objekte und erzeugt PDFs/ZIPs direkt aus diesen Daten.

Wesentliche Änderungen
---------------------
- Neue öffentliche Methoden in `ExportService`:
  - `buildExportZipFromMeta({ required String evnr, required List<Map<String,dynamic>> metas, ... })`
  - `buildZipFromPlanMeta(ExportPlan plan, List<Map<String,dynamic>> metas, ...)`
  - `buildEinzelFromFields({ required Map<String,String> fields, List<String>? notes })`
  - `buildGesamtPdfFromMetas(...)`

- `StorageService.metaToFields(meta)` erzeugt eine normierte Feld-Map aus dem gespeicherten Meta-JSON (inkl. Umrechnung m → cm).

- Alte öffentliche Konvertierungen von Meta → `BaseEntry` wurden entfernt. Export- und Plan-Logik arbeiten jetzt direkt mit `meta` oder optionalen `BaseEntry`-Instanzen im `ExportPlan`.

Normalisierte Feldnamen
-----------------------
Für Gruben-/VS-Daten verwenden wir jetzt maschinenfreundliche Keys:
- `tiefe_cm` — Grubentiefe in Zentimetern
- `wasser_cm` — Wasserstand in Zentimetern

Falls Werte in Metern gespeichert sind (`tiefe_m`, `wasser_m`), werden sie beim Erzeugen der Feld-Map in `cm` konvertiert (z. B. `1.2` m → `120` cm).

PDF-Generator
-------------
- `PdfMiniKit` liest bevorzugt die normalisierten Keys (`tiefe_cm`, `wasser_cm`) und formatiert Labels für Menschen (`Grubentiefe (cm)`).

Beispiele
---------

Einträge laden:

```dart
final metas = await StorageService.loadEntriesForEvNr(evnr);
```

ExportPlan (Preview) aus Metas bauen:

```dart
final plan = buildExportPlanFromMeta(
  evnr: evnr,
  strasse: metas.isNotEmpty ? metas.first['strasse'] as String? : null,
  metas: metas,
  fotosPerEntry: metas.map((m) => (m['mediaFotos'] as List<dynamic>?)?.cast<String>() ?? <String>[]).toList(),
  videosPerEntry: metas.map((m) => (m['mediaVideos'] as List<dynamic>?)?.cast<String>() ?? <String>[]).toList(),
);
```

ZIP direkt aus Metas erzeugen (ohne Preview):

```dart
final zipBytes = await ExportService.buildExportZipFromMeta(evnr: evnr, metas: metas, strasse: 'Beispielstr');
```

ZIP aus Preview-Plan + Metas (bevorzugt, wenn Nutzer Auswahl getroffen hat):

```dart
final zipBytes = await ExportService.buildZipFromPlanMeta(plan, metas, erfasser: 'Max', wetter: 'Regen');
```

Migration & Kompatibilität
-------------------------
- Falls externe Codepfade `BaseEntry` erwartet haben, kannst du:
  - entweder `StorageService.metaToFields(meta)` nutzen, um ein feldbasiertes Steckbrief-Layout zu erzeugen, oder
  - Meta-Objekte in `BaseEntry` umwandeln (falls unbedingt erforderlich) und `buildExportZip`/`buildZipFromPlan` verwenden.

- Es wurden schrittweise alle internen Shims entfernt; `buildExportZipFromMeta` und `buildZipFromPlanMeta` sind jetzt die empfohlenen Entrypoints.

Quick-Migrations-Snippet (normalisiert Meter → cm in gespeicherte Metas):

```dart
final metas = await StorageService.loadEntriesForEvNr(evnr);
for (final m in metas) {
  bool changed = false;
  if ((m['tiefe_m'] as String?) != null && (m['tiefe_cm'] as String?) == null) {
    final v = num.tryParse((m['tiefe_m'] as String).replaceAll(',', '.'));
    if (v != null) {
      m['tiefe_cm'] = (v * 100).toStringAsFixed(v.truncateToDouble() == v ? 0 : 2);
      changed = true;
    }
  }
  if (changed) {
    await StorageService.updateEntry(m['storageKey'] as String, m);
  }
}
```

Weitere Hinweise
----------------
- Während der Tests können Warnungen zur `dart_pdf`-Fontverwaltung erscheinen (fehlende Unicode-Glyphen). Diese sind unkritisch für die Funktion, du kannst optional Roboto/DejaVu-Fonts in `assets/fonts` einbinden, wenn du volle Unicode-Unterstützung willst.

Bei Bedarf erstelle ich gern ein kleines CLI-Skript, das alle gespeicherten Metas durchläuft und sicher normalisiert.
