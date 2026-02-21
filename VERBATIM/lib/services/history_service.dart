import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../models/history_entry.dart';

const _maxEntries = 500;

class HistoryService {
  String? _historyPath;

  Future<String> _getPath() async {
    if (_historyPath != null) return _historyPath!;
    final dir = await getApplicationSupportDirectory();
    _historyPath = p.join(dir.path, 'history.json');
    return _historyPath!;
  }

  Future<List<HistoryEntry>> load() async {
    try {
      final path = await _getPath();
      final file = File(path);
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      final list = jsonDecode(content) as List<dynamic>;
      return list
          .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[HistoryService] Failed to load history: $e');
      return [];
    }
  }

  Future<void> save(List<HistoryEntry> entries) async {
    try {
      final path = await _getPath();
      final file = File(path);
      await file.parent.create(recursive: true);
      final trimmed = entries.length > _maxEntries
          ? entries.sublist(entries.length - _maxEntries)
          : entries;
      await file.writeAsString(jsonEncode(trimmed.map((e) => e.toJson()).toList()));
    } catch (e) {
      debugPrint('[HistoryService] Failed to save history: $e');
    }
  }

  Future<List<HistoryEntry>> addEntry(
    List<HistoryEntry> current,
    HistoryEntry entry,
  ) async {
    final updated = [...current, entry];
    await save(updated);
    return updated;
  }

  Future<List<HistoryEntry>> deleteEntry(
    List<HistoryEntry> current,
    String id,
  ) async {
    final updated = current.where((e) => e.id != id).toList();
    await save(updated);
    return updated;
  }

  Future<List<HistoryEntry>> clearAll() async {
    await save([]);
    return [];
  }
}
