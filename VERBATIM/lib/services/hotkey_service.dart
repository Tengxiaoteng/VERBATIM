import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

class HotkeyService {
  final VoidCallback onKeyDown;
  final VoidCallback onKeyUp;

  HotkeyService({required this.onKeyDown, required this.onKeyUp});

  HotKey? _hotKey;

  Future<void> register({
    PhysicalKeyboardKey key = PhysicalKeyboardKey.space,
    List<HotKeyModifier> modifiers = const [HotKeyModifier.alt],
  }) async {
    _hotKey = HotKey(key: key, modifiers: modifiers, scope: HotKeyScope.system);
    await hotKeyManager.register(
      _hotKey!,
      keyDownHandler: (_) {
        debugPrint('[Hotkey] keyDown');
        onKeyDown();
      },
      keyUpHandler: (_) {
        debugPrint('[Hotkey] keyUp');
        onKeyUp();
      },
    );
    debugPrint(
      '[Hotkey] Registered ${modifiers.map((m) => m.name).join("+")}+${key.debugName}',
    );
  }

  Future<void> reRegister({
    required PhysicalKeyboardKey key,
    required List<HotKeyModifier> modifiers,
  }) async {
    await unregister();
    await register(key: key, modifiers: modifiers);
  }

  Future<void> unregister() async {
    if (_hotKey != null) {
      await hotKeyManager.unregister(_hotKey!);
      _hotKey = null;
    }
  }

  void dispose() {
    unregister();
  }

  // ---------------------------------------------------------------------------
  // Helpers to convert persisted strings → hotkey_manager types
  // ---------------------------------------------------------------------------

  static final Map<String, PhysicalKeyboardKey> _keyMap = {
    for (final entry in <MapEntry<String, PhysicalKeyboardKey>>[
      MapEntry('Space', PhysicalKeyboardKey.space),
      MapEntry('Fn', PhysicalKeyboardKey.fn),
      MapEntry('Key A', PhysicalKeyboardKey.keyA),
      MapEntry('Key B', PhysicalKeyboardKey.keyB),
      MapEntry('Key C', PhysicalKeyboardKey.keyC),
      MapEntry('Key D', PhysicalKeyboardKey.keyD),
      MapEntry('Key E', PhysicalKeyboardKey.keyE),
      MapEntry('Key F', PhysicalKeyboardKey.keyF),
      MapEntry('Key G', PhysicalKeyboardKey.keyG),
      MapEntry('Key H', PhysicalKeyboardKey.keyH),
      MapEntry('Key I', PhysicalKeyboardKey.keyI),
      MapEntry('Key J', PhysicalKeyboardKey.keyJ),
      MapEntry('Key K', PhysicalKeyboardKey.keyK),
      MapEntry('Key L', PhysicalKeyboardKey.keyL),
      MapEntry('Key M', PhysicalKeyboardKey.keyM),
      MapEntry('Key N', PhysicalKeyboardKey.keyN),
      MapEntry('Key O', PhysicalKeyboardKey.keyO),
      MapEntry('Key P', PhysicalKeyboardKey.keyP),
      MapEntry('Key Q', PhysicalKeyboardKey.keyQ),
      MapEntry('Key R', PhysicalKeyboardKey.keyR),
      MapEntry('Key S', PhysicalKeyboardKey.keyS),
      MapEntry('Key T', PhysicalKeyboardKey.keyT),
      MapEntry('Key U', PhysicalKeyboardKey.keyU),
      MapEntry('Key V', PhysicalKeyboardKey.keyV),
      MapEntry('Key W', PhysicalKeyboardKey.keyW),
      MapEntry('Key X', PhysicalKeyboardKey.keyX),
      MapEntry('Key Y', PhysicalKeyboardKey.keyY),
      MapEntry('Key Z', PhysicalKeyboardKey.keyZ),
      MapEntry('Digit 0', PhysicalKeyboardKey.digit0),
      MapEntry('Digit 1', PhysicalKeyboardKey.digit1),
      MapEntry('Digit 2', PhysicalKeyboardKey.digit2),
      MapEntry('Digit 3', PhysicalKeyboardKey.digit3),
      MapEntry('Digit 4', PhysicalKeyboardKey.digit4),
      MapEntry('Digit 5', PhysicalKeyboardKey.digit5),
      MapEntry('Digit 6', PhysicalKeyboardKey.digit6),
      MapEntry('Digit 7', PhysicalKeyboardKey.digit7),
      MapEntry('Digit 8', PhysicalKeyboardKey.digit8),
      MapEntry('Digit 9', PhysicalKeyboardKey.digit9),
      MapEntry('F1', PhysicalKeyboardKey.f1),
      MapEntry('F2', PhysicalKeyboardKey.f2),
      MapEntry('F3', PhysicalKeyboardKey.f3),
      MapEntry('F4', PhysicalKeyboardKey.f4),
      MapEntry('F5', PhysicalKeyboardKey.f5),
      MapEntry('F6', PhysicalKeyboardKey.f6),
      MapEntry('F7', PhysicalKeyboardKey.f7),
      MapEntry('F8', PhysicalKeyboardKey.f8),
      MapEntry('F9', PhysicalKeyboardKey.f9),
      MapEntry('F10', PhysicalKeyboardKey.f10),
      MapEntry('F11', PhysicalKeyboardKey.f11),
      MapEntry('F12', PhysicalKeyboardKey.f12),
    ])
      entry.key: entry.value,
  };

  static final Map<String, HotKeyModifier> _modMap = {
    'alt': HotKeyModifier.alt,
    'control': HotKeyModifier.control,
    'shift': HotKeyModifier.shift,
    'meta': HotKeyModifier.meta,
  };

  /// Converts a debug name string (e.g. "Space", "Key A") to a [PhysicalKeyboardKey].
  /// Falls back to [PhysicalKeyboardKey.space] if not found.
  static PhysicalKeyboardKey parseKey(String debugName) {
    final raw = debugName.trim();
    final direct = _keyMap[raw];
    if (direct != null) return direct;

    final upper = raw.toUpperCase();

    // Accept single-letter forms like "E" (from keyLabel/debugName variants).
    if (upper.length == 1 &&
        upper.codeUnitAt(0) >= 65 &&
        upper.codeUnitAt(0) <= 90) {
      final normalized = 'Key $upper';
      return _keyMap[normalized] ?? PhysicalKeyboardKey.space;
    }

    // Accept single-digit forms like "1".
    if (upper.length == 1 &&
        upper.codeUnitAt(0) >= 48 &&
        upper.codeUnitAt(0) <= 57) {
      final normalized = 'Digit $upper';
      return _keyMap[normalized] ?? PhysicalKeyboardKey.space;
    }

    // Accept lowercase "key e" / "digit 1" / "fn".
    final titleCase = raw.isEmpty
        ? raw
        : '${raw[0].toUpperCase()}${raw.substring(1).toLowerCase()}';
    final byTitleCase = _keyMap[titleCase];
    if (byTitleCase != null) return byTitleCase;
    if (upper == 'FN') return PhysicalKeyboardKey.fn;

    return PhysicalKeyboardKey.space;
  }

  /// Converts a list of modifier name strings (e.g. ["alt","shift"])
  /// to a list of [HotKeyModifier].
  static List<HotKeyModifier> parseModifiers(List<String> mods) {
    return mods
        .map((m) => _modMap[m.toLowerCase()])
        .whereType<HotKeyModifier>()
        .toList();
  }
}
