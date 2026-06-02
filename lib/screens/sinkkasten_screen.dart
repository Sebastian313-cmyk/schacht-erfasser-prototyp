// ======================= lib/screens/sinkkasten_screen.dart =======================
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../services/session_store.dart';
import '../services/repository.dart';
import '../models/ssk_entry.dart';
import '../constants/options.dart';
import '../services/speicher_service.dart';
import '../services/validation_service.dart';
import '../services/gps_service.dart';
import '../services/media_picker_service.dart';
import '../services/audio_service.dart';
import '../services/speech_service.dart';
import '../widgets/nis_plan_viewer_dialog.dart';
import '../widgets/form_ui.dart';

class SinkkastenScreen extends StatefulWidget {
  final Map<String, dynamic>? existingMeta;
  final String? storageKey;

  const SinkkastenScreen({super.key, this.existingMeta, this.storageKey});
  @override
  State<SinkkastenScreen> createState() => _SinkkastenScreenState();
}

class _SinkkastenScreenState extends State<SinkkastenScreen> {
    // State für 312/313 Buttons
    bool _show312 = false;
    bool _show313 = false;
    void _toggle312() {
      setState(() {
        _show312 = !_show312;
        if (_show312) _show313 = false;
      });
    }
    void _toggle313() {
      setState(() {
        _show313 = !_show313;
        if (_show313) _show312 = false;
      });
    }
  SessionData? _session;
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;

  bool get _isEdit {
    final key = widget.storageKey ?? widget.existingMeta?['storageKey'] as String?;
    return widget.existingMeta != null && (key ?? '').isNotEmpty;
  }

  // Pflicht
  final _posCtrl = TextEditingController();
  final _idNrCtrl = TextEditingController();

  // Typ (zweistufig)
  String _gruppe = 'SSK Münchner Modell';
  String _auspraegung = 'Normalausführung';
  bool _aufbauMuenchner = false;
  String _abdeckung = 'Passavant';
  final _herstellerBemCtrl = TextEditingController(); // für "Weitere Hersteller / Bemerkung"
  final _abdeckungBemCtrl = TextEditingController(); // für Abdeckung (Bemerkung)

  // Ablaufrinne (neu, nur SSK) – Positionsnummer im Format "X/Y"
  bool _ablaufrinne = false;
  final _ablaufrinneVerbindungCtrl = TextEditingController();
  String? _letztePosition; // Letzte gespeicherte SSK-Position für Ablaufrinne
  final Set<String> _usedAblaufrinnePositions = <String>{}; // Bereits belegte Positionen aus Ablaufrinnen

  // Verfügbarkeit & Status vor Ort (SSK) - Mehrfachauswahl
  final Set<String> _verfuegbarkeit = <String>{};
  final Set<String> _statusVorOrt = <String>{};
  final _verfuegbarkeitErgaenzenCtrl = TextEditingController();

  // Abteilungen (Marker)
  // Nur für 312/313-Logik: aktuelle Abteilungs-Auswahl
  final Set<String> _abteilungen = <String>{};

  // Schäden + Leitung kaputt
  final Set<String> _schaeden = <String>{};
  bool _keinBefund = false;

  final List<_LeitRow> _leitung = [];
  final List<String> _leitungArten = const ['Scherbe', 'Riss', 'Beton', 'Verstopft', 'Wurzeln', 'Fremder Gegenstand'];

  // Medien & Bemerkung
  final List<String> _fotos = [];
  final List<String> _videos = [];
  final List<String> _audios = [];
  final List<String> _pdfs = [];
  final _bemCtrl = TextEditingController();

  // Display-Reihenfolge (für Bericht)
  final List<String> _displayOrder = [
    'verfuegbarkeit',
    'statusVorOrt',
    'gruppe',
    'aufbauMuenchner',
    'auspraegung',
    'abdeckung',
    'ablaufrinne',
    'ablaufrinneVerbindung',
    'schaeden',
    'abteilungen',
    'leitung',
    'bemerkung',
  ];

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Widget _sectionLabel(String text) => SectionLabel(text);

  Future<void> _loadSession() async {
    _session = await SessionStore.load();
    await _loadLetztePosition();
    if (widget.existingMeta != null) _applyExistingMeta(widget.existingMeta!);
    if (mounted) setState(() {});
  }

  void _applyExistingMeta(Map<String, dynamic> m) {
    _posCtrl.text = (m['posNr'] ?? '').toString();
    _idNrCtrl.text = (m['idNr'] ?? '').toString();

    _gruppe = (m['gruppe'] as String?) ?? _gruppe;
    _aufbauMuenchner = (m['aufbauMuenchner'] == true);
    _auspraegung = _normalizeAuspraegung(m['auspraegung'] as String?);
    _herstellerBemCtrl.text = _extractHerstellerBem(m['auspraegung'] as String?);
    _abdeckung = _normalizeAbdeckung(m['abdeckung'] as String?);
    _abdeckungBemCtrl.text = _extractAbdeckungBem(m['abdeckung'] as String?);
    _ablaufrinne = (m['ablaufrinne'] == true);
    _ablaufrinneVerbindungCtrl.text = (m['ablaufrinneVerbindung'] ?? '').toString();

    _verfuegbarkeit
      ..clear()
      ..addAll(_splitSet(m['verfuegbarkeit']));
    _statusVorOrt
      ..clear()
      ..addAll(_splitSet(m['statusVorOrt']));

    _abteilungen
      ..clear()
      ..addAll(_splitSet(m['abteilungen']));

    _schaeden
      ..clear()
      ..addAll(((m['schaeden'] as List<dynamic>?) ?? const []).map((e) => e.toString()));
    _keinBefund = (m['keinBefund'] == true);

    _leitung.clear();
    final leitung = (m['leitung'] as List<dynamic>?) ?? const [];
    for (final l in leitung) {
      if (l is Map<String, dynamic>) {
        _leitung.add(_LeitRow.fromJson(l));
      }
    }

    _fotos
      ..clear()
      ..addAll(((m['mediaFotos'] as List<dynamic>?) ?? const []).map((e) => e.toString()));
    _videos
      ..clear()
      ..addAll(((m['mediaVideos'] as List<dynamic>?) ?? const []).map((e) => e.toString()));
    _audios.clear();
    final audios = (m['mediaAudios'] as List<dynamic>?)?.cast<String>() ?? <String>[];
    _audios.addAll(audios);
    final pdf = m['mediaPdfs'];
    if (pdf is List) _pdfs.addAll(pdf.cast<String>());

    _bemCtrl.text = (m['bemerkung'] ?? '').toString();

    setState(() {});
  }

  Set<String> _splitSet(dynamic v) {
    if (v is List) {
      return v.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toSet();
    }
    final s = (v ?? '').toString().trim();
    if (s.isEmpty) return {};
    return s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
  }

  String _normalizeAuspraegung(String? stored) {
    final s = (stored ?? '').trim();
    if (s.startsWith('Bemerkung:')) return 'Bemerkung';
    return s.isEmpty ? _auspraegung : s;
  }

  String _extractHerstellerBem(String? stored) {
    final s = (stored ?? '').trim();
    if (s.startsWith('Bemerkung:')) return s.replaceFirst('Bemerkung:', '').trim();
    return '';
  }

  String _normalizeAbdeckung(String? stored) {
    final s = (stored ?? '').trim();
    if (s.startsWith('Bemerkung:')) return 'Bemerkung';
    return s.isEmpty ? _abdeckung : s;
  }

  String _extractAbdeckungBem(String? stored) {
    final s = (stored ?? '').trim();
    if (s.startsWith('Bemerkung:')) return s.replaceFirst('Bemerkung:', '').trim();
    return '';
  }

  Future<void> _loadLetztePosition() async {
    if (_session == null) return;
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('obj_${_session!.evnr}_${_session!.strasse}_') && k.endsWith('_SSK')).toList();
    if (keys.isEmpty) return;
    
    // Sortiere nach Positionsnummer
    keys.sort((a, b) {
      final posA = a.split('_')[3];
      final posB = b.split('_')[3];
      return _comparePositions(posA, posB);
    });
    
    // Letzte Position extrahieren
    final lastKey = keys.last;
    _letztePosition = lastKey.split('_')[3];
    
    // Lade alle belegten Ablaufrinne-Positionen
    await _loadUsedAblaufrinnePositions();
  }

  /// Lädt alle bereits in Ablaufrinnen verwendeten Positionen
  Future<void> _loadUsedAblaufrinnePositions() async {
    if (_session == null) return;
    
    _usedAblaufrinnePositions.clear();
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => 
      k.startsWith('obj_${_session!.evnr}_${_session!.strasse}_') && 
      k.endsWith('_SSK')).toList();
    
    for (final key in keys) {
      final jsonStr = prefs.getString(key);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        try {
          final json = jsonDecode(jsonStr);
          if (json is Map<String, dynamic>) {
            final posNr = (json['posNr'] as String?) ?? '';
            // Wenn posNr im Format "2/4" ist (Ablaufrinne), extrahiere beide Zahlen
            if (posNr.contains('/')) {
              final parts = posNr.split('/');
              if (parts.length == 2) {
                _usedAblaufrinnePositions.add(parts[0].trim());
                _usedAblaufrinnePositions.add(parts[1].trim());
              }
            }
          }
        } catch (_) {
          // Ignoriere Fehler beim Deserialisieren
        }
      }
    }
  }
  int _comparePositions(String a, String b) {
    final numA = int.tryParse(a.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final numB = int.tryParse(b.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (numA != numB) return numA.compareTo(numB);
    return a.compareTo(b);
  }

  @override
  void dispose() {
    _posCtrl.dispose();
    _idNrCtrl.dispose();
    _herstellerBemCtrl.dispose();
    _abdeckungBemCtrl.dispose();
    _ablaufrinneVerbindungCtrl.dispose();
    _bemCtrl.dispose();
    super.dispose();
  }

  // ----------------------------- Helpers -----------------------------
  Future<void> _pickMedia() async {
    final res = await MediaPickerService.pickMedia(context: context);
    if (res.fotos.isNotEmpty) _fotos.addAll(res.fotos);
    if (res.videos.isNotEmpty) _videos.addAll(res.videos);
    setState(() {});
  }

  Future<void> _pickAudio() async {
    final choice = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Audio hinzufügen'),
        content: const Text('Wie möchtest du vorgehen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Abbrechen'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop('diktat'),
            child: const Text('Diktat'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop('aufnehmen'),
            child: const Text('Aufnehmen'),
          ),
        ],
      ),
    );

    if (choice == 'diktat') {
      // Show speech recognition dialog
      if (mounted) {
        await _showDiktatDialog();
      }
    } else if (choice == 'aufnehmen') {
      // Record audio normally
      final audioData = await AudioService.pickOrRecordAudio();
      if (audioData != null && audioData.isNotEmpty) {
        _audios.add(audioData);
        setState(() {});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Audio hinzugefügt')),
          );
        }
      }
    }
  }

  Future<void> _showDiktatDialog() async {
    // First check if speech recognition is available
    final init = await SpeechService.initialize();
    if (!mounted) return;

    if (!init) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Spracherkennung nicht verfügbar')),
      );
      return;
    }

    String recognizedText = '';
    bool isListening = false;

    // Create a stateful dialog
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Diktat'),
          content: SizedBox(
            height: 150,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isListening ? Icons.mic : Icons.mic_none,
                  size: 48,
                  color: isListening ? Colors.red : Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  isListening ? 'Höre zu...' : 'Bereit zum Sprechen',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      recognizedText.isEmpty ? 'Erkannter Text wird hier angezeigt' : recognizedText,
                      style: TextStyle(
                        fontSize: 14,
                        color: recognizedText.isEmpty ? Colors.grey : Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Abbrechen'),
            ),
            if (recognizedText.isNotEmpty)
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop('save'),
                child: const Text('Speichern'),
              ),
            FilledButton.tonal(
              onPressed: () async {
                if (isListening) {
                  // Stop listening
                  await SpeechService.stopListening();
                  setState(() {
                    isListening = false;
                  });
                } else {
                  // Start listening
                  setState(() {
                    isListening = true;
                  });
                  await SpeechService.startListening(
                    onResult: (text) {
                      setState(() {
                        recognizedText = text;
                      });
                    },
                  );
                }
              },
              child: Text(isListening ? 'Stopp' : 'Sprechen'),
            ),
          ],
        ),
      ),
    ).then((result) {
      // After dialog closes, append text to Bemerkung if saved
      if (recognizedText.isNotEmpty && result == 'save') {
        setState(() {
          if (_bemCtrl.text.isEmpty) {
            _bemCtrl.text = recognizedText;
          } else {
            _bemCtrl.text = '${_bemCtrl.text}\n$recognizedText';
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Diktat hinzugefügt')),
          );
        }
      }
    });
  }

  Future<void> _pickFolder() async {
    final result = await MediaPickerService.pickFolder();
    setState(() {
      _fotos.addAll(result.fotos);
      _videos.addAll(result.videos);
      _pdfs.addAll(result.pdfs);
    });
  }

  Future<bool> _confirm(BuildContext ctx, String title, String msg) async {
    return (await showDialog<bool>(
          context: ctx,
          builder: (c) => AlertDialog(
            title: Text(title),
            content: Text(msg),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Abbrechen')),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('OK')),
            ],
          ),
        )) ??
        false;
  }

  void _toggleLeitungKaputt(bool on) {
    setState(() {
      if (on) {
        _schaeden.add('Leitung kaputt');
        if (_leitung.isEmpty) _leitung.add(_LeitRow());
      } else {
        _schaeden.remove('Leitung kaputt');
        _leitung.clear();
      }
    });
  }

  // ----------------------------- Save -----------------------------
  Future<void> _onSave() async {
    if (_session == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Bitte zuerst auf der Startseite EVNr/Straße/Erfasser setzen.')));
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    // Exklusivität: Kein Befund ↔ andere Schäden
    final keinBefundCheck = ValidationService.validateNoKeinBefundMitSchaeden(
      keinBefund: _keinBefund,
      schaeden: _schaeden,
      message: '"Kein Befund" schließt Schaden-Auswahl aus.',
    );
    if (!keinBefundCheck.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(keinBefundCheck.message!)),
      );
      return;
    }

    // Positionsnummer: bei Ablaufrinne kombinieren
    String pos = _posCtrl.text.trim();
    if (_ablaufrinne) {
      final verbindung = _ablaufrinneVerbindungCtrl.text.trim();
      if (verbindung.isEmpty) {
        // Verbindung ist optional: ohne zweite Position bleibt die normale Positionsnummer bestehen.
      } else {
      // Kleinere Zahl zuerst (z.B. 2/5 statt 5/2)
      final num1 = int.tryParse(verbindung) ?? 0;
      final num2 = int.tryParse(pos) ?? 0;
      final sorted = num1 < num2 ? '$num1/$num2' : '$num2/$num1';
      pos = sorted;
      
      // Prüfe ob eine der beiden Positionen bereits belegt ist (nur wenn Edit)
      final oldPos = (widget.existingMeta?['posNr'] as String?)?.trim();
      if (oldPos == null || oldPos != pos) { // Bei neuen oder geänderten Einträgen
        final parts = pos.split('/');
        final alreadyUsed = <String>[];
        for (final part in parts) {
          if (_usedAblaufrinnePositions.contains(part)) {
            alreadyUsed.add(part);
          }
        }
        
        if (alreadyUsed.isNotEmpty && mounted) {
          final ok = await _confirm(
            context, 
            'Warnung', 
            'Die Position(en) ${alreadyUsed.join(", ")} ist/sind bereits in einer anderen Ablaufrinne belegt.\n\nTrotzdem speichern?'
          );
          if (!ok) return;
        }
      }
      }
    }

    final existingKey = widget.storageKey ?? widget.existingMeta?['storageKey'] as String?;
    final uniqueCheck = await ValidationService.validateUniquePosition(
      evnr: _session!.evnr,
      strasse: _session!.strasse,
      posNr: pos,
      excludeStorageKey: _isEdit ? existingKey : null,
    );
    if (!uniqueCheck.isValid) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(uniqueCheck.message!)),
      );
      return;
    }

    // Ablaufrinne erzwingt Hersteller=Bemerkung 'Ablaufrinne' (nur SSK)
    if (_ablaufrinne) {
      _gruppe = 'Weitere Hersteller';
      _aufbauMuenchner = false;
      _auspraegung = 'Bemerkung';
      if (_herstellerBemCtrl.text.trim().isEmpty) {
        _herstellerBemCtrl.text = 'Ablaufrinne';
      }
    }

    final usesMuenchnerAufbau = _gruppe == 'Weitere Hersteller' && _aufbauMuenchner;
    String? abdeckungMeta;
    if (usesMuenchnerAufbau) {
      if (_abdeckung == 'Bemerkung') {
        final t = _abdeckungBemCtrl.text.trim();
        abdeckungMeta = t.isEmpty ? 'Bemerkung' : 'Bemerkung: $t';
      } else {
        abdeckungMeta = _abdeckung;
      }
    }

    // Bemerkung automatisch um Medien/Ablaufrinne ergänzen
    var bemerkung = _bemCtrl.text.trim();
    if (_ablaufrinne) {
      final emoji = '🟦';
      bemerkung = bemerkung.isEmpty ? '$emoji Ablaufrinne' : '$bemerkung | $emoji Ablaufrinne';
    }
    if (_fotos.isNotEmpty || _videos.isNotEmpty) {
      final mv = '📷 ${_fotos.length}${_videos.isNotEmpty ? ' / 🎥 ${_videos.length}' : ''}';
      bemerkung = bemerkung.isEmpty ? mv : '$bemerkung | $mv';
    }

    // Zusätzlich: Eintrag im Repository für Bericht/Export ablegen
    try {
      final leitungText = _leitung
          .map((e) => (e.meter.trim().isEmpty && (e.art).trim().isEmpty)
              ? null
              : '${e.meter.trim().isEmpty ? '?' : e.meter.trim()} m: ${e.art}')
          .whereType<String>()
          .join(', ');

      final ssk = SskEntry(
        id: Repository.instance.newId(),
        evnr: _session!.evnr,
        positionsnummer: pos,

        // SCHADEN = Schaden-Chips oder "Kein Befund"
        titel: _keinBefund
            ? 'Kein Befund'
            : (_schaeden.isEmpty ? '—' : _schaeden.join(', ')),

        zeit: DateTime.now(),
        strasse: _session!.strasse,

        bemerkung: bemerkung.isEmpty ? null : bemerkung,

        verfuegbarkeitLabel: _verfuegbarkeit.isEmpty ? null : _verfuegbarkeit.join(', '),

        statusVorOrtLabel: _statusVorOrt.isEmpty ? null : _statusVorOrt.join(', '),

        // Typ/Ausprägung geht in "spezial"
        notizen: null,
        spezial: () {
          String spezial;
          if (_gruppe == 'SSK Münchner Modell') {
            spezial = 'Münchner Modell – $_auspraegung';
          } else if (_aufbauMuenchner) {
            spezial = 'Weitere Hersteller – Aufbau Münchner Modell – $_auspraegung';
          } else {
            spezial = _auspraegung == 'Bemerkung'
                ? 'Weitere Hersteller – ${_herstellerBemCtrl.text.trim()}'
                : 'Weitere Hersteller – $_auspraegung';
          }
          final abdeckungLabel = (abdeckungMeta ?? '').replaceFirst('Bemerkung:', '').trim();
          if (abdeckungLabel.isNotEmpty) {
            spezial = '$spezial • Abdeckung: $abdeckungLabel';
          }
          return spezial;
        }(),

        leitungsverlauf: leitungText.isEmpty ? null : leitungText,
      );
      await Repository.instance.add(ssk);
    } catch (_) {
      // Silent: Repository ist nur für Bericht/Export, PDF läuft unabhängig.
    }

    // GPS erfassen (einmalig beim Speichern)
    final gps = await GpsService.getCurrentLocation();

    // Persistenz
    final idNr = _idNrCtrl.text.trim();
    final idValidation = ValidationService.validateIdNumberByType(
      idNr,
      typ: 'SSK',
      required: false,
    );
    if (idValidation != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(idValidation)),
      );
      return;
    }
    final meta = {
      'typ': 'SSK',
      'evnr': _session!.evnr,
      'strasse': _session!.strasse,
      'erfasser': _session!.erfasser,
      'zeitIso': _session!.zeitIso,
      'wetter': _session!.wetter,
      'posNr': pos,
      'idNr': idNr,
      'gruppe': _gruppe,
      'auspraegung': _auspraegung == 'Bemerkung' ? 'Bemerkung: ${_herstellerBemCtrl.text.trim()}' : _auspraegung,
      if (_gruppe == 'Weitere Hersteller') 'aufbauMuenchner': _aufbauMuenchner,
      if (usesMuenchnerAufbau) 'abdeckung': abdeckungMeta,
      'ablaufrinne': _ablaufrinne,
      'ablaufrinneVerbindung': _ablaufrinne ? _ablaufrinneVerbindungCtrl.text.trim() : '',
      'verfuegbarkeit': _verfuegbarkeit.toList(),
      'statusVorOrt': _statusVorOrt.toList(),
      'abteilungen': _abteilungen.toList(),
      'schaeden': _schaeden.toList(),
      'keinBefund': _keinBefund,
      'leitung': _leitung.map((e) => e.toJson()).toList(),
      'bemerkung': bemerkung,
      'mediaFotos': _fotos,
      'mediaVideos': _videos,
      'mediaAudios': _audios,
      'mediaPdfs': _pdfs,
      'displayOrder': _displayOrder,
      'createdAt': DateTime.now().toIso8601String(),
      'gps': gps,
    };
    final metaKey = (_isEdit && (existingKey ?? '').isNotEmpty)
        ? existingKey!
        : 'obj_${_session!.evnr}_${_session!.strasse}_${pos}_SSK';
    if (_isEdit) {
      meta['createdAt'] = widget.existingMeta?['createdAt'] ?? meta['createdAt'];
    }
    meta['storageKey'] = metaKey;
    await SpeicherService.upsertEntry(metaKey, meta);

    // Hinweis: Einzel-PDF-Download entfernt. Export erfolgt zentral über ZIP.

    if (!mounted) return;
    
    // Letzte Position aktualisieren für nächste Ablaufrinne
    await _loadLetztePosition();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SSK gespeichert (im Gesamt-Export enthalten).')));
      Navigator.pop(context);
    }
  }

  // ----------------------------- UI -----------------------------
  Future<void> _openNisPlan() async {
    final evnr = _session?.evnr ?? '';
    final nis = evnr.trim().isNotEmpty ? await SessionStore.loadNisPlanForEvnr(evnr) : null;
    if (!mounted) return;
    final base64 = nis?.pdfBase64 ?? _session?.nisPlanPdf;
    if (base64 == null || base64.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kein NIS-Plan hinterlegt.')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) => NisPlanViewerDialog(
        pdfBase64: base64,
        fileName: nis?.fileName ?? 'NIS-Plan.pdf',
        evnr: evnr.trim().isEmpty ? null : evnr,
        initialDrawings: nis?.drawings,
        initialRoutes: nis?.routes,
        initialStamps: nis?.stamps,
      ),
    );
  }

  Future<void> _openBeschreibung() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Beschreibung - Straßensinkkasten (SSK)'),
        content: const SingleChildScrollView(
          child: Text(
            'Dieses Modul erfasst Straßensinkkästen (SSK).\n\n'
            'Wichtig:\n'
            '- Pflichtfeld ist die Positionsnummer.\n'
            '- Ablaufart, Zustand und weitere SSK-Merkmale eintragen.\n'
            '- Zugeordnete Positionen können optional ergänzt werden.\n\n'
            'Hinweis:\n'
            'Die Erfassung wird im Modul gespeichert, Exportdateien entstehen erst im Bericht.'
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _session;
    final df = DateFormat('dd.MM.yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Straßensinkkasten (SSK)'),
        actions: [
          TextButton.icon(
            onPressed: _openNisPlan,
            icon: const Icon(Icons.map_outlined),
            label: const Text('NIS'),
            style: TextButton.styleFrom(foregroundColor: Colors.black),
          ),
          TextButton.icon(
            onPressed: _openBeschreibung,
            icon: const Icon(Icons.info_outline),
            label: const Text('Beschreibung'),
            style: TextButton.styleFrom(foregroundColor: Colors.black),
          ),
        ],
      ),
      body: s == null
          ? const Center(child: Text('Bitte zuerst auf der Startseite EVNr/Straße/Erfasser setzen.'))
          : Form(
              key: _formKey,
              child: Stepper(
                currentStep: _currentStep,
                onStepTapped: (step) => setState(() => _currentStep = step),
                onStepContinue: () {
                  if (_currentStep == 0) {
                    if (!_formKey.currentState!.validate()) return;
                  }
                  if (_currentStep < 3) {
                    setState(() => _currentStep += 1);
                  } else {
                    _onSave();
                  }
                },
                onStepCancel: () {
                  if (_currentStep > 0) {
                    setState(() => _currentStep -= 1);
                  }
                },
                controlsBuilder: (context, details) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Row(
                      children: [
                        FilledButton(
                          onPressed: details.onStepContinue,
                          child: Text(_currentStep == 3 ? 'Speichern' : 'Weiter'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: details.onStepCancel,
                          child: const Text('Zurück'),
                        ),
                      ],
                    ),
                  );
                },
                steps: [
                  // Schritt 1: Basis-Daten
                  Step(
                    title: const Text('1. Basis-Daten'),
                    isActive: _currentStep >= 0,
                    state: _currentStep > 0 ? StepState.complete : StepState.indexed,
                    content: ListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        // Kopf
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('SSK – Kopf', style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 6),
                              _kv('EVNr', s.evnr),
                              _kv('Straße', s.strasse),
                              _kv('Erfasser:in', s.erfasser),
                              _kv('Datum/Zeit', df.format(DateTime.tryParse(s.zeitIso) ?? DateTime.now())),
                              _kv('Wetter', _wIcon(s.wetter)),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ObjectGpsPanel(initialMeta: widget.existingMeta),
                        const SizedBox(height: 12),

                        // Positionsnummer
                        _label('Positionsnummer *'),
                        TextFormField(
                          controller: _posCtrl,
                          decoration: const InputDecoration(hintText: 'z. B. 1, 1a, 2'),
                          validator: ValidationService.validatePositionField,
                          onChanged: (_) => setState(() {}),
                        ),

                        const SizedBox(height: 12),
                        // ID-Nummer
                        _label('ID-Nummer (optional)'),
                        TextField(
                          controller: _idNrCtrl,
                          decoration: const InputDecoration(
                            hintText: '8-stellig, nur Ziffern (z. B. 12345678)',
                            helperText: 'Optional',
                          ),
                        ),

                        const SizedBox(height: 16),
                        // Verfügbarkeit
                        _sectionLabel('Verfügbarkeit'),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: kVerfuegbarkeitOptionsSsk.map((opt) {
                            return FilterChip(
                              label: Text(opt),
                              selected: _verfuegbarkeit.contains(opt),
                              onSelected: (v) {
                                setState(() {
                                  if (v) {
                                    _verfuegbarkeit.add(opt);
                                  } else {
                                    _verfuegbarkeit.remove(opt);
                                    if (opt == 'Ergänzen') _verfuegbarkeitErgaenzenCtrl.clear();
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        if (_verfuegbarkeit.contains('Ergänzen')) ... [
                          const SizedBox(height: 8),
                          TextField(
                            controller: _verfuegbarkeitErgaenzenCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Ergänzen - Freitext',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 2,
                          ),
                        ],

                        const SizedBox(height: 16),
                        // Status vor Ort
                        _sectionLabel('Status vor Ort'),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ...kStatusAllgemein,
                            ...kStatusSskExtra,
                          ].map((opt) {
                            return FilterChip(
                              label: Text(opt),
                              selected: _statusVorOrt.contains(opt),
                              onSelected: (v) {
                                setState(() {
                                  if (v) {
                                    _statusVorOrt.add(opt);
                                  } else {
                                    _statusVorOrt.remove(opt);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  // Schritt 2: Art (Deckelart + Ablaufrinne)
                  Step(
                    title: const Text('2. Art'),
                    isActive: _currentStep >= 1,
                    state: _currentStep > 1 ? StepState.complete : StepState.indexed,
                    content: ListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        // Deckelart (Gruppe)
                        _sectionLabel('Deckelart'),
                        const SizedBox(height: 6),
                        Wrap(spacing: 8, children: [
                          ChoiceChip(
                            label: const Text('SSK Münchner Modell'),
                            selected: _gruppe == 'SSK Münchner Modell',
                            onSelected: (_) => setState(() {
                              _gruppe = 'SSK Münchner Modell';
                              _aufbauMuenchner = false;
                              _auspraegung = 'Normalausführung';
                            }),
                          ),
                          ChoiceChip(
                            label: const Text('Weitere Hersteller'),
                            selected: _gruppe == 'Weitere Hersteller',
                            onSelected: (_) => setState(() {
                              _gruppe = 'Weitere Hersteller';
                              _aufbauMuenchner = false;
                              _auspraegung = 'Passavant';
                            }),
                          ),
                        ]),
                        const SizedBox(height: 12),

                        if (_gruppe == 'Weitere Hersteller') ...[
                          _sectionLabel('Aufbau wie Münchner Modell?'),
                          const SizedBox(height: 6),
                          Wrap(spacing: 8, children: [
                            ChoiceChip(
                              label: const Text('Ja'),
                              selected: _aufbauMuenchner,
                              onSelected: (_) => setState(() {
                                _aufbauMuenchner = true;
                                _auspraegung = 'Normalausführung';
                              }),
                            ),
                            ChoiceChip(
                              label: const Text('Nein'),
                              selected: !_aufbauMuenchner,
                              onSelected: (_) => setState(() {
                                _aufbauMuenchner = false;
                                _auspraegung = 'Passavant';
                              }),
                            ),
                          ]),
                          const SizedBox(height: 12),
                        ],

                        // Ausprägung (Label abhängig von Gruppe)
                        _sectionLabel(_gruppe == 'SSK Münchner Modell' ? 'Aufbau' : 'Deckelart'),
                        const SizedBox(height: 6),
                        if (_gruppe == 'SSK Münchner Modell' || (_gruppe == 'Weitere Hersteller' && _aufbauMuenchner))
                          DropdownButtonFormField<String>(
                            initialValue: _auspraegung,
                            items: const ['Normalausführung', 'Kurzausführung', 'Beton', 'Sifon']
                                .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                                .toList(),
                            onChanged: (v) => setState(() => _auspraegung = v ?? 'Normalausführung'),
                          )
                        else
                          DropdownButtonFormField<String>(
                            initialValue: _auspraegung,
                            items: const ['Passavant', 'Brückenablauf', 'Einwalzbar', 'DIN-Modell', 'Bemerkung']
                                .map((d) => DropdownMenuItem(value: d, child: Text(d == 'Bemerkung' ? 'Bemerkung (frei)' : d)))
                                .toList(),
                            onChanged: (v) => setState(() => _auspraegung = v ?? 'Passavant'),
                          ),
                        if (_gruppe == 'Weitere Hersteller' && !_aufbauMuenchner && _auspraegung == 'Bemerkung') ...[
                          const SizedBox(height: 8),
                          TextField(controller: _herstellerBemCtrl, decoration: const InputDecoration(labelText: 'Hersteller/Typ (Bemerkung)')),
                        ],

                        if (_gruppe == 'Weitere Hersteller' && _aufbauMuenchner) ...[
                          const SizedBox(height: 12),
                          _sectionLabel('Abdeckung *'),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: _abdeckung,
                            items: const ['Passavant', 'Brückenablauf', 'Einwalzbar', 'DIN-Modell', 'Bemerkung']
                                .map((d) => DropdownMenuItem(value: d, child: Text(d == 'Bemerkung' ? 'Bemerkung (frei)' : d)))
                                .toList(),
                            onChanged: (v) => setState(() => _abdeckung = v ?? 'Passavant'),
                          ),
                          if (_abdeckung == 'Bemerkung') ...[
                            const SizedBox(height: 8),
                            TextField(controller: _abdeckungBemCtrl, decoration: const InputDecoration(labelText: 'Abdeckung (Bemerkung)')),
                          ],
                        ],

                        const SizedBox(height: 20),
                        // Ablaufrinne
                        _sectionLabel('Ablaufrinne'),
                        const SizedBox(height: 6),
                        CheckboxListTile(
                          value: _ablaufrinne,
                          onChanged: (v) => setState(() {
                            _ablaufrinne = v ?? false;
                            if (_ablaufrinne && _letztePosition != null) {
                              _ablaufrinneVerbindungCtrl.text = _letztePosition!;
                            }
                          }),
                          title: const Text('Mit anderer Position verbinden'),
                          subtitle: Text(_ablaufrinne 
                            ? 'Ergebnis: ${_ablaufrinneVerbindungCtrl.text.trim().isEmpty ? "X" : _ablaufrinneVerbindungCtrl.text.trim()}/${_posCtrl.text.trim().isEmpty ? "Y" : _posCtrl.text.trim()}'
                            : 'Wenn es sich um eine Ablaufrinne handelt, die zwei Positionen verbindet (z.B. Position 2 und 5)'),
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                        ),
                        if (_ablaufrinne) ...[
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _ablaufrinneVerbindungCtrl,
                            decoration: InputDecoration(
                              labelText: 'Position zum Verbinden *',
                              hintText: _letztePosition != null ? 'z.B. $_letztePosition' : 'z.B. 2',
                            ),
                            validator: (v) => !_ablaufrinne
                                ? null
                                : (v == null || v.trim().isEmpty
                                    ? null
                                    : ValidationService.validatePositionField(v)),
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Schritt 3: Schäden & Abteilung
                  Step(
                    title: const Text('3. Schäden & Abteilung'),
                    isActive: _currentStep >= 2,
                    state: _currentStep > 2 ? StepState.complete : StepState.indexed,
                    content: ListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        // Schäden
                        _sectionLabel('Schäden'),
                        const SizedBox(height: 6),
                        _chipsMulti([
                          'Komplett', 'Rost', 'Rahmen/Rost', 'Auflagerringe', 'Eimer', 'Mittelstück', 'Leitung kaputt', 'Reinigung/Nachbefahren'
                        ], _schaeden, disable: _keinBefund, onToggle: (name, sel) {
                          if (name == 'Leitung kaputt') _toggleLeitungKaputt(sel);
                        }),
                        const SizedBox(height: 8),
                        FilterChip(
                          label: Text('Kein Befund', style: TextStyle(color: _keinBefund ? Colors.green : null)),
                          selected: _keinBefund,
                          onSelected: (v) => setState(() {
                            _keinBefund = v;
                            if (v) {
                              _schaeden.clear();
                              _leitung.clear();
                            }
                          }),
                        ),

                        const SizedBox(height: 20),
                        // Abteilungen
                        _sectionLabel('Abteilungen'),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: _toggle312,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _show312 ? Colors.blue : null,
                              ),
                              child: const Text('312'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _toggle313,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _show313 ? Colors.blue : null,
                              ),
                              child: const Text('313'),
                            ),
                          ],
                        ),
                        if (_show312)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Wrap(
                              spacing: 8,
                              children: [
                                FilterChip(
                                  label: const Text('312 IZ AR'),
                                  selected: _abteilungen.contains('312 IZ AR'),
                                  onSelected: (v) => setState(() {
                                    v ? _abteilungen.add('312 IZ AR') : _abteilungen.remove('312 IZ AR');
                                  }),
                                ),
                                FilterChip(
                                  label: const Text('312 Ost'),
                                  selected: _abteilungen.contains('312 Ost'),
                                  onSelected: (v) => setState(() {
                                    v ? _abteilungen.add('312 Ost') : _abteilungen.remove('312 Ost');
                                  }),
                                ),
                                FilterChip(
                                  label: const Text('312 Service'),
                                  selected: _abteilungen.contains('312 Service'),
                                  onSelected: (v) => setState(() {
                                    v ? _abteilungen.add('312 Service') : _abteilungen.remove('312 Service');
                                  }),
                                ),
                                FilterChip(
                                  label: const Text('312 West'),
                                  selected: _abteilungen.contains('312 West'),
                                  onSelected: (v) => setState(() {
                                    v ? _abteilungen.add('312 West') : _abteilungen.remove('312 West');
                                  }),
                                ),
                              ],
                            ),
                          ),
                        if (_show313)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Wrap(
                              spacing: 8,
                              children: [
                                FilterChip(
                                  label: const Text('313 TU'),
                                  selected: _abteilungen.contains('313 TU'),
                                  onSelected: (v) => setState(() {
                                    v ? _abteilungen.add('313 TU') : _abteilungen.remove('313 TU');
                                  }),
                                ),
                                FilterChip(
                                  label: const Text('313 BU'),
                                  selected: _abteilungen.contains('313 BU'),
                                  onSelected: (v) => setState(() {
                                    v ? _abteilungen.add('313 BU') : _abteilungen.remove('313 BU');
                                  }),
                                ),
                                FilterChip(
                                  label: const Text('313 BauKo'),
                                  selected: _abteilungen.contains('313 BauKo'),
                                  onSelected: (v) => setState(() {
                                    v ? _abteilungen.add('313 BauKo') : _abteilungen.remove('313 BauKo');
                                  }),
                                ),
                              ],
                            ),
                          ),
                        // ...entfernt: doppelte Abteilungs-Buttons...

                        // Leitung kaputt Details (wenn aktiviert)
                        if (_schaeden.contains('Leitung kaputt')) ...[
                          const SizedBox(height: 20),
                          _sectionLabel('Leitungsdetails'),
                          const SizedBox(height: 6),
                          if (_leitung.isEmpty)
                            OutlinedButton.icon(
                              onPressed: () => setState(() => _leitung.add(_LeitRow())),
                              icon: const Icon(Icons.add),
                              label: const Text('Erste Zeile hinzufügen'),
                            )
                          else ...[
                            ..._leitung.asMap().entries.map((e) => _leitRow(e.key)),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton.icon(
                                onPressed: () => setState(() => _leitung.add(_LeitRow())),
                                icon: const Icon(Icons.add),
                                label: const Text('Weitere Zeile'),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),

                  // Schritt 4: Speichern
                  Step(
                    title: const Text('4. Speichern'),
                    isActive: _currentStep >= 3,
                    state: StepState.indexed,
                    content: ListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        // Bemerkung
                        _sectionLabel('Bemerkung'),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _bemCtrl,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Zusätzliche Bemerkung (optional)',
                            hintText: 'z. B. besondere Merkmale...',
                          ),
                        ),

                        const SizedBox(height: 20),
                        // Medien
                        _sectionLabel('Medien'),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _pickMedia,
                              icon: const Icon(Icons.image),
                              label: const Text('Medien'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _pickAudio,
                              icon: const Icon(Icons.mic),
                              label: const Text('Audio'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _pickFolder,
                              icon: const Icon(Icons.folder_open),
                              label: const Text('PDF'),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.blue.withValues(alpha: 0.1),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Chip(label: Text('📷 ${_fotos.length}   🎥 ${_videos.length}   🎤 ${_audios.length}   📄 ${_pdfs.length}')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ----------------------------- helpers -----------------------------
  Widget _leitRow(int i) {
    final row = _leitung[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(children: [
        SizedBox(
          width: 120,
          child: TextField(
            controller: row.mCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Länge (m)  z. B. 1,50'),
          ),
        ),
        const SizedBox(width: 8),
        DropdownButton<String>(
          value: row.art,
          items: _leitungArten.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
          onChanged: (v) => setState(() => row.art = v ?? _leitungArten.first),
        ),
        const Spacer(),
        IconButton(
          onPressed: () => setState(() => _leitung.removeAt(i)),
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Zeile entfernen',
        )
      ]),
    );
  }

  Widget _chipsMulti(List<String> items, Set<String> target, {bool disable = false, void Function(String, bool)? onToggle}) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items
            .map((name) => FilterChip(
                  label: Text(name),
                  selected: target.contains(name),
                  onSelected: disable
                      ? null
                      : (v) => setState(() {
                            if (v) {
                              target.add(name);
                            } else {
                              target.remove(name);
                            }
                            if (onToggle != null) onToggle(name, v);
                          }),
                ))
            .toList(),
      );

  Widget _label(String t) => FieldLabel(t);

  Widget _kv(String k, String v) => KvRow(label: k, value: v);

  String _wIcon(String key) {
    switch (key) {
      case 'bewoelkt':
        return '☁️';
      case 'regen':
        return '🌧️';
      case 'schnee':
        return '❄️';
      case 'windig':
        return '🌬️';
      case 'klar':
      default:
        return '☀️';
    }
  }
}

class _LeitRow {
  final TextEditingController mCtrl;
  String art;

  _LeitRow({String meter = '', this.art = 'Scherbe'}) : mCtrl = TextEditingController(text: meter);
  
  String get meter => mCtrl.text.replaceAll(',', '.');
  Map<String, String> toJson() => {'meter': meter, 'art': art};
  
  factory _LeitRow.fromJson(Map<String, dynamic> json) {
    return _LeitRow(
      meter: (json['meter'] as String?) ?? '',
      art: (json['art'] as String?) ?? 'Scherbe',
    );
  }
}
