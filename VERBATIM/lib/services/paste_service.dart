import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PasteResult {
  final bool success;
  final bool permissionDenied;
  final String? error;

  const PasteResult({
    required this.success,
    this.permissionDenied = false,
    this.error,
  });
}

class PasteService {
  static const MethodChannel _nativeInput = MethodChannel(
    'verbatim/native_input',
  );
  DateTime? _lastPermissionPromptAt;

  Future<bool> checkAccessibilityPermission() async {
    try {
      final granted = await _nativeInput.invokeMethod<bool>(
        'checkAccessibilityPermission',
      );
      return granted == true;
    } catch (e) {
      debugPrint('[Paste] checkAccessibilityPermission error: $e');
      return false;
    }
  }

  Future<bool> checkMicrophonePermission() async {
    try {
      final granted = await _nativeInput.invokeMethod<bool>(
        'checkMicrophonePermission',
      );
      return granted == true;
    } catch (e) {
      debugPrint('[Paste] checkMicrophonePermission error: $e');
      return false;
    }
  }

  Future<bool> requestMicrophonePermission() async {
    try {
      final granted = await _nativeInput.invokeMethod<bool>(
        'requestMicrophonePermission',
      );
      return granted == true;
    } catch (e) {
      debugPrint('[Paste] requestMicrophonePermission error: $e');
      return false;
    }
  }

  /// Best-effort capture of current frontmost app bundle id.
  Future<String?> getFrontmostBundleId() async {
    try {
      final id = await _nativeInput.invokeMethod<String>('getFrontmostBundleId');
      final normalized = id?.trim();
      if (normalized != null && normalized.isNotEmpty) {
        debugPrint('[Paste] frontmost bundle id (native): $normalized');
        return normalized;
      }
    } catch (e) {
      debugPrint('[Paste] native getFrontmostBundleId error: $e');
    }

    // Fallback to AppleScript for older builds.
    try {
      final result = await Process.run('osascript', [
        '-e',
        'tell application "System Events" to get bundle identifier of first application process whose frontmost is true',
      ]);
      if (result.exitCode != 0) {
        debugPrint('[Paste] getFrontmostBundleId stderr: ${result.stderr}');
        return null;
      }
      final id = (result.stdout as String).trim();
      if (id.isEmpty) return null;
      debugPrint('[Paste] frontmost bundle id: $id');
      return id;
    } catch (e) {
      debugPrint('[Paste] getFrontmostBundleId error: $e');
      return null;
    }
  }

  /// Copies [text] to clipboard and simulates Cmd+V in the frontmost app.
  /// If [preferredBundleId] is provided, tries to activate that app first.
  Future<PasteResult> pasteToFrontApp(
    String text, {
    String? preferredBundleId,
  }) async {
    await Clipboard.setData(ClipboardData(text: text));
    // Brief delay so the pasteboard is updated before the keystroke
    await Future.delayed(const Duration(milliseconds: 100));

    // Preferred path: native macOS event injection (more reliable than osascript).
    try {
      final response = await _nativeInput.invokeMapMethod<String, dynamic>(
        'pasteClipboardToFrontApp',
        {'bundleId': preferredBundleId ?? ''},
      );
      if (response != null) {
        final success = response['success'] == true;
        final permissionDenied = response['permissionDenied'] == true;
        final error = response['error']?.toString();
        debugPrint(
          '[Paste] native paste: success=$success, permissionDenied=$permissionDenied, error=$error',
        );
        if (success) {
          return const PasteResult(success: true);
        }
        if (permissionDenied) {
          return PasteResult(
            success: false,
            permissionDenied: true,
            error: error,
          );
        }
        // Fall through to osascript fallback when native path fails unexpectedly.
      }
    } catch (e) {
      debugPrint('[Paste] native paste error: $e');
    }

    try {
      // 1) Preferred app route: activate captured target app, then paste.
      if (preferredBundleId != null && preferredBundleId.isNotEmpty) {
        final targeted = await Process.run('osascript', [
          '-e',
          'tell application id "$preferredBundleId" to activate',
          '-e',
          'delay 0.12',
          '-e',
          'tell application "System Events" to keystroke "v" using command down',
        ]);
        debugPrint('[Paste] targeted paste exit: ${targeted.exitCode}');
        if (targeted.exitCode == 0) {
          return const PasteResult(success: true);
        }
        debugPrint('[Paste] targeted paste stderr: ${targeted.stderr}');
        final targetedErr = '${targeted.stderr}'.trim();
        if (_isPermissionDenied(targetedErr)) {
          return PasteResult(
            success: false,
            permissionDenied: true,
            error: targetedErr,
          );
        }
      }

      // 2) Fallback route: paste into whichever app is currently frontmost.
      final fallback = await Process.run('osascript', [
        '-e',
        'tell application "System Events" to keystroke "v" using command down',
      ]);
      debugPrint('[Paste] fallback paste exit: ${fallback.exitCode}');
      if (fallback.exitCode != 0) {
        debugPrint('[Paste] fallback paste stderr: ${fallback.stderr}');
        final fallbackErr = '${fallback.stderr}'.trim();
        if (_isPermissionDenied(fallbackErr)) {
          return PasteResult(
            success: false,
            permissionDenied: true,
            error: fallbackErr,
          );
        }
        return PasteResult(success: false, error: fallbackErr);
      }
      return const PasteResult(success: true);
    } catch (e) {
      debugPrint('[Paste] Error: $e');
      return PasteResult(success: false, error: '$e');
    }
  }

  /// Only opens System Preferences to the Accessibility page without
  /// triggering the system permission prompt dialog.
  Future<void> openAccessibilityPreferences() async {
    try {
      await Process.run('open', [
        'x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility',
      ]);
    } catch (e) {
      debugPrint('[Paste] open accessibility preferences failed: $e');
    }
  }

  /// Triggers the system accessibility permission dialog
  /// (AXIsProcessTrustedWithOptions prompt:true) then opens System Settings.
  ///
  /// NOTE: Do NOT call tccutil reset here. Resetting clears the TCC entry
  /// for this app, which means it disappears from System Settings and the
  /// user cannot toggle it. The prompt alone is sufficient to add the app
  /// to the Accessibility list on macOS 13+.
  Future<void> openAccessibilitySettings() async {
    final now = DateTime.now();
    if (_lastPermissionPromptAt != null &&
        now.difference(_lastPermissionPromptAt!) <
            const Duration(seconds: 8)) {
      debugPrint('[Paste] Skip repeated accessibility prompt (throttled)');
      return;
    }
    _lastPermissionPromptAt = now;

    // Trigger the macOS system prompt. On Sequoia this shows an alert that
    // directs the user to System Settings and adds the app to the list.
    try {
      await _nativeInput.invokeMethod<bool>('requestAccessibilityPermission');
    } catch (e) {
      debugPrint('[Paste] requestAccessibilityPermission error: $e');
    }

    // Open directly to the Accessibility pane.
    try {
      await Process.run('open', [
        'x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility',
      ]);
    } catch (e) {
      debugPrint('[Paste] open settings failed: $e');
    }
  }

  Future<void> openMicrophoneSettings() async {
    try {
      await Process.run('open', [
        'x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone',
      ]);
    } catch (e) {
      debugPrint('[Paste] open microphone settings failed: $e');
    }
  }

  bool _isPermissionDenied(String stderr) {
    if (stderr.isEmpty) return false;
    return stderr.contains('不允许发送按键') ||
        stderr.contains('not allowed to send keystrokes') ||
        stderr.contains('1002');
  }
}
