import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/session_store.dart';
import '../constants/options.dart';
import '../services/repository.dart';
import '../models/base_entry.dart';
import '../models/enums.dart';
import '../services/speicher_service.dart';
import '../services/validation_service.dart';
import '../services/media_picker_service.dart';
import '../services/audio_service.dart';
import '../services/gps_service.dart';
import '../services/speech_service.dart';
import '../widgets/nis_plan_viewer_dialog.dart';
import '../widgets/form_ui.dart';

class KanalScreen extends StatefulWidget {
  final Map<String, dynamic>? existingMeta;
  final String? storageKey;

  const KanalScreen({super.key, this.existingMeta, this.storageKey});
  @override
  State<KanalScreen> createState() => _KanalScreenState();
}

class _KanalScreenState extends State<KanalScreen> {
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

  bool get _isEdit {
    final key =
        widget.storageKey ?? widget.existingMeta?['storageKey'] as String?;
    return widget.existingMeta != null && (key ?? '').isNotEmpty;
  }

  // Pflichtfelder
  final _posCtrl = TextEditingController();
  final _idNrCtrl = TextEditingController();
  final _kanalprofilCtrl = TextEditingController();

  // Verfügbarkeit
  final Set<String> _verfuegbarkeit = <String>{};
  final _verfuegbarkeitErgaenzenCtrl = TextEditingController();
  // Schäden
  final Set<String> _schaeden = <String>{};
  bool _keinBefund = false;
  bool _schadenActive = false;
  final _schadensdetailsCtrl = TextEditingController();

  // Bemerkung
  final _bemCtrl = TextEditingController();

  // Abteilungen
  final Set<String> _abteilungen = <String>{};

  // Medien
  final List<String> _fotos = [];
  final List<String> _videos = [];
  final List<String> _audios = [];
  final List<String> _pdfs = [];

  // Display-Reihenfolge (für Bericht)
  final List<String> _displayOrder = [
    'idNr',
    'kanalprofil',
    'verfuegbarkeit',
    'keinBefund',
    'schaeden',
    'schadensdetails',
    'abteilungen',
    'bemerkung',
  ];

  final _formKey = GlobalKey<FormState>();

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
    _kanalprofilCtrl.text = (m['kanalprofil'] ?? '').toString();

    _verfuegbarkeit
      ..clear()
      ..addAll(_splitSet(m['verfuegbarkeit']));

    _keinBefund = (m['keinBefund'] == true);
    _schadenActive = (m['schadensdetails'] ?? '').toString().isNotEmpty;
    _schadensdetailsCtrl.text = (m['schadensdetails'] ?? '').toString();
    _bemCtrl.text = (m['bemerkung'] ?? '').toString();

    final sch = m['schaeden'];
    _schaeden.clear();
    if (sch is List) _schaeden.addAll(sch.cast<String>());
    if (sch is String && sch.isNotEmpty)
      _schaeden.addAll(sch.split(',').map((s) => s.trim()));

    final abt = m['abteilungen'];
    _abteilungen.clear();
    if (abt is List) _abteilungen.addAll(abt.cast<String>());
    if (abt is String && abt.isNotEmpty)
      _abteilungen.addAll(abt.split(',').map((s) => s.trim()));
    _syncAbteilungsToggles();

    final fot = m['mediaFotos'];
    if (fot is List) _fotos.addAll(fot.cast<String>());
    final vid = m['mediaVideos'];
    if (vid is List) _videos.addAll(vid.cast<String>());
    final aud = m['mediaAudios'];
    if (aud is List) _audios.addAll(aud.cast<String>());
    final pdf = m['mediaPdfs'];
    if (pdf is List) _pdfs.addAll(pdf.cast<String>());
  }

  Set<String> _splitSet(dynamic value) {
    if (value is Iterable) {
      return value
          .map((entry) => entry.toString().trim())
          .where((entry) => entry.isNotEmpty)
          .toSet();
    }
    final text = (value ?? '').toString().trim();
    if (text.isEmpty) return <String>{};
    return text
        .split(',')
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toSet();
  }

  @override
  void dispose() {
    _posCtrl.dispose();
    _idNrCtrl.dispose();
    _kanalprofilCtrl.dispose();
    _verfuegbarkeitErgaenzenCtrl.dispose();
    _schadensdetailsCtrl.dispose();
    _bemCtrl.dispose();
    super.dispose();
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
    if (!_formKey.currentState!.validate()) return;
    if (_session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Keine Session. Bitte auf Startseite EVNr/Straße setzen.',
          ),
        ),
      );
      return;
    }

    final pos = _posCtrl.text.trim();
    final existingKey =
        widget.storageKey ?? widget.existingMeta?['storageKey'] as String?;
    final uniqueCheck = await ValidationService.validateUniquePosition(
      evnr: _session!.evnr,
      strasse: _session!.strasse,
      posNr: pos,
      excludeStorageKey: _isEdit ? existingKey : null,
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
      typ: 'KANAL',
      required: false,
    );
    if (idValidation != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(idValidation)));
      return;
    }

    final gps = hasNichtImNis(_verfuegbarkeit)
        ? ((await GpsService.getCurrentLocation()) ??
              widget.existingMeta?['gps'])
        : null;

    // Persistenz
    final meta = {
      'typ': 'KANAL',
      'evnr': _session!.evnr,
      'strasse': _session!.strasse,
      'erfasser': _session!.erfasser,
      'zeitIso': _session!.zeitIso,
      'wetter': _session!.wetter,
      'temperatur': _session!.temperatur,
      'posNr': pos,
      'idNr': idNr,
      'kanalprofil': _kanalprofilCtrl.text.trim(),
      'verfuegbarkeit': _verfuegbarkeit.toList(),
      'keinBefund': _keinBefund,
      'schaeden': _schaeden.toList(),
      'schadensdetails': _schadensdetailsCtrl.text.trim(),
      'abteilungen': _abteilungen.toList(),
      'bemerkung': _bemCtrl.text.trim(),
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
        : 'obj_${_session!.evnr}_${_session!.strasse}_${pos}_KANAL';
    if (_isEdit) {
      meta['createdAt'] =
          widget.existingMeta?['createdAt'] ?? meta['createdAt'];
    }
    meta['storageKey'] = metaKey;
    await SpeicherService.upsertEntry(metaKey, meta);

    // Repository-Eintrag
    try {
      final entry = BaseEntry(
        id: Repository.instance.newId(),
        type: EntryType.kanal,
        evnr: _session!.evnr,
        positionsnummer: pos,
        titel: 'Kanal – ${_idNrCtrl.text.trim()}',
        zeit: DateTime.now(),
        strasse: _session!.strasse,
        bemerkung: _bemCtrl.text.trim().isEmpty ? null : _bemCtrl.text.trim(),
        verfuegbarkeitLabel: _verfuegbarkeit.isEmpty
            ? null
            : _verfuegbarkeit.join(', '),
        statusVorOrtLabel: null,
        notizen: _kanalprofilCtrl.text.trim(),
        spezial: null,
      );
      await Repository.instance.add(entry);
    } catch (_) {}

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Kanal gespeichert.')));
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
        title: const Text('Beschreibung - Kanal'),
        content: const SingleChildScrollView(
          child: Text(
            'Hier werden Kanalobjekte erfasst.\n\n'
            'Wichtig:\n'
            '- Pflichtfeld ist die Positionsnummer.\n'
            '- Kanalprofil, Zustandsangaben und Bemerkungen erfassen.\n'
            '- Medien können bei Bedarf ergänzt werden.\n\n'
            'Hinweis:\n'
            'Gespeichert wird direkt in der App, exportiert wird gesammelt im Bericht.',
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
        title: const Text('Kanal'),
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
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Kopf
                  Card(
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
                  const SizedBox(height: 12),
                  ObjectGpsPanel(
                    initialMeta: widget.existingMeta,
                    captureEnabled: hasNichtImNis(_verfuegbarkeit),
                  ),
                  const SizedBox(height: 12),

                  // Pflichtfelder
                  _label('Positionsnummer *'),
                  TextFormField(
                    controller: _posCtrl,
                    decoration: const InputDecoration(
                      hintText: 'z. B. 1, 1a, 2',
                    ),
                    validator: ValidationService.validatePositionField,
                  ),

                  const SizedBox(height: 12),
                  _label('ID-Nummer (optional)'),
                  TextField(
                    controller: _idNrCtrl,
                    decoration: const InputDecoration(
                      hintText: '6-stellig, nur Ziffern (z. B. 123456)',
                      helperText: 'Optional',
                    ),
                  ),

                  const SizedBox(height: 12),
                  _label('Kanalprofil'),
                  TextField(
                    controller: _kanalprofilCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(hintText: 'optional'),
                  ),

                  const SizedBox(height: 16),
                  _sectionLabel('Verfügbarkeit'),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: kVerfuegbarkeitOptionsAll.map((opt) {
                      return FilterChip(
                        label: Text(opt),
                        selected: _verfuegbarkeit.contains(opt),
                        onSelected: (v) {
                          setState(() {
                            if (v) {
                              _verfuegbarkeit.add(opt);
                            } else {
                              _verfuegbarkeit.remove(opt);
                              if (opt == 'Ergänzen') {
                                _verfuegbarkeitErgaenzenCtrl.clear();
                              }
                            }
                          });
                        },
                      );
                    }).toList(),
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
                  _sectionLabel('Schäden'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => setState(() {
                            _keinBefund = false;
                            _schadenActive = true;
                          }),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _schadenActive ? Colors.red : null,
                          ),
                          icon: const Icon(Icons.warning_outlined),
                          label: const Text('Schäden'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => setState(() {
                            _keinBefund = true;
                            _schadenActive = false;
                            _schadensdetailsCtrl.clear();
                          }),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _keinBefund ? Colors.green : null,
                          ),
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Kein Befund'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_schadenActive)
                    TextField(
                      controller: _schadensdetailsCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Schadensdetails',
                        hintText: 'Beschreiben Sie die Schäden',
                        border: OutlineInputBorder(),
                      ),
                    ),

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
                              v
                                  ? _abteilungen.add('312 IZ AR')
                                  : _abteilungen.remove('312 IZ AR');
                            }),
                          ),
                          FilterChip(
                            label: const Text('312 Ost'),
                            selected: _abteilungen.contains('312 Ost'),
                            onSelected: (v) => setState(() {
                              v
                                  ? _abteilungen.add('312 Ost')
                                  : _abteilungen.remove('312 Ost');
                            }),
                          ),
                          FilterChip(
                            label: const Text('312 Service'),
                            selected: _abteilungen.contains('312 Service'),
                            onSelected: (v) => setState(() {
                              v
                                  ? _abteilungen.add('312 Service')
                                  : _abteilungen.remove('312 Service');
                            }),
                          ),
                          FilterChip(
                            label: const Text('312 West'),
                            selected: _abteilungen.contains('312 West'),
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
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Wrap(
                        spacing: 8,
                        children: [
                          FilterChip(
                            label: const Text('313 TU'),
                            selected: _abteilungen.contains('313 TU'),
                            onSelected: (v) => setState(() {
                              v
                                  ? _abteilungen.add('313 TU')
                                  : _abteilungen.remove('313 TU');
                            }),
                          ),
                          FilterChip(
                            label: const Text('313 BU'),
                            selected: _abteilungen.contains('313 BU'),
                            onSelected: (v) => setState(() {
                              v
                                  ? _abteilungen.add('313 BU')
                                  : _abteilungen.remove('313 BU');
                            }),
                          ),
                          FilterChip(
                            label: const Text('313 BauKo'),
                            selected: _abteilungen.contains('313 BauKo'),
                            onSelected: (v) => setState(() {
                              v
                                  ? _abteilungen.add('313 BauKo')
                                  : _abteilungen.remove('313 BauKo');
                            }),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),
                  _sectionLabel('Bemerkung'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _bemCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'optional',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 16),
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
                  Text(
                    '📷 ${_fotos.length}   🎥 ${_videos.length}   🎤 ${_audios.length}   📄 ${_pdfs.length}',
                  ),

                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _onSave,
                    icon: const Icon(Icons.save),
                    label: const Text('Speichern'),
                  ),
                ],
              ),
            ),
    );
  }

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
