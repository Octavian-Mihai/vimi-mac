import ApplicationServices
import AppKit

struct HintTarget {
    let element: AXUIElement
    let frame: CGRect // AX / Quartz coordinates (origin top-left)
    let role: String
    let title: String
    let url: String?
    let interactive: Bool

    var quartzCenter: CGPoint {
        CGPoint(x: frame.midX, y: frame.midY)
    }

    var area: CGFloat {
        frame.width * frame.height
    }

    var copyText: String {
        if let url, !url.isEmpty { return url }
        if let value = AXSupport.valueString(element), !value.isEmpty {
            if value.contains("://") || value.hasPrefix("http") || value.hasPrefix("mailto:") {
                return value
            }
        }
        if !title.isEmpty { return title }
        if let value = AXSupport.valueString(element), !value.isEmpty { return value }
        return AXSupport.role(element)
    }
}

enum ElementCollector {
    private static let maxResults = 300
    private static let maxVisits = 4000
    private static let maxDepth = 50

    private static let skipRoles: Set<String> = [
        "AXMenuBar",
        "AXMenuBarItem",
        "AXScrollBar",
        "AXSplitter",
        "AXBusyIndicator",
        "AXProgressIndicator",
        "AXApplication",
        "AXWindow",
        "AXGrowArea",
    ]

    private static let clickableRoles: Set<String> = [
        "AXButton",
        "AXLink",
        "AXCheckBox",
        "AXRadioButton",
        "AXPopUpButton",
        "AXMenuButton",
        "AXMenuItem",
        "AXTab",
        "AXDisclosureTriangle",
        "AXComboBox",
        "AXColorWell",
        "AXTextField",
        "AXTextArea",
        "AXSearchField",
        "AXSecureTextField",
        "AXSlider",
        "AXIncrementArrow",
        "AXDecrementArrow",
        "AXLevelIndicator",
        "AXRadioGroup",
    ]

    /// Roles Discord / Chromium expose once AXManualAccessibility is on.
    /// Only hinted when they look interactive (press, description, or enabled).
    private static let extraRoles: Set<String> = [
        "AXGroup",
        "AXStaticText",
        "AXImage",
        "AXRow",
        "AXCell",
        "AXList",
        "AXGenericElement",
        "AXUnknown",
        "AXHeading",
        "AXWebArea",
    ]

    static func collect(pid: pid_t) -> [HintTarget] {
        AXSupport.enableEnhancedAccessibility(pid: pid)
        guard let window = AXSupport.focusedWindow(pid: pid) else { return [] }
        let windowFrame = AXSupport.frame(window)
        var results: [HintTarget] = []
        var visits = 0
        walk(window, depth: 0, windowFrame: windowFrame, results: &results, visits: &visits)
        return prioritize(deduplicate(results))
    }

    private static func walk(
        _ element: AXUIElement,
        depth: Int,
        windowFrame: CGRect?,
        results: inout [HintTarget],
        visits: inout Int
    ) {
        visits += 1
        guard visits < maxVisits, depth < maxDepth else { return }
        guard !AXSupport.isHidden(element) else { return }

        let role = AXSupport.role(element)
        if let frame = AXSupport.frame(element) {
            if let windowFrame, !frame.intersects(windowFrame) {
                // Still recurse; some parents report empty/offset frames.
            } else if isOnScreen(frame), let target = makeTarget(element, role: role, frame: frame) {
                results.append(target)
            }
        }

        if skipDeepDive(role) { return }

        let children = visibleChildren(of: element)
        for child in children {
            walk(child, depth: depth + 1, windowFrame: windowFrame, results: &results, visits: &visits)
            if visits >= maxVisits { return }
        }
    }

    private static func visibleChildren(of element: AXUIElement) -> [AXUIElement] {
        let visible = AXSupport.elements(element, "AXVisibleChildren")
        if !visible.isEmpty { return visible }
        return AXSupport.elements(element, kAXChildrenAttribute as String)
    }

    private static func makeTarget(_ element: AXUIElement, role: String, frame: CGRect) -> HintTarget? {
        if skipRoles.contains(role) { return nil }
        if frame.width < 4 || frame.height < 4 { return nil }

        let hasPress = AXSupport.hasPress(element)
        let description = AXSupport.title(element)
        let enabled = AXSupport.isEnabled(element)
        let isClickableRole = clickableRoles.contains(role)
        let isExtra = extraRoles.contains(role)

        let interactive = hasPress || isClickableRole
        let extraOK = isExtra && (hasPress || !description.isEmpty || (enabled && (hasPress || isClickableRole || !description.isEmpty)))

        guard interactive || extraOK else { return nil }

        return HintTarget(
            element: element,
            frame: frame,
            role: role,
            title: description,
            url: AXSupport.urlString(element),
            interactive: interactive
        )
    }

    private static func skipDeepDive(_ role: String) -> Bool {
        role == "AXMenuBar" || role == "AXMenuBarItem"
    }

    private static func isOnScreen(_ frame: CGRect) -> Bool {
        let cocoa = AXSupport.axRectToCocoa(frame)
        return NSScreen.screens.contains { $0.frame.intersects(cocoa) }
    }

    /// Drop stacked / nested duplicates so Discord does not emit 500 overlapping hints.
    private static func deduplicate(_ targets: [HintTarget]) -> [HintTarget] {
        let sorted = targets.sorted { lhs, rhs in
            if lhs.interactive != rhs.interactive { return lhs.interactive }
            return lhs.area < rhs.area
        }
        var kept: [HintTarget] = []
        for candidate in sorted {
            let overlaps = kept.contains { existing in
                let inter = candidate.frame.intersection(existing.frame)
                guard !inter.isNull, !inter.isEmpty else { return false }
                let interArea = inter.width * inter.height
                let smaller = min(candidate.area, existing.area)
                if smaller < 1 { return false }
                // Same center stack, or one box mostly covers the other.
                if interArea / smaller > 0.72 { return true }
                let c1 = candidate.quartzCenter
                let c2 = existing.quartzCenter
                if hypot(c1.x - c2.x, c1.y - c2.y) < 10 { return true }
                return false
            }
            if !overlaps {
                kept.append(candidate)
            }
        }
        return kept
    }

    /// Prefer on-screen, larger, interactive nodes and cap the hint count.
    private static func prioritize(_ targets: [HintTarget]) -> [HintTarget] {
        let ranked = targets.sorted { lhs, rhs in
            if lhs.interactive != rhs.interactive { return lhs.interactive && !rhs.interactive }
            return lhs.area > rhs.area
        }
        if ranked.count <= maxResults { return ranked }
        return Array(ranked.prefix(maxResults))
    }
}
