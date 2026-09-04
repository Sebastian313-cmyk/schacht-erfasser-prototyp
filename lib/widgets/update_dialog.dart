import 'package:flutter/material.dart';
import '../services/update_service.dart';

/// ============================================================
/// UPDATE DIALOG - Zeigt verfügbare Updates an
/// ============================================================

class UpdateDialog extends StatelessWidget {
  final UpdateInfo updateInfo;
  final VoidCallback? onLater;

  const UpdateDialog({
    super.key,
    required this.updateInfo,
    this.onLater,
  });

  @override
  Widget build(BuildContext context) {
    final platform = UpdateService.getPlatformName();

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.system_update, color: Colors.blue),
          const SizedBox(width: 12),
          Text(updateInfo.forceUpdate ? 'Update erforderlich' : 'Update verfügbar'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Neue Version: ${updateInfo.latestVersion}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Aktuelle Version: ${updateInfo.currentVersion}',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            if (updateInfo.releaseNotes.isNotEmpty) ...[
              const Text(
                'Änderungen:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  updateInfo.releaseNotes,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              'Plattform: $platform',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            if (updateInfo.forceUpdate) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red[300]!),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Dieses Update ist verpflichtend.',
                        style: TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (!updateInfo.forceUpdate && onLater != null)
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onLater?.call();
            },
            child: const Text('Später'),
          ),
        FilledButton.icon(
          icon: const Icon(Icons.download),
          label: const Text('Jetzt aktualisieren'),
          onPressed: () async {
            Navigator.pop(context);
            try {
              await UpdateService.performUpdate(updateInfo);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Update-Fehler: $e')),
                );
              }
            }
          },
        ),
      ],
    );
  }
}

/// ============================================================
/// UPDATE CHECKER WIDGET - Automatischer Update-Check beim Start
/// ============================================================

class UpdateChecker extends StatefulWidget {
  final Widget child;
  final Duration checkInterval;
  final bool checkOnStart;

  const UpdateChecker({
    super.key,
    required this.child,
    this.checkInterval = const Duration(hours: 24),
    this.checkOnStart = true,
  });

  @override
  State<UpdateChecker> createState() => _UpdateCheckerState();
}

class _UpdateCheckerState extends State<UpdateChecker> {
  @override
  void initState() {
    super.initState();
    if (widget.checkOnStart) {
      _checkForUpdates();
    }
  }

  Future<void> _checkForUpdates() async {
    // Kurz warten, damit UI geladen ist
    await Future.delayed(const Duration(seconds: 2));

    final updateInfo = await UpdateService.checkForUpdates();
    if (updateInfo != null && mounted) {
      _showUpdateDialog(updateInfo);
    }
  }

  void _showUpdateDialog(UpdateInfo info) {
    showDialog(
      context: context,
      barrierDismissible: !info.forceUpdate,
      builder: (ctx) => UpdateDialog(
        updateInfo: info,
        onLater: () {
          // Später erinnern
          Future.delayed(widget.checkInterval, _checkForUpdates);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
