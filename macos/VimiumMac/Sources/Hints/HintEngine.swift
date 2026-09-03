import Foundation

/// Port of Vimium AlphabetHints: home-row labels, filter as you type, unique match activates.
final class HintEngine {
    static let alphabet = Array("sadfjklewcmpgh")

    struct Marker {
        var target: HintTarget
        var hintString: String
    }

    private(set) var markers: [Marker] = []
    private(set) var typed = ""
    private(set) var action: HintAction = .click

    var visible: [Marker] {
        markers.filter { $0.hintString.hasPrefix(typed) }
    }

    func start(targets: [HintTarget], action: HintAction) {
        self.action = action
        typed = ""
        let labels = Self.hintStrings(count: targets.count)
        markers = zip(targets, labels).map { Marker(target: $0, hintString: $1) }
    }

    func reset() {
        markers = []
        typed = ""
    }

    enum Step {
        case updated
        case activate(HintTarget)
        case cancel
    }

    func push(_ character: String) -> Step {
        let ch = character.lowercased()
        guard ch.count == 1, let scalar = ch.unicodeScalars.first,
              Self.alphabet.contains(Character(scalar)) else {
            return .updated
        }
        typed += ch
        let matches = visible
        if matches.isEmpty {
            return .cancel
        }
        if matches.count == 1 {
            return .activate(matches[0].target)
        }
        return .updated
    }

    func pop() -> Step {
        guard !typed.isEmpty else { return .cancel }
        typed.removeLast()
        return .updated
    }

    /// Same generation as Vimium's AlphabetHints.hintStrings.
    static func hintStrings(count: Int) -> [String] {
        guard count > 0 else { return [] }
        var hints = [""]
        var offset = 0
        while (hints.count - offset) < count || hints.count == 1 {
            let hint = hints[offset]
            offset += 1
            for ch in alphabet {
                hints.append(String(ch) + hint)
            }
        }
        let slice = hints[offset..<(offset + count)]
        return slice.sorted().map { String($0.reversed()) }
    }
}
