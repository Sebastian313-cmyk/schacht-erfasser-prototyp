// ======================= lib/screens/einsteig_screen.dart =======================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class EinsteigScreen extends StatefulWidget {
  final Map<String, dynamic>? initialMeta;
  const EinsteigScreen({super.key, this.initialMeta});

  @override
  State<EinsteigScreen> createState() => _EinsteigScreenState();
}

class _EinsteigScreenState extends State<EinsteigScreen> {
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

  final _posCtrl = TextEditingController();
  final _idNrCtrl = TextEditingController();

  final Set<String> _verfuegbarkeit = <String>{};
  final Set<String> _statusVorOrt = <String>{};
  final _verfuegbarkeitErgaenzenCtrl = TextEditingController();

  String _eingang = 'Seiteneinstieg';
  String _einsteigart = 'Leiter';
  String _steigeisenStand = 'Alt';
  bool _fallschutzVorhanden = false;

  String _deckel = kStandardSchachtDeckelart;
  final _deckelBemCtrl = TextEditingController();
  String _kl = 'D';
  final List<String> _deckelOpts = kSchachtDeckelartOptions;

  final Set<String> _schaeden = <String>{};
  bool _keinBefund = false;
  String _klUnterDSchaden = 'unter KL D (automatisch)';
  final List<String> _schaedenList = const [
    'Schrauben fest',
    'Schacht locker',
    'Schlammschüssel fehlt',
    'Ausgleichsringe defekt',
    '1. Steigeisen entfernen',
    'Steigeisen kaputt',
    'Leiter einbauen',
    'Keine Rückenfreiheit',
    'unter KL D (automatisch)',
  ];

  final Set<String> _abteilungen = <String>{};

  final _massSteigeisen1Ctrl = TextEditingController();
  final _rf1Ctrl = TextEditingController();
  final _massSteigeisen2Ctrl = TextEditingController();
  final _rf2Ctrl = TextEditingController();

  // Objektattribute
  final _durchmesserCtrl = TextEditingController();
  final _kanalprofilCtrl = TextEditingController();

  // Örtlichkeit & Oberfläche
  final Set<String> _oertlichkeit = <String>{};
  final Set<String> _oberflaeche = <String>{};
  final _oertlBemCtrl = TextEditingController();
  final _obflBemCtrl = TextEditingController();

  // Schachtkopfdaten & Maße
  final Set<String> _schachtkopf = <String>{kStandardSchachtDeckelart};
  final _uebergangsplatteBemCtrl = TextEditingController();
  final _sonstigeTypenBemCtrl = TextEditingController();
  String _massSchachtkopf = '80';
  final _massAusgleichCtrl = TextEditingController();
  final _massKonusAnfCtrl = TextEditingController();
  final _massKonusEndCtrl = TextEditingController();
  final _massBermeCtrl = TextEditingController();
  final _massSolltiefeCtrl = TextEditingController();

  // Medien & Bemerkung
  final List<String> _fotos = [];
  final List<String> _videos = [];
  final List<String> _audios = [];
  final List<String> _pdfs = [];
  final _bemCtrl = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    _session = await SessionStore.load();
    // If we were opened for editing with an existing meta, populate fields
    if (widget.initialMeta != null) {
      _applyInitialMeta(widget.initialMeta!);
    }
    if (mounted) setState(() {});
  }

  void _applyInitialMeta(Map<String, dynamic> meta) {
    // helper to handle list-or-string
    Set<String> toSet(dynamic v) {
      if (v == null) return <String>{};
      if (v is List) return v.cast<String>().toSet();
      if (v is String && v.isNotEmpty)
        return v
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toSet();
      return <String>{};
    }

    _posCtrl.text = (meta['posNr'] as String?) ?? '';
    _idNrCtrl.text = (meta['idNr'] as String?) ?? '';
    _verfuegbarkeit.clear();
    _verfuegbarkeit.addAll(toSet(meta['verfuegbarkeit']));
    _statusVorOrt.clear();
    _statusVorOrt.addAll(toSet(meta['statusVorOrt']));
    _eingang = (meta['eingang'] as String?) ?? _eingang;
    _einsteigart = (meta['einsteigart'] as String?) ?? _einsteigart;
    _steigeisenStand = (meta['steigeisenStand'] as String?) ?? 'Alt';
    _fallschutzVorhanden = (meta['fallschutz'] == true);
    _deckel = normalizeSchachtDeckelart(meta['deckel'], fallback: _deckel);
    _deckelBemCtrl.text =
        (meta['deckelBem'] as String?) ??
        schachtDeckelBemerkung(meta['deckel']);
    _kl = (meta['kl'] as String?) ?? _kl;
    _schaeden.clear();
    _schaeden.addAll(toSet(meta['schaeden']));
    _keinBefund = (meta['keinBefund'] == true);
    _applyKlUnterDSchaden();

    _massSteigeisen1Ctrl.text = (meta['st1Hoehe'] as String?) ?? '';
    _rf1Ctrl.text = (meta['st1Rf'] as String?) ?? '';
    _massSteigeisen2Ctrl.text = (meta['st2Hoehe'] as String?) ?? '';
    _rf2Ctrl.text = (meta['st2Rf'] as String?) ?? '';

    _durchmesserCtrl.text = (meta['durchmesser'] as String?) ?? '';
    _kanalprofilCtrl.text = (meta['kanalprofil'] as String?) ?? '';

    _oertlichkeit.clear();
    _oertlichkeit.addAll(toSet(meta['oertlichkeit']));
    _oberflaeche.clear();
    _oberflaeche.addAll(toSet(meta['oberflaeche']));
    _oertlBemCtrl.text = (meta['oertlBem'] as String?) ?? '';
    _obflBemCtrl.text = (meta['obflBem'] as String?) ?? '';

    _abteilungen.clear();
    _abteilungen.addAll(toSet(meta['abteilungen']));

    _schachtkopf.clear();
    _schachtkopf.addAll(toSet(meta['schachtkopf']));
    _uebergangsplatteBemCtrl.text = (meta['uebergangsBem'] as String?) ?? '';
    _massAusgleichCtrl.text = (meta['mAusgleich'] as String?) ?? '';
    _massSchachtkopf = _normalizeSchachtkopfMass(
      meta['mSchachtkopf'] ?? meta['mass_schachtkopf'],
    );
    _massKonusAnfCtrl.text = (meta['mKonusAnf'] as String?) ?? '';
    _massKonusEndCtrl.text = (meta['mKonusEnd'] as String?) ?? '';
    _massBermeCtrl.text = (meta['mBerme'] as String?) ?? '';
    _massSolltiefeCtrl.text = (meta['mSolltiefe'] as String?) ?? '';

    _bemCtrl.text = (meta['bemerkung'] as String?) ?? '';

    // media
    _fotos.clear();
    _videos.clear();
    _audios.clear();
    final fotos =
        (meta['mediaFotos'] as List<dynamic>?)?.cast<String>() ?? <String>[];
    final videos =
        (meta['mediaVideos'] as List<dynamic>?)?.cast<String>() ?? <String>[];
    final audios =
        (meta['mediaAudios'] as List<dynamic>?)?.cast<String>() ?? <String>[];
    _fotos.addAll(fotos);
    _videos.addAll(videos);
    _audios.addAll(audios);
  }

  @override
  void dispose() {
    _posCtrl.dispose();
    _idNrCtrl.dispose();
    _deckelBemCtrl.dispose();
    _massSteigeisen1Ctrl.dispose();
    _rf1Ctrl.dispose();
    _massSteigeisen2Ctrl.dispose();
    _rf2Ctrl.dispose();
    _durchmesserCtrl.dispose();
    _kanalprofilCtrl.dispose();
    _oertlBemCtrl.dispose();
    _obflBemCtrl.dispose();
    _uebergangsplatteBemCtrl.dispose();
    _sonstigeTypenBemCtrl.dispose();
    _massAusgleichCtrl.dispose();
    _massKonusAnfCtrl.dispose();
    _massKonusEndCtrl.dispose();
    _massBermeCtrl.dispose();
    _massSolltiefeCtrl.dispose();
    _bemCtrl.dispose();
    super.dispose();
  }

  String _normalizeSchachtkopfMass(dynamic value) {
    final raw = value?.toString().trim().replaceAll('.', ',') ?? '';
    if (raw.startsWith('62')) return '62,5';
    if (raw.startsWith('80')) return '80';
    return '80';
  }

  bool get _needsSchachtkopfMassChoice =>
      _deckel != kStandardSchachtDeckelart && _deckel != 'Mannloch';

  String get _effectiveSchachtkopfMass {
    if (_deckel == kStandardSchachtDeckelart) return '62,5';
    if (_deckel == 'Mannloch') return '';
    return _massSchachtkopf;
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

  bool get _rfActive => _schaeden.contains('Keine Rückenfreiheit');

  bool get _klUnterD =>
      _deckel != 'Mannloch' && (_kl == 'A' || _kl == 'B' || _kl == 'C');

  void _applyKlUnterDSchaden() {
    if (_deckel == 'Mannloch') {
      _schaeden.remove(_klUnterDSchaden);
      return;
    }
    if (_klUnterD) {
      _schaeden.add(_klUnterDSchaden);
      _keinBefund = false;
    } else {
      _schaeden.remove(_klUnterDSchaden);
    }
  }

  List<String> _schaedenDisplay() {
    final result = <String>[];
    for (final name in _schaedenList) {
      if (_schaeden.contains(name)) result.add(name);
    }
    return result;
  }

  // ----------------------------- Validation ----
  /// Validiert nur die notwendige Pflichtangabe: Positionsnummer (inkl. Eindeutigkeit).
  Future<bool> _validateEinsteigschaechteFields() async {
    final pos = _posCtrl.text.trim();
    if (pos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte Positionsnummer eintragen.')),
      );
      return false;
    }

    // Eindeutigkeit der Positionsnummer
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
      if (!mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(uniqueCheck.message!)));
      return false;
    }

    return true;
  }

  // ----------------------------- Save -----------------------------
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

    if (_oberflaeche.contains('Baum in der Nähe')) {
      final hasBaumMass = _obflBemCtrl.text.trim().isNotEmpty;
      final hasBaumFoto = _fotos.isNotEmpty;
      if (!hasBaumMass || !hasBaumFoto) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Bei "Baum in der Nähe" sind Maße in cm (Abstand + Stammdurchmesser) und mindestens 1 Foto Pflicht.',
            ),
          ),
        );
        return;
      }
    }

    // Export in Word-Vorlage nur nach erfolgreicher ES-Validierung
    if (!await _validateEinsteigschaechteFields()) return;

    final keinBefundCheck = ValidationService.validateNoKeinBefundMitSchaeden(
      keinBefund: _keinBefund,
      schaeden: _schaeden,
      message: '"Kein Befund" schließt Schäden aus.',
    );
    if (!keinBefundCheck.isValid) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(keinBefundCheck.message!)));
      return;
    }

    // Bemerkung + Medien (Zähler separat für BaseEntry.notizen)
    final bemerkungText = _bemCtrl.text.trim();
    final hasFotos = _fotos.isNotEmpty;
    final hasVideos = _videos.isNotEmpty;

    final mediaNote = (hasFotos || hasVideos)
        ? 'Fotos: ${_fotos.length}${hasVideos ? ' / Videos: ${_videos.length}' : ''}'
        : null;

    final bemerkungMeta = mediaNote == null
        ? bemerkungText
        : (bemerkungText.isEmpty ? mediaNote : '$bemerkungText | $mediaNote');

    final pos = _posCtrl.text.trim();
    final existingKey = widget.initialMeta != null
        ? widget.initialMeta!['storageKey'] as String?
        : null;

    // GPS nur einmal beim Speichern erfassen (flüssig für UI)
    final gps = hasNichtImNis(_verfuegbarkeit)
        ? ((await GpsService.getCurrentLocation()) ??
              widget.initialMeta?['gps'])
        : null;

    final deckelLabel = buildSchachtDeckelartLabel(
      _deckel,
      _deckelBemCtrl.text,
    );

    // Persistenz
    final idNr = _idNrCtrl.text.trim();
    final idValidation = ValidationService.validateIdNumberByType(
      idNr,
      typ: 'ES',
      required: _rfActive,
    );
    if (idValidation != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(idValidation)));
      return;
    }

    final meta = {
      'typ': 'ES',
      'evnr': _session!.evnr,
      'strasse': _session!.strasse,
      'erfasser': _session!.erfasser,
      'zeitIso': _session!.zeitIso,
      'wetter': _session!.wetter,
      'temperatur': _session!.temperatur,
      'posNr': pos,
      'idNr': _idNrCtrl.text.trim(),
      'verfuegbarkeit': _verfuegbarkeit.join(', '),
      'statusVorOrt': _statusVorOrt.join(', '),
      'eingang': _eingang,
      'einsteigart': _einsteigart,
      'steigeisenStand': _einsteigart == 'Steigeisen' ? _steigeisenStand : '',
      if (_einsteigart == 'Steigbaum') 'fallschutz': _fallschutzVorhanden,
      'deckel': deckelLabel,
      'kl': _deckel == 'Mannloch' ? '' : _kl,
      'schaeden': _schaeden.toList(),
      'keinBefund': _keinBefund,
      'st1Hoehe': _rfActive ? _massSteigeisen1Ctrl.text.trim() : '',
      'st1Rf': _rfActive ? _rf1Ctrl.text.trim() : '',
      'st2Hoehe': _rfActive ? _massSteigeisen2Ctrl.text.trim() : '',
      'st2Rf': _rfActive ? _rf2Ctrl.text.trim() : '',
      'durchmesser': _durchmesserCtrl.text.trim(),
      'kanalprofil': _kanalprofilCtrl.text.trim(),
      'oertlichkeit': _oertlichkeit.join(', '),
      'oertlBem': _oertlBemCtrl.text.trim(),
      'oberflaeche': _oberflaeche.join(', '),
      'obflBem': _obflBemCtrl.text.trim(),
      'schachtkopf': _schachtkopf.join(', '),
      'uebergangsBem': _uebergangsplatteBemCtrl.text.trim(),
      'mSchachtkopf': _effectiveSchachtkopfMass,
      'abteilungen': _abteilungen.toList(),
      'mAusgleich': '',
      'mKonusAnf': _rfActive ? _massKonusAnfCtrl.text.trim() : '',
      'mKonusEnd': _rfActive ? _massKonusEndCtrl.text.trim() : '',
      'mBerme': _rfActive ? _massBermeCtrl.text.trim() : '',
      'mSolltiefe': _rfActive ? _massSolltiefeCtrl.text.trim() : '',
      'bemerkung': bemerkungMeta,
      'mediaFotos': _fotos,
      'mediaVideos': _videos,
      'mediaAudios': _audios,
      'mediaPdfs': _pdfs,
      'createdAt': DateTime.now().toIso8601String(),
      'gps': gps,
    };

    // If editing an existing meta, preserve its storageKey and createdAt
    final metaKey =
        existingKey ?? 'obj_${_session!.evnr}_${_session!.strasse}_${pos}_ES';
    if (existingKey != null) {
      meta['createdAt'] = widget.initialMeta!['createdAt'] ?? meta['createdAt'];
    }
    meta['storageKey'] = metaKey;
    await SpeicherService.upsertEntry(metaKey, meta);

    // BaseEntry in Repository speichern (für Gesamtbericht)
    final repo = Repository.instance;

    final spezialParts = <String>[];
    if (_einsteigart == 'Steigeisen') {
      spezialParts.add('Steigeisen: $_steigeisenStand');
    } else if (_einsteigart == 'Steigbaum') {
      spezialParts.add(
        'Steigbaum: Fallschutz ${_fallschutzVorhanden ? 'Ja' : 'Nein'}',
      );
    }
    if (_rfActive) {
      final rf1 = _rf1Ctrl.text.trim();
      final rf2 = _rf2Ctrl.text.trim();
      final parts = <String>[];
      if (rf1.isNotEmpty) parts.add('RF1 $rf1 cm');
      if (rf2.isNotEmpty) parts.add('RF2 $rf2 cm');
      if (parts.isNotEmpty) spezialParts.add(parts.join(', '));
    }
    if (_durchmesserCtrl.text.trim().isNotEmpty) {
      spezialParts.add('Ø ${_durchmesserCtrl.text.trim()}');
    }
    if (_kanalprofilCtrl.text.trim().isNotEmpty) {
      spezialParts.add('Profil ${_kanalprofilCtrl.text.trim()}');
    }

    final schaedenDisplay = _schaedenDisplay();

    final baseEntry = BaseEntry(
      id: repo.newId(),
      type: EntryType.einsteigschacht,
      evnr: _session!.evnr,
      positionsnummer: pos,
      titel: _keinBefund
          ? 'Kein Befund'
          : (schaedenDisplay.isNotEmpty ? schaedenDisplay.join(', ') : null),
      zeit: DateTime.tryParse(_session!.zeitIso),
      strasse: _session!.strasse,
      bemerkung: bemerkungText.isEmpty ? null : bemerkungText,
      verfuegbarkeitLabel: _verfuegbarkeit.isEmpty
          ? null
          : _verfuegbarkeit.join(', '),
      statusVorOrtLabel: _statusVorOrt.isEmpty
          ? null
          : _statusVorOrt.join(', '),
      notizen: mediaNote,
      spezial: spezialParts.isEmpty ? null : spezialParts.join(' • '),
      deckelart: deckelLabel,
      klasse: _deckel == 'Mannloch' ? null : _kl,
      zugang: _eingang,
      einsteigart: _einsteigart,
    );

    await repo.add(baseEntry);

    // PDF erzeugen
    final df = DateFormat('dd.MM.yyyy HH:mm');
    final fields = <String, String>{};

    // Kopfzeilen (immer vorhanden)
    fields['EVNr'] = _session!.evnr;
    fields['Straße'] = _session!.strasse;
    fields['Erfasser:in'] = _session!.erfasser;
    fields['Datum/Zeit'] = df.format(
      DateTime.tryParse(_session!.zeitIso) ?? DateTime.now(),
    );
    fields['Wetter'] = _session!.wetter;
    fields['Temperatur'] = formatTemperatureValue(_session!.temperatur);
    fields['Positionsnummer'] = pos;

    // Optionale Felder (nur wenn gefüllt)
    if (idNr.isNotEmpty) fields['ID-Nummer'] = idNr;
    if (_verfuegbarkeit.isNotEmpty)
      fields['Verfügbarkeit'] = _verfuegbarkeit.join(', ');
    if (_statusVorOrt.isNotEmpty)
      fields['Status vor Ort'] = _statusVorOrt.join(', ');

    // Standard-Felder
    fields['Eingang'] = _eingang;
    if (_einsteigart == 'Steigeisen') {
      fields['Einsteigart'] = 'Steigeisen – $_steigeisenStand';
    } else if (_einsteigart == 'Steigbaum') {
      fields['Einsteigart'] =
          'Steigbaum – Fallschutz: ${_fallschutzVorhanden ? 'Ja' : 'Nein'}';
    } else {
      fields['Einsteigart'] = _einsteigart;
    }
    fields['Deckelart'] = deckelLabel;
    // KL nur speichern wenn Deckel NICHT Mannloch ist
    if (_deckel != 'Mannloch') {
      fields['KL'] = _kl;
    }
    fields['Schäden'] = _keinBefund
        ? 'Kein Befund'
        : (schaedenDisplay.isEmpty ? '' : schaedenDisplay.join(', '));

    // Objektattribute (nur wenn gefüllt)
    if (_durchmesserCtrl.text.trim().isNotEmpty) {
      fields['Schacht Durchmesser'] = _durchmesserCtrl.text.trim();
    }
    if (_kanalprofilCtrl.text.trim().isNotEmpty) {
      fields['Kanalprofil'] = _kanalprofilCtrl.text.trim();
    }

    // Örtlichkeit
    if (_oertlichkeit.isNotEmpty) {
      fields['Örtlichkeit'] = _oertlichkeit.join(', ');
    }
    if (_oertlBemCtrl.text.trim().isNotEmpty) {
      fields['Örtlichkeit – Bemerkung'] = _oertlBemCtrl.text.trim();
    }

    // Oberflächenart
    if (_oberflaeche.isNotEmpty) {
      fields['Oberflächenart'] = _oberflaeche.join(', ');
    }
    if (_obflBemCtrl.text.trim().isNotEmpty) {
      fields['Oberfläche – Bemerkung'] = _obflBemCtrl.text.trim();
    }

    // Schachtkopfdaten
    if (_schachtkopf.isNotEmpty) {
      fields['Schachtkopfdaten'] = _schachtkopf.join(', ');
    }
    if (_uebergangsplatteBemCtrl.text.trim().isNotEmpty) {
      fields['Übergangsplatte (Höhe)'] = _uebergangsplatteBemCtrl.text.trim();
    }

    // Maße nur wenn RF aktiv
    if (_rfActive) {
      if (_massSteigeisen1Ctrl.text.trim().isNotEmpty) {
        fields['1. Steigeisen – Steighöhe'] = _massSteigeisen1Ctrl.text.trim();
      }
      if (_rf1Ctrl.text.trim().isNotEmpty) {
        fields['1. Steigeisen – Rückenfreiheit'] = _rf1Ctrl.text.trim();
      }

      if (_massSteigeisen2Ctrl.text.trim().isNotEmpty) {
        fields['2. Steigeisen – Steighöhe'] = _massSteigeisen2Ctrl.text.trim();
      }
      if (_rf2Ctrl.text.trim().isNotEmpty) {
        fields['2. Steigeisen – Rückenfreiheit'] = _rf2Ctrl.text.trim();
      }

      if (_massKonusAnfCtrl.text.trim().isNotEmpty) {
        fields['Konusanfang'] = _massKonusAnfCtrl.text.trim();
      }
      if (_massKonusEndCtrl.text.trim().isNotEmpty) {
        fields['Konusende'] = _massKonusEndCtrl.text.trim();
      }
      if (_massBermeCtrl.text.trim().isNotEmpty) {
        fields['Berme'] = _massBermeCtrl.text.trim();
      }
      if (_massSolltiefeCtrl.text.trim().isNotEmpty) {
        fields['Solltiefe'] = _massSolltiefeCtrl.text.trim();
      }
    }

    // Bemerkung (nur wenn gefüllt)
    if (bemerkungText.isNotEmpty) {
      fields['Bemerkung'] = bemerkungMeta;
    }

    // Meta-first export: PDFs werden jetzt über ExportService.buildEinzelPdfFromMeta gebaut
    // final theme = await ExportService.getTheme();
    // await PdfMiniKit.esSteckbrief(...);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Einsteigschacht gespeichert (im Gesamt-Export enthalten).',
        ),
      ),
    );
    Navigator.pop(context);
  }

  // ----------------------------- UI -----------------------------
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
        title: const Text('Beschreibung - Einsteigschacht (ES)'),
        content: const SingleChildScrollView(
          child: Text(
            'Dieses Modul erfasst Einsteigschächte.\n\n'
            'Wichtig:\n'
            '- Pflichtfeld ist die Positionsnummer.\n'
            '- Danach schrittweise Eingangsart, Deckel, Schäden, Details und Maße erfassen.\n'
            '- Medien (Foto/Video/Audio/PDF) können im letzten Schritt ergänzt werden.\n\n'
            'Hinweis:\n'
            'Die Daten werden im Modul gespeichert. Dateien werden erst im Bericht beim Export erzeugt.',
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
        title: const Text('Einsteigschacht (ES)'),
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
                        if (_currentStep < 5) {
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
                                  _currentStep == 5 ? 'Speichern' : 'Weiter',
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
                              _label('Positionsnummer *'),
                              TextFormField(
                                controller: _posCtrl,
                                decoration: const InputDecoration(
                                  hintText: 'z. B. 1, 1a, 2',
                                  helperText: 'Muss eindeutig sein',
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Bitte Positionsnummer eintragen.';
                                  }
                                  return ValidationService.validatePositionField(
                                    value,
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _idNrCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'ID-Nummer',
                                  hintText:
                                      '8-stellig, nur Ziffern (z. B. 12345678)',
                                  helperText:
                                      'Optional, Pflicht nur bei "Keine Rückenfreiheit"',
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Verfügbarkeit',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                children: kVerfuegbarkeitOptionsAll
                                    .map(
                                      (opt) => FilterChip(
                                        label: Text(opt),
                                        selected: _verfuegbarkeit.contains(opt),
                                        onSelected: (selected) {
                                          setState(() {
                                            if (selected) {
                                              _verfuegbarkeit.add(opt);
                                            } else {
                                              _verfuegbarkeit.remove(opt);
                                              if (opt == 'Ergänzen')
                                                _verfuegbarkeitErgaenzenCtrl
                                                    .clear();
                                            }
                                          });
                                        },
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
                              const SizedBox(height: 12),
                              Text(
                                'Status vor Ort',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                children: kStatusAllgemein
                                    .map(
                                      (opt) => FilterChip(
                                        label: Text(opt),
                                        selected: _statusVorOrt.contains(opt),
                                        onSelected: (selected) {
                                          setState(() {
                                            if (selected) {
                                              _statusVorOrt.add(opt);
                                            } else {
                                              _statusVorOrt.remove(opt);
                                            }
                                          });
                                        },
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ),
                        ),

                        // Schritt 2: Eingang & Deckelart
                        Step(
                          title: const Text('2. Eingang & Deckelart'),
                          isActive: _currentStep >= 1,
                          state: _currentStep > 1
                              ? StepState.complete
                              : StepState.indexed,
                          content: ListView(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              Text(
                                'Eingangsart',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [
                                  ChoiceChip(
                                    label: const Text('Seiteneinstieg'),
                                    selected: _eingang == 'Seiteneinstieg',
                                    onSelected: (_) => setState(
                                      () => _eingang = 'Seiteneinstieg',
                                    ),
                                  ),
                                  ChoiceChip(
                                    label: const Text('Direkteinstieg'),
                                    selected: _eingang == 'Direkteinstieg',
                                    onSelected: (_) => setState(
                                      () => _eingang = 'Direkteinstieg',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Einsteigart',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [
                                  ChoiceChip(
                                    label: const Text('Leiter'),
                                    selected: _einsteigart == 'Leiter',
                                    onSelected: (_) =>
                                        setState(() => _einsteigart = 'Leiter'),
                                  ),
                                  ChoiceChip(
                                    label: const Text('Steigeisen'),
                                    selected: _einsteigart == 'Steigeisen',
                                    onSelected: (_) => setState(
                                      () => _einsteigart = 'Steigeisen',
                                    ),
                                  ),
                                  ChoiceChip(
                                    label: const Text('Steigbaum'),
                                    selected: _einsteigart == 'Steigbaum',
                                    onSelected: (_) => setState(
                                      () => _einsteigart = 'Steigbaum',
                                    ),
                                  ),
                                ],
                              ),
                              if (_einsteigart == 'Steigeisen') ...[
                                const SizedBox(height: 12),
                                Text(
                                  'Steigeisenzustand',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    ChoiceChip(
                                      label: const Text('Alt'),
                                      selected: _steigeisenStand == 'Alt',
                                      onSelected: (_) => setState(
                                        () => _steigeisenStand = 'Alt',
                                      ),
                                    ),
                                    ChoiceChip(
                                      label: const Text('Neu'),
                                      selected: _steigeisenStand == 'Neu',
                                      onSelected: (_) => setState(
                                        () => _steigeisenStand = 'Neu',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (_einsteigart == 'Steigbaum') ...[
                                const SizedBox(height: 12),
                                Text(
                                  'Fallschutz vorhanden?',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    ChoiceChip(
                                      label: const Text('Ja'),
                                      selected: _fallschutzVorhanden,
                                      onSelected: (_) => setState(
                                        () => _fallschutzVorhanden = true,
                                      ),
                                    ),
                                    ChoiceChip(
                                      label: const Text('Nein'),
                                      selected: !_fallschutzVorhanden,
                                      onSelected: (_) => setState(
                                        () => _fallschutzVorhanden = false,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 20),
                              Text(
                                'Deckelart',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                initialValue: _deckel,
                                items: _deckelOpts
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
                                onChanged: (v) => setState(() {
                                  _deckel = v ?? kStandardSchachtDeckelart;
                                  if (_deckel == kStandardSchachtDeckelart) {
                                    _schachtkopf.add(kStandardSchachtDeckelart);
                                  } else {
                                    _schachtkopf.remove(
                                      kStandardSchachtDeckelart,
                                    );
                                  }
                                  _applyKlUnterDSchaden();
                                }),
                              ),
                              if (_deckel == 'Bemerkung') ...[
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _deckelBemCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Hersteller/Typ',
                                  ),
                                ),
                              ],
                              if (_needsSchachtkopfMassChoice) ...[
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  initialValue: _massSchachtkopf,
                                  decoration: const InputDecoration(
                                    labelText: 'Maß Schachtkopf',
                                    helperText:
                                        'Wird in der Skizze in cm eingetragen.',
                                    suffixText: 'cm',
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: '62,5',
                                      child: Text('62,5 cm'),
                                    ),
                                    DropdownMenuItem(
                                      value: '80',
                                      child: Text('80 cm'),
                                    ),
                                  ],
                                  onChanged: (value) => setState(
                                    () => _massSchachtkopf =
                                        _normalizeSchachtkopfMass(value),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                              // KL-Klasse: nur wenn Deckel NICHT Mannloch ist
                              if (_deckel != 'Mannloch') ...[
                                Text(
                                  'KL-Klasse',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
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
                                const SizedBox(height: 20),
                              ],
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
                              Text(
                                'Schadstellen',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _schaedenList.map((name) {
                                  final sel = _schaeden.contains(name);
                                  final isKlUnterD =
                                      name == _klUnterDSchaden && _klUnterD;
                                  return FilterChip(
                                    label: Text(name),
                                    selected: sel,
                                    onSelected: (_keinBefund || isKlUnterD)
                                        ? null
                                        : (v) {
                                            setState(() {
                                              if (name ==
                                                  'Keine Rückenfreiheit') {
                                                if (v) {
                                                  _schaeden.add(name);
                                                } else {
                                                  _schaeden.remove(name);
                                                  _massSteigeisen1Ctrl.clear();
                                                  _rf1Ctrl.clear();
                                                  _massSteigeisen2Ctrl.clear();
                                                  _rf2Ctrl.clear();
                                                  _massAusgleichCtrl.clear();
                                                  _massKonusAnfCtrl.clear();
                                                  _massKonusEndCtrl.clear();
                                                  _massBermeCtrl.clear();
                                                  _massSolltiefeCtrl.clear();
                                                }
                                              } else {
                                                if (v) {
                                                  _schaeden.add(name);
                                                } else {
                                                  _schaeden.remove(name);
                                                }
                                              }
                                            });
                                          },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 12),
                              FilterChip(
                                label: const Text('🔍 Kein Befund'),
                                selected: _keinBefund,
                                onSelected: (v) {
                                  if (v && _klUnterD) {
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
                                    _keinBefund = v;
                                    if (v) _schaeden.clear();
                                  });
                                },
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Abteilung',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
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

                        // Schritt 4: Details
                        Step(
                          title: const Text('4. Details'),
                          isActive: _currentStep >= 3,
                          state: _currentStep > 3
                              ? StepState.complete
                              : StepState.indexed,
                          content: _rfActive
                              ? ListView(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  children: [
                                    Text(
                                      'Objektattribute',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _durchmesserCtrl,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                          RegExp(r'[0-9.,]'),
                                        ),
                                      ],
                                      decoration: const InputDecoration(
                                        labelText: 'Schacht Durchmesser (cm)',
                                        hintText: '100 oder 120',
                                        helperText:
                                            'Standardwerte: 100 cm oder 120 cm',
                                        suffixText: 'cm',
                                      ),
                                      validator: ValidationService
                                          .validateSchachtdurchmesserCm,
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _kanalprofilCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Kanalprofil',
                                        hintText:
                                            'z. B. KR 250, KR 300 oder Freispiegelprofil',
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      'Örtlichkeit',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 8),
                                    _chipsMulti([
                                      'Hauptstraße',
                                      'Nebenstraße',
                                      'Kreuzung',
                                      'Einbahnstraße',
                                      'Geh-/Radweg',
                                      'Spuren',
                                      'Baustellensicherung',
                                    ], _oertlichkeit),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _oertlBemCtrl,
                                      maxLines: 2,
                                      decoration: const InputDecoration(
                                        labelText: 'Bemerkung (optional)',
                                        hintText:
                                            'z.B. Besonderheiten der Örtlichkeit',
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      'Oberflächenart',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 8),
                                    _chipsMulti([
                                      'Asphalt',
                                      'teerhaltig',
                                      'Kleinstein',
                                      'Großstein',
                                      'Kupla',
                                      'Sonstige',
                                      'Grünfläche',
                                      'Baum in der Nähe',
                                    ], _oberflaeche),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _obflBemCtrl,
                                      maxLines: 2,
                                      decoration: const InputDecoration(
                                        labelText: 'Bemerkung (optional)',
                                        hintText:
                                            'Bei „Baum in der Nähe": Abstand in cm + Stammdurchmesser in cm (z. B. 120 cm / Ø35 cm)',
                                        helperText:
                                            'Foto so aufnehmen, dass Schacht und angrenzender Baum gleichzeitig und eindeutig sichtbar sind (keine Einzelaufnahme).',
                                      ),
                                      validator: (value) {
                                        if (_oberflaeche.contains(
                                              'Baum in der Nähe',
                                            ) &&
                                            (value == null ||
                                                value.trim().isEmpty)) {
                                          return 'Bitte Abstand zum Baum und Stammdurchmesser in cm eintragen.';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      'Schachtkopfdaten',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 8),
                                    _chipsMulti([
                                      'Begu DN 625',
                                      'Ausgleichsringe',
                                      'Übergangsplatte (Höhe)',
                                      'Konus DN 625 o. Versatz',
                                      'Konus DN 700 m. Versatz',
                                      'Sonstige Typen',
                                    ], _schachtkopf),
                                    if (_schachtkopf.contains(
                                      'Übergangsplatte (Höhe)',
                                    )) ...[
                                      const SizedBox(height: 8),
                                      TextFormField(
                                        controller: _uebergangsplatteBemCtrl,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                            RegExp(r'[0-9.,]'),
                                          ),
                                        ],
                                        decoration: const InputDecoration(
                                          labelText: 'Höhe *',
                                          hintText: 'z. B. 25 oder 30',
                                          suffixText: 'cm',
                                        ),
                                        validator: (value) {
                                          if (value == null ||
                                              value.trim().isEmpty) {
                                            return 'Bitte Höhe eintragen.';
                                          }
                                          return null;
                                        },
                                      ),
                                    ],
                                    if (_schachtkopf.contains(
                                      'Sonstige Typen',
                                    )) ...[
                                      const SizedBox(height: 8),
                                      TextFormField(
                                        controller: _sonstigeTypenBemCtrl,
                                        maxLines: 2,
                                        decoration: const InputDecoration(
                                          labelText:
                                              'Sonstige Typen (Beschreibung) *',
                                          hintText:
                                              'z. B. Besondere Schachtkopf-Ausführung',
                                        ),
                                        validator: (value) {
                                          if (value == null ||
                                              value.trim().isEmpty) {
                                            return 'Bitte Beschreibung eintragen.';
                                          }
                                          return null;
                                        },
                                      ),
                                    ],
                                  ],
                                )
                              : Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    'Nur sichtbar wenn "Keine Rückenfreiheit" ausgewählt ist',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                        ),

                        // Schritt 5: Maße (nur wenn RF aktiv)
                        Step(
                          title: const Text('5. Maße'),
                          isActive: _currentStep >= 4,
                          state: _currentStep > 4
                              ? StepState.complete
                              : StepState.indexed,
                          content: _rfActive
                              ? ListView(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  children: [
                                    Text(
                                      'Messwerte (cm)',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 12),
                                    Card(
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '1. Steigeisen',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleSmall,
                                            ),
                                            const SizedBox(height: 10),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: TextField(
                                                    controller:
                                                        _massSteigeisen1Ctrl,
                                                    keyboardType:
                                                        TextInputType.number,
                                                    inputFormatters: [
                                                      FilteringTextInputFormatter
                                                          .digitsOnly,
                                                    ],
                                                    decoration:
                                                        const InputDecoration(
                                                          labelText:
                                                              'Steighöhe (cm)',
                                                          hintText:
                                                              'z. B. 60 cm',
                                                          suffixText: 'cm',
                                                        ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: TextField(
                                                    controller: _rf1Ctrl,
                                                    keyboardType:
                                                        TextInputType.number,
                                                    inputFormatters: [
                                                      FilteringTextInputFormatter
                                                          .digitsOnly,
                                                    ],
                                                    decoration:
                                                        const InputDecoration(
                                                          labelText:
                                                              'Rückenfreiheit (cm)',
                                                          hintText:
                                                              'z. B. 40 cm',
                                                          suffixText: 'cm',
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Card(
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '2. Steigeisen',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleSmall,
                                            ),
                                            const SizedBox(height: 10),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: TextField(
                                                    controller:
                                                        _massSteigeisen2Ctrl,
                                                    keyboardType:
                                                        TextInputType.number,
                                                    inputFormatters: [
                                                      FilteringTextInputFormatter
                                                          .digitsOnly,
                                                    ],
                                                    decoration:
                                                        const InputDecoration(
                                                          labelText:
                                                              'Steighöhe (cm)',
                                                          hintText:
                                                              'z. B. 80 cm',
                                                          suffixText: 'cm',
                                                        ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: TextField(
                                                    controller: _rf2Ctrl,
                                                    keyboardType:
                                                        TextInputType.number,
                                                    inputFormatters: [
                                                      FilteringTextInputFormatter
                                                          .digitsOnly,
                                                    ],
                                                    decoration:
                                                        const InputDecoration(
                                                          labelText:
                                                              'Rückenfreiheit (cm)',
                                                          hintText:
                                                              'z. B. 60 cm',
                                                          suffixText: 'cm',
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 16,
                                      runSpacing: 16,
                                      children: [
                                        SizedBox(
                                          width: 200,
                                          child: TextField(
                                            controller: _massKonusAnfCtrl,
                                            keyboardType: TextInputType.number,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                            ],
                                            decoration: const InputDecoration(
                                              labelText: 'Konusanfang',
                                              suffixText: 'cm',
                                            ),
                                          ),
                                        ),

                                        SizedBox(
                                          width: 200,
                                          child: TextField(
                                            controller: _massKonusEndCtrl,
                                            keyboardType: TextInputType.number,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                            ],
                                            decoration: const InputDecoration(
                                              labelText: 'Konusende',
                                              suffixText: 'cm',
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 200,
                                          child: TextField(
                                            controller: _massBermeCtrl,
                                            keyboardType: TextInputType.number,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                            ],
                                            decoration: const InputDecoration(
                                              labelText: 'Berme',
                                              suffixText: 'cm',
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 200,
                                          child: TextField(
                                            controller: _massSolltiefeCtrl,
                                            keyboardType: TextInputType.number,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                            ],
                                            decoration: const InputDecoration(
                                              labelText: 'Solltiefe',
                                              suffixText: 'cm',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                )
                              : Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    'Nur sichtbar wenn "Keine Rückenfreiheit" ausgewählt ist',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                        ),

                        // Schritt 6: Speichern
                        Step(
                          title: const Text('6. Speichern'),
                          isActive: _currentStep >= 5,
                          state: StepState.indexed,
                          content: ListView(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              Text(
                                'Bemerkung',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _bemCtrl,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  labelText: 'Zusätzliche Bemerkung (optional)',
                                  hintText:
                                      'z. B. besondere Merkmale, Handwerksmängel, ...',
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Medien',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
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

  // ----------------------------- UI helpers -----------------------------
  Widget _chipsMulti(List<String> items, Set<String> target) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: items
        .map(
          (name) => FilterChip(
            label: Text(name),
            selected: target.contains(name),
            onSelected: (v) => setState(() {
              v ? target.add(name) : target.remove(name);
            }),
          ),
        )
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
