import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Blend the title bar into the content so no dark native strip is visible.
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    self.styleMask.insert(.fullSizeContentView)
    self.hasShadow = false

    // Transparent background for overlay mode
    self.isOpaque = false
    self.backgroundColor = .clear

    // Force light appearance so the window frame/border matches the light UI
    self.appearance = NSAppearance(named: .aqua)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
