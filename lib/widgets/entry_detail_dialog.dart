import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'entry_video_view.dart';
import 'audio_player_widget.dart';

/// Dialog zum Anzeigen und Bearbeiten eines gespeicherten Eintrags
class EntryDetailDialog extends StatefulWidget {
  final Map<String, dynamic> meta;
  final Function(Map<String, dynamic>) onUpdate;
  final VoidCallback onDelete;

  const EntryDetailDialog({
    super.key,
    required this.meta,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<EntryDetailDialog> createState() => _EntryDetailDialogState();
}

class _EntryDetailDialogState extends State<EntryDetailDialog> {
  static const double _fontTitle = 18;
  static const double _fontSection = 14;
  static const double _fontMeta = 12;
  static const double _fontField = 11;

  late TextEditingController _bemerkungCtrl;
  late Map<String, dynamic> _currentMeta;

  @override
  void initState() {
    super.initState();
    _currentMeta = Map<String, dynamic>.from(widget.meta);
    _bemerkungCtrl = TextEditingController(text: _currentMeta['bemerkung'] as String? ?? '');
  }

  @override
  void dispose() {
    _bemerkungCtrl.dispose();
    super.dispose();
  }

  void _save() {
    _currentMeta['bemerkung'] = _bemerkungCtrl.text.trim();
    widget.onUpdate(_currentMeta);
    Navigator.of(context).pop();
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Löschen bestätigen'),
        content: const Text('Möchten Sie diesen Eintrag wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.onDelete();
              Navigator.of(context).pop();
            },
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final typ = _canonicalTyp(_currentMeta['typ'] as String?);
    final objektLabel = _objektLabel(typ);
    final posNr = _currentMeta['posNr'] as String? ?? '?';
    final fotos = _safeStringList(_currentMeta['mediaFotos']);
    final videos = _safeStringList(_currentMeta['mediaVideos']);
    final audios = _safeStringList(_currentMeta['mediaAudios']);

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.9,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'STECKBRIEF ${objektLabel.toUpperCase()}',
                        style: const TextStyle(
                          fontSize: _fontTitle,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (typ == 'ES')
                      _buildEsSteckbrief(fotos, videos, audios)
                    else
                      _buildStandardSteckbrief(typ, fotos, videos, audios),
                  ],
                ),
              ),
            ),
            const Divider(),
            Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: _confirmDelete,
                  icon: const Icon(Icons.delete),
                  label: const Text('Löschen'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Abbrechen'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _save,
                  child: const Text('Speichern'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _canonicalTyp(String? rawTyp) {
    final value = (rawTyp ?? '').trim();
    if (value.isEmpty) return 'DIV';

    final upper = value.toUpperCase();
    if (upper == 'ES' || upper.contains('EINSTIEG')) return 'ES';
    if (upper == 'VS' || upper.contains('SICKERGRUBE') || upper.contains('GRUBE')) return 'VS';
    if (upper == 'SSK' || upper.contains('SINKKASTEN')) return 'SSK';
    if (upper == 'LÜ' || upper == 'LUE' || upper.contains('LUEFTUNG') || upper.contains('LÜFTUNG')) {
      return 'LÜ';
    }
    if (upper == 'SK' || upper.contains('SCHIEBER')) return 'SK';
    if (upper == 'KANAL') return 'KANAL';
    if (upper == 'DIV' || upper.contains('SONST')) return 'DIV';

    return upper;
  }

  List<String> _safeStringList(dynamic value) {
    if (value is! List) return const <String>[];
    return value
        .map((e) => e?.toString() ?? '')
        .where((e) => e.trim().isNotEmpty)
        .toList();
  }

  Widget _buildSection(String title, List<Widget> children) {
    final visibleChildren = children.where((w) => w is! SizedBox).toList();
    if (visibleChildren.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: _fontSection,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        ...visibleChildren,
      ],
    );
  }

  Widget _buildField(String label, String? value) {
    if (value == null || value.isEmpty || value == '—') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: _fontField, color: Colors.black87),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontSize: _fontField, fontWeight: FontWeight.w700, color: Colors.black87),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherField(Map<String, dynamic> meta) {
    final wetter = (meta['wetter'] as String?)?.trim();
    final temperatur = (meta['temperatur'] as String?)?.trim();

    if ((wetter == null || wetter.isEmpty || wetter == '—') &&
        (temperatur == null || temperatur.isEmpty || temperatur == '—')) {
      return const SizedBox.shrink();
    }

    String value = wetter ?? '—';
    if (temperatur != null && temperatur.isNotEmpty && temperatur != '—') {
      value += ' $temperatur°C';
    }

    return _buildField('Wetter', value);
  }

  Widget _buildKeinBefundField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: _fontField, color: Colors.black87),
          children: [
            const TextSpan(
              text: 'Schäden: ',
              style: TextStyle(fontSize: _fontField, fontWeight: FontWeight.w700, color: Colors.black87),
            ),
            const TextSpan(
              text: '✓ Kein Befund',
              style: TextStyle(fontSize: _fontField, color: Colors.green, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSpecificFields(String typ) {
    final fields = <Widget>[];

    switch (typ) {
      case 'SSK':
        {
          final keinBefund = _currentMeta['keinBefund'] == true;
            final schaeden = (_currentMeta['schaeden'] as List<dynamic>?)
                ?.map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList() ??
              const <String>[];
          final abteilungenText = _getAbteilungenText(_currentMeta);

          fields.addAll([
            _buildField('Deckelart', _deckelartFromMeta(_currentMeta)),
            if (keinBefund)
              _buildKeinBefundField()
            else
              _buildBulletSection('Schäden', schaeden),
            _buildField('Abteilungen', abteilungenText),
            // Nach Schäden: spezifische Leitungsschäden mit Meterangaben anzeigen
            _buildField('Leitung kaputt', _buildLeitungKaputtSummary(_currentMeta)),
            _buildField('Ablaufrinne', _currentMeta['ablaufrinne'] == true ? 'Ja' : null),
            if (_currentMeta['ablaufrinne'] == true && (_currentMeta['ablaufrinneVerbindung'] as String?)?.isNotEmpty == true)
              _buildField('Ablaufrinne Verbindung', _currentMeta['ablaufrinneVerbindung']),
          ]);
        }
        break;

      case 'ES':
        final schaeden = (_currentMeta['schaeden'] as List<dynamic>?)
            ?.map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList() ??
          const <String>[];
        final rfActive = schaeden.contains('Keine Rückenfreiheit');
        final einsteigart = _currentMeta['einsteigart'] as String?;
        final steigeisenStand = _currentMeta['steigeisenStand'] as String?;
        final einsteigartDisplay = (einsteigart == 'Steigeisen' && (steigeisenStand?.isNotEmpty ?? false))
            ? 'Steigeisen – $steigeisenStand'
            : einsteigart;

        {
          final keinBefund = _currentMeta['keinBefund'] == true;
          final abteilungenText = _getAbteilungenText(_currentMeta);
          fields.addAll([
            _buildField('Eingang', _currentMeta['eingang'] as String?),
            _buildField('Einsteigart', einsteigartDisplay),
            _buildField('Deckelart', _currentMeta['deckel'] as String?),
            _buildField('KL', _currentMeta['kl'] as String?),
            if (keinBefund)
              _buildKeinBefundField()
            else
              _buildBulletSection('Schäden', schaeden),
            _buildField('Abteilungen', abteilungenText),
            _buildField('Schacht Durchmesser', _appendCm(_currentMeta['durchmesser'])),
            _buildField('Kanalprofil', _currentMeta['kanalprofil'] as String?),
          ]);
        }

        // ---- RF-abhängige Zusatzdaten ----
        if (rfActive) {
          fields.add(const SizedBox(height: 12));
          fields.add(Text('Maße (cm)', style: Theme.of(context).textTheme.titleSmall));

          fields.addAll([
            _buildField(
              '1. Steigeisen',
              _pairCm(
                _currentMeta['st1Hoehe'],
                _currentMeta['st1Rf'],
              ),
            ),
            _buildField(
              '2. Steigeisen',
              _pairCm(
                _currentMeta['st2Hoehe'],
                _currentMeta['st2Rf'],
              ),
            ),
            _buildField('815 (cm)', _appendCm(_currentMeta['mAusgleich'])),
            _buildField('Konusanfang (cm)', _appendCm(_currentMeta['mKonusAnf'])),
            _buildField('Konusende (cm)', _appendCm(_currentMeta['mKonusEnd'])),
            _buildField('Berme (cm)', _appendCm(_currentMeta['mBerme'])),
            _buildField('Solltiefe (cm)', _appendCm(_currentMeta['mSolltiefe'])),
          ]);

          fields.add(const SizedBox(height: 12));
          fields.add(Text('Örtlichkeit / Oberfläche / Schachtkopf',
              style: Theme.of(context).textTheme.titleSmall));

          fields.addAll([
            _buildField('Örtlichkeit', _currentMeta['oertlichkeit'] as String?),
            _buildField('Örtlichkeit – Bem.', _currentMeta['oertlBem'] as String?),
            _buildField('Oberflächenart', _currentMeta['oberflaeche'] as String?),
            _buildField('Oberfläche – Bem.', _currentMeta['obflBem'] as String?),
            _buildField('Schachtkopfdaten', _currentMeta['schachtkopf'] as String?),
            _buildField('Übergangsplatte', _appendCm(_currentMeta['uebergangsBem'])),
          ]);
        }
        break;

      case 'VS':
        {
          final keinBefund = _currentMeta['keinBefund'] == true;
          final schaeden = (_currentMeta['schaeden'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const <String>[];
          final abteilungenText = _getAbteilungenText(_currentMeta);
          fields.addAll([
            _buildField('Grubentyp', _currentMeta['grubentyp'] as String?),
            _buildField('Deckelart', _currentMeta['deckel'] as String?),
            _buildField('KL', _currentMeta['kl'] as String?),
            if (keinBefund)
              _buildKeinBefundField()
            else
              _buildBulletSection('Schäden', schaeden),
            _buildField('Abteilungen', abteilungenText),
          ]);
        }
        break;

      case 'LÜ':
        final art = (_currentMeta['art'] as String?) ?? (_currentMeta['typ_detail'] as String?);
        final kl = (_currentMeta['kl'] as String?)?.trim();
        final keinBefund = _currentMeta['keinBefund'] == true;
        final schaeden = (_currentMeta['schaeden'] as List<dynamic>?)
                ?.map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList() ??
            const <String>[];
        final abteilungenText = _getAbteilungenText(_currentMeta);

        fields.addAll([
          _buildField('Deckelart', art),
          _buildField('Aufbau', art),
          _buildField('KL', kl),
          if (keinBefund)
            _buildKeinBefundField()
          else
            _buildBulletSection('Schäden', schaeden),
          _buildField('Abteilungen', abteilungenText),
        ]);
        break;

      case 'SK':
        final schaeden = (_currentMeta['schaeden'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
        final keinBefund = _currentMeta['keinBefund'] == true;
        final abteilungenText = _getAbteilungenText(_currentMeta);
        fields.addAll([
          _buildField('Typ', _currentMeta['typ_detail'] as String?),
          _buildField('Zustand', _currentMeta['zustand'] as String?),
          if (keinBefund)
            _buildKeinBefundField()
          else if (schaeden.isNotEmpty)
            _buildField('Schäden', schaeden.join(', ')),
          _buildField('Abteilungen', abteilungenText),
        ]);
        break;

      case 'KANAL':
        {
          final schaeden = (_currentMeta['schaeden'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const <String>[];
          final keinBefund = _currentMeta['keinBefund'] == true;
          final abteilungenText = _getAbteilungenText(_currentMeta);
          final schadensdetails = (_currentMeta['schadensdetails'] as String?)?.trim();
          fields.addAll([
            _buildField('ID-Nummer', _currentMeta['idNr'] as String?),
            _buildField('Kanalprofil', _currentMeta['kanalprofil'] as String?),
            if (keinBefund)
              _buildKeinBefundField()
            else if (schaeden.isNotEmpty)
              _buildBulletSection('Schäden', schaeden),
            _buildField('Schadensdetails', (keinBefund == true) ? null : schadensdetails),
            _buildField('Abteilungen', abteilungenText),
          ]);
        }
        break;

      case 'DIV':
        {
          final schaeden = (_currentMeta['schaeden'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const <String>[];
          final keinBefund = _currentMeta['keinBefund'] == true;
          final schadensdetails = (_currentMeta['schadensdetails'] as String?)?.trim();
          final abteilungenText = _getAbteilungenText(_currentMeta);
          fields.addAll([
            _buildField('Titel', _currentMeta['titel'] as String?),
            _buildField('Beschreibung', _currentMeta['beschreibung'] as String?),
            if (keinBefund)
              _buildKeinBefundField()
            else if (schaeden.isNotEmpty)
              _buildBulletSection('Schäden', schaeden),
            _buildField('Schadensdetails', (keinBefund == true) ? null : schadensdetails),
            _buildField('Abteilungen', abteilungenText),
          ]);
        }
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Details', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...fields,
      ],
    );
  }

  String _objektLabel(String typ) {
    switch (typ) {
      case 'ES':
        return 'Einstiegschacht';
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

  Widget _buildStandardSteckbrief(String typ, List<String> fotos, List<String> videos, List<String> audios) {
    final posNr = _currentMeta['posNr'] as String? ?? '—';
    final idNr = _currentMeta['idNr'] as String? ?? '—';
    final erfasser = _currentMeta['erfasser'] as String?;
    final abteilungen = _getAbteilungenText(_currentMeta);
    final keinBefund = _currentMeta['keinBefund'] == true;
    final schaeden = (_currentMeta['schaeden'] as List<dynamic>?)
            ?.map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>[];

    final gps = _currentMeta['gps'];
    String? gpsLat;
    String? gpsLon;
    if (gps is Map) {
      final g = Map<String, dynamic>.from(gps);
      final lat = (g['lat'] as num?)?.toDouble();
      final lon = (g['lon'] as num?)?.toDouble();
      if (lat != null && lon != null) {
        gpsLat = lat.toStringAsFixed(6);
        gpsLon = lon.toStringAsFixed(6);
      }
    }

    final aufbau = <Widget>[];
    switch (typ) {
      case 'VS':
        aufbau.addAll([
          _buildField('Grubentyp', (_currentMeta['grubentyp'] as String?) ?? (_currentMeta['grubenart'] as String?)),
          _buildField('Deckelart', _currentMeta['deckel'] as String?),
          _buildField('KL', _currentMeta['kl'] as String?),
          _buildField('Tiefe', _joinNonEmpty([
            _appendCm(_currentMeta['tiefe_m']),
            _appendCm(_currentMeta['tiefe_cm']),
          ], separator: ' / ')),
        ]);
        break;
      case 'SSK':
        aufbau.addAll([
          _buildField('Deckelart', _deckelartFromMeta(_currentMeta)),
          _buildField('Ablaufrinne', _currentMeta['ablaufrinne'] == true ? 'Ja' : null),
          _buildField('Ablaufrinne Verbindung', _currentMeta['ablaufrinneVerbindung'] as String?),
        ]);
        break;
      case 'LÜ':
        aufbau.addAll([
          _buildField('Art', (_currentMeta['art'] as String?) ?? (_currentMeta['typ_detail'] as String?)),
          _buildField('KL', _currentMeta['kl'] as String?),
        ]);
        break;
      case 'SK':
        aufbau.addAll([
          _buildField('Typ', _currentMeta['typ_detail'] as String?),
          _buildField('Zustand', _currentMeta['zustand'] as String?),
        ]);
        break;
      case 'KANAL':
        aufbau.addAll([
          _buildField('Kanalprofil', _currentMeta['kanalprofil'] as String?),
          _buildField('ID-Nummer', _currentMeta['idNr'] as String?),
        ]);
        break;
      case 'DIV':
        aufbau.addAll([
          _buildField('Titel', _currentMeta['titel'] as String?),
          _buildField('Beschreibung', _currentMeta['beschreibung'] as String?),
        ]);
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection('Grunddaten', [
          _buildField('Position', posNr),
          _buildField('ID', idNr),
          _buildField('Objekt', _objektLabel(typ)),
          _buildField('Erfasser', erfasser),
          _buildField('GPS Breitengrad', gpsLat),
          _buildField('GPS Längengrad', gpsLon),
        ]),
        _buildSection('Status vor Ort', [
          _buildField('Verfügbarkeit', _getListOrString(_currentMeta['verfuegbarkeit'])),
          _buildField('Status vor Ort', _getListOrString(_currentMeta['statusVorOrt'])),
          _buildField('Abteilung', abteilungen),
        ]),
        _buildSection('Aufbau', aufbau),
        _buildSection('Schäden / Maßnahmen', [
          if (keinBefund) _buildKeinBefundField() else _buildBulletSection('Schäden', schaeden),
          _buildField('Bemerkung', _getFirstNonEmptyString([
            _currentMeta['bemerkung'] as String?,
            _currentMeta['schadensdetails'] as String?,
          ])),
        ]),
        _buildSection('Lage / Örtlichkeit', [
          _buildField('Örtlichkeit', _currentMeta['oertlichkeit'] as String?),
          _buildField('Bemerkung Örtlichkeit', _currentMeta['oertlBem'] as String?),
        ]),
        _buildSection('Oberfläche / Umfeld', [
          _buildField('Oberflächenart', _currentMeta['oberflaeche'] as String?),
          _buildField('Bemerkung Oberfläche', _currentMeta['obflBem'] as String?),
        ]),
        _buildSection('Schachtmasse / Einstieg', [
          _buildField('Konusanfang (cm)', _appendCm(_currentMeta['mKonusAnf'])),
          _buildField('815 (cm)', _appendCm(_currentMeta['mAusgleich'])),
          _buildField('Konusende (cm)', _appendCm(_currentMeta['mKonusEnd'])),
          _buildField('Berme (cm)', _appendCm(_currentMeta['mBerme'])),
          _buildField('Solltiefe (cm)', _appendCm(_currentMeta['mSolltiefe'])),
        ]),
        _buildMediaSection('Medien / Anhänge', fotos: fotos, videos: videos, audios: audios),
      ],
    );
  }

  Widget _buildMediaSection(
    String title, {
    required List<String> fotos,
    required List<String> videos,
    required List<String> audios,
  }) {
    final allRefs = _collectAllAttachmentRefs(fotos: fotos, videos: videos, audios: audios);
    final hints = _bindingKindHints();

    final groups = <String, List<String>>{
      'photo': <String>[],
      'video': <String>[],
      'audio': <String>[],
      'pdf': <String>[],
      'word': <String>[],
      'excel': <String>[],
      'powerpoint': <String>[],
      'other': <String>[],
    };

    for (final ref in allRefs) {
      final kind = _detectAttachmentKind(ref, hint: hints[ref]);
      groups[kind]!.add(ref);
    }

    final mediaChildren = <Widget>[
      _buildAttachmentGroup('Fotos', groups['photo']!, kind: 'image', icon: Icons.image, showPreviews: true),
      _buildAttachmentGroup('Videos', groups['video']!, kind: 'video', icon: Icons.videocam, showPreviews: true),
      _buildAttachmentGroup('Audio-Dateien', groups['audio']!, kind: 'audio', icon: Icons.audiotrack),
      _buildAttachmentGroup('PDF-Dateien', groups['pdf']!, kind: 'pdf', icon: Icons.picture_as_pdf),
      _buildAttachmentGroup('Word-Dateien', groups['word']!, kind: 'document', icon: Icons.description),
      _buildAttachmentGroup('Excel-Dateien', groups['excel']!, kind: 'document', icon: Icons.table_chart),
      _buildAttachmentGroup('PowerPoint-Dateien', groups['powerpoint']!, kind: 'document', icon: Icons.slideshow),
      _buildAttachmentGroup('Sonstige Dateien', groups['other']!, kind: 'document', icon: Icons.insert_drive_file),
    ];

    return _buildSection(title, mediaChildren);
  }

  Widget _buildAttachmentGroup(
    String label,
    List<String> refs, {
    required String kind,
    required IconData icon,
    bool showPreviews = false,
  }) {
    if (refs.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMediaTypeLabel(label, icon, refs.length),
          if (showPreviews)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: refs.map((ref) => _buildMediaThumbnail(ref, kind == 'image')).toList(),
            ),
          if (showPreviews) const SizedBox(height: 4),
          ...refs.asMap().entries.map((entry) {
            final ref = entry.value;
            final fileName = _fileNameFromRef(ref, fallbackIndex: entry.key + 1, kind: kind);
            final rowKind = _detectAttachmentKind(ref);
            return _buildAttachmentRow(
              ref: ref,
              openKind: kind,
              fileName: fileName,
              kindForIcon: rowKind,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMediaTypeLabel(String label, IconData icon, int count) {
    if (count <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.blueGrey.shade700),
          const SizedBox(width: 6),
          Text(
            '$label: $count',
            style: const TextStyle(fontSize: _fontField, fontWeight: FontWeight.w700, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentRow({
    required String ref,
    required String openKind,
    required String fileName,
    required String kindForIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: InkWell(
        onTap: () => _openAttachment(ref, kind: openKind),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              Icon(_iconForKind(kindForIcon), size: 16, color: _colorForKind(kindForIcon)),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_shortText(fileName, 44)} öffnen',
                        style: const TextStyle(fontSize: _fontField, color: Colors.black87),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildTypeBadge(kindForIcon),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.open_in_new, size: 14, color: Colors.blueGrey.shade700),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _collectAllAttachmentRefs({
    required List<String> fotos,
    required List<String> videos,
    required List<String> audios,
  }) {
    final refs = <String>[];
    refs.addAll(fotos);
    refs.addAll(videos);
    refs.addAll(audios);
    refs.addAll(_safeStringList(_currentMeta['mediaFotos']));
    refs.addAll(_safeStringList(_currentMeta['mediaVideos']));
    refs.addAll(_safeStringList(_currentMeta['mediaAudios']));
    refs.addAll(_safeStringList(_currentMeta['mediaPdfs']));

    final bindings = _currentMeta['mediaBindings'];
    if (bindings is List) {
      for (final item in bindings) {
        if (item is! Map) continue;
        final value = (item['value'] ?? item['name'] ?? item['fileName'] ?? '').toString().trim();
        if (value.isNotEmpty) refs.add(value);
      }
    }

    final seen = <String>{};
    final result = <String>[];
    for (final ref in refs) {
      if (ref.trim().isEmpty) continue;
      if (seen.add(ref)) result.add(ref);
    }
    return result;
  }

  Map<String, String> _bindingKindHints() {
    final hints = <String, String>{};
    final bindings = _currentMeta['mediaBindings'];
    if (bindings is! List) return hints;

    for (final item in bindings) {
      if (item is! Map) continue;
      final value = (item['value'] ?? item['name'] ?? item['fileName'] ?? '').toString().trim();
      if (value.isEmpty) continue;
      final kind = (item['kind'] ?? '').toString().trim().toLowerCase();
      if (kind.isNotEmpty) hints[value] = kind;
    }

    return hints;
  }

  String _detectAttachmentKind(String ref, {String? hint}) {
    final lower = ref.trim().toLowerCase();

    if (hint == 'foto') return 'photo';
    if (hint == 'video') return 'video';
    if (hint == 'audio') return 'audio';

    if (lower.startsWith('data:')) {
      if (lower.startsWith('data:image/')) return 'photo';
      if (lower.startsWith('data:video/')) return 'video';
      if (lower.startsWith('data:audio/')) return 'audio';
      if (lower.startsWith('data:application/pdf')) return 'pdf';
      if (lower.contains('wordprocessingml') || lower.contains('msword')) return 'word';
      if (lower.contains('spreadsheetml') || lower.contains('excel')) return 'excel';
      if (lower.contains('presentationml') || lower.contains('powerpoint')) return 'powerpoint';
      return 'other';
    }

    final ext = RegExp(r'\.([a-z0-9]+)(?:\?|#|$)').firstMatch(lower)?.group(1) ?? '';
    if (const {'jpg', 'jpeg', 'png', 'webp', 'heic'}.contains(ext)) return 'photo';
    if (const {'mp4', 'mov', 'avi', 'mkv'}.contains(ext)) return 'video';
    if (const {'mp3', 'wav', 'm4a', 'aac'}.contains(ext)) return 'audio';
    if (ext == 'pdf') return 'pdf';
    if (const {'doc', 'docx'}.contains(ext)) return 'word';
    if (const {'xls', 'xlsx', 'csv'}.contains(ext)) return 'excel';
    if (const {'ppt', 'pptx'}.contains(ext)) return 'powerpoint';
    return 'other';
  }

  IconData _iconForKind(String kind) {
    switch (kind) {
      case 'photo':
        return Icons.image;
      case 'video':
        return Icons.videocam;
      case 'audio':
        return Icons.audiotrack;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'word':
        return Icons.description;
      case 'excel':
        return Icons.table_chart;
      case 'powerpoint':
        return Icons.slideshow;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _colorForKind(String kind) {
    switch (kind) {
      case 'photo':
        return Colors.lightBlue.shade700;
      case 'video':
        return Colors.indigo.shade600;
      case 'pdf':
        return Colors.red.shade600;
      case 'word':
        return Colors.blue.shade700;
      case 'excel':
        return Colors.green.shade700;
      case 'powerpoint':
        return Colors.orange.shade700;
      case 'audio':
        return Colors.deepPurple.shade500;
      default:
        return Colors.blueGrey.shade700;
    }
  }

  Widget _buildTypeBadge(String kind) {
    final color = _colorForKind(kind);
    final label = _badgeLabelForKind(kind);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.5), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  String _badgeLabelForKind(String kind) {
    switch (kind) {
      case 'photo':
        return 'FOTO';
      case 'video':
        return 'VIDEO';
      case 'audio':
        return 'AUDIO';
      case 'pdf':
        return 'PDF';
      case 'word':
        return 'WORD';
      case 'excel':
        return 'EXCEL';
      case 'powerpoint':
        return 'PPT';
      default:
        return 'DATEI';
    }
  }

  String _fileNameFromRef(String ref, {required int fallbackIndex, required String kind}) {
    final normalized = ref.split('?').first.split('#').first.replaceAll('\\', '/').trim();
    if (normalized.isNotEmpty && !normalized.startsWith('data:')) {
      final name = normalized.split('/').last.trim();
      if (name.isNotEmpty) return name;
    }

    if (normalized.startsWith('data:')) {
      final mime = RegExp(r'^data:([^;,]+)').firstMatch(normalized)?.group(1) ?? '';
      final ext = _extFromMime(mime, kind: kind);
      return 'Anhang_$fallbackIndex.$ext';
    }

    return 'Anhang_$fallbackIndex';
  }

  String _extFromMime(String mime, {required String kind}) {
    final m = mime.toLowerCase();
    if (m.contains('jpeg')) return 'jpg';
    if (m.contains('png')) return 'png';
    if (m.contains('webp')) return 'webp';
    if (m.contains('heic')) return 'heic';
    if (m.contains('mp4')) return 'mp4';
    if (m.contains('quicktime')) return 'mov';
    if (m.contains('mpeg') || m.contains('mp3')) return 'mp3';
    if (m.contains('wav')) return 'wav';
    if (m.contains('pdf')) return 'pdf';
    if (m.contains('word')) return 'docx';
    if (m.contains('excel') || m.contains('spreadsheet')) return 'xlsx';
    if (m.contains('powerpoint') || m.contains('presentation')) return 'pptx';
    switch (kind) {
      case 'image':
        return 'jpg';
      case 'video':
        return 'mp4';
      case 'audio':
        return 'mp3';
      case 'pdf':
        return 'pdf';
      default:
        return 'dat';
    }
  }

  String _shortText(String value, int max) {
    if (value.length <= max) return value;
    return '${value.substring(0, max - 1)}…';
  }

  Future<void> _openAttachment(String ref, {required String kind}) async {
    final value = ref.trim();
    if (value.isEmpty) return;

    if (kind == 'image') {
      _showMediaFullscreen(value, true);
      return;
    }
    if (kind == 'video') {
      _showMediaFullscreen(value, false);
      return;
    }
    if (kind == 'audio') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Audio'),
          content: _buildAudioPlayer(value),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Schließen'),
            ),
          ],
        ),
      );
      return;
    }

    final uriValue = value.startsWith('http') || value.startsWith('data:') ? value : _resolveWebSrc(value);
    final uri = (uriValue.startsWith('http') || uriValue.startsWith('data:'))
      ? Uri.tryParse(uriValue)
      : Uri.base.resolveUri(Uri.parse(uriValue));
    if (uri == null) return;

    var opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (!opened && kIsWeb) {
      // Web fallback: enforce a new browser tab/window.
      opened = await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
        webOnlyWindowName: '_blank',
      );
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Anhang konnte nicht geöffnet werden.')),
      );
    }
  }

  Widget _buildEsSteckbrief(List<String> fotos, List<String> videos, List<String> audios) {
    final posNr = _currentMeta['posNr'] as String? ?? '—';
    final idNr = _currentMeta['idNr'] as String? ?? '—';
    final erfasser = _currentMeta['erfasser'] as String?;
    final objekt = 'Einstiegschacht';
    final abteilung = _getAbteilungenText(_currentMeta) ?? '—';
    final deckel = _firstNonEmpty([
      _currentMeta['deckel'] as String?,
      _currentMeta['deckelart'] as String?,
      _currentMeta['Deckelart'] as String?,
    ]);
    final schachtkopf = _firstNonEmpty([
      _currentMeta['schachtkopf'] as String?,
      _currentMeta['schachtkopfart'] as String?,
    ]);
    final eingangsart = _currentMeta['eingang'] as String?;
    final einsteigart = _currentMeta['einsteigart'] as String?;
    final steigeisenStand = _currentMeta['steigeisenStand'] as String?;
    final einsteigartDisplay = (einsteigart == 'Steigeisen' && (steigeisenStand?.isNotEmpty ?? false))
        ? 'Steigeisen ${steigeisenStand!.toLowerCase()}'
        : einsteigart;
    final kl = _currentMeta['kl'] as String?;
    final verfu = _getListOrString(_currentMeta['verfuegbarkeit']);
    final status = _getListOrString(_currentMeta['statusVorOrt']);
          final schaeden = (_currentMeta['schaeden'] as List<dynamic>?)?.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList() ?? const <String>[];
    final keinBefund = _currentMeta['keinBefund'] == true;
    final oertlichkeit = _currentMeta['oertlichkeit'] as String?;
    final oertlBem = _currentMeta['oertlBem'] as String?;
    final oberflaeche = _currentMeta['oberflaeche'] as String?;
    final obflBem = _currentMeta['obflBem'] as String?;
    final gps = _currentMeta['gps'];
    String? gpsLat;
    String? gpsLon;
    if (gps is Map) {
      try {
        final g = Map<String, dynamic>.from(gps);
        final lat = (g['lat'] as num?)?.toDouble();
        final lon = (g['lon'] as num?)?.toDouble();
        if (lat != null && lon != null) {
          gpsLat = lat.toStringAsFixed(6);
          gpsLon = lon.toStringAsFixed(6);
        }
      } catch (_) {}
    }

    final st1Hoehe = _currentMeta['st1Hoehe'] ?? _currentMeta['steighoehe_1_steigeisen'];
    final st1Rf = _currentMeta['st1Rf'] ?? _currentMeta['rueckenfreiheit_1_steigeisen'];
    final st2Hoehe = _currentMeta['st2Hoehe'] ?? _currentMeta['steighoehe_2_steigeisen'];
    final st2Rf = _currentMeta['st2Rf'] ?? _currentMeta['rueckenfreiheit_2_steigeisen'];
    final konusAnf = _currentMeta['mKonusAnf'] ?? _currentMeta['konusanfang'];
    final mass815 = _currentMeta['mAusgleich'] ?? _currentMeta['mass_815'];
    final konusEnd = _currentMeta['mKonusEnd'] ?? _currentMeta['konusende'];
    final berme = _currentMeta['mBerme'] ?? _currentMeta['berme'];
    final solltiefe = _currentMeta['mSolltiefe'] ?? _currentMeta['solltiefe'];

    Widget section(String title, List<Widget> children) => _buildSection(title, children);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        section('Grunddaten', [
          _buildField('Position', posNr),
          _buildField('ID', idNr),
          _buildField('Objekt', objekt),
          _buildField('Erfasser', erfasser),
          _buildField('GPS Breitengrad', gpsLat),
          _buildField('GPS Längengrad', gpsLon),
        ]),
        const SizedBox(height: 16),
        section('Status vor Ort', [
          _buildField('Verfügbarkeit', verfu),
          _buildField('Status vor Ort', status),
          _buildField('Abteilung', abteilung),
        ]),
        section('Aufbau', [
          _buildField('Eingangsart', eingangsart),
          _buildField('Einsteigart', einsteigartDisplay),
          _buildField('Deckelart', deckel),
          _buildField('KL', kl),
          _buildField('Schachtkopfart', schachtkopf),
          _buildField('Objektaufbau', _joinNonEmpty([
            eingangsart,
            einsteigartDisplay,
            deckel,
            kl == null || kl.trim().isEmpty ? null : 'KL $kl',
            schachtkopf,
          ])),
        ]),
        section('Schäden / Maßnahmen', [
          if (keinBefund) _buildKeinBefundField() else _buildBulletSection('Schäden', schaeden),
          _buildField('Bemerkung', _getFirstNonEmptyString([_currentMeta['bemerkung'] as String?, _currentMeta['schadensdetails'] as String?])),
        ]),
        section('Lage / Örtlichkeit', [
          _buildField('Örtlichkeit', oertlichkeit),
          _buildField('Bemerkung Örtlichkeit', oertlBem),
        ]),
        section('Oberfläche / Umfeld', [
          _buildField('Oberflächenart', oberflaeche),
          _buildField('Bemerkung Oberfläche', obflBem),
        ]),
        section('Schachtmaße / Einstieg', [
          _buildField('Steigeisen Steighöhe (cm)', _appendCm(st1Hoehe)),
          _buildField('Steigeisen Rückenfreiheit (cm)', _appendCm(st1Rf)),
          _buildField('Steigeisen Steighöhe (cm)', _appendCm(st2Hoehe)),
          _buildField('Steigeisen Rückenfreiheit (cm)', _appendCm(st2Rf)),
          _buildField('Konusanfang (cm)', _appendCm(konusAnf)),
          _buildField('815 (cm)', _firstNonEmpty([mass815?.toString(), null])),
          _buildField('Konusende (cm)', _appendCm(konusEnd)),
          _buildField('Berme (cm)', _firstNonEmpty([berme?.toString(), null])),
          _buildField('Solltiefe (cm)', _appendCm(solltiefe)),
        ]),
        _buildMediaSection('Medien / Anhänge', fotos: fotos, videos: videos, audios: audios),
      ],
    );
  }

  Widget _buildMediaThumbnail(String dataUrl, bool isImage) {
    final isData = _isDataUrl(dataUrl);
    return GestureDetector(
      onTap: () => _showMediaFullscreen(dataUrl, isImage),
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: isImage
            ? (isData
                ? Image.memory(
                    _dataUrlToBytes(dataUrl),
                    fit: BoxFit.cover,
                    width: 48,
                    height: 48,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image),
                  )
                : (kIsWeb
                    ? Image.network(
                        _resolveWebSrc(dataUrl),
                        fit: BoxFit.cover,
                        width: 48,
                        height: 48,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image),
                      )
                    : const Icon(Icons.broken_image, size: 32)))
            : const Center(child: Icon(Icons.play_circle_outline, size: 40)),
      ),
    );
  }

  void _showMediaFullscreen(String dataUrl, bool isImage) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: isImage
                  ? InteractiveViewer(
                      panEnabled: true,
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: _isDataUrl(dataUrl)
                        ? Image.memory(_dataUrlToBytes(dataUrl), fit: BoxFit.contain)
                        : (kIsWeb
                          ? Image.network(_resolveWebSrc(dataUrl), fit: BoxFit.contain)
                          : const Icon(Icons.broken_image, size: 128)),
                    )
                  : _buildVideoPlayer(dataUrl),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer(String dataUrl) {
    // Delegiere an die plattform-spezifische Video-View-Factory
    return buildVideoPlayer(dataUrl);
  }

  Uint8List _dataUrlToBytes(String dataUrl) {
    if (!_isDataUrl(dataUrl)) return Uint8List(0);
    final base64Str = dataUrl.split(',').last;
    return base64Decode(base64Str);
  }

  bool _isDataUrl(String value) => value.startsWith('data:');

  String _resolveWebSrc(String value) {
    final normalized = value.replaceAll('\\', '/');
    if (normalized.startsWith('data:') || normalized.startsWith('http')) return normalized;
    if (normalized.startsWith('assets/')) return normalized;
    // Prefer the Flutter web asset path; fallback to raw value
    return 'assets/$normalized';
  }

  String? _formatDateTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return null;
    try {
      final dt = DateTime.parse(isoString);
      final datePart = DateFormat('dd.MM.yyyy').format(dt);
      final timePart = DateFormat('HH:mm').format(dt);
      return '$datePart $timePart';
    } catch (_) {
      return isoString;
    }
  }

  String? _getListOrString(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      return value.join(', ');
    }
    return value.toString();
  }

  String? _getAbteilungenText(Map<String, dynamic> meta) {
    final raw = meta['abteilungen'] ?? meta['abteilungsMarker'];
    if (raw == null) return null;
    if (raw is List) {
      final list = raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (list.isEmpty) return null;
      return list.join(', ');
    }
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    final parts = s
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return null;
    return parts.join(', ');
  }

  String _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final text = value?.trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '—';
  }

  String? _joinNonEmpty(List<String?> values, {String separator = ' / '}) {
    final parts = <String>[];
    for (final value in values) {
      final text = value?.trim() ?? '';
      if (text.isNotEmpty) parts.add(text);
    }
    if (parts.isEmpty) return null;
    return parts.join(separator);
  }

  String? _getFirstNonEmptyString(List<String?> values) {
    for (final value in values) {
      final text = value?.trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  Widget _buildBulletSection(String label, List<String> items) {
    final visible = items
        .map((e) => e.trim().replaceFirst(RegExp(r'^\d+\.\s*'), ''))
        .where((e) => e.isNotEmpty)
        .toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: _fontField, color: Colors.black87),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontSize: _fontField, fontWeight: FontWeight.w700, color: Colors.black87),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          ...visible.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  item,
                  style: const TextStyle(fontSize: _fontField, color: Colors.black87),
                ),
              )),
        ],
      ),
    );
  }

  int _countPdf(Map<String, dynamic> meta) {
    final pdfs = _safeStringList(meta['mediaPdfs']);
    return pdfs.length;
  }

  int _countByType(List<String> extensions, dynamic mediaPdfs, dynamic mediaBindings) {
    final values = <String>[..._safeStringList(mediaPdfs)];
    if (mediaBindings is List) {
      for (final item in mediaBindings) {
        if (item is Map) {
          final value = (item['value'] ?? '').toString().trim().toLowerCase();
          if (extensions.any((ext) => value.endsWith('.$ext'))) {
            values.add(value);
          }
        }
      }
    }
    return values.where((value) => extensions.any((ext) => value.toLowerCase().endsWith('.$ext'))).length;
  }

  String? _appendCm(dynamic v) {
    final t = (v ?? '').toString().trim();
    if (t.isEmpty) return null;
    return '$t cm';
  }

  String? _pairCm(dynamic hoehe, dynamic rf) {
    final h = (hoehe ?? '').toString().trim();
    final r = (rf ?? '').toString().trim();
    if (h.isEmpty && r.isEmpty) return null;
    return 'Höhe ${h.isNotEmpty ? '$h cm' : '–'} | RF ${r.isNotEmpty ? '$r cm' : '–'}';
  }

  String? _buildLeitungKaputtSummary(Map<String, dynamic> meta) {
    final schaeden = (meta['schaeden'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [];
    final hasLeitungKaputt = schaeden.any((s) => s.toLowerCase() == 'leitung kaputt');
    if (!hasLeitungKaputt) return null;

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
    return pairs.join(', ');
  }
  Widget _buildAudioPlayer(String audioPath) {
    final fileName = audioPath.contains('/') ? audioPath.split('/').last : audioPath;
    
    return AudioPlayerWidget(
      audioPath: audioPath,
      fileName: fileName,
    );
  }

  // ...existing code...

  String? _deckelartFromMeta(Map<String, dynamic> meta) {
    final fromSskTyp = (meta['sskTyp'] as String?)?.trim();
    if (fromSskTyp != null && fromSskTyp.isNotEmpty) return fromSskTyp;
    final gruppe = (meta['gruppe'] as String?)?.trim() ?? '';
    final auspr = (meta['auspraegung'] as String?)?.trim() ?? '';
    if (gruppe.isEmpty || auspr.isEmpty) return null;
    if (gruppe == 'SSK Münchner Modell') return 'Münchner Modell – $auspr';
    if (auspr.toLowerCase().startsWith('bemerkung:')) {
      final txt = auspr.substring('Bemerkung:'.length).trim();
      return 'Weitere Hersteller – ${txt.isEmpty ? 'Bemerkung' : txt}';
    }
    return 'Weitere Hersteller – $auspr';
  }
}
