import 'package:flutter/material.dart';

import '../services/handoff_rules_service.dart';
import '../services/session_store.dart';
import '../services/speicher_service.dart';

class SchnittstellenScreen extends StatefulWidget {
  const SchnittstellenScreen({super.key});

  @override
  State<SchnittstellenScreen> createState() => _SchnittstellenScreenState();
}

class _SchnittstellenScreenState extends State<SchnittstellenScreen> {
  late Future<_SchnittstellenOverview> _overviewFuture;

  @override
  void initState() {
    super.initState();
    _overviewFuture = _loadOverview();
  }

  Future<_SchnittstellenOverview> _loadOverview() async {
    final session = await SessionStore.load();
    final evnr = session?.evnr.trim() ?? '';
    final strasse = session?.strasse.trim() ?? '';
    final entries = evnr.isEmpty
        ? <Map<String, dynamic>>[]
        : await SpeicherService.ladeEintraegeFuerEvNr(
            evnr,
            strasse: strasse.isEmpty ? null : strasse,
          );
    final nis = evnr.isEmpty
        ? null
        : await SessionStore.loadNisPlanForEvnr(evnr);
    final pending = await SpeicherService.loadReadyToRetry();
    final pendingCount = pending.values.fold<int>(
      0,
      (sum, list) => sum + list.length,
    );
    final handoffSummary = HandoffRulesService.buildSummary(entries);

    return _SchnittstellenOverview(
      evnr: evnr,
      strasse: strasse,
      positionCount: entries.length,
      hasNisPlan: nis != null,
      pendingCount: pendingCount,
      handoffSummary: handoffSummary,
    );
  }

  void _reload() {
    setState(() {
      _overviewFuture = _loadOverview();
    });
  }

  void _showPreparedMessage(String systemName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$systemName ist vorbereitet. Die echte Verbindung wird ergänzt, sobald Zugang/API oder Importformat vorliegt.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schnittstellen'),
        actions: [
          IconButton(
            tooltip: 'Aktualisieren',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<_SchnittstellenOverview>(
        future: _overviewFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final overview = snapshot.data ?? const _SchnittstellenOverview();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _CurrentBatchCard(overview: overview),
              const SizedBox(height: 12),
              _AutomaticHandoffCard(summary: overview.handoffSummary),
              const SizedBox(height: 12),
              _InterfaceCard(
                title: 'Small World / NIS-Abteilung',
                icon: Icons.map_outlined,
                status: 'Regel aktiv',
                statusColor: Colors.green,
                details: const [
                  'Nicht im NIS wird automatisch für Small World vorgemerkt',
                  'gibt es nicht wird automatisch für die NIS-Abteilung vorgemerkt',
                  'Leitungsverlauf ergänzen wird für Small World vorgemerkt',
                ],
                onPressed: () =>
                    _showPreparedMessage('Small World / NIS-Abteilung'),
              ),
              const SizedBox(height: 12),
              _InterfaceCard(
                title: 'Kanio Aufträge',
                icon: Icons.assignment_outlined,
                status: 'Regel aktiv',
                statusColor: Colors.green,
                details: const [
                  'Schäden werden automatisch für Kanio-Aufträge vorgemerkt',
                  'Kein Befund wird nicht als Schaden übertragen',
                  'Position, Objektart, EVNr, Abteilung und Bemerkung bleiben enthalten',
                ],
                onPressed: () => _showPreparedMessage('Kanio Aufträge'),
              ),
              const SizedBox(height: 12),
              _InterfaceCard(
                title: 'Content-Server',
                icon: Icons.folder_copy_outlined,
                status: 'Vorbereitet',
                statusColor: Colors.orange,
                details: const [
                  'Alle Berichte, Steckbriefe und Medien werden dort gespeichert',
                  'EV-, NIS-, Schriftverkehr-, Auftrags- und Erfassungsordner',
                  'Server-Ablage für die komplette EVNr-Struktur',
                ],
                onPressed: () => _showPreparedMessage('Content-Server'),
              ),
              const SizedBox(height: 12),
              const _NextStepCard(),
            ],
          );
        },
      ),
    );
  }
}

class _CurrentBatchCard extends StatelessWidget {
  final _SchnittstellenOverview overview;

  const _CurrentBatchCard({required this.overview});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.hub_outlined, color: Colors.blueGrey.shade700),
                const SizedBox(width: 8),
                Text('Aktuelle Übergabe', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(
              label: 'EVNr',
              value: overview.evnr.isEmpty ? '-' : overview.evnr,
            ),
            _InfoRow(
              label: 'Straße',
              value: overview.strasse.isEmpty ? '-' : overview.strasse,
            ),
            _InfoRow(
              label: 'Positionen',
              value: overview.positionCount.toString(),
            ),
            _InfoRow(
              label: 'NIS-Plan',
              value: overview.hasNisPlan ? 'vorhanden' : 'nicht hinterlegt',
            ),
            _InfoRow(
              label: 'Wartende Änderungen',
              value: overview.pendingCount.toString(),
            ),
          ],
        ),
      ),
    );
  }
}

class _AutomaticHandoffCard extends StatelessWidget {
  final HandoffSummary summary;

  const _AutomaticHandoffCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.alt_route, color: Colors.blueGrey.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Automatische Übergaben',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                _StatusPill(
                  label: summary.isEmpty
                      ? 'Keine offen'
                      : '${summary.totalCount} offen',
                  color: summary.isEmpty ? Colors.green : Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 10),
            _InfoRow(
              label: 'Small World / NIS',
              value: '${summary.nisItems.length} Positionen',
            ),
            _InfoRow(
              label: 'Kanio Aufträge',
              value: '${summary.kanioItems.length} Positionen',
            ),
            if (summary.isEmpty) ...[
              const SizedBox(height: 6),
              const Text(
                'Für die aktuelle EVNr ist keine automatische Übergabe nötig.',
              ),
            ] else ...[
              const SizedBox(height: 10),
              _HandoffGroup(
                title: 'An Small World / NIS-Abteilung',
                items: summary.nisItems,
                emptyText: 'Keine Small-World/NIS-Übergabe erkannt.',
              ),
              const SizedBox(height: 8),
              _HandoffGroup(
                title: 'An Kanio Aufträge',
                items: summary.kanioItems,
                emptyText: 'Keine Kanio-Auftragsübergabe erkannt.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HandoffGroup extends StatelessWidget {
  final String title;
  final List<HandoffItem> items;
  final String emptyText;

  const _HandoffGroup({
    required this.title,
    required this.items,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    final visibleItems = items.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        if (items.isEmpty)
          Text(emptyText, style: TextStyle(color: Colors.grey.shade700))
        else
          for (final item in visibleItems)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.arrow_right, size: 18),
                  const SizedBox(width: 4),
                  Expanded(child: Text('${item.title}: ${item.reasonsText}')),
                ],
              ),
            ),
        if (items.length > visibleItems.length)
          Text(
            '+ ${items.length - visibleItems.length} weitere Positionen',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
      ],
    );
  }
}

class _InterfaceCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String status;
  final Color statusColor;
  final List<String> details;
  final VoidCallback onPressed;

  const _InterfaceCard({
    required this.title,
    required this.icon,
    required this.status,
    required this.statusColor,
    required this.details,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.blueGrey.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
                _StatusPill(label: status, color: statusColor),
              ],
            ),
            const SizedBox(height: 10),
            for (final detail in details)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check, size: 16, color: Colors.green.shade700),
                    const SizedBox(width: 6),
                    Expanded(child: Text(detail)),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.settings_ethernet),
                label: const Text('Schnittstelle öffnen'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextStepCard extends StatelessWidget {
  const _NextStepCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.blueGrey.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: const Padding(
        padding: EdgeInsets.all(14),
        child: Text(
          'Für die echte Direktübertragung brauchen wir später: Small-World-Zugang der NIS-Abteilung, Kanio-Auftragsfelder, Content-Server-Ablageort, Berechtigungen und die Freigabe, was die App automatisch senden darf.',
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color.shade700OrSelf,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 145,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _SchnittstellenOverview {
  final String evnr;
  final String strasse;
  final int positionCount;
  final bool hasNisPlan;
  final int pendingCount;
  final HandoffSummary handoffSummary;

  const _SchnittstellenOverview({
    this.evnr = '',
    this.strasse = '',
    this.positionCount = 0,
    this.hasNisPlan = false,
    this.pendingCount = 0,
    this.handoffSummary = const HandoffSummary(),
  });
}

extension on Color {
  Color get shade700OrSelf {
    final color = this;
    if (color == Colors.orange) return Colors.orange.shade800;
    if (color == Colors.green) return Colors.green.shade800;
    if (color == Colors.red) return Colors.red.shade800;
    if (color == Colors.blue) return Colors.blue.shade800;
    return color;
  }
}
