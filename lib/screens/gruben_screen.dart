// ======================= lib/screens/gruben_screen.dart =======================
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/session_store.dart';
import '../constants/options.dart';
import '../services/speicher_service.dart';
import '../services/validation_service.dart';
import '../services/gps_service.dart';
import '../services/media_picker_service.dart';
import '../services/audio_service.dart';
import '../services/speech_service.dart';
import '../widgets/nis_plan_viewer_dialog.dart';
import '../widgets/form_ui.dart';

class GrubenScreen extends StatefulWidget {
  final Map<String, dynamic>? initialMeta;
  const GrubenScreen({super.key, this.initialMeta});
  @override
  State<GrubenScreen> createState() => _GrubenScreenState();
}

class _GrubenScreenState extends State<GrubenScreen> {
  // State für 312/313 Buttons
  bool _show312 = false;
  bool _show313 = false;

  void _toggle312() {
    setState(() {
      _show312 = !_show312;
      if (_show312) {
        _show313 = false;
        _abteilungen.removeWhere((e) => e.startsWith('313'));
      }
    });
  }

  void _toggle313() {
    setState(() {
      _show313 = !_show313;
      if (_show313) {
        _show312 = false;
        _abteilungen.removeWhere((e) => e.startsWith('312'));
      }
    });
  }

  void _syncAbteilungsToggles() {
    final has312 = _abteilungen.any((e) => e.startsWith('312'));
    final has313 = _abteilungen.any((e) => e.startsWith('313'));
    if (has312 && !has313) {
      _show312 = true;
      _show313 = false;
    } else if (has313 && !has312) {
      _show313 = true;
      _show312 = false;
    }
  }

  SessionData? _session;

  // Pflicht
  final _posCtrl = TextEditingController();
  final _idNrCtrl = TextEditingController(); // optional

  // Verfügbarkeit & Status (wie ES)
  final Set<String> _verfuegbarkeit = <String>{};
  final Set<String> _statusVorOrt = <String>{};
  final _verfuegbarkeitErgaenzenCtrl = TextEditingController();

  // Abteilungen (Marker)
  // Nur für 312/313-Logik: aktuelle Abteilungs-Auswahl
  final Set<String> _abteilungen = <String>{};

  // Kernfelder
  String _grubenart =
      'Absetzschacht'; // Absetzschacht, Sickerschacht, KB-Schacht, DIN, Gemauert
  String _deckel = kStandardSchachtDeckelart;
  final _deckelBemCtrl = TextEditingController();
  String _kl = 'D'; // A–F

  // Schäden
  final Set<String> _schaeden = <String>{};
  bool _keinBefund = false;

  static const String _klUnterDSchaden = 'unter KL D (automatisch)';

  // Zusatzinfos (kein Schaden!) -> nur im Steckbrief sichtbar
  final _tiefeCtrl = TextEditingController(); // m
  final _wasserCtrl = TextEditingController(); // m
  bool? _anschlussJa;
  String _teller = ''; // 'offen' | 'nicht offen'
  bool? _filtersandJa;
  final Set<String> _filtersandEigensch = {};
  final _baujahrCtrl = TextEditingController();

  // Medien + Bemerkung
  final List<String> _fotos = [];
  final List<String> _videos = [];
  final List<String> _audios = [];
  final List<String> _pdfs = [];
  final _bemCtrl = TextEditingController();

  // Display-Reihenfolge (für Bericht)
  final List<String> _displayOrder = [
    'grubentyp',
    'deckel',
    'kl',
    'verfuegbarkeit',
    'statusVorOrt',
    'schaeden',
    'abteilungen',
    'bemerkung',
  ];

  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    _session = await SessionStore.load();
    if (widget.initialMeta != null) _applyInitialMeta(widget.initialMeta!);
    if (mounted) setState(() {});
  }

  void _applyInitialMeta(Map<String, dynamic> meta) {
    _posCtrl.text = (meta['posNr'] as String?) ?? '';
    _idNrCtrl.text = (meta['idNr'] as String?) ?? '';
    _verfuegbarkeit.clear();
    final v = meta['verfuegbarkeit'];
    if (v is List) _verfuegbarkeit.addAll(v.cast<String>());
    if (v is String && v.isNotEmpty)
      _verfuegbarkeit.addAll(v.split(',').map((s) => s.trim()));
    _statusVorOrt.clear();
    final s = meta['statusVorOrt'];
    if (s is List) _statusVorOrt.addAll(s.cast<String>());
    if (s is String && s.isNotEmpty)
      _statusVorOrt.addAll(s.split(',').map((t) => t.trim()));

    _abteilungen.clear();
    final ab = meta['abteilungen'];
    if (ab is List) _abteilungen.addAll(ab.map((e) => e.toString()));
    if (ab is String && ab.isNotEmpty) {
      _abteilungen.addAll(
        ab.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty),
      );
    }
    _syncAbteilungsToggles();

    _grubenart = (meta['grubentyp'] as String?) ?? _grubenart;
    _deckel = normalizeSchachtDeckelart(meta['deckel'], fallback: _deckel);
    _deckelBemCtrl.text =
        (meta['deckelBem'] as String?) ??
        schachtDeckelBemerkung(meta['deckel']);
    _kl = (meta['kl'] as String?) ?? _kl;
    _schaeden.clear();
    final sch = meta['schaeden'];
    if (sch is List) _schaeden.addAll(sch.cast<String>());
    if (sch is String && sch.isNotEmpty)
      _schaeden.addAll(sch.split(',').map((s) => s.trim()));
    _keinBefund = (meta['keinBefund'] == true);
    _applyKlUnterDSchaden();
    _tiefeCtrl.text =
        (meta['tiefe_cm'] as String?) ?? (meta['tiefe_m'] as String?) ?? '';
    _wasserCtrl.text = (meta['wasser_cm'] as String?) ?? '';
    final dynamic anschlussRaw = meta['anschlussJa'] ?? meta['anschluss'];
    _anschlussJa = _parseJaNein(anschlussRaw);
    _teller = (meta['teller'] as String?) ?? _teller;
    if (_anschlussJa == true && _teller.isEmpty) {
      _teller = 'offen';
    }
    _filtersandJa = _parseJaNein(meta['filtersandJa'] ?? meta['filtersand']);
    _filtersandEigensch.clear();
    final fe = meta['filtersandEigensch'];
    if (fe is List) _filtersandEigensch.addAll(fe.cast<String>());
    _baujahrCtrl.text = (meta['baujahr'] as String?) ?? '';
    _fotos.clear();
    _videos.clear();
    _fotos.addAll(
      (meta['mediaFotos'] as List<dynamic>?)?.cast<String>() ?? <String>[],
    );
    _videos.addAll(
      (meta['mediaVideos'] as List<dynamic>?)?.cast<String>() ?? <String>[],
    );
    _audios.clear();
    final audios =
        (meta['mediaAudios'] as List<dynamic>?)?.cast<String>() ?? <String>[];
    _audios.addAll(audios);
    final pdf = meta['mediaPdfs'];
    if (pdf is List) _pdfs.addAll(pdf.cast<String>());
    _bemCtrl.text = (meta['bemerkung'] as String?) ?? '';
  }

  bool get _klUnterD => _kl == 'A' || _kl == 'B' || _kl == 'C';

  void _applyKlUnterDSchaden() {
    if (_klUnterD) {
      _schaeden.add(_klUnterDSchaden);
      _keinBefund = false;
    } else {
      _schaeden.remove(_klUnterDSchaden);
    }
  }

  @override
  void dispose() {
    _posCtrl.dispose();
    _idNrCtrl.dispose();
    _deckelBemCtrl.dispose();
    _tiefeCtrl.dispose();
    _wasserCtrl.dispose();
    _baujahrCtrl.dispose();
    _bemCtrl.dispose();
    super.dispose();
  }

  double? _parseDecimal(String input) {
    final t = input.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  bool? _parseJaNein(dynamic value) {
    if (value is bool) return value;
    final t = (value ?? '').toString().trim().toLowerCase();
    if (t == 'ja' || t == 'yes' || t == 'true' || t == '1') return true;
    if (t == 'nein' || t == 'no' || t == 'false' || t == '0') return false;
    return null;
  }

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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Audio hinzugefügt')));
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
                      recognizedText.isEmpty
                          ? 'Erkannter Text wird hier angezeigt'
                          : recognizedText,
                      style: TextStyle(
                        fontSize: 14,
                        color: recognizedText.isEmpty
                            ? Colors.grey
                            : Colors.black,
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Diktat hinzugefügt')));
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

  Future<void> _onSave() async {
    if (_session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bitte zuerst auf der Startseite EVNr/Straße/Erfasser setzen.',
          ),
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final keinBefundCheck = ValidationService.validateNoKeinBefundMitSchaeden(
      keinBefund: _keinBefund,
      schaeden: _schaeden,
      message: '"Kein Befund" und Schäden schließen sich aus.',
    );
    if (!keinBefundCheck.isValid) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(keinBefundCheck.message!)));
      return;
    }

    // Zahlen prüfen
    final tiefeM = _parseDecimal(_tiefeCtrl.text);
    final wasserCm = _parseDecimal(_wasserCtrl.text);
    if (tiefeM != null && wasserCm != null && wasserCm > tiefeM) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Wasserstand darf nicht größer als Grubentiefe in cm sein.',
          ),
        ),
      );
      return;
    }
    if (_anschlussJa == true && _teller.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte Überlauf: offen/nicht offen angeben.'),
        ),
      );
      return;
    }

    final pos = _posCtrl.text.trim();
    final existingKey = widget.initialMeta != null
        ? widget.initialMeta!['storageKey'] as String?
        : null;
    final uniqueCheck = await ValidationService.validateUniquePosition(
      evnr: _session!.evnr,
      strasse: _session!.strasse,
      posNr: pos,
      excludeStorageKey: existingKey,
    );
    if (!uniqueCheck.isValid) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(uniqueCheck.message!)));
      return;
    }

    final idNr = _idNrCtrl.text.trim();
    final idValidation = ValidationService.validateIdNumberByType(
      idNr,
      typ: 'VG',
      required: false,
    );
    if (idValidation != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(idValidation)));
      return;
    }
    final deckelLabel = buildSchachtDeckelartLabel(
      _deckel,
      _deckelBemCtrl.text,
    );

    // Medien-Notiz
    final hasFotos = _fotos.isNotEmpty;
    final hasVideos = _videos.isNotEmpty;
    final mediaNote = (hasFotos || hasVideos)
        ? '📷 ${_fotos.length}${hasVideos ? ' / 🎥 ${_videos.length}' : ''}'
        : null;

    // Hinweis für Gesamtbericht (Grube-Zusatzdaten werden NICHT als Schaden gewertet)
    const grubeHint = 'Hinweis: Wasserstand und Grubentiefe in cm prüfen';

    final bemerkungText = _bemCtrl.text.trim();
    final bemerkungMeta = [
      if (bemerkungText.isNotEmpty) bemerkungText,
      if (mediaNote != null) mediaNote,
    ].join(' | ');

    // GPS erfassen (einmalig beim Speichern)
    final gps = hasNichtImNis(_verfuegbarkeit)
        ? ((await GpsService.getCurrentLocation()) ??
              widget.initialMeta?['gps'])
        : null;

    final tiefeText = _tiefeCtrl.text.trim();
    final tiefeCm = tiefeText;
    final anschlussText = _anschlussJa == null
        ? ''
        : (_anschlussJa! ? 'Ja' : 'Nein');

    // Persistenz – Meta (für BerichtScreen Detail-Dialog etc.)
    final meta = {
      'typ': 'VG', // kanonischer Typ für Grube
      'evnr': _session!.evnr,
      'strasse': _session!.strasse,
      'erfasser': _session!.erfasser,
      'zeitIso': _session!.zeitIso,
      'wetter': _session!.wetter,
      'temperatur': _session!.temperatur,
      'posNr': pos,
      'idNr': idNr,

      'verfuegbarkeit': _verfuegbarkeit.toList(),
      'statusVorOrt': _statusVorOrt.toList(),
      'abteilungen': _abteilungen.toList(),

      'grubentyp': _grubenart,
      'deckel': deckelLabel,
      'kl': _kl,

      'schaeden': _schaeden.toList(),
      'keinBefund': _keinBefund,

      // Zusatzdaten (nur Steckbrief)
      'tiefe_m': tiefeText,
      'tiefe_cm': tiefeCm,
      'wasser_cm': _wasserCtrl.text.trim(),
      'gesamtHinweis': grubeHint,
      'anschlussJa': _anschlussJa,
      'anschluss': anschlussText,
      'teller': _anschlussJa == true ? _teller : '',
      'filtersandJa': _filtersandJa,
      'filtersandEigensch': _filtersandEigensch.toList(),
      'baujahr': _baujahrCtrl.text.trim(),

      'bemerkung': bemerkungMeta,
      'mediaFotos': _fotos,
      'mediaVideos': _videos,
      'mediaAudios': _audios,
      'mediaPdfs': _pdfs,
      'displayOrder': _displayOrder,

      'createdAt': DateTime.now().toIso8601String(),
      'gps': gps,
    };

    final metaKey =
        existingKey ?? 'obj_${_session!.evnr}_${_session!.strasse}_${pos}_VS';
    if (existingKey != null) {
      meta['createdAt'] = widget.initialMeta!['createdAt'] ?? meta['createdAt'];
    }
    meta['storageKey'] = metaKey;
    await SpeicherService.upsertEntry(metaKey, meta);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Grube erfasst. Dateien werden erst im Bericht-Export erstellt.',
        ),
      ),
    );
    Navigator.pop(context);
  }

  Future<void> _openNisPlan() async {
    final evnr = _session?.evnr ?? '';
    final nis = evnr.trim().isNotEmpty
        ? await SessionStore.loadNisPlanForEvnr(evnr)
        : null;
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
        title: const Text('Beschreibung - Grube (VG)'),
        content: const SingleChildScrollView(
          child: Text(
            'Hier werden Grubenanlagen (VG) erfasst.\n\n'
            'Wichtig:\n'
            '- Pflichtfeld ist die Positionsnummer.\n'
            '- Zustands- und Ausstattungsmerkmale der Grube erfassen.\n'
            '- Optional Medien anhängen.\n\n'
            'Hinweis:\n'
            'Speichern legt die Erfassung ab. Die Dateierstellung erfolgt erst im Bericht beim Export.',
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
        title: const Text('Grube (VG)'),
        centerTitle: true,
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
          ? const Center(
              child: Text(
                'Bitte zuerst auf der Startseite EVNr/Straße/Erfasser setzen.',
              ),
            )
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  // Kopf
                  Card(
                    margin: const EdgeInsets.all(16),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Erfasser Daten',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          _kv('EVNr', s.evnr),
                          _kv('Straße', s.strasse),
                          _kv('Erfasser:in', s.erfasser),
                          _kv(
                            'Datum/Zeit',
                            df.format(
                              DateTime.tryParse(s.zeitIso) ?? DateTime.now(),
                            ),
                          ),
                          _kv('Wetter', _wIcon(s.wetter)),
                          _kv(
                            'Temperatur',
                            formatTemperatureValue(s.temperatur),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ObjectGpsPanel(
                      initialMeta: widget.initialMeta,
                      captureEnabled: hasNichtImNis(_verfuegbarkeit),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Stepper
                  Expanded(
                    child: Stepper(
                      currentStep: _currentStep,
                      onStepTapped: (step) =>
                          setState(() => _currentStep = step),
                      onStepContinue: () {
                        if (_currentStep == 0) {
                          if (!_formKey.currentState!.validate()) return;
                        }
                        if (_currentStep < 4) {
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
                                child: Text(
                                  _currentStep == 4 ? 'Speichern' : 'Weiter',
                                ),
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
                          state: _currentStep > 0
                              ? StepState.complete
                              : StepState.indexed,
                          content: ListView(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              TextFormField(
                                controller: _posCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Positionsnummer *',
                                  border: OutlineInputBorder(),
                                ),
                                validator:
                                    ValidationService.validatePositionField,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _idNrCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'ID-Nummer (optional)',
                                  hintText:
                                      '6-stellig, nur Ziffern (z. B. 123456)',
                                  helperText: 'Optional',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _sectionLabel('Verfügbarkeit'),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: kVerfuegbarkeitOptionsAll
                                    .map(
                                      (opt) => FilterChip(
                                        label: Text(opt),
                                        selected: _verfuegbarkeit.contains(opt),
                                        onSelected: (sel) => setState(() {
                                          if (sel) {
                                            _verfuegbarkeit.add(opt);
                                          } else {
                                            _verfuegbarkeit.remove(opt);
                                            if (opt == 'Ergänzen')
                                              _verfuegbarkeitErgaenzenCtrl
                                                  .clear();
                                          }
                                        }),
                                      ),
                                    )
                                    .toList(),
                              ),
                              if (_verfuegbarkeit.contains('Ergänzen')) ...[
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
                              _sectionLabel('Status vor Ort'),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: kStatusAllgemein
                                    .map(
                                      (opt) => FilterChip(
                                        label: Text(opt),
                                        selected: _statusVorOrt.contains(opt),
                                        onSelected: (sel) => setState(() {
                                          sel
                                              ? _statusVorOrt.add(opt)
                                              : _statusVorOrt.remove(opt);
                                        }),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ),
                        ),

                        // Schritt 2: Grubenart & Deckelart
                        Step(
                          title: const Text('2. Grubenart & Deckelart'),
                          isActive: _currentStep >= 1,
                          state: _currentStep > 1
                              ? StepState.complete
                              : StepState.indexed,
                          content: ListView(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              _sectionLabel('Grubenart'),
                              Wrap(
                                spacing: 8,
                                children: [
                                  ChoiceChip(
                                    label: const Text('Absetzschacht'),
                                    selected: _grubenart == 'Absetzschacht',
                                    onSelected: (_) => setState(
                                      () => _grubenart = 'Absetzschacht',
                                    ),
                                  ),
                                  ChoiceChip(
                                    label: const Text('Sickerschacht'),
                                    selected: _grubenart == 'Sickerschacht',
                                    onSelected: (_) => setState(
                                      () => _grubenart = 'Sickerschacht',
                                    ),
                                  ),
                                  ChoiceChip(
                                    label: const Text('KB-Schacht'),
                                    selected: _grubenart == 'KB-Schacht',
                                    onSelected: (_) => setState(
                                      () => _grubenart = 'KB-Schacht',
                                    ),
                                  ),
                                  ChoiceChip(
                                    label: const Text('DIN'),
                                    selected: _grubenart == 'DIN',
                                    onSelected: (_) =>
                                        setState(() => _grubenart = 'DIN'),
                                  ),
                                  ChoiceChip(
                                    label: const Text('Gemauert'),
                                    selected: _grubenart == 'Gemauert',
                                    onSelected: (_) =>
                                        setState(() => _grubenart = 'Gemauert'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              _sectionLabel('Deckelart'),
                              DropdownButtonFormField<String>(
                                initialValue: _deckel,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                ),
                                items: kSchachtDeckelartOptions
                                    .map(
                                      (d) => DropdownMenuItem(
                                        value: d,
                                        child: Text(
                                          d == 'Bemerkung'
                                              ? 'Bemerkung (andere Hersteller)'
                                              : d,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) => setState(
                                  () =>
                                      _deckel = v ?? kStandardSchachtDeckelart,
                                ),
                              ),
                              if (_deckel == 'Bemerkung') ...[
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _deckelBemCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Deckelbemerkung',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                              _sectionLabel('KL-Klasse'),
                              Wrap(
                                spacing: 8,
                                children: ['A', 'B', 'C', 'D', 'E', 'F']
                                    .map(
                                      (k) => ChoiceChip(
                                        label: Text('KL $k'),
                                        selected: _kl == k,
                                        onSelected: (_) => setState(() {
                                          _kl = k;
                                          _applyKlUnterDSchaden();
                                        }),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ),
                        ),

                        // Schritt 3: Schäden & Abteilung
                        Step(
                          title: const Text('3. Schäden & Abteilung'),
                          isActive: _currentStep >= 2,
                          state: _currentStep > 2
                              ? StepState.complete
                              : StepState.indexed,
                          content: ListView(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              _sectionLabel('Schadstellen'),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children:
                                    [
                                      'Schacht locker',
                                      'Ausgleichsringe beschädigt',
                                      'Versottet',
                                      _klUnterDSchaden,
                                    ].map((name) {
                                      final selected = _schaeden.contains(name);
                                      final isKlUnterD =
                                          name == _klUnterDSchaden && _klUnterD;
                                      return FilterChip(
                                        label: Text(name),
                                        selected: selected,
                                        onSelected: (_keinBefund || isKlUnterD)
                                            ? null
                                            : (v) => setState(() {
                                                v
                                                    ? _schaeden.add(name)
                                                    : _schaeden.remove(name);
                                              }),
                                      );
                                    }).toList(),
                              ),
                              const SizedBox(height: 12),
                              FilterChip(
                                label: const Text('🔍 Kein Befund'),
                                selected: _keinBefund,
                                onSelected: (val) {
                                  if (val && _klUnterD) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'KL unter D gilt als Schaden – "Kein Befund" nicht möglich.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  setState(() {
                                    _keinBefund = val;
                                    if (_keinBefund) _schaeden.clear();
                                  });
                                },
                              ),
                              const SizedBox(height: 20),
                              _sectionLabel('Abteilungen'),
                              Row(
                                children: [
                                  ElevatedButton(
                                    onPressed: _toggle312,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _show312
                                          ? Colors.blue
                                          : null,
                                    ),
                                    child: const Text('312'),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: _toggle313,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _show313
                                          ? Colors.blue
                                          : null,
                                    ),
                                    child: const Text('313'),
                                  ),
                                ],
                              ),
                              if (_show312)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Wrap(
                                    spacing: 8,
                                    children: [
                                      FilterChip(
                                        label: const Text('312 IZ AR'),
                                        selected: _abteilungen.contains(
                                          '312 IZ AR',
                                        ),
                                        onSelected: (v) => setState(() {
                                          v
                                              ? _abteilungen.add('312 IZ AR')
                                              : _abteilungen.remove(
                                                  '312 IZ AR',
                                                );
                                        }),
                                      ),
                                      FilterChip(
                                        label: const Text('312 Ost'),
                                        selected: _abteilungen.contains(
                                          '312 Ost',
                                        ),
                                        onSelected: (v) => setState(() {
                                          v
                                              ? _abteilungen.add('312 Ost')
                                              : _abteilungen.remove('312 Ost');
                                        }),
                                      ),
                                      FilterChip(
                                        label: const Text('312 Service'),
                                        selected: _abteilungen.contains(
                                          '312 Service',
                                        ),
                                        onSelected: (v) => setState(() {
                                          v
                                              ? _abteilungen.add('312 Service')
                                              : _abteilungen.remove(
                                                  '312 Service',
                                                );
                                        }),
                                      ),
                                      FilterChip(
                                        label: const Text('312 West'),
                                        selected: _abteilungen.contains(
                                          '312 West',
                                        ),
                                        onSelected: (v) => setState(() {
                                          v
                                              ? _abteilungen.add('312 West')
                                              : _abteilungen.remove('312 West');
                                        }),
                                      ),
                                    ],
                                  ),
                                ),
                              if (_show313)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Wrap(
                                    spacing: 8,
                                    children: [
                                      FilterChip(
                                        label: const Text('313 TU'),
                                        selected: _abteilungen.contains(
                                          '313 TU',
                                        ),
                                        onSelected: (v) => setState(() {
                                          v
                                              ? _abteilungen.add('313 TU')
                                              : _abteilungen.remove('313 TU');
                                        }),
                                      ),
                                      FilterChip(
                                        label: const Text('313 BU'),
                                        selected: _abteilungen.contains(
                                          '313 BU',
                                        ),
                                        onSelected: (v) => setState(() {
                                          v
                                              ? _abteilungen.add('313 BU')
                                              : _abteilungen.remove('313 BU');
                                        }),
                                      ),
                                      FilterChip(
                                        label: const Text('313 BauKo'),
                                        selected: _abteilungen.contains(
                                          '313 BauKo',
                                        ),
                                        onSelected: (v) => setState(() {
                                          v
                                              ? _abteilungen.add('313 BauKo')
                                              : _abteilungen.remove(
                                                  '313 BauKo',
                                                );
                                        }),
                                      ),
                                    ],
                                  ),
                                ),
                              // ...entfernt: doppelte Abteilungs-Buttons...
                            ],
                          ),
                        ),

                        // Schritt 4: Grubendaten & Anschluss
                        Step(
                          title: const Text('4. Grubendaten & Anschluss'),
                          isActive: _currentStep >= 3,
                          state: _currentStep > 3
                              ? StepState.complete
                              : StepState.indexed,
                          content: ListView(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              _sectionLabel('Abmessungen'),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _tiefeCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Tiefe (cm)',
                                        hintText: 'z. B. 200 cm',
                                        suffixText: 'cm',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _wasserCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Wasserstand (cm)',
                                        hintText: 'z. B. 50 cm',
                                        suffixText: 'cm',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              _sectionLabel('Anschluss am Kanal'),
                              SegmentedButton<bool>(
                                segments: const [
                                  ButtonSegment(
                                    value: false,
                                    label: Text('Nein'),
                                  ),
                                  ButtonSegment(value: true, label: Text('Ja')),
                                ],
                                selected: _anschlussJa != null
                                    ? <bool>{_anschlussJa!}
                                    : <bool>{},
                                emptySelectionAllowed: true,
                                onSelectionChanged: (s) => setState(() {
                                  _anschlussJa = s.isNotEmpty ? s.first : null;
                                  if (_anschlussJa == true && _teller.isEmpty) {
                                    _teller = 'offen';
                                  }
                                  if (_anschlussJa == false) _teller = '';
                                }),
                              ),
                              if (_anschlussJa == true) ...[
                                const SizedBox(height: 20),
                                _sectionLabel('Überlauf'),
                                SegmentedButton<String>(
                                  segments: const [
                                    ButtonSegment(
                                      value: 'offen',
                                      label: Text('offen'),
                                    ),
                                    ButtonSegment(
                                      value: 'nicht offen',
                                      label: Text('nicht offen'),
                                    ),
                                  ],
                                  selected: <String>{
                                    _teller.isEmpty ? 'offen' : _teller,
                                  },
                                  onSelectionChanged: (s) =>
                                      setState(() => _teller = s.first),
                                ),
                              ],
                              const SizedBox(height: 20),
                              _sectionLabel('Filtersand'),
                              SegmentedButton<bool>(
                                segments: const [
                                  ButtonSegment(
                                    value: false,
                                    label: Text('Nein'),
                                  ),
                                  ButtonSegment(value: true, label: Text('Ja')),
                                ],
                                selected: _filtersandJa != null
                                    ? <bool>{_filtersandJa!}
                                    : <bool>{},
                                emptySelectionAllowed: true,
                                onSelectionChanged: (s) => setState(() {
                                  _filtersandJa = s.isNotEmpty ? s.first : null;
                                  if (_filtersandJa == false)
                                    _filtersandEigensch.clear();
                                }),
                              ),
                              if (_filtersandJa == true) ...[
                                const SizedBox(height: 12),
                                _sectionLabel('Eigenschaften Filtersand'),
                                Wrap(
                                  spacing: 8,
                                  children:
                                      [
                                            'locker',
                                            'sickerfähig',
                                            'fest',
                                            'lehmig',
                                          ]
                                          .map(
                                            (opt) => FilterChip(
                                              label: Text(opt),
                                              selected: _filtersandEigensch
                                                  .contains(opt),
                                              onSelected: (sel) => setState(
                                                () => sel
                                                    ? _filtersandEigensch.add(
                                                        opt,
                                                      )
                                                    : _filtersandEigensch
                                                          .remove(opt),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                ),
                              ],
                              const SizedBox(height: 20),
                              _sectionLabel('Baujahr'),
                              TextField(
                                controller: _baujahrCtrl,
                                decoration: const InputDecoration(
                                  hintText: 'wenn bekannt',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ],
                          ),
                        ),

                        // Schritt 5: Speichern
                        Step(
                          title: const Text('5. Speichern'),
                          isActive: _currentStep >= 4,
                          state: StepState.indexed,
                          content: ListView(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              _sectionLabel('Bemerkung'),
                              TextFormField(
                                controller: _bemCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Zusätzliche Bemerkung (optional)',
                                  border: OutlineInputBorder(),
                                ),
                                minLines: 3,
                                maxLines: 5,
                              ),
                              const SizedBox(height: 20),
                              _sectionLabel('Medien'),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: _pickMedia,
                                    icon: const Icon(Icons.image, size: 20),
                                    label: const Text('Medien'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: _pickAudio,
                                    icon: const Icon(Icons.mic, size: 20),
                                    label: const Text('Audio'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: _pickFolder,
                                    icon: const Icon(
                                      Icons.folder_open,
                                      size: 20,
                                    ),
                                    label: const Text('PDF'),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: Colors.blue.withValues(
                                        alpha: 0.1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Chip(
                                label: Text(
                                  '📷 ${_fotos.length}   🎥 ${_videos.length}   🎤 ${_audios.length}   📄 ${_pdfs.length}',
                                ),
                              ),
                              const SizedBox(height: 30),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _sectionLabel(String text) => SectionLabel(text);

  Widget _kv(String key, String val) => KvRow(label: key, value: val);
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
