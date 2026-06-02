import '../models/base_entry.dart';

/// Einfache In-Memory-Repository-Implementierung
/// - Jedes Objekt hat seine EVNr (e.evnr)
/// - byEvNr filtert anhand dieses Feldes
/// - allEvNr liefert die vorhandenen unterschiedlichen EVNr
class Repository {
  Repository._internal();
  static final Repository instance = Repository._internal();

  final List<BaseEntry> _entries = <BaseEntry>[];

  String newId() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<void> add(BaseEntry e) async {
    _entries.removeWhere((old) => old.id == e.id);
    _entries.add(e);
  }

  Future<List<BaseEntry>> byEvNr(String evnr) async {
    final v = evnr.trim();
    return _entries.where((e) => (e.evnr).trim() == v).toList();
  }

  Future<List<String>> allEvNr() async {
    final set = <String>{};
    for (final e in _entries) {
      final v = e.evnr.trim();
      if (v.isNotEmpty) set.add(v);
    }
    final list = set.toList();
    list.sort();
    return list;
  }

  /// Löscht alle Einträge für eine bestimmte EVNr aus dem Repository
  Future<void> deleteAllForEvNr(String evnr) async {
    final v = evnr.trim();
    _entries.removeWhere((e) => e.evnr.trim() == v);
  }
}
