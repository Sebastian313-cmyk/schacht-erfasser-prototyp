
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/session_store.dart';
// entfernt: ungenutzter PDF-Import
import '../services/repository.dart';
import '../models/base_entry.dart';
import '../models/enums.dart';
import '../constants/options.dart';
import '../services/speicher_service.dart';
import '../services/validation_service.dart';
import '../services/gps_service.dart';
import '../services/media_picker_service.dart';
import '../services/audio_service.dart';
import '../services/speech_service.dart';
import '../widgets/nis_plan_viewer_dialog.dart';
import '../widgets/form_ui.dart';
// entfernt: ungenutzter ExportService-Import

class SchieberScreen extends StatefulWidget {
  final Map<String, dynamic>? existingMeta;
  final String? storageKey;

  const SchieberScreen({super.key, this.existingMeta, this.storageKey});
  @override
  State<SchieberScreen> createState() => _SchieberScreenState();
}

class _SchieberScreenState extends State<SchieberScreen> {
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
  // Kopf/Session
  SessionData? _session;

  bool get _isEdit {
    final key = widget.storageKey ?? widget.existingMeta?['storageKey'] as String?;
    return widget.existingMeta != null && (key ?? '').isNotEmpty;
  }

  // Pflicht
  final _posCtrl = TextEditingController();
  final _idNrCtrl = TextEditingController();

  // Schäden
  bool _austausch = false;
  bool _keinBefund = false;

  // Verfügbarkeit & Status
  final Set<String> _verfuegbarkeit = <String>{}; // Mehrfachauswahl
  final Set<String> _statusVorOrt = <String>{}; // Mehrfachauswahl
  final _verfuegbarkeitErgaenzenCtrl = TextEditingController();

  // Abteilungen (Marker)
  // Nur für 312/313-Logik: aktuelle Abteilungs-Auswahl
  final Set<String> _abteilungen = <String>{};

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
    'schaeden',
    'abteilungen',
    'bemerkung',
  ];

  final _formKey = GlobalKey<FormState>();

  // Stepper state
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    _session = await SessionStore.load();
    if (widget.existingMeta != null) _applyExistingMeta(widget.existingMeta!);
    if (mounted) setState(() {});
  }

  void _applyExistingMeta(Map<String, dynamic> m) {
    _posCtrl.text = (m['posNr'] ?? '').toString();
    _idNrCtrl.text = (m['idNr'] ?? '').toString();

    _austausch = (m['austauschErforderlich'] == true);
    _keinBefund = (m['keinBefund'] == true);

    _verfuegbarkeit
      ..clear()
      ..addAll(_splitSet(m['verfuegbarkeit']));
    _statusVorOrt
      ..clear()
      ..addAll(_splitSet(m['statusVorOrt']));

    _abteilungen
      ..clear()
      ..addAll(_splitSet(m['abteilungen']));
    _syncAbteilungsToggles();

    _bemCtrl.text = (m['bemerkung'] ?? '').toString();

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

  @override
  void dispose() {
    _posCtrl.dispose();
    _idNrCtrl.dispose();
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

  // ----------------------------- Save -----------------------------
  Future<void> _onSave() async {
    if (_session == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Bitte zuerst auf der Startseite EVNr/Straße/Erfasser setzen.')));
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    // Exklusivität: Kein Befund ↔ Schaden (Austausch)
    if (_austausch && _keinBefund) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('"Austausch erforderlich" und "Kein Befund" schließen sich aus.')));
      return;
    }

    final pos = _posCtrl.text.trim();
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

    // Einheitlich: Medien-Hinweis in Bemerkung automatisch ergänzen
    var bemerkung = _bemCtrl.text.trim();
    if (_fotos.isNotEmpty || _videos.isNotEmpty) {
      final mv = '📷 ${_fotos.length}${_videos.isNotEmpty ? ' / 🎥 ${_videos.length}' : ''}';
      bemerkung = bemerkung.isEmpty ? mv : '$bemerkung | $mv';
    }

    // GPS erfassen (einmalig beim Speichern)
    final gps = await GpsService.getCurrentLocation();

    // Persistenz
    final idNr = _idNrCtrl.text.trim();
    final idValidation = ValidationService.validateIdNumberByType(
      idNr,
      typ: 'SK',
      required: false,
    );
    if (idValidation != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(idValidation)),
      );
      return;
    }
    final meta = {
      'typ': 'SK',
      'evnr': _session!.evnr,
      'strasse': _session!.strasse,
      'erfasser': _session!.erfasser,
      'zeitIso': _session!.zeitIso,
      'wetter': _session!.wetter,
      'posNr': pos,
      'idNr': idNr,
      'verfuegbarkeit': _verfuegbarkeit.toList(),
      'statusVorOrt': _statusVorOrt.toList(),
      'austauschErforderlich': _austausch,
      'keinBefund': _keinBefund,
      // Für Bericht/Export einheitlich als „Schäden“ ablegen
      'schaeden': _keinBefund
          ? <String>[]
          : (_austausch ? <String>['Austausch erforderlich'] : <String>[]),
      'abteilungen': _abteilungen.toList(),
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
        : 'obj_${_session!.evnr}_${_session!.strasse}_${pos}_SK';
    if (_isEdit) {
      meta['createdAt'] = widget.existingMeta?['createdAt'] ?? meta['createdAt'];
    }
    meta['storageKey'] = metaKey;
    await SpeicherService.upsertEntry(metaKey, meta);

    // Zusätzlich: Eintrag im Repository für Bericht/Export ablegen
    try {
      final schadenLabel = _keinBefund
          ? 'Kein Befund'
          : (_austausch ? 'Austausch erforderlich' : null);
      final entry = BaseEntry(
        id: Repository.instance.newId(),
        type: EntryType.schieberkappe,
        evnr: _session!.evnr,
        positionsnummer: pos,
        titel: schadenLabel ?? '—',
        zeit: DateTime.now(),
        strasse: _session!.strasse,
        bemerkung: bemerkung.isEmpty ? null : bemerkung,
        verfuegbarkeitLabel: _verfuegbarkeit.isEmpty ? null : _verfuegbarkeit.join(', '),
        statusVorOrtLabel: _statusVorOrt.isEmpty ? null : _statusVorOrt.join(', '),
        notizen: null,
        spezial: null,
      );
      await Repository.instance.add(entry);
    } catch (_) {}

    // PDF
    final df = DateFormat('dd.MM.yyyy HH:mm');
    String schaden = '—';
    if (_keinBefund) schaden = 'Kein Befund';
    if (_austausch && !_keinBefund) schaden = 'Austausch erforderlich';

    // entfällt: ungenutzte lokale Variable
    final _ = <String, String>{
      'EVNr': _session!.evnr,
      'Straße': _session!.strasse,
      'Erfasser:in': _session!.erfasser,
      'Datum/Zeit': df.format(DateTime.tryParse(_session!.zeitIso) ?? DateTime.now()),
      'Wetter': _session!.wetter,
      'Positionsnummer': pos,
      if (idNr.isNotEmpty) 'ID-Nummer': idNr,
      if (_verfuegbarkeit.isNotEmpty) 'Verfügbarkeit': _verfuegbarkeit.join(', '),
      if (_statusVorOrt.isNotEmpty) 'Status vor Ort': _statusVorOrt.join(', '),
      'Schaden': schaden,
      'Bemerkung': bemerkung.isEmpty ? '—' : bemerkung,
    };

    final notes = <String>[];
    if (_fotos.isNotEmpty) notes.add('Fotos: ${_fotos.length}');
    if (_videos.isNotEmpty) notes.add('Videos: ${_videos.length}');
    // Meta-first export
    // final theme = await ExportService.getTheme();
    // await PdfMiniKit.skSteckbrief(fields: felder, notes: notes, theme: theme);
    // Entfernt: Einzel-Steckbrief Download für Schieberkappe.
    // final safeEv = _session!.evnr.replaceAll('/', '-');
    // final safePos = pos.replaceAll('/', '-');
    // downloadBytesWeb(pdf, 'ErfasserApp_Schieber_Steckbrief.pdf');

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Schieberkappe gespeichert (im Gesamt-Export enthalten).')),
    );
    Navigator.pop(context);
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
        title: const Text('Beschreibung - Schieberkappen (SK)'),
        content: const SingleChildScrollView(
          child: Text(
            'Dieses Modul erfasst Schieberkappen (SK).\n\n'
            'Wichtig:\n'
            '- Pflichtfeld ist die Positionsnummer.\n'
            '- Bauart, Zustand und ergänzende Angaben erfassen.\n'
            '- Medien können optional hinzugefügt werden.\n\n'
            'Hinweis:\n'
            'Die Daten werden gespeichert, die Dateierstellung erfolgt erst im Bericht beim Export.'
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
        title: const Text('Schieberkappen (SK)'),
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
              child: Column(
                children: [
                  // Kopf
                  Card(
                    margin: const EdgeInsets.all(16),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('SK – Kopf', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 6),
                        _kv('EVNr', s.evnr),
                        _kv('Straße', s.strasse),
                        _kv('Erfasser:in', s.erfasser),
                        _kv('Datum/Zeit', df.format(DateTime.tryParse(s.zeitIso) ?? DateTime.now())),
                        _kv('Wetter', _wIcon(s.wetter)),
                      ]),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ObjectGpsPanel(initialMeta: widget.existingMeta),
                  ),
                  const SizedBox(height: 12),

                  // Stepper
                  Expanded(
                    child: Stepper(
                      type: StepperType.vertical,
                      currentStep: _currentStep,
                      onStepContinue: () {
                        if (_currentStep == 0) {
                          if (!_formKey.currentState!.validate()) {
                            return;
                          }
                        }
                        if (_currentStep < 2) {
                          setState(() => _currentStep++);
                        } else {
                          _onSave();
                        }
                      },
                      onStepCancel: () {
                        if (_currentStep > 0) {
                          setState(() => _currentStep--);
                        }
                      },
                      onStepTapped: (step) => setState(() => _currentStep = step),
                      controlsBuilder: (context, details) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Row(
                            children: [
                              FilledButton(
                                onPressed: details.onStepContinue,
                                child: Text(_currentStep == 2 ? 'Speichern' : 'Weiter'),
                              ),
                              const SizedBox(width: 12),
                              if (_currentStep > 0)
                                TextButton(
                                  onPressed: details.onStepCancel,
                                  child: const Text('Zurück'),
                                ),
                            ],
                          ),
                        );
                      },
                      steps: [
                        // ============ SCHRITT 0: BASISDATEN ============
                        Step(
                          title: const Text('Basisdaten'),
                          isActive: _currentStep >= 0,
                          state: _currentStep > 0 ? StepState.complete : StepState.indexed,
                          content: ListView(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [

                  // PosNr
                  _label('Positionsnummer *'),
                  TextFormField(
                    controller: _posCtrl,
                    decoration: const InputDecoration(hintText: 'z. B. 1, 1a, 2'),
                    validator: ValidationService.validatePositionField,
                  ),

                  const SizedBox(height: 12),
                  _label('ID-Nummer (optional)'),
                  TextField(
                    controller: _idNrCtrl,
                    decoration: const InputDecoration(
                      hintText: '4-stellig, nur Ziffern (z. B. 1234)',
                      helperText: 'Optional',
                    ),
                  ),

                  const SizedBox(height: 16),
                  _sectionLabel('Verfügbarkeit'),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: kVerfuegbarkeitOptionsAll.map((opt) => FilterChip(
                          label: Text(opt),
                          selected: _verfuegbarkeit.contains(opt),
                          onSelected: (v) => setState(() {
                            if (v) {
                              _verfuegbarkeit.add(opt);
                            } else {
                              _verfuegbarkeit.remove(opt);
                              if (opt == 'Ergänzen') _verfuegbarkeitErgaenzenCtrl.clear();
                            }
                          }),
                        )).toList(),
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

                  const SizedBox(height: 12),
                  _sectionLabel('Status vor Ort'),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: kStatusAllgemein.map((opt) => FilterChip(
                          label: Text(opt),
                          selected: _statusVorOrt.contains(opt),
                          onSelected: (v) => setState(() {
                            if (v) {
                              _statusVorOrt.add(opt);
                            } else {
                              _statusVorOrt.remove(opt);
                            }
                          }),
                        )).toList(),
                  ),
                            ],
                          ),
                        ),

                        // ============ SCHRITT 1: SCHÄDEN/ABTEILUNG ============
                        Step(
                          title: const Text('Schäden/Abteilung'),
                          isActive: _currentStep >= 1,
                          state: _currentStep > 1 ? StepState.complete : StepState.indexed,
                          content: ListView(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              _sectionLabel('Schäden'),
                              Wrap(spacing: 8, children: [
                                ChoiceChip(
                                  label: const Text('Austausch erforderlich'),
                                  selected: _austausch,
                                  onSelected: (v) => setState(() {
                                    _austausch = v;
                                    if (v) _keinBefund = false;
                                  }),
                                ),
                                ChoiceChip(
                                  label: Text('Kein Befund', style: TextStyle(color: _keinBefund ? Colors.green : null)),
                                  selected: _keinBefund,
                                  onSelected: (v) => setState(() {
                                    _keinBefund = v;
                                    if (v) _austausch = false;
                                  }),
                                ),
                              ]),

                              const SizedBox(height: 16),
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
                            ],
                          ),
                        ),

                        // ============ SCHRITT 2: SPEICHERN ============
                        Step(
                          title: const Text('Speichern'),
                          isActive: _currentStep >= 2,
                          state: _currentStep == 2 ? StepState.indexed : StepState.indexed,
                          content: ListView(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [

                              TextField(
                                controller: _bemCtrl,
                                maxLines: 2,
                                decoration: const InputDecoration(labelText: 'Bemerkung (optional)'),
                              ),

                              const SizedBox(height: 16),
                              _sectionLabel('Medien'),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                      onPressed: _pickMedia,
                                      icon: const Icon(Icons.image),
                                      label: const Text('Medien')),
                                  OutlinedButton.icon(
                                      onPressed: _pickAudio,
                                      icon: const Icon(Icons.mic),
                                      label: const Text('Audio')),
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
                              Text('📷 ${_fotos.length}   🎥 ${_videos.length}   🎤 ${_audios.length}   📄 ${_pdfs.length}'),
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

  // ----------------------------- Small UI helpers -----------------------------
  Widget _label(String t) => FieldLabel(t);

  Widget _sectionLabel(String text) => SectionLabel(text);

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

// ============================ pdf_mini_kit.dart PATCH ============================
/*
// Füge in lib/pdf_mini_kit.dart hinzu (falls nicht vorhanden):

  static Future<Uint8List> skSteckbrief({
    required Map<String, String> fields,
    List<String>? notes,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('SK – Schieberkappen – Steckbrief',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            _table(fields),
            if (notes != null && notes.isNotEmpty) _notes(notes),
          ],
        ),
      ),
    );
    return doc.save();
  }
*/
