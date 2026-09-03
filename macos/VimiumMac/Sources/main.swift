import AppKit

/// Explicit entry point. `@main` on `NSApplicationDelegate` only calls
/// `NSApplicationMain`, which never instantiates the delegate unless a
/// MainMenu nib or storyboard wires it — so the app would launch, stay
/// faceless, and never create a window, status item, or Accessibility prompt.
let appDelegate = AppDelegate()
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
app.delegate = appDelegate
app.run()
