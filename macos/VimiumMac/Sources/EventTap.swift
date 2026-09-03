import CoreGraphics
import Foundation

final class EventTap {
    var handler: ((CGEventType, CGEvent) -> KeyOutcome)?

    private var port: CFMachPort?
    private var source: CFRunLoopSource?

    var isRunning: Bool { port != nil }

    @discardableResult
    func start() -> Bool {
        stop()

        var mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        mask |= CGEventMask(1 << CGEventType.keyUp.rawValue)
        mask |= CGEventMask(1 << CGEventType.tapDisabledByTimeout.rawValue)
        mask |= CGEventMask(1 << CGEventType.tapDisabledByUserInput.rawValue)

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else {
                    return Unmanaged.passUnretained(event)
                }
                let tap = Unmanaged<EventTap>.fromOpaque(refcon).takeUnretainedValue()
                return tap.handleCallback(type: type, event: event)
            },
            userInfo: refcon
        ) else {
            return false
        }

        self.port = port
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        return true
    }

    func stop() {
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let port {
            CGEvent.tapEnable(tap: port, enable: false)
        }
        self.source = nil
        self.port = nil
    }

    private func handleCallback(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let port {
                CGEvent.tapEnable(tap: port, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        switch handler?(type, event) ?? .pass {
        case .pass:
            return Unmanaged.passUnretained(event)
        case .swallow:
            return nil
        }
    }
}
