import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/session_store.dart';
import '../services/speicher_service.dart';
import '../services/repository.dart';
import '../services/export_plan_service.dart';
import '../services/export_service.dart';
import '../services/export_store.dart';
import '../services/device_export_storage.dart';
import '../widgets/export_preview_dialog.dart';
import '../widgets/entry_detail_dialog.dart';
import '../widgets/responsive_layout.dart';
import '../services/web_download.dart';
import 'einsteig_screen.dart';
import 'gruben_screen.dart';
import 'sinkkasten_screen.dart';
import 'lueftung_screen.dart';
import 'schieber_screen.dart';
import 'sonstiges_screen.dart';
import 'kanal_screen.dart';
import '../routes.dart';

// ================== ZENTRALE HILFSFUNKTIONEN ==================

bool hasSchaden(Map<String, dynamic> meta) {
  // Kein Befund => KEIN Schaden
  if (meta['keinBefund'] == true) return false;

  // Schäden-Liste
  final schaeden = meta['schaeden'];
  if (schaeden is List && schaeden.isNotEmpty) return true;

  // Schadensdetails (für Kanal, Sonstige, etc.)
  final schadensdetails = meta['schadensdetails'];
  if (schadensdetails is String && schadensdetails.trim().isNotEmpty)
    return true;

  // RF-Flag (für Gruben/Einstieg)
  final flags = meta['flags'];
  if (flags is List && flags.contains('rf')) return true;

  return false;
}

String abbreviateAbteilung(String abteilung) {
  final map = {
    'Maurer': 'M',
    'Schlosser': 'S',
    'Baukontrollmeister': 'BAUKO',
    'NIS': 'NIS',
    'Reinigung': 'R',
  };
  // Neue 312/313-Abteilungen: nicht abkürzen, direkt zurückgeben
  if (abteilung.startsWith('312') || abteilung.startsWith('313')) {
    return abteilung;
  }
  return map[abteilung] ?? abteilung;
}

List<String> getAbteilungen(Map<String, dynamic> meta) {
  // Neue Modules nutzen 'abteilungen' (plural) mit 312/313-Werten
  final a = meta['abteilungen'] ?? meta['abteilungsMarker'];
  if (a is List) {
    return a
        .map((e) => abbreviateAbteilung(e.toString()))
        .where((e) => e.trim().isNotEmpty)
        .toList();
  }
  if (a is String && a.trim().isNotEmpty) {
    return a
        .split(',')
        .map((e) => abbreviateAbteilung(e.trim()))
        .where((e) => e.isNotEmpty)
        .toList();
  }
  return const [];
}

List<String> getAllSchaedenFromMetas(List<Map<String, dynamic>> metas) {
  final set = <String>{};
  for (final m in metas) {
    final schaeden = m['schaeden'];
    if (schaeden is List) {
      set.addAll(
        schaeden.map((e) => e.toString()).where((e) => e.trim().isNotEmpty),
      );
    }
  }
  return set.toList()..sort();
}

List<String> _cleanSchaeden(List<dynamic> schaeden) {
  return schaeden
      .map((e) => e.toString())
      .where((e) => e.trim().isNotEmpty)
      .toList();
}

List<String> getAllAbteilungenFromMetas(List<Map<String, dynamic>> metas) {
  final set = <String>{};
  for (final m in metas) {
    set.addAll(getAbteilungen(m));
  }
  return set.toList()..sort();
}

// ========== Zentrale Renderer-Funktion ==========

Widget buildMetaSection(String title, dynamic value) {
  if (value == null) return const SizedBox.shrink();

  String text;
  if (value is List) {
    if (value.isEmpty) return const SizedBox.shrink();
    text = value
        .map((e) => e.toString().trim().replaceFirst(RegExp(r'^\d+\.\s*'), ''))
        .where((e) => e.isNotEmpty)
        .join(', ');
    if (text.isEmpty) return const SizedBox.shrink();
  } else if (value is bool) {
    text = value ? 'Ja' : 'Nein';
  } else {
    text = value.toString().trim();
    if (text.isEmpty) return const SizedBox.shrink();
  }

  return Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 11, color: Colors.black87),
        children: [
          TextSpan(
            text: '$title: ',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          TextSpan(text: text),
        ],
      ),
    ),
  );
}

String _beautifyKey(String key) {
  final map = {
    'grubentyp': 'Grubentyp',
    'deckel': 'Deckel',
    'deckelBem': 'Deckel Bemerkung',
    'kl': 'KL',
    'bemerkung': 'Bemerkung',
    'gruppe': 'Gruppe',
    'auspraegung': 'Ausprägung',
    'aufbauMuenchner': 'Aufbau wie Münchner Modell',
    'abdeckung': 'Abdeckung',
    'fallschutz': 'Fallschutz vorhanden',
    'ablaufrinne': 'Ablaufrinne',
    'ablaufrinneVerbindung': 'Ablaufrinne Verbindung',
    'leitung': 'Leitung',
    'art': 'Art',
    'typ_detail': 'Typ Detail',
    'austauschErforderlich': 'Austausch erforderlich',
    'beschreibung': 'Beschreibung',
    'durchmesser': 'Schacht Durchmesser',
    'abteilungen': 'Abteilungen',
    'abteilungsMarker': 'Abteilungen',
  };
  return map[key] ?? key;
}

// ============================================================

class BerichtScreen extends StatefulWidget {
  const BerichtScreen({super.key});

  @override
  State<BerichtScreen> createState() => _BerichtScreenState();
}

class _BerichtScreenState extends State<BerichtScreen> {
  final _df = DateFormat('dd.MM.yyyy HH:mm');
  final _evCtrl = TextEditingController();

  SessionData? _s;
  bool _loading = false;

  List<String> _evList = [];
  bool _loadingEv = false;
  bool _loadingExports = false;
  List<ExportFile> _exportFiles = const [];
  final _exportFilterCtrl = TextEditingController();

  List<Map<String, dynamic>> _items = [];

  // ========== Filter-State ==========
  String _filterModul = 'Alle';
  String _filterAbteilung = 'Alle';
  bool _nurSchadenFilter = false;
  String? _openingEditorKey;

  @override
  void initState() {
    super.initState();
    _ladeSession();
  }

  @override
  void dispose() {
    _evCtrl.dispose();
    _exportFilterCtrl.dispose();
    super.dispose();
  }

  Future<void> _ladeSession() async {
    setState(() => _loading = true);
    try {
      final s = await SessionStore.load();
      _s = s;
      _evCtrl.text = s?.evnr ?? '';
    } finally {
      if (mounted) setState(() => _loading = false);
    }

    await _ladeEvListe();
    if (_evCtrl.text.trim().isEmpty && _evList.isNotEmpty) {
      _evCtrl.text = _evList.first;
    }
    if (_evCtrl.text.trim().isNotEmpty) {
      await _laden();
    } else if (mounted) {
      setState(() => _items = const []);
    }
    await _loadExports();
  }

  Future<void> _loadExports() async {
    setState(() => _loadingExports = true);
    try {
      final list = await ExportStore.loadExports();
      if (!mounted) return;
      setState(() => _exportFiles = list);
    } catch (e) {
      debugPrint('Fehler beim Laden der Exporte: $e');
      if (!mounted) return;
      setState(() => _exportFiles = const []);
    } finally {
      if (mounted) setState(() => _loadingExports = false);
    }
  }

  void _openExport(ExportFile file) {
    try {
      downloadBytesWeb(file.bytes(), file.fileName);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Datei konnte nicht geoeffnet werden: $e')),
      );
    }
  }

  bool _isImportantExportFile(ExportFile file) {
    final name = file.fileName.toLowerCase();
    return file.mimeType.contains('pdf') || name.endsWith('.pdf');
  }

  Future<void> _deleteExport(ExportFile file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export loeschen?'),
        content: Text('Datei "${file.fileName}" wirklich loeschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Loeschen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ExportStore.deleteExport(file.id);
    await _loadExports();
  }

  // --- 312/313 Buttons werden im Filterbereich im Widget-Baum eingefügt ---
  Future<void> _ladeEvListe() async {
    setState(() => _loadingEv = true);
    try {
      final list = await SpeicherService.ladeAlleEvNr();
      list.sort((a, b) => a.compareTo(b));
      if (mounted) setState(() => _evList = list);
    } catch (_) {
      // optional
    } finally {
      if (mounted) setState(() => _loadingEv = false);
    }
  }

  Future<void> _exportDataZip() async {
    try {
      final ev = _evCtrl.text.trim();
      if (ev.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Bitte EVNr eingeben.')));
        return;
      }

      if (!_isExportReady()) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_exportBlockReason())));
        return;
      }

      setState(() => _loading = true);

      final resolvedStrasse = _resolvedStrasse();
      final resolvedErfasser = _resolvedErfasser();

      final metas = await SpeicherService.ladeEintraegeFuerEvNr(ev);
      final s = await SessionStore.load();
      final nis = await SessionStore.loadNisPlanForEvnr(ev);

      final fotosPerEntry = metas
          .map(
            (m) =>
                (m['mediaFotos'] as List<dynamic>?)?.cast<String>() ??
                <String>[],
          )
          .toList();
      final videosPerEntry = metas
          .map(
            (m) =>
                (m['mediaVideos'] as List<dynamic>?)?.cast<String>() ??
                <String>[],
          )
          .toList();
      final audiosPerEntry = metas
          .map(
            (m) =>
                (m['mediaAudios'] as List<dynamic>?)?.cast<String>() ??
                <String>[],
          )
          .toList();
      final pdfsPerEntry = metas
          .map(
            (m) =>
                (m['mediaPdfs'] as List<dynamic>?)?.cast<String>() ??
                <String>[],
          )
          .toList();

      final plan = buildExportPlanFromMeta(
        evnr: ev,
        strasse: resolvedStrasse,
        metas: metas,
        fotosPerEntry: fotosPerEntry,
        videosPerEntry: videosPerEntry,
        audiosPerEntry: audiosPerEntry,
        pdfsPerEntry: pdfsPerEntry,
      );

      final zipBytes = await ExportService.buildZipFromPlanMeta(
        plan,
        metas,
        erfasser: resolvedErfasser,
        wetter: s?.wetter,
        zeit: s?.zeit,
        nisPlanPdfBase64: nis?.pdfBase64 ?? s?.nisPlanPdf,
      );

      final fileName =
          '${_cleanName(ev)}_${_cleanName(resolvedStrasse ?? 'Unbekannt')}';
      final savedPath = await _saveExportOnDevice(
        bytes: zipBytes,
        fileName: '$fileName.zip',
        evnr: ev,
      );
      final savedFiles = await saveZipStructureToDevice(zipBytes);
      await _trySaveExportHistory(
        fileName: '$fileName.zip',
        mimeType: 'application/zip',
        bytes: zipBytes,
        evnr: ev,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              savedPath == null
                  ? '✓ Kompletter Ordner exportiert: $fileName.zip'
                  : (savedFiles > 0
                        ? '✓ Export + Ordnerstruktur gespeichert ($savedFiles Dateien)'
                        : '✓ Kompletter Ordner gespeichert: $savedPath'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler beim Export: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportDataCsv() async {
    try {
      final ev = _evCtrl.text.trim();
      if (ev.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Bitte EVNr eingeben.')));
        return;
      }

      setState(() => _loading = true);

      final resolvedStrasse = _resolvedStrasse();
      final metas = await SpeicherService.ladeEintraegeFuerEvNr(ev);
      final bytes = ExportService.buildCsvFromMetas(
        evnr: ev,
        metas: metas,
        strasse: resolvedStrasse,
      );
      final fileName =
          '${_cleanName(resolvedStrasse ?? 'Unbekannt')}_EVNr_$ev.csv';

      downloadBytesWeb(bytes, fileName);
      final savedPath = await _saveExportOnDevice(
        bytes: bytes,
        fileName: fileName,
        evnr: ev,
      );
      await _trySaveExportHistory(
        fileName: fileName,
        mimeType: 'text/csv',
        bytes: bytes,
        evnr: ev,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              savedPath == null
                  ? '✓ CSV exportiert: $fileName'
                  : '✓ CSV gespeichert: $savedPath',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler beim CSV-Export: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _laden() async {
    final ev = _evCtrl.text.trim();
    if (ev.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bitte EVNr eingeben.')));
      return;
    }

    setState(() => _loading = true);
    try {
      final list = await SpeicherService.ladeEintraegeFuerEvNr(ev);
      if (!mounted) return;
      setState(() => _items = list);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Fehler beim Laden: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteEvNr() async {
    final ev = _evCtrl.text.trim();
    if (ev.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('EVNr löschen'),
        content: Text(
          'Möchten Sie die EVNr "$ev" und alle ${_items.length} zugehörigen Positionen wirklich löschen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _loading = true);
    try {
      await SpeicherService.deleteAllForEvNr(ev);
      await Repository.instance.deleteAllForEvNr(ev);
      // Session zurücksetzen, falls diese EVNr aktiv war
      await SessionStore.clear();
      setState(() => _items = []);
      _evCtrl.clear();
      await _ladeEvListe();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('EVNr "$ev" wurde gelöscht')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler beim Löschen: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ========== Filter-Match-Funktionen ==========
  bool _matchModul(Map<String, dynamic> m) {
    if (_filterModul == 'Alle') return true;
    return (m['typ']?.toString() ?? '') == _filterModul;
  }

  String _typCodeLabel(String typ) {
    final upper = typ.trim().toUpperCase();
    if (upper == 'VS' ||
        upper == 'VG' ||
        upper == 'G' ||
        upper.contains('SICKERGRUBE') ||
        upper.contains('GRUBE')) {
      return 'VG';
    }
    return typ;
  }

  bool _matchAbteilung(Map<String, dynamic> m) {
    if (_filterAbteilung == 'Alle') return true;
    final a = getAbteilungen(m);
    return a.contains(_filterAbteilung);
  }

  bool _matchSchaden(Map<String, dynamic> m) {
    if (!_nurSchadenFilter) return true;
    return hasSchaden(m);
  }

  int _comparePositions(Map<String, dynamic> a, Map<String, dynamic> b) {
    final posA = a['posNr']?.toString() ?? '0';
    final posB = b['posNr']?.toString() ?? '0';
    return _comparePositionStrings(posA, posB);
  }

  int _comparePositionStrings(String posA, String posB) {
    // Parse Position: "1" → (1, ""), "1a" → (1, "a"), "12b" → (12, "b")
    final regExp = RegExp(r'^(\d+)([a-zA-Z]*)$');

    final matchA = regExp.firstMatch(posA);
    final matchB = regExp.firstMatch(posB);

    // Falls keine Matches, fallback zu String-Vergleich
    if (matchA == null || matchB == null) {
      return posA.compareTo(posB);
    }

    final numA = int.tryParse(matchA.group(1) ?? '0') ?? 0;
    final numB = int.tryParse(matchB.group(1) ?? '0') ?? 0;
    final suffixA = matchA.group(2) ?? '';
    final suffixB = matchB.group(2) ?? '';

    // Erst nach Zahl sortieren
    if (numA != numB) return numA.compareTo(numB);

    // Bei gleicher Zahl: nach Suffix sortieren (leerer Suffix kommt zuerst)
    if (suffixA.isEmpty && suffixB.isNotEmpty) return -1;
    if (suffixA.isNotEmpty && suffixB.isEmpty) return 1;
    return suffixA.toLowerCase().compareTo(suffixB.toLowerCase());
  }

  // ========== Edit-Handler ==========
  Future<void> _editEntry(Map<String, dynamic> meta) async {
    final openingKey = (meta['storageKey'] ?? meta['posNr'] ?? '').toString();
    if (_openingEditorKey != null) return;

    try {
      final editMeta = _normalizeEditMeta(meta);
      final currentTyp = _canonicalEditTyp(editMeta['typ']);
      final typ = await _selectEditModule(
        currentTyp: currentTyp,
        posNr: (editMeta['posNr'] ?? '').toString(),
      );
      if (typ == null || !mounted) return;

      setState(() => _openingEditorKey = openingKey);
      final storageKey = (editMeta['storageKey'] ?? '').toString().trim();
      editMeta['typ'] = typ;

      await _activateEntrySession(editMeta);
      if (!mounted) return;

      final screen = _editorForMeta(
        editMeta,
        typ: typ,
        storageKey: storageKey.isEmpty ? null : storageKey,
      );
      await Navigator.of(context).push(
        MaterialPageRoute(
          settings: RouteSettings(name: _editorRouteName(typ)),
          builder: (_) => screen,
        ),
      );
      if (!mounted) return;
      await _laden();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bearbeiten konnte nicht geöffnet werden: $e')),
      );
    } finally {
      if (mounted) setState(() => _openingEditorKey = null);
    }
  }

  Future<String?> _selectEditModule({
    required String currentTyp,
    required String posNr,
  }) {
    const modules = <(String, String, IconData)>[
      ('ES', 'Einstiegschacht', Icons.vertical_align_bottom),
      ('VG', 'Sickergrube / Versitzgrube', Icons.water_drop_outlined),
      ('SSK', 'Straßensinkkasten', Icons.grid_view_outlined),
      ('LÜ', 'Lüftung', Icons.air),
      ('SK', 'Schieberkappe', Icons.settings_outlined),
      ('KANAL', 'Kanal', Icons.account_tree_outlined),
      ('DIV', 'Sonstiges', Icons.category_outlined),
    ];

    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Objekt zum Bearbeiten auswählen'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (posNr.trim().isNotEmpty) ...[
                  Text('Position $posNr'),
                  const SizedBox(height: 8),
                ],
                ...modules.map((module) {
                  final (code, label, icon) = module;
                  final selected = code == currentTyp;
                  return ListTile(
                    leading: Icon(icon),
                    title: Text(label),
                    subtitle: Text(code),
                    trailing: selected
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : const Icon(Icons.chevron_right),
                    selected: selected,
                    onTap: () => Navigator.of(dialogContext).pop(code),
                  );
                }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Abbrechen'),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _normalizeEditMeta(Map<String, dynamic> source) {
    final meta = Map<String, dynamic>.from(source);

    const listKeys = <String>[
      'verfuegbarkeit',
      'statusVorOrt',
      'schaeden',
      'abteilungen',
      'abteilungsMarker',
      'oertlichkeit',
      'oberflaeche',
      'schachtkopf',
      'filtersandEigensch',
      'mediaFotos',
      'mediaVideos',
      'mediaAudios',
      'mediaPdfs',
    ];
    for (final key in listKeys) {
      final value = meta[key];
      if (value == null) {
        meta[key] = <String>[];
      } else if (value is List) {
        meta[key] = value
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList();
      } else {
        meta[key] = value
            .toString()
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList();
      }
    }

    const stringKeys = <String>[
      'typ',
      'evnr',
      'strasse',
      'erfasser',
      'wetter',
      'temperatur',
      'zeitIso',
      'posNr',
      'idNr',
      'eingang',
      'einsteigart',
      'steigeisenStand',
      'deckel',
      'deckelBem',
      'kl',
      'durchmesser',
      'kanalprofil',
      'oertlBem',
      'obflBem',
      'uebergangsBem',
      'mKonusAnf',
      'mKonusEnd',
      'mBerme',
      'mSolltiefe',
      'st1Hoehe',
      'st1Rf',
      'st2Hoehe',
      'st2Rf',
      'grubentyp',
      'grubenart',
      'tiefe_cm',
      'tiefe_m',
      'wasser_cm',
      'wasser_m',
      'teller',
      'baujahr',
      'gruppe',
      'auspraegung',
      'abdeckung',
      'art',
      'typ_detail',
      'zustand',
      'titel',
      'beschreibung',
      'schadensdetails',
      'bemerkung',
      'storageKey',
    ];
    for (final key in stringKeys) {
      final value = meta[key];
      if (value != null && value is! String) {
        meta[key] = value.toString();
      }
    }
    return meta;
  }

  String _canonicalEditTyp(dynamic rawTyp) {
    final upper = (rawTyp ?? '').toString().trim().toUpperCase();
    if (upper == 'ES' || upper.contains('EINSTIEG')) return 'ES';
    if (upper == 'VG' ||
        upper == 'VS' ||
        upper == 'G' ||
        upper.contains('SICKERGRUBE') ||
        upper.contains('GRUBE')) {
      return 'VG';
    }
    if (upper == 'SSK' || upper.contains('SINKKASTEN')) return 'SSK';
    if (upper == 'L' ||
        upper == 'LÜ' ||
        upper == 'LUE' ||
        upper.contains('LÜFTUNG') ||
        upper.contains('LUEFTUNG')) {
      return 'LÜ';
    }
    if (upper == 'SK' || upper.contains('SCHIEBER')) return 'SK';
    if (upper == 'KANAL' || upper.contains('KANAL')) return 'KANAL';
    return 'DIV';
  }

  Future<void> _activateEntrySession(Map<String, dynamic> meta) async {
    final current = await SessionStore.load();
    final evnr = (meta['evnr'] ?? _evCtrl.text).toString().trim();
    final strasse = (meta['strasse'] ?? current?.strasse ?? '')
        .toString()
        .trim();
    if (evnr.isEmpty || strasse.isEmpty) {
      throw StateError('EVNr oder Straße fehlt.');
    }

    final nisPlan = await SessionStore.loadNisPlanForEvnr(evnr);
    final session = SessionData(
      evnr: evnr,
      strasse: strasse,
      erfasser: (meta['erfasser'] ?? current?.erfasser ?? '').toString(),
      wetter: (meta['wetter'] ?? current?.wetter ?? 'klar').toString(),
      zeitIso:
          (meta['zeitIso'] ??
                  current?.zeitIso ??
                  DateTime.now().toIso8601String())
              .toString(),
      temperatur: (meta['temperatur'] ?? current?.temperatur ?? '').toString(),
      nisPlanPdf: nisPlan?.pdfBase64,
    );
    await SessionStore.save(session);
    _s = session;
  }

  Widget _editorForMeta(
    Map<String, dynamic> meta, {
    required String typ,
    String? storageKey,
  }) {
    switch (typ) {
      case 'ES':
        return EinsteigScreen(initialMeta: meta);
      case 'VG':
        return GrubenScreen(initialMeta: meta);
      case 'SSK':
        return SinkkastenScreen(existingMeta: meta, storageKey: storageKey);
      case 'LÜ':
        return LueftungScreen(existingMeta: meta, storageKey: storageKey);
      case 'SK':
        return SchieberScreen(existingMeta: meta, storageKey: storageKey);
      case 'KANAL':
        return KanalScreen(existingMeta: meta, storageKey: storageKey);
      default:
        return SonstigesScreen(existingMeta: meta, storageKey: storageKey);
    }
  }

  String _editorRouteName(String typ) {
    switch (typ) {
      case 'ES':
        return Routes.es;
      case 'VG':
        return Routes.g;
      case 'SSK':
        return Routes.ssk;
      case 'LÜ':
        return Routes.l;
      case 'SK':
        return Routes.sk;
      case 'KANAL':
        return Routes.kanal;
      default:
        return Routes.div;
    }
  }

  String? _sskSchaedenMitLeitung(Map<String, dynamic> meta) {
    final typ = meta['typ']?.toString() ?? '';
    if (typ != 'SSK') return null;
    final rawSchaeden = meta['schaeden'];
    String schaedenText;
    if (rawSchaeden is List) {
      final list = rawSchaeden
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList();
      schaedenText = list.join(', ');
    } else {
      schaedenText = (rawSchaeden?.toString() ?? '').trim();
    }

    final leitung = meta['leitung'];
    if (leitung is! List) return null;
    final pairs = <String>[];
    for (final it in leitung) {
      if (it is! Map) continue;
      final m = (it['meter'] ?? '').toString().trim();
      final art = (it['art'] ?? '').toString().trim();
      if (m.isEmpty || art.isEmpty) continue;
      final mStr = m.endsWith('m') ? m : '${m}m';
      pairs.add('$mStr $art');
    }
    if (pairs.isEmpty) return null;
    final summary = pairs.join(', ');

    if (schaedenText.isEmpty) return summary;
    if (RegExp(
      r'Leitung kaputt',
      caseSensitive: false,
    ).hasMatch(schaedenText)) {
      return schaedenText.replaceFirst(
        RegExp(r'Leitung kaputt(\s*\(.*?\))?', caseSensitive: false),
        summary,
      );
    }
    return '$schaedenText | $summary';
  }

  List<Widget> _buildSteckbriefSections(Map<String, dynamic> meta, String typ) {
    final sections = <Widget>[];

    void addBlock(String title, List<Widget> fields) {
      if (fields.isEmpty) return;
      sections.add(
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 6),
          child: Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      );
      sections.addAll(fields);
      sections.add(const SizedBox(height: 6));
    }

    final idNr = (meta['idNr'] as String? ?? '').trim();

    if (typ == 'ES') {
      addBlock(
        'Identifikation',
        [
          buildMetaSection('ID', idNr),
          buildMetaSection('Objekt', _objektLabel(typ)),
        ].where((w) => w is! SizedBox).toList(),
      );

      addBlock(
        'Status',
        [
          buildMetaSection('Verfügbarkeit', meta['verfuegbarkeit']),
          buildMetaSection('Status vor Ort', meta['statusVorOrt']),
        ].where((w) => w is! SizedBox).toList(),
      );

      addBlock(
        'Grunddaten',
        [
          buildMetaSection(
            'Eingangsart',
            _firstMetaValue(meta, ['eingang', 'Eingang']),
          ),
          buildMetaSection('Einsteigart', meta['einsteigart']),
          buildMetaSection(
            'Deckelart',
            _firstMetaValue(meta, ['deckel', 'deckelart', 'Deckelart']),
          ),
          buildMetaSection('KL', meta['kl']),
          buildMetaSection('Schäden', _displaySchaeden(meta, typ)),
          buildMetaSection('Abteilung', getAbteilungen(meta)),
        ].where((w) => w is! SizedBox).toList(),
      );

      addBlock(
        'Lage / Oberfläche',
        [
          buildMetaSection(
            'Örtlichkeit',
            _firstMetaValue(meta, [
              'oertlichkeit',
              'Oertlichkeit',
              'Örtlichkeit',
            ]),
          ),
          buildMetaSection(
            'Bemerkung Örtlichkeit',
            _firstMetaValue(meta, [
              'oertlBem',
              'oertlichkeitBem',
              'ÖrtlichkeitBemerkung',
            ]),
          ),
          buildMetaSection(
            'Oberflächenart',
            _firstMetaValue(meta, [
              'oberflaeche',
              'oberflaechenart',
              'Oberflächenart',
            ]),
          ),
          buildMetaSection('Bemerkung Oberfläche', meta['obflBem']),
          buildMetaSection('Bemerkung', meta['bemerkung']),
        ].where((w) => w is! SizedBox).toList(),
      );

      addBlock(
        'Schachtkopf / Maße',
        [
          buildMetaSection('Schachtkopfart', meta['schachtkopf']),
          buildMetaSection(
            '1. Steigeisen Steighöhe (cm)',
            _firstMetaValue(meta, ['st1Hoehe', 'steighoehe_1_steigeisen']),
          ),
          buildMetaSection(
            '1. Steigeisen Rückenfreiheit (cm)',
            _firstMetaValue(meta, ['st1Rf', 'rueckenfreiheit_1_steigeisen']),
          ),
          buildMetaSection(
            '2. Steigeisen Steighöhe (cm)',
            _firstMetaValue(meta, ['st2Hoehe', 'steighoehe_2_steigeisen']),
          ),
          buildMetaSection(
            '2. Steigeisen Rückenfreiheit (cm)',
            _firstMetaValue(meta, ['st2Rf', 'rueckenfreiheit_2_steigeisen']),
          ),
          buildMetaSection(
            'Konusanfang (cm)',
            _firstMetaValue(meta, ['mKonusAnf', 'konusanfang']),
          ),
          buildMetaSection(
            'Konusende (cm)',
            _firstMetaValue(meta, ['mKonusEnd', 'konusende']),
          ),
          buildMetaSection(
            'Berme (cm)',
            _firstMetaValue(meta, ['mBerme', 'berme']),
          ),
          buildMetaSection(
            'Solltiefe (cm)',
            _firstMetaValue(meta, ['mSolltiefe', 'solltiefe']),
          ),
        ].where((w) => w is! SizedBox).toList(),
      );
    } else {
      addBlock(
        'Identifikation',
        [
          buildMetaSection('ID', idNr),
          buildMetaSection('Objekt', _objektLabel(typ)),
        ].where((w) => w is! SizedBox).toList(),
      );

      addBlock(
        'Status',
        [
          buildMetaSection('Verfügbarkeit', meta['verfuegbarkeit']),
          buildMetaSection('Status vor Ort', meta['statusVorOrt']),
        ].where((w) => w is! SizedBox).toList(),
      );

      addBlock(
        'Basisdaten',
        [
          buildMetaSection('Schäden', _displaySchaeden(meta, typ)),
          buildMetaSection('Abteilung', getAbteilungen(meta)),
          buildMetaSection('Örtlichkeit', meta['oertlichkeit']),
          buildMetaSection('Bemerkung', meta['bemerkung']),
        ].where((w) => w is! SizedBox).toList(),
      );

      final usedTypeKeys = <String>{};
      switch (typ) {
        case 'VG':
        case 'VS':
          addBlock(
            'Technische Daten',
            [
              buildMetaSection(
                'Grubentyp',
                _firstMetaValue(meta, ['grubentyp', 'grubenart']),
              ),
              buildMetaSection('Deckelart', meta['deckel']),
              buildMetaSection('KL', meta['kl']),
              buildMetaSection('Grubentiefe (m)', meta['tiefe_m']),
              buildMetaSection('Grubentiefe (cm)', meta['tiefe_cm']),
              buildMetaSection('Wasserstand (cm)', meta['wasser_cm']),
              buildMetaSection('Anschluss vorhanden', meta['anschlussJa']),
              buildMetaSection('Anschluss', meta['anschluss']),
              buildMetaSection('Überlauf', meta['teller']),
              buildMetaSection('Filtersand vorhanden', meta['filtersandJa']),
              buildMetaSection(
                'Filtersand Eigenschaften',
                meta['filtersandEigensch'],
              ),
              buildMetaSection('Baujahr', meta['baujahr']),
              buildMetaSection('Hinweis', meta['gesamtHinweis']),
            ].where((w) => w is! SizedBox).toList(),
          );
          usedTypeKeys.addAll({
            'grubentyp',
            'grubenart',
            'deckel',
            'kl',
            'tiefe_m',
            'tiefe_cm',
            'wasser_cm',
            'anschlussJa',
            'anschluss',
            'teller',
            'filtersandJa',
            'filtersandEigensch',
            'baujahr',
            'gesamtHinweis',
          });
          break;
        case 'SSK':
          addBlock(
            'Technische Daten',
            [
              buildMetaSection('Gruppe', meta['gruppe']),
              buildMetaSection('Ausprägung', meta['auspraegung']),
              buildMetaSection(
                'Aufbau wie Münchner Modell',
                meta['aufbauMuenchner'],
              ),
              buildMetaSection('Abdeckung', meta['abdeckung']),
              buildMetaSection('Ablaufrinne', meta['ablaufrinne']),
              buildMetaSection(
                'Ablaufrinne Verbindung',
                meta['ablaufrinneVerbindung'],
              ),
              buildMetaSection('Leitung', meta['leitung']),
            ].where((w) => w is! SizedBox).toList(),
          );
          usedTypeKeys.addAll({
            'gruppe',
            'auspraegung',
            'aufbauMuenchner',
            'abdeckung',
            'ablaufrinne',
            'ablaufrinneVerbindung',
            'leitung',
          });
          break;
        case 'LÜ':
          addBlock(
            'Technische Daten',
            [
              buildMetaSection(
                'Art',
                _firstMetaValue(meta, ['art', 'typ_detail']),
              ),
              buildMetaSection('Deckelart', meta['deckel']),
              buildMetaSection('KL', meta['kl']),
            ].where((w) => w is! SizedBox).toList(),
          );
          usedTypeKeys.addAll({
            'art',
            'typ_detail',
            'deckel',
            'deckelBem',
            'kl',
          });
          break;
        case 'SK':
          addBlock(
            'Technische Daten',
            [
              buildMetaSection(
                'Austausch erforderlich',
                meta['austauschErforderlich'],
              ),
            ].where((w) => w is! SizedBox).toList(),
          );
          usedTypeKeys.add('austauschErforderlich');
          break;
        case 'KANAL':
          addBlock(
            'Technische Daten',
            [
              buildMetaSection('Kanalprofil', meta['kanalprofil']),
              buildMetaSection('Schadensdetails', meta['schadensdetails']),
            ].where((w) => w is! SizedBox).toList(),
          );
          usedTypeKeys.addAll({'kanalprofil', 'schadensdetails'});
          break;
      }

      final usedKeys = <String>{
        'typ',
        'idNr',
        'evnr',
        'strasse',
        'erfasser',
        'zeitIso',
        'wetter',
        'temperatur',
        'gpsLat',
        'gpsLon',
        'posNr',
        'storageKey',
        'createdAt',
        'gps',
        'verfuegbarkeit',
        'statusVorOrt',
        'schaeden',
        'keinBefund',
        'abteilungen',
        'abteilungsMarker',
        'oertlichkeit',
        'bemerkung',
        'mediaFotos',
        'mediaVideos',
        'mediaAudios',
        'mediaPdfs',
        'mediaBindings',
        'flags',
        'displayOrder',
        'syncStatus',
        'lastLocalChangeAt',
        'syncVersion',
      };
      usedKeys.addAll(usedTypeKeys);

      final specific = <Widget>[];
      final allowedExtraKeys = _allowedExtraKeysForType(typ);
      for (final key in allowedExtraKeys) {
        if (usedKeys.contains(key)) continue;
        final value = meta[key];
        if (value == null) continue;
        if (value is List && value.isEmpty) continue;
        if (value is String && value.trim().isEmpty) continue;
        if (value is bool && !value) continue;
        specific.add(buildMetaSection(_beautifyKey(key), value));
      }

      addBlock(
        'Weitere Attribute',
        specific.where((w) => w is! SizedBox).toList(),
      );
    }

    final mediaCounts = _countMedia(meta);
    addBlock('Medien / Anhänge', [
      if ((mediaCounts['fotos'] ?? 0) > 0)
        buildMetaSection('Foto', 'vorhanden'),
      if ((mediaCounts['videos'] ?? 0) > 0)
        buildMetaSection('Video', 'vorhanden'),
      if ((mediaCounts['audios'] ?? 0) > 0)
        buildMetaSection('Audio', 'vorhanden'),
      if ((mediaCounts['office'] ?? 0) > 0)
        buildMetaSection('Office-Datei', 'vorhanden'),
      if ((mediaCounts['pdf'] ?? 0) > 0)
        buildMetaSection('PDF-Datei', 'vorhanden'),
    ]);

    if (sections.isNotEmpty && sections.last is SizedBox) {
      sections.removeLast();
    }
    return sections;
  }

  String _objektLabel(String typ) {
    switch (typ) {
      case 'ES':
        return 'Einstiegschacht';
      case 'VG':
      case 'VS':
        return 'Sickergrube';
      case 'SSK':
        return 'Straßensinkkasten';
      case 'LÜ':
        return 'Lüftung';
      case 'SK':
        return 'Schieberkappe';
      case 'KANAL':
        return 'Kanal';
      default:
        return 'Sonstiges';
    }
  }

  Set<String> _allowedExtraKeysForType(String typ) {
    switch (typ) {
      case 'VG':
      case 'VS':
        return {'deckelBem'};
      case 'SSK':
        return {'fallschutz'};
      case 'LÜ':
        return {'typ_detail'};
      case 'SK':
        return {'typ_detail'};
      case 'KANAL':
        return {'durchmesser', 'beschreibung'};
      default:
        return <String>{};
    }
  }

  dynamic _firstMetaValue(Map<String, dynamic> meta, List<String> keys) {
    for (final key in keys) {
      if (!meta.containsKey(key)) continue;
      final value = meta[key];
      if (value == null) continue;
      if (value is String && value.trim().isEmpty) continue;
      if (value is List && value.isEmpty) continue;
      return value;
    }
    return null;
  }

  dynamic _displaySchaeden(Map<String, dynamic> meta, String typ) {
    if (meta['keinBefund'] == true) return 'Kein Befund';

    final raw = meta['schaeden'];
    if (raw is! List || raw.isEmpty) {
      final details = (meta['schadensdetails'] as String?)?.trim();
      return details == null || details.isEmpty ? null : details;
    }

    if (typ == 'SSK') {
      return _sskSchaedenMitLeitung(meta) ?? raw;
    }
    if (typ == 'ES') {
      return _cleanSchaeden(raw);
    }
    return raw;
  }

  String _buildAufbauModul(Map<String, dynamic> meta, String typ) {
    final parts = <String>[];

    void addPart(dynamic value) {
      final text = (value ?? '').toString().trim();
      if (text.isEmpty) return;
      parts.add(text);
    }

    switch (typ) {
      case 'ES':
        final esProfil = _kanalProfilKurz(meta);
        if (esProfil.isNotEmpty) addPart(esProfil);
        addPart(_firstMetaValue(meta, ['deckel', 'deckelart', 'Deckelart']));
        final kl = (meta['kl'] ?? '').toString().trim();
        if (kl.isNotEmpty) addPart('KL $kl');
        final einsteigart = (meta['einsteigart'] ?? '').toString().trim();
        final steigeisenStand = (meta['steigeisenStand'] ?? '')
            .toString()
            .trim();
        if (einsteigart.isNotEmpty) {
          if (einsteigart == 'Steigeisen' && steigeisenStand.isNotEmpty) {
            addPart('Steigeisen ${steigeisenStand.toLowerCase()}');
          } else {
            addPart(einsteigart);
          }
        }
        break;
      case 'VG':
      case 'VS':
        addPart(_firstMetaValue(meta, ['grubentyp', 'grubenart']));
        addPart(_firstMetaValue(meta, ['deckel', 'deckelart', 'Deckelart']));
        final kl = (meta['kl'] ?? '').toString().trim();
        if (kl.isNotEmpty) addPart('KL $kl');
        break;
      case 'SSK':
        addPart(meta['gruppe']);
        addPart(meta['auspraegung']);
        addPart(meta['abdeckung']);
        break;
      case 'LÜ':
        addPart(_firstMetaValue(meta, ['art', 'typ_detail']));
        final kl = (meta['kl'] ?? '').toString().trim();
        if (kl.isNotEmpty) addPart('KL $kl');
        break;
      case 'SK':
        final austausch = meta['austauschErforderlich'] == true;
        addPart(austausch ? 'Austausch erforderlich' : 'Bestand');
        break;
      case 'KANAL':
        addPart(_kanalProfilKurz(meta));
        break;
      default:
        addPart(_firstMetaValue(meta, ['beschreibung', 'typ_detail']));
        break;
    }

    if (parts.isEmpty) return '—';
    return parts.join(' / ');
  }

  String _kanalProfilKurz(Map<String, dynamic> meta) {
    final breite = (meta['breite'] ?? meta['kanalBreite'] ?? '')
        .toString()
        .trim();
    final hoehe = (meta['hoehe'] ?? meta['höhe'] ?? meta['kanalHoehe'] ?? '')
        .toString()
        .trim();
    if (breite.isNotEmpty && hoehe.isNotEmpty) {
      return '$breite/$hoehe';
    }

    final raw = (_firstMetaValue(meta, ['kanalprofil', 'kanalProfil']) ?? '')
        .toString()
        .trim();
    if (raw.isEmpty) return '';

    // Bevorzuge Breite/Höhe-Muster (z. B. 600/900, 600x900, 600 x 900).
    final wh = RegExp(r'(\d{2,4})\s*[\/xX*]\s*(\d{2,4})').firstMatch(raw);
    if (wh != null) {
      return '${wh.group(1)}/${wh.group(2)}';
    }

    return raw;
  }

  Map<String, int> _countMedia(Map<String, dynamic> meta) {
    final counts = <String, int>{
      'fotos': 0,
      'videos': 0,
      'audios': 0,
      'office': 0,
      'pdf': 0,
    };

    void addRefs(dynamic value, String source) {
      if (value is! List) return;
      for (final item in value) {
        final ref = item is Map
            ? (item['value'] ??
                      item['name'] ??
                      item['fileName'] ??
                      item['path'] ??
                      '')
                  .toString()
                  .trim()
            : (item ?? '').toString().trim();
        if (ref.isEmpty) continue;
        final kind = _detectAttachmentKind(ref, source: source);
        if (kind != null && counts.containsKey(kind)) {
          counts[kind] = counts[kind]! + 1;
        }
      }
    }

    final bindings = meta['mediaBindings'];
    if (bindings is List && bindings.isNotEmpty) {
      addRefs(bindings, 'bindings');
    } else {
      addRefs(meta['mediaFotos'], 'fotos');
      addRefs(meta['mediaVideos'], 'videos');
      addRefs(meta['mediaAudios'], 'audios');
      addRefs(meta['mediaPdfs'], 'pdf');
    }

    return counts;
  }

  String _mediaSummaryText(Map<String, int> counts) {
    final parts = <String>[];

    void addPart(String singular, String plural, String key) {
      final count = counts[key] ?? 0;
      if (count <= 0) return;
      parts.add('$count ${count == 1 ? singular : plural}');
    }

    addPart('Foto', 'Fotos', 'fotos');
    addPart('Video', 'Videos', 'videos');
    addPart('Audio-Datei', 'Audio-Dateien', 'audios');
    addPart('Office-Datei', 'Office-Dateien', 'office');
    addPart('PDF-Datei', 'PDF-Dateien', 'pdf');

    return parts.join(', ');
  }

  String _remarkWithMedia(String remark, String mediaSummary) {
    final parts = <String>[
      if (remark.trim().isNotEmpty && remark.trim() != '—') remark.trim(),
      if (mediaSummary.isNotEmpty) 'Medien / Dateien: $mediaSummary',
    ];
    return parts.isEmpty ? '—' : parts.join(' | ');
  }

  String? _detectAttachmentKind(String value, {required String source}) {
    final v = value.trim().toLowerCase();
    final photoExt = {'jpg', 'jpeg', 'png', 'webp', 'heic'};
    final videoExt = {'mp4', 'mov', 'avi', 'mkv'};
    final audioExt = {'mp3', 'wav', 'm4a', 'aac'};
    final officeExt = {'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx'};

    if (v.startsWith('data:')) {
      final end = v.indexOf(';') == -1 ? v.indexOf(',') : v.indexOf(';');
      final mime = end > 5 ? v.substring(5, end) : '';
      if (mime.startsWith('image/')) return 'fotos';
      if (mime.startsWith('video/')) return 'videos';
      if (mime.startsWith('audio/')) return 'audios';
      if (mime.contains('pdf')) return 'pdf';
      if (mime.contains('msword') ||
          mime.contains('officedocument.wordprocessingml') ||
          mime.contains('excel') ||
          mime.contains('officedocument.spreadsheetml') ||
          mime.contains('powerpoint') ||
          mime.contains('officedocument.presentationml')) {
        return 'office';
      }
    }

    final match = RegExp(r'\.([a-z0-9]+)(?:\?|#|$)').firstMatch(v);
    final ext = match?.group(1) ?? '';
    if (photoExt.contains(ext)) return 'fotos';
    if (videoExt.contains(ext)) return 'videos';
    if (audioExt.contains(ext)) return 'audios';
    if (officeExt.contains(ext)) return 'office';
    if (ext == 'pdf') return 'pdf';

    // Fallback auf Ursprungsfeld, wenn keine Endung erkennbar ist.
    if (source == 'fotos' || source == 'videos' || source == 'audios')
      return source;
    if (source == 'pdf') return 'pdf';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final canExport = _isExportReady();
    final isMobile = ResponsiveLayout.isMobile(context);

    // ========== Gefilterte Liste ==========
    final visibleItems = _items.where((m) {
      if (!_matchModul(m)) return false;
      if (!_matchAbteilung(m)) return false;
      if (!_matchSchaden(m)) return false;
      return true;
    }).toList()..sort((a, b) => _comparePositions(a, b));

    return Scaffold(
      appBar: AppBar(
        title: Text(isMobile ? 'Bericht' : 'Bericht / Steckbriefe'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.all(ResponsiveLayout.contentPadding(context)),
              children: [
                if (_s != null)
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text('Session: ${_s!.strasse}'),
                      subtitle: Text(
                        'Datum: ${_df.format(_s!.zeit)}\n'
                        'Erfasser: ${_s!.erfasser} • EVNr: ${_s!.evnr} • Wetter: ${_formatWeatherWithTemp(_s!.wetter, _s!.temperatur)}',
                      ),
                    ),
                  ),

                TextField(
                  controller: _evCtrl,
                  decoration: const InputDecoration(labelText: 'EVNr *'),
                  onSubmitted: (_) => _laden(),
                ),
                const SizedBox(height: 8),
                ResponsiveButtonBar(
                  children: [
                    FilledButton(onPressed: _laden, child: const Text('Laden')),
                    FilledButton.icon(
                      onPressed: canExport ? _exportDataZip : null,
                      icon: const Icon(Icons.folder_zip_outlined),
                      label: const Text('Kompletter Ordner'),
                    ),
                    if (_items.isNotEmpty)
                      OutlinedButton.icon(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        label: const Text('Löschen'),
                        onPressed: _deleteEvNr,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    if (!canExport)
                      Tooltip(
                        message: _exportBlockReason(),
                        child: const Icon(Icons.info_outline, size: 20),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                if (!isMobile) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Gespeicherte EVNr',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      // Push the refresh button towards the right but leave extra
                      // space on the far right so the app logo overlay doesn't
                      // cover it on smaller screens.
                      Padding(
                        padding: const EdgeInsets.only(right: 96),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.refresh,
                              color: Colors.white,
                            ),
                            tooltip: 'Liste aktualisieren',
                            onPressed: _loadingEv ? null : _ladeEvListe,
                            splashRadius: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_loadingEv)
                    const LinearProgressIndicator()
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _evList
                          .map(
                            (ev) => OutlinedButton(
                              onPressed: () {
                                _evCtrl.text = ev;
                                _laden();
                              },
                              child: Text(ev),
                            ),
                          )
                          .toList(),
                    ),

                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Gespeicherte PDFs',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.refresh,
                            size: 16,
                            color: Colors.white,
                          ),
                          onPressed: _loadExports,
                          visualDensity: VisualDensity.compact,
                          splashRadius: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _exportFilterCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Suche Datei/EVNr',
                      isDense: true,
                      prefixIcon: Icon(Icons.search, size: 18),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (_loadingExports)
                    const LinearProgressIndicator(minHeight: 2)
                  else if (_exportFiles.isEmpty)
                    const Text(
                      'Keine PDF-Exporte vorhanden.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    )
                  else
                    Builder(
                      builder: (context) {
                        final filter = _exportFilterCtrl.text
                            .trim()
                            .toLowerCase();
                        final pdfExports = _exportFiles
                            .where(_isImportantExportFile)
                            .toList();
                        if (pdfExports.isEmpty) {
                          return const Text(
                            'Keine PDF-Exporte vorhanden.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          );
                        }
                        final visible = filter.isEmpty
                            ? pdfExports
                            : pdfExports.where((file) {
                                final ev = (file.evnr ?? '').toLowerCase();
                                final name = file.fileName.toLowerCase();
                                return name.contains(filter) ||
                                    ev.contains(filter);
                              }).toList();
                        if (visible.isEmpty) {
                          return const Text(
                            'Keine Treffer.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          );
                        }
                        return Column(
                          children: visible.map((file) {
                            final dateText = DateFormat(
                              'dd.MM.yyyy HH:mm',
                            ).format(file.createdAt);
                            final subtitle =
                                file.evnr == null || file.evnr!.isEmpty
                                ? dateText
                                : 'EVNr ${file.evnr}  •  $dateText';
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.picture_as_pdf_outlined,
                                size: 18,
                              ),
                              title: Text(
                                file.fileName,
                                style: const TextStyle(fontSize: 12),
                              ),
                              subtitle: Text(
                                subtitle,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                              trailing: Wrap(
                                spacing: 6,
                                children: [
                                  IconButton(
                                    tooltip: 'Download',
                                    icon: const Icon(Icons.download, size: 18),
                                    onPressed: () => _openExport(file),
                                  ),
                                  IconButton(
                                    tooltip: 'Loeschen',
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => _deleteExport(file),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                ],

                const SizedBox(height: 12),

                if (_items.isEmpty) ...[
                  const SizedBox(height: 24),
                  const Center(child: Text('Keine Einträge vorhanden.')),
                ] else ...[
                  // ========== FILTER ==========
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: EdgeInsets.all(
                        ResponsiveLayout.cardPadding(context),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Filter',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Builder(
                            builder: (context) {
                              final abteilungen = [
                                'Alle',
                                ...getAllAbteilungenFromMetas(
                                  _items,
                                ).toSet().toList()..sort(),
                              ];
                              final selectedAbteilung =
                                  abteilungen.contains(_filterAbteilung)
                                  ? _filterAbteilung
                                  : 'Alle';
                              return Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Theme.of(context).dividerColor,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  children: [
                                    ListTile(
                                      leading: const Icon(
                                        Icons.category_outlined,
                                      ),
                                      title: const Text('Objekttyp'),
                                      trailing: DropdownButton<String>(
                                        value: _filterModul,
                                        items:
                                            [
                                                  'Alle',
                                                  'ES',
                                                  'VS',
                                                  'SSK',
                                                  'LÜ',
                                                  'SK',
                                                  'KANAL',
                                                  'DIV',
                                                ]
                                                .map(
                                                  (m) => DropdownMenuItem(
                                                    value: m,
                                                    child: Text(
                                                      _typCodeLabel(m),
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                        onChanged: (v) => setState(
                                          () => _filterModul = v ?? 'Alle',
                                        ),
                                      ),
                                    ),
                                    const Divider(height: 1),
                                    ListTile(
                                      leading: const Icon(
                                        Icons.apartment_outlined,
                                      ),
                                      title: const Text('Abteilung'),
                                      trailing: DropdownButton<String>(
                                        value: selectedAbteilung,
                                        items: abteilungen
                                            .map(
                                              (a) => DropdownMenuItem(
                                                value: a,
                                                child: Text(a),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (v) => setState(
                                          () => _filterAbteilung = v ?? 'Alle',
                                        ),
                                      ),
                                    ),
                                    const Divider(height: 1),
                                    SwitchListTile(
                                      secondary: const Icon(
                                        Icons.warning_amber_outlined,
                                      ),
                                      title: const Text('Nur Schäden'),
                                      value: _nurSchadenFilter,
                                      onChanged: (v) =>
                                          setState(() => _nurSchadenFilter = v),
                                    ),
                                    const Divider(height: 1),
                                    Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton.icon(
                                          onPressed: () => setState(() {
                                            _filterModul = 'Alle';
                                            _filterAbteilung = 'Alle';
                                            _nurSchadenFilter = false;
                                          }),
                                          icon: const Icon(
                                            Icons.filter_alt_off_outlined,
                                          ),
                                          label: const Text(
                                            'Filter zurücksetzen',
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                              children: [
                                const TextSpan(
                                  text: 'Bericht für EVNr: ',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                ),
                                TextSpan(text: _evCtrl.text.trim()),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          buildMetaSection(
                            'Straße',
                            _items.first['strasse'] as String? ?? '—',
                          ),
                          buildMetaSection(
                            'Datum/Zeit',
                            _formatIso(_items.first['zeitIso'] as String?),
                          ),
                          buildMetaSection(
                            'Wetter',
                            _formatWeatherWithTemp(_s?.wetter, _s?.temperatur),
                          ),
                        ],
                      ),
                    ),
                  ),

                  ...visibleItems.map((meta) {
                    final typ = meta['typ'] as String? ?? 'DIV';
                    final posNr = meta['posNr'] as String? ?? '?';
                    final objektArt = _objektLabel(typ);

                    final schadenVorhanden = hasSchaden(meta);
                    final aufbauModul = _buildAufbauModul(meta, typ);
                    final schaedenKurz = _displaySchaeden(meta, typ);
                    final bemerkungKurz = (meta['bemerkung'] as String?)
                        ?.trim();
                    final mediaSummary = _mediaSummaryText(_countMedia(meta));
                    final bemerkung = _remarkWithMedia(
                      bemerkungKurz ?? '',
                      mediaSummary,
                    );

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: schadenVorhanden ? Colors.red.shade50 : null,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header: Objektart + Position
                            Text(
                              '$objektArt${posNr.isNotEmpty && posNr != '?' ? ' – Position $posNr' : ''}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: schadenVorhanden
                                    ? Colors.red.shade900
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Divider(height: 1),
                            const SizedBox(height: 8),

                            // Kurzansicht in der Berichtoberfläche
                            buildMetaSection(
                              'Beschreibung',
                              aufbauModul.trim().isEmpty ? '—' : aufbauModul,
                            ),
                            buildMetaSection('Schäden', schaedenKurz),
                            buildMetaSection('Bemerkung', bemerkung),
                            const SizedBox(height: 8),

                            // Footer: Actions
                            SizedBox(
                              width: double.infinity,
                              child: Row(
                                children: [
                                  const Spacer(),

                                  // rechte Seite: Actions
                                  IconButton(
                                    icon: const Icon(Icons.visibility),
                                    tooltip: 'Anschauen',
                                    onPressed: () => _showDetail(meta),
                                  ),
                                  IconButton(
                                    icon:
                                        _openingEditorKey ==
                                            (meta['storageKey'] ??
                                                    meta['posNr'] ??
                                                    '')
                                                .toString()
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.edit_note),
                                    tooltip: 'Bearbeiten',
                                    onPressed: _openingEditorKey == null
                                        ? () => _editEntry(meta)
                                        : null,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    tooltip: 'Löschen',
                                    onPressed: () => _confirmDeleteSingle(meta),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],

                if (isMobile) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Gespeicherte EVNr',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 96),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.refresh,
                              color: Colors.white,
                            ),
                            tooltip: 'Liste aktualisieren',
                            onPressed: _loadingEv ? null : _ladeEvListe,
                            splashRadius: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_loadingEv)
                    const LinearProgressIndicator()
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _evList
                          .map(
                            (ev) => OutlinedButton(
                              onPressed: () {
                                _evCtrl.text = ev;
                                _laden();
                              },
                              child: Text(ev),
                            ),
                          )
                          .toList(),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Gespeicherte PDFs',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.refresh,
                            size: 16,
                            color: Colors.white,
                          ),
                          onPressed: _loadExports,
                          visualDensity: VisualDensity.compact,
                          splashRadius: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _exportFilterCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Suche Datei/EVNr',
                      isDense: true,
                      prefixIcon: Icon(Icons.search, size: 18),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (_loadingExports)
                    const LinearProgressIndicator(minHeight: 2)
                  else if (_exportFiles.isEmpty)
                    const Text(
                      'Keine PDF-Exporte vorhanden.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    )
                  else
                    Builder(
                      builder: (context) {
                        final filter = _exportFilterCtrl.text
                            .trim()
                            .toLowerCase();
                        final pdfExports = _exportFiles
                            .where(_isImportantExportFile)
                            .toList();
                        if (pdfExports.isEmpty) {
                          return const Text(
                            'Keine PDF-Exporte vorhanden.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          );
                        }
                        final visible = filter.isEmpty
                            ? pdfExports
                            : pdfExports.where((file) {
                                final ev = (file.evnr ?? '').toLowerCase();
                                final name = file.fileName.toLowerCase();
                                return name.contains(filter) ||
                                    ev.contains(filter);
                              }).toList();
                        if (visible.isEmpty) {
                          return const Text(
                            'Keine Treffer.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          );
                        }
                        return Column(
                          children: visible.map((file) {
                            final dateText = DateFormat(
                              'dd.MM.yyyy HH:mm',
                            ).format(file.createdAt);
                            final subtitle =
                                file.evnr == null || file.evnr!.isEmpty
                                ? dateText
                                : 'EVNr ${file.evnr}  •  $dateText';
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.picture_as_pdf_outlined,
                                size: 18,
                              ),
                              title: Text(
                                file.fileName,
                                style: const TextStyle(fontSize: 12),
                              ),
                              subtitle: Text(
                                subtitle,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                              trailing: Wrap(
                                spacing: 6,
                                children: [
                                  IconButton(
                                    tooltip: 'Download',
                                    icon: const Icon(Icons.download, size: 18),
                                    onPressed: () => _openExport(file),
                                  ),
                                  IconButton(
                                    tooltip: 'Loeschen',
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => _deleteExport(file),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                ],
              ],
            ),
    );
  }

  String _formatWeatherWithTemp(String? weather, String? temp) {
    final w = (weather ?? '').trim();
    final t = (temp ?? '').trim();
    if (w.isEmpty && t.isEmpty) return '—';
    if (w.isEmpty) return t;
    if (t.isEmpty) return w;
    return '$w $t°C';
  }

  String _formatIso(String? iso) {
    if (iso == null || iso.trim().isEmpty) return '—';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return _df.format(dt);
  }

  void _showDetail(Map<String, dynamic> meta) async {
    try {
      await showDialog(
        context: context,
        builder: (ctx) => EntryDetailDialog(
          meta: meta,
          onUpdate: (updatedMeta) async {
            final key = (updatedMeta['storageKey'] as String?)?.trim();
            if (key == null || key.isEmpty) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Eintrag kann nicht gespeichert werden (storageKey fehlt).',
                    ),
                  ),
                );
              }
              return;
            }
            await SpeicherService.updateEntry(key, updatedMeta);
            await _laden();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Eintrag aktualisiert')),
              );
            }
          },
          onDelete: () async {
            final key = (meta['storageKey'] as String?)?.trim();
            if (key == null || key.isEmpty) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Eintrag kann nicht gelöscht werden (storageKey fehlt).',
                    ),
                  ),
                );
              }
              return;
            }
            await _confirmDeleteSingle(meta);
          },
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Laden des Objekts: $e')),
        );
      }
    }
  }

  Future<void> _confirmDeleteSingle(Map<String, dynamic> meta) async {
    final typ = meta['typ'] as String? ?? 'DIV';
    final posNr = meta['posNr'] as String? ?? '?';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Löschen bestätigen'),
        content: Text(
          'Möchtest du den Eintrag "$typ – Pos. $posNr" wirklich löschen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final key = (meta['storageKey'] as String?)?.trim();
    if (key == null || key.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Eintrag kann nicht gelöscht werden (storageKey fehlt).',
          ),
        ),
      );
      return;
    }

    await SpeicherService.deleteEntry(key);
    await _laden();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Eintrag gelöscht')));
    }
  }

  void _openPreview() async {
    final ev = _evCtrl.text.trim();
    if (ev.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bitte EVNr eingeben.')));
      return;
    }
    if (!_isExportReady()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_exportBlockReason())));
      return;
    }

    setState(() => _loading = true);
    try {
      final metas = await SpeicherService.ladeEintraegeFuerEvNr(ev);
      final s = await SessionStore.load();

      final fotosPerEntry = metas
          .map(
            (m) =>
                (m['mediaFotos'] as List<dynamic>?)?.cast<String>() ??
                <String>[],
          )
          .toList();
      final videosPerEntry = metas
          .map(
            (m) =>
                (m['mediaVideos'] as List<dynamic>?)?.cast<String>() ??
                <String>[],
          )
          .toList();
      final audiosPerEntry = metas
          .map(
            (m) =>
                (m['mediaAudios'] as List<dynamic>?)?.cast<String>() ??
                <String>[],
          )
          .toList();
      final pdfsPerEntry = metas
          .map(
            (m) =>
                (m['mediaPdfs'] as List<dynamic>?)?.cast<String>() ??
                <String>[],
          )
          .toList();

      final plan = buildExportPlanFromMeta(
        evnr: ev,
        strasse: s?.strasse,
        metas: metas,
        fotosPerEntry: fotosPerEntry,
        videosPerEntry: videosPerEntry,
        audiosPerEntry: audiosPerEntry,
        pdfsPerEntry: pdfsPerEntry,
      );

      if (!mounted) return;
      setState(() => _loading = false);

      showDialog(
        context: context,
        builder: (_) => ExportPreviewDialog(
          initialPlan: plan,
          onConfirm: (confirmed) async {
            setState(() => _loading = true);
            try {
              await _savePdfExportsFromPlan(confirmed, s, ev);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'PDF-Export erfolgreich (${confirmed.positions.length} Positionen)',
                    ),
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Export fehlgeschlagen: $e')),
                );
              }
            } finally {
              if (mounted) setState(() => _loading = false);
            }
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Aufbau der Vorschau: $e')),
      );
    }
  }

  bool _isExportReady() {
    final ev = _evCtrl.text.trim();
    if (ev.isEmpty) return false;
    if (_items.isEmpty) return false;
    return true;
  }

  Future<void> _savePdfExportsFromPlan(
    ExportPlan plan,
    SessionData? s,
    String ev,
  ) async {
    final metas = plan.positions
        .map((p) => p.meta)
        .whereType<Map<String, dynamic>>()
        .toList();
    final strasse = s?.strasse ?? 'Unbekannt';

    if (plan.gesamtPdfPlanned) {
      final bytes = await ExportService.buildGesamtPdfFromMetas(
        evnr: plan.evnr,
        metas: metas,
        erfasser: s?.erfasser,
        strasse: strasse,
        wetter: s?.wetter,
        zeit: s?.zeit,
      );
      final fileName = '${_cleanName(strasse)}_EVNr_${ev}_Gesamt_Bericht.pdf';
      await _saveExportOnDevice(
        bytes: bytes,
        fileName: fileName,
        evnr: ev,
        inErfassungen: true,
      );
      await _trySaveExportHistory(
        fileName: fileName,
        mimeType: 'application/pdf',
        bytes: bytes,
        evnr: ev,
      );
    }

    for (final pos in plan.positions) {
      final meta = pos.meta;
      if (meta == null || !pos.steckbriefPlanned) continue;
      final posNum = (pos.positionsnummer ?? pos.index.toString()).trim();
      final bytes = await ExportService.buildEinzelPdfFromMeta(
        meta: meta,
        erfasser: s?.erfasser,
        wetter: s?.wetter,
      );
      final fileName =
          '${_cleanName(strasse)}_EVNr_${ev}_Pos_${posNum}_Steckbrief.pdf';
      await _saveExportOnDevice(
        bytes: bytes,
        fileName: fileName,
        evnr: ev,
        inErfassungen: true,
      );
      await _trySaveExportHistory(
        fileName: fileName,
        mimeType: 'application/pdf',
        bytes: bytes,
        evnr: ev,
      );
    }

    final abteilungsMap = <String, List<Map<String, dynamic>>>{};
    for (final pos in plan.positions) {
      final meta = pos.meta;
      if (meta == null) continue;
      final abtList = getAbteilungen(meta);
      for (final abt in abtList) {
        abteilungsMap
            .putIfAbsent(abt, () => <Map<String, dynamic>>[])
            .add(meta);
      }
    }
    for (final entry in abteilungsMap.entries) {
      final abt = entry.key;
      final bytes = await ExportService.buildAbteilungsPdfFromMetas(
        abteilung: abt,
        evnr: plan.evnr,
        metas: entry.value,
        erfasser: s?.erfasser,
        strasse: strasse,
        wetter: s?.wetter,
        zeit: s?.zeit,
      );
      final fileName =
          '${_cleanName(strasse)}_EVNr_${ev}_Abteilungsbericht_${_cleanName(abt)}.pdf';
      await _saveExportOnDevice(bytes: bytes, fileName: fileName, evnr: ev);
      await _trySaveExportHistory(
        fileName: fileName,
        mimeType: 'application/pdf',
        bytes: bytes,
        evnr: ev,
      );
    }
  }

  String _exportBlockReason() {
    final ev = _evCtrl.text.trim();
    if (ev.isEmpty) return 'EVNr fehlt';
    if (_items.isEmpty) return 'Keine Objekte geladen';
    return 'Blocker unbekannt';
  }

  Future<void> _trySaveExportHistory({
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
    String? evnr,
  }) async {
    try {
      await ExportStore.saveExport(
        fileName: fileName,
        mimeType: mimeType,
        bytes: bytes,
        evnr: evnr,
      );
    } catch (e) {
      debugPrint(
        '[BerichtScreen] Export-Historie konnte nicht gespeichert werden: $e',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Export erstellt. Hinweis: Lokale Export-Historie konnte nicht gespeichert werden.',
          ),
        ),
      );
    }
  }

  String? _resolvedStrasse() {
    final sessionStrasse = _s?.strasse.trim();
    if (sessionStrasse != null && sessionStrasse.isNotEmpty)
      return sessionStrasse;

    for (final m in _items) {
      final strasse = (m['strasse'] as String?)?.trim();
      if (strasse != null && strasse.isNotEmpty) return strasse;
    }
    return null;
  }

  String? _resolvedErfasser() {
    final sessionErfasser = _s?.erfasser.trim();
    if (sessionErfasser != null && sessionErfasser.isNotEmpty)
      return sessionErfasser;

    for (final m in _items) {
      final erfasser = (m['erfasser'] as String?)?.trim();
      if (erfasser != null && erfasser.isNotEmpty) return erfasser;
    }
    return null;
  }

  String _cleanName(String name) {
    return name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
  }

  String _exportFolderName(String evnr) {
    final strasse = _resolvedStrasse() ?? 'Unbekannt';
    return '${_cleanName(evnr)}_${_cleanName(strasse)}';
  }

  Future<String?> _saveExportOnDevice({
    required Uint8List bytes,
    required String fileName,
    required String evnr,
    bool inErfassungen = false,
  }) async {
    return saveExportToDevice(
      bytes: bytes,
      fileName: fileName,
      exportFolderName: _exportFolderName(evnr),
      inErfassungen: inErfassungen,
    );
  }
}
