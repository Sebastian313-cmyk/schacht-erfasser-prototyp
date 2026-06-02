import 'package:flutter/material.dart';
import '../services/export_plan_service.dart';
import 'audio_player_widget.dart';

/// Dialog zur Vorschau des Exports (Ordnerstruktur + Medien) mit Auswahl.
class ExportPreviewDialog extends StatefulWidget {
  final ExportPlan initialPlan;
  final void Function(ExportPlan confirmed) onConfirm;
  const ExportPreviewDialog({super.key, required this.initialPlan, required this.onConfirm});

  @override
  State<ExportPreviewDialog> createState() => _ExportPreviewDialogState();
}

class _ExportPreviewDialogState extends State<ExportPreviewDialog> {
  late ExportPlan _plan;

  @override
  void initState() {
    super.initState();
    _plan = widget.initialPlan;
  }

  @override
  Widget build(BuildContext context) {
    final fotoCount = _plan.positions.fold<int>(0, (p, c) => p + c.fotos.where((m) => m.planned).length);
    final videoCount = _plan.positions.fold<int>(0, (p, c) => p + c.videos.where((m) => m.planned).length);
    final audioCount = _plan.positions.fold<int>(0, (p, c) => p + c.audios.where((m) => m.planned).length);
    return AlertDialog(
      title: const Text('Export Vorschau'),
      content: SizedBox(
        width: 560,
        child: ListView(
          children: [
            Text('Root-Ordner: ${_plan.rootFolder}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('EVNr: ${_plan.evnr}  •  Einträge: ${_plan.positions.length}'),
            Text('Ausgewählte Medien: $fotoCount Foto(s), $videoCount Video(s), $audioCount Audio(s)'),
            const Divider(height: 20),
            CheckboxListTile(
              value: _plan.gesamtPdfPlanned,
              onChanged: (v) => setState(() => _plan = ExportPlan(
                    rootFolder: _plan.rootFolder,
                    evnr: _plan.evnr,
                    strasse: _plan.strasse,
                    gesamtPdfPlanned: v ?? true,
                    positions: _plan.positions,
                  )),
              title: const Text('Gesamt_Bericht.pdf'),
              subtitle: const Text('A3 Landschaft – Übersicht aller Positionen'),
            ),
            const Divider(),
            ..._plan.positions.map((pos) => ExpansionTile(
                  title: Text('Pos_${pos.positionsnummer ?? pos.index}'),
                  subtitle: Text(pos.entry?.titel ?? (pos.meta != null ? (pos.meta!['titel'] as String?) : null) ?? 'ohne Titel'),
                  children: [
                    CheckboxListTile(
                      value: pos.steckbriefPlanned,
                      onChanged: (v) => setState(() => pos.steckbriefPlanned = v ?? true),
                      title: const Text('Steckbrief.pdf'),
                    ),
                    if (pos.fotos.isNotEmpty) _mediaWrap('Fotos', pos.fotos),
                    if (pos.videos.isNotEmpty) _mediaWrap('Videos', pos.videos),
                    if (pos.audios.isNotEmpty) _audioWrap('Audios', pos.audios),
                  ],
                )),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            widget.onConfirm(_plan);
            Navigator.pop(context);
          },
          icon: const Icon(Icons.download),
          label: const Text('Export starten'),
        )
      ],
    );
  }

  Widget _mediaWrap(String label, List<PlannedMedia> list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label (${list.where((m) => m.planned).length}/${list.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: list.map((m) => SizedBox(
                width: 90,
                child: Column(
                  children: [
                    Checkbox(
                      value: m.planned,
                      onChanged: (v) => setState(() => m.planned = v ?? true),
                    ),
                    _thumb(m),
                  ],
                ),
              )).toList(),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _audioWrap(String label, List<PlannedMedia> list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label (${list.where((m) => m.planned).length}/${list.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: list.where((m) => m.planned).map((m) {
            final fileName = m.dataUrl.contains('/') ? m.dataUrl.split('/').last : m.dataUrl;
            return SizedBox(
              width: 220,
              child: Card(
                elevation: 1,
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: AudioPlayerWidget(
                    audioPath: m.dataUrl,
                    fileName: fileName,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _thumb(PlannedMedia m) {
    if (m.type == MediaType.photo) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network(
          m.dataUrl,
          height: 60,
          width: 60,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 40),
        ),
      );
    }
    return Container(
      height: 60,
      width: 60,
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Icon(Icons.videocam, color: Colors.deepPurple),
    );
  }
}
