import Cocoa
import FlutterMacOS
import AVFoundation

@main
class AppDelegate: FlutterAppDelegate {
  private var nativeInputChannel: FlutterMethodChannel?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    guard
      let window = mainFlutterWindow,
      let controller = window.contentViewController as? FlutterViewController
    else {
      super.applicationDidFinishLaunching(notification)
      return
    }

    nativeInputChannel = FlutterMethodChannel(
      name: "verbatim/native_input",
      binaryMessenger: controller.engine.binaryMessenger
    )
    nativeInputChannel?.setMethodCallHandler { [weak self] call, result in
      self?.handleNativeInput(call: call, result: result)
    }
    super.applicationDidFinishLaunching(notification)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  private func handleNativeInput(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getFrontmostBundleId":
      let bundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
      result(bundleId)

    case "checkAccessibilityPermission":
      result(AXIsProcessTrusted())

    case "pasteClipboardToFrontApp":
      guard AXIsProcessTrusted() else {
        result([
          "success": false,
          "permissionDenied": true,
          "error": "Accessibility permission is not granted."
        ])
        return
      }

      let args = call.arguments as? [String: Any]
      let bundleId = args?["bundleId"] as? String
      if let id = bundleId, !id.isEmpty {
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: id).first {
          _ = app.activate(options: [.activateIgnoringOtherApps])
          usleep(220_000)
        }
      }

      if postCommandV() {
        result([
          "success": true,
          "permissionDenied": false
        ])
      } else {
        result([
          "success": false,
          "permissionDenied": false,
          "error": "Failed to post Command+V event."
        ])
      }

    case "requestAccessibilityPermission":
      let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
      let options = [key: true] as CFDictionary
      let trusted = AXIsProcessTrustedWithOptions(options)
      result(trusted)

    case "checkMicrophonePermission":
      let status = AVCaptureDevice.authorizationStatus(for: .audio)
      result(status == .authorized)

    case "requestMicrophonePermission":
      AVCaptureDevice.requestAccess(for: .audio) { granted in
        result(granted)
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func postCommandV() -> Bool {
    guard let source = CGEventSource(stateID: .combinedSessionState) else {
      return false
    }

    let vKey: CGKeyCode = 9
    guard
      let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true),
      let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
    else {
      return false
    }

    keyDown.flags = .maskCommand
    keyUp.flags = .maskCommand
    keyDown.post(tap: .cghidEventTap)
    keyUp.post(tap: .cghidEventTap)
    return true
  }
}
