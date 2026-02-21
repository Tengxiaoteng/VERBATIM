import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'services/settings_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(280, 80),
    backgroundColor: Colors.transparent,
    skipTaskbar: true,
    titleBarStyle: TitleBarStyle.hidden,
    alwaysOnTop: true,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setHasShadow(false);
    await windowManager.hide();
  });

  final settingsService = SettingsService();
  final settings = await settingsService.load();

  runApp(VerbatimApp(
    initialSettings: settings,
    settingsService: settingsService,
  ));
}
