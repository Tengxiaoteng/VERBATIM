import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../models/app_settings.dart';

class SettingsService {
  String? _settingsPath;

  Future<String> _getSettingsPath() async {
    if (_settingsPath != null) return _settingsPath!;
    final dir = await getApplicationSupportDirectory();
    _settingsPath = p.join(dir.path, 'settings.json');
    return _settingsPath!;
  }

  Future<AppSettings> load() async {
    try {
      final path = await _getSettingsPath();
      final file = File(path);
      if (!await file.exists()) {
        return AppSettings.defaults();
      }
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return AppSettings.fromJson(json);
    } catch (e) {
      debugPrint('[SettingsService] Failed to load settings: $e');
      return AppSettings.defaults();
    }
  }

  Future<void> save(AppSettings settings) async {
    try {
      final path = await _getSettingsPath();
      final file = File(path);
      await file.parent.create(recursive: true);
      final json = jsonEncode(settings.toJson());
      await file.writeAsString(json);
    } catch (e) {
      debugPrint('[SettingsService] Failed to save settings: $e');
    }
  }
}
