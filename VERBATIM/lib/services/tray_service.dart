import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';

class TrayService with TrayListener {
  final VoidCallback? onToggleSettings;
  final VoidCallback? onQuit;
  final TrayManager _trayManager = TrayManager.instance;

  TrayService({this.onToggleSettings, this.onQuit});

  Future<void> init() async {
    _trayManager.addListener(this);

    await _trayManager.setIcon('assets/tray_icon.png');
    await _trayManager.setToolTip('VERBATIM - Option+Space 语音输入');

    final menu = Menu(items: [
      MenuItem(key: 'about', label: 'VERBATIM v2.1', disabled: true),
      MenuItem.separator(),
      MenuItem(key: 'settings', label: '显示设置'),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: '退出'),
    ]);
    await _trayManager.setContextMenu(menu);
  }

  @override
  void onTrayIconMouseDown() {
    onToggleSettings?.call();
  }

  @override
  void onTrayIconRightMouseDown() {
    _trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'settings':
        onToggleSettings?.call();
      case 'quit':
        onQuit?.call();
    }
  }

  void dispose() {
    _trayManager.removeListener(this);
  }
}
