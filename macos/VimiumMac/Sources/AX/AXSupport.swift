import ApplicationServices
import AppKit
import CoreGraphics

enum AXSupport {
    static func application(pid: pid_t) -> AXUIElement {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 1.0)
        return app
    }

    /// Homerow / Vimac trick: Chromium, Electron, and Firefox expose a useful
    /// AX tree only after these flags are flipped. Unsupported attributes fail
    /// silently.
    static func enableEnhancedAccessibility(pid: pid_t) {
        guard pid != 0 else { return }
        let app = application(pid: pid)
        AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue)
    }

    static func copy(_ element: AXUIElement, _ attribute: String) -> AnyObject? {
        var value: AnyObject?
        let status = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard status == .success else { return nil }
        return value
    }

    static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        if let s = copy(element, attribute) as? String { return s }
        if let n = copy(element, attribute) as? NSNumber { return n.stringValue }
        if let url = copy(element, attribute) as? URL { return url.absoluteString }
        return nil
    }

    static func bool(_ element: AXUIElement, _ attribute: String) -> Bool? {
        (copy(element, attribute) as? NSNumber)?.boolValue
    }

    static func element(_ parent: AXUIElement, _ attribute: String) -> AXUIElement? {
        guard let value = copy(parent, attribute) else { return nil }
        return (value as! AXUIElement)
    }

    static func elements(_ parent: AXUIElement, _ attribute: String) -> [AXUIElement] {
        (copy(parent, attribute) as? [AXUIElement]) ?? []
    }

    static func role(_ element: AXUIElement) -> String {
        string(element, kAXRoleAttribute as String) ?? ""
    }

    static func subrole(_ element: AXUIElement) -> String {
        string(element, kAXSubroleAttribute as String) ?? ""
    }

    static func title(_ element: AXUIElement) -> String {
        string(element, kAXTitleAttribute as String)
            ?? string(element, kAXDescriptionAttribute as String)
            ?? string(element, kAXHelpAttribute as String)
            ?? ""
    }

    static func isHidden(_ element: AXUIElement) -> Bool {
        bool(element, kAXHiddenAttribute as String) ?? false
    }

    static func isEnabled(_ element: AXUIElement) -> Bool {
        bool(element, kAXEnabledAttribute as String) ?? true
    }

    static func actions(_ element: AXUIElement) -> [String] {
        var names: CFArray?
        let status = AXUIElementCopyActionNames(element, &names)
        guard status == .success, let names = names as? [String] else { return [] }
        return names
    }

    static func hasPress(_ element: AXUIElement) -> Bool {
        actions(element).contains(kAXPressAction as String)
    }

    static func press(_ element: AXUIElement) -> Bool {
        AXUIElementPerformAction(element, kAXPressAction as CFString) == .success
    }

    static func frame(_ element: AXUIElement) -> CGRect? {
        guard let origin = point(element, kAXPositionAttribute as String),
              let size = size(element, kAXSizeAttribute as String),
              size.width >= 1, size.height >= 1 else {
            return nil
        }
        return CGRect(origin: origin, size: size)
    }

    static func point(_ element: AXUIElement, _ attribute: String) -> CGPoint? {
        guard let axValue = copy(element, attribute) else { return nil }
        var point = CGPoint.zero
        let ok = AXValueGetValue(axValue as! AXValue, .cgPoint, &point)
        return ok ? point : nil
    }

    static func size(_ element: AXUIElement, _ attribute: String) -> CGSize? {
        guard let axValue = copy(element, attribute) else { return nil }
        var size = CGSize.zero
        let ok = AXValueGetValue(axValue as! AXValue, .cgSize, &size)
        return ok ? size : nil
    }

    static func urlString(_ element: AXUIElement) -> String? {
        if let url = copy(element, kAXURLAttribute as String) as? URL {
            return url.absoluteString
        }
        if let s = copy(element, kAXURLAttribute as String) as? String, !s.isEmpty {
            return s
        }
        return nil
    }

    static func valueString(_ element: AXUIElement) -> String? {
        if let s = copy(element, kAXValueAttribute as String) as? String { return s }
        return nil
    }

    static func focusedElement(pid: pid_t) -> AXUIElement? {
        element(application(pid: pid), kAXFocusedUIElementAttribute as String)
    }

    static func focusedWindow(pid: pid_t) -> AXUIElement? {
        let app = application(pid: pid)
        if let window = element(app, kAXFocusedWindowAttribute as String) {
            return window
        }
        return elements(app, kAXWindowsAttribute as String).first
    }

    static func isTextInput(_ element: AXUIElement) -> Bool {
        let r = role(element)
        let sub = subrole(element)
        if Self.textRoles.contains(r) { return true }
        if Self.textRoles.contains(sub) { return true }
        if r == "AXComboBox" { return true }
        if bool(element, "AXEdited") == true { return true }
        if bool(element, "AXEditable") == true { return true }
        // AXEdit is used by some Carbon / older apps.
        if r == "AXEdit" || sub == "AXEdit" { return true }
        if actions(element).contains("AXConfirm") && r == "AXTextField" { return true }
        return false
    }

    static let textRoles: Set<String> = [
        "AXTextField",
        "AXTextArea",
        "AXSearchField",
        "AXSecureTextField",
        "AXComboBox",
    ]

    /// Convert AX / Quartz (top-left origin) to Cocoa (bottom-left origin).
    static func axPointToCocoa(_ point: CGPoint) -> CGPoint {
        guard let primary = NSScreen.screens.first(where: { $0.frame.origin == .zero }) ?? NSScreen.main else {
            return point
        }
        return CGPoint(x: point.x, y: primary.frame.maxY - point.y)
    }

    static func cocoaPointToAX(_ point: CGPoint) -> CGPoint {
        guard let primary = NSScreen.screens.first(where: { $0.frame.origin == .zero }) ?? NSScreen.main else {
            return point
        }
        return CGPoint(x: point.x, y: primary.frame.maxY - point.y)
    }

    static func axRectToCocoa(_ rect: CGRect) -> CGRect {
        let topLeft = axPointToCocoa(rect.origin)
        return CGRect(x: topLeft.x, y: topLeft.y - rect.height, width: rect.width, height: rect.height)
    }
}
