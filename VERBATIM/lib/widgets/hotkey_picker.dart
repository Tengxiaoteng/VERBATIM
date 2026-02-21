import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// A widget for recording and displaying custom keyboard shortcuts.
///
/// Shows the current hotkey combination and allows the user to record
/// a new one by entering listening mode.
class HotkeyPicker extends StatefulWidget {
  final String currentKey;
  final List<String> currentModifiers;
  final void Function(String key, List<String> modifiers) onHotkeyChanged;
  final ValueChanged<bool>? onListeningStateChanged;
  final String description;

  const HotkeyPicker({
    super.key,
    required this.currentKey,
    required this.currentModifiers,
    required this.onHotkeyChanged,
    this.onListeningStateChanged,
    this.description = '按住快捷键开始录音',
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
    'alt': '⌥',
    'shift': '⇧',
    'control': '⌃',
    'meta': '⌘',
  };

  static const _modifierLongNames = {
    'alt': '⌥ Option',
    'shift': '⇧ Shift',
    'control': '⌃ Control',
    'meta': '⌘ Command',
  };

  static String _modifierSymbol(String mod) =>
      _modifierLongNames[mod.toLowerCase()] ?? mod;

  static String _keyLabel(String debugName) {
    // Common key name overrides for display
    final lower = debugName.toLowerCase();
    if (lower == 'space') return 'Space';
    if (lower == 'fn') return 'Fn';
    if (lower.startsWith('key ')) return debugName.substring(4).toUpperCase();
    if (lower.startsWith('digit ')) return debugName.substring(6);
    return debugName;
  }

  String _debugNameForKey(PhysicalKeyboardKey key) {
    if (key == PhysicalKeyboardKey.fn) return 'Fn';
    return key.debugName ?? 'Unknown';
  }

  bool _isFnEvent(KeyEvent event) {
    return event.physicalKey == PhysicalKeyboardKey.fn ||
        event.logicalKey == LogicalKeyboardKey.fn ||
        (event.logicalKey.debugName ?? '').toLowerCase() == 'fn';
  }

  bool _isLogicalModifier(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight ||
        key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight;
  }

  String? _resolveCapturedKey(KeyEvent event) {
    if (_isFnEvent(event)) return 'Fn';

    final physical = _debugNameForKey(event.physicalKey);
    if (physical.isNotEmpty && physical != 'Unknown') {
      return physical;
    }

    final logicalName = event.logicalKey.debugName ?? '';
    if (logicalName.isNotEmpty) {
      return logicalName;
    }

    final label = event.logicalKey.keyLabel;
    if (label.isNotEmpty) {
      return label.length == 1 ? label.toUpperCase() : label;
    }

    return null;
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

    if (_isModifierKey(event.physicalKey) ||
        _isLogicalModifier(event.logicalKey)) {
      return KeyEventResult.handled;
    }

    final keyName = _resolveCapturedKey(event);
    if (keyName == null) return KeyEventResult.handled;

    final modifiers = <String>[];
    if (keyName != 'Fn') {
      final keyboard = HardwareKeyboard.instance;
      if (keyboard.isAltPressed) modifiers.add('alt');
      if (keyboard.isShiftPressed) modifiers.add('shift');
      if (keyboard.isControlPressed) modifiers.add('control');
      if (keyboard.isMetaPressed) modifiers.add('meta');
    }

    setState(() {
      _capturedKey = keyName;
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
        duration: AppTheme.dNormal,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(
            color: _listening
                ? AppTheme.accentPrimary.withValues(alpha: 0.35)
                : AppTheme.borderSubtle,
            width: _listening ? 1.1 : 0.8,
          ),
          boxShadow: _listening
              ? [
                  BoxShadow(
                    color: AppTheme.accentPrimary.withValues(alpha: 0.16),
                    blurRadius: 16,
                    spreadRadius: -4,
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusMD - 0.8),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _listening
                      ? [
                          AppTheme.accentPrimary.withValues(alpha: 0.08),
                          Colors.white.withValues(alpha: 0.55),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.46),
                          Colors.white.withValues(alpha: 0.32),
                        ],
                ),
              ),
              child: _listening ? _buildListeningMode() : _buildDisplayMode(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDisplayMode() {
    final parts = _hotkeyParts(widget.currentKey, widget.currentModifiers);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.accentPrimary.withValues(alpha: 0.10),
            border: Border.all(
              color: AppTheme.accentPrimary.withValues(alpha: 0.20),
              width: 0.8,
            ),
          ),
          child: const Icon(
            Icons.keyboard_rounded,
            size: 15,
            color: AppTheme.accentPrimary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.description,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 7),
              _buildHotkeyCaps(parts),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _actionButton(
          label: '修改',
          onPressed: _startListening,
          isPrimary: false,
        ),
      ],
    );
  }

  Widget _buildListeningMode() {
    final hasCapture = _capturedKey != null;
    final capturedParts = hasCapture
        ? _hotkeyParts(_capturedKey!, _capturedModifiers)
        : <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!hasCapture)
          const Row(
            children: [
              Icon(
                Icons.radio_button_checked_rounded,
                size: 11,
                color: AppTheme.accentPrimary,
              ),
              SizedBox(width: 6),
              Text(
                '请按下新的快捷键组合...',
                style: TextStyle(
                  color: AppTheme.accentPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          )
        else
          _buildHotkeyCaps(capturedParts, active: true),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _actionButton(label: '取消', onPressed: _cancelListening),
            const SizedBox(width: 8),
            _actionButton(
              label: '确认',
              onPressed: hasCapture ? _confirmCapture : null,
              isPrimary: true,
            ),
          ],
        ),
      ],
    );
  }

  List<String> _hotkeyParts(String key, List<String> modifiers) {
    final parts = modifiers
        .map((m) => _modifierSymbols[m.toLowerCase()] ?? _modifierSymbol(m))
        .toList();
    parts.add(_keyLabel(key));
    return parts;
  }

  Widget _buildHotkeyCaps(List<String> parts, {bool active = false}) {
    if (parts.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: List.generate(parts.length * 2 - 1, (index) {
        if (index.isOdd) {
          return Text(
            '+',
            style: const TextStyle(
              color: AppTheme.textTertiary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          );
        }

        final part = parts[index ~/ 2];
        final isMainKey = index ~/ 2 == parts.length - 1;
        final background = isMainKey
            ? AppTheme.accentPrimary.withValues(alpha: active ? 0.18 : 0.13)
            : Colors.white.withValues(alpha: active ? 0.55 : 0.42);
        final borderColor = isMainKey
            ? AppTheme.accentPrimary.withValues(alpha: 0.35)
            : AppTheme.borderDefault;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: 0.8),
          ),
          child: Text(
            part,
            style: TextStyle(
              color: isMainKey ? AppTheme.accentPrimary : AppTheme.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }),
    );
  }

  Widget _actionButton({
    required String label,
    required VoidCallback? onPressed,
    bool isPrimary = false,
  }) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: isPrimary ? Colors.white : AppTheme.textSecondary,
        backgroundColor: isPrimary
            ? AppTheme.accentPrimary.withValues(alpha: 0.85)
            : Colors.white.withValues(alpha: 0.35),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isPrimary
                ? AppTheme.accentPrimary.withValues(alpha: 0.55)
                : AppTheme.borderDefault,
            width: 0.8,
          ),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
      ),
    );
  }
}
