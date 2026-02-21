import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A widget for recording and displaying custom keyboard shortcuts.
///
/// Shows the current hotkey combination and allows the user to record
/// a new one by entering listening mode.
class HotkeyPicker extends StatefulWidget {
  final String currentKey;
  final List<String> currentModifiers;
  final void Function(String key, List<String> modifiers) onHotkeyChanged;
  final ValueChanged<bool>? onListeningStateChanged;

  const HotkeyPicker({
    super.key,
    required this.currentKey,
    required this.currentModifiers,
    required this.onHotkeyChanged,
    this.onListeningStateChanged,
  });

  @override
  State<HotkeyPicker> createState() => _HotkeyPickerState();
}

class _HotkeyPickerState extends State<HotkeyPicker> {
  bool _listening = false;
  String? _capturedKey;
  List<String> _capturedModifiers = [];
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  // ── Modifier symbols ──────────────────────────────────────────────

  static const _modifierSymbols = {
    'alt': '⌥ Option',
    'shift': '⇧ Shift',
    'control': '⌃ Control',
    'meta': '⌘ Command',
  };

  static String _modifierSymbol(String mod) =>
      _modifierSymbols[mod.toLowerCase()] ?? mod;

  /// Converts a key debugName and modifier list into a display string.
  static String hotkeyDisplayString(String key, List<String> modifiers) {
    final parts = modifiers.map(_modifierSymbol).toList();
    parts.add(_keyLabel(key));
    return parts.join(' + ');
  }

  static String _keyLabel(String debugName) {
    // Common key name overrides for display
    final lower = debugName.toLowerCase();
    if (lower == 'space') return 'Space';
    if (lower.startsWith('key ')) return debugName.substring(4).toUpperCase();
    if (lower.startsWith('digit ')) return debugName.substring(6);
    return debugName;
  }

  // ── Listening mode ────────────────────────────────────────────────

  void _startListening() {
    setState(() {
      _listening = true;
      _capturedKey = null;
      _capturedModifiers = [];
    });
    _focusNode.requestFocus();
    widget.onListeningStateChanged?.call(true);
  }

  void _cancelListening() {
    setState(() => _listening = false);
    widget.onListeningStateChanged?.call(false);
  }

  void _confirmCapture() {
    setState(() => _listening = false);
    // Restore old hotkey first, then notify the new key.
    // This ensures the old hotkey is re-registered before
    // onHotkeyChanged triggers reRegister with the new key.
    widget.onListeningStateChanged?.call(false);
    if (_capturedKey != null) {
      widget.onHotkeyChanged(_capturedKey!, List.of(_capturedModifiers));
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!_listening) return KeyEventResult.ignored;
    if (event is! KeyDownEvent) return KeyEventResult.handled;

    final key = event.physicalKey;

    // Ignore standalone modifier presses
    if (_isModifierKey(key)) return KeyEventResult.handled;

    final modifiers = <String>[];
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isAltPressed) modifiers.add('alt');
    if (keyboard.isShiftPressed) modifiers.add('shift');
    if (keyboard.isControlPressed) modifiers.add('control');
    if (keyboard.isMetaPressed) modifiers.add('meta');

    setState(() {
      _capturedKey = key.debugName ?? 'Unknown';
      _capturedModifiers = modifiers;
    });

    return KeyEventResult.handled;
  }

  bool _isModifierKey(PhysicalKeyboardKey key) {
    return key == PhysicalKeyboardKey.altLeft ||
        key == PhysicalKeyboardKey.altRight ||
        key == PhysicalKeyboardKey.shiftLeft ||
        key == PhysicalKeyboardKey.shiftRight ||
        key == PhysicalKeyboardKey.controlLeft ||
        key == PhysicalKeyboardKey.controlRight ||
        key == PhysicalKeyboardKey.metaLeft ||
        key == PhysicalKeyboardKey.metaRight;
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _listening
                ? Colors.blueAccent.withValues(alpha: 0.6)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: _listening ? _buildListeningMode() : _buildDisplayMode(),
      ),
    );
  }

  Widget _buildDisplayMode() {
    final display =
        hotkeyDisplayString(widget.currentKey, widget.currentModifiers);
    return Row(
      children: [
        const Icon(Icons.keyboard, size: 18, color: Colors.white54),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            display,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        TextButton(
          onPressed: _startListening,
          style: TextButton.styleFrom(
            foregroundColor: Colors.blueAccent,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('修改', style: TextStyle(fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildListeningMode() {
    final hasCapture = _capturedKey != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!hasCapture)
          const Text(
            '请按下新的快捷键组合...',
            style: TextStyle(
              color: Colors.blueAccent,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          )
        else
          Text(
            hotkeyDisplayString(_capturedKey!, _capturedModifiers),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _cancelListening,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white54,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('取消', style: TextStyle(fontSize: 13)),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: hasCapture ? _confirmCapture : null,
              style: TextButton.styleFrom(
                foregroundColor: Colors.blueAccent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('确认', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      ],
    );
  }
}
