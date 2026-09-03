import Foundation

/// Port of Vimium's KeyHandlerMode: a key-sequence trie plus count prefixes (`5j`, `gg`, `yf`).
final class KeyMapper {
    typealias Mapping = [String: KeyNode]

    final class KeyNode {
        var command: Command?
        var children: Mapping = [:]
    }

    private let root: Mapping
    private var keyState: [Mapping]
    private var countPrefix = 0

    init(bindings: [String: Command] = KeyMapper.defaultBindings) {
        root = KeyMapper.buildTrie(bindings)
        keyState = [root]
    }

    static let defaultBindings: [String: Command] = [
        "j": .scrollDown,
        "k": .scrollUp,
        "h": .scrollLeft,
        "l": .scrollRight,
        "J": .scrollFullPageDown,
        "K": .scrollFullPageUp,
        "d": .scrollPageDown,
        "u": .scrollPageUp,
        "gg": .scrollToTop,
        "G": .scrollToBottom,
        "H": .goBack,
        "L": .goForward,
        "r": .reload,
        "i": .enterInsertMode,
        "f": .activateHints,
        "F": .activateHintsNewTab,
        "yf": .activateHintsCopyLink,
    ]

    var isInResetState: Bool {
        countPrefix == 0 && keyState.count == 1
    }

    func reset(count: Int = 0) {
        countPrefix = count
        keyState = [root]
    }

    enum Result: Equatable {
        case command(Command, count: Int)
        case consumed
        case pass
    }

    func handle(keyChar: String) -> Result {
        if isMappedKey(keyChar) {
            return handleMapped(keyChar)
        }
        if isCountKey(keyChar), let digit = Int(keyChar) {
            let next = keyState.count == 1 ? (countPrefix * 10) + digit : digit
            reset(count: next)
            return .consumed
        }
        if !keyChar.isEmpty {
            reset()
        }
        return .pass
    }

    private func isMappedKey(_ keyChar: String) -> Bool {
        keyState.contains { $0[keyChar] != nil }
    }

    private func isCountKey(_ keyChar: String) -> Bool {
        guard keyChar.count == 1, let scalar = keyChar.unicodeScalars.first else { return false }
        let lower: Unicode.Scalar = countPrefix > 0 ? "0" : "1"
        return lower <= scalar && scalar <= "9"
    }

    private func handleMapped(_ keyChar: String) -> Result {
        // A count prefix applies only while keyChar is mapped in keyState[0]; e.g. 7gj is 1j.
        if keyState.first?[keyChar] == nil {
            countPrefix = 0
        }

        var nextState: [Mapping] = []
        for mapping in keyState {
            guard let node = mapping[keyChar] else { continue }
            if let command = node.command {
                let count = countPrefix > 0 ? countPrefix : 1
                reset()
                return .command(command, count: count)
            }
            nextState.append(node.children)
        }
        nextState.append(root)
        keyState = nextState
        return .consumed
    }

    private static func buildTrie(_ bindings: [String: Command]) -> Mapping {
        let rootNode = KeyNode()
        for (sequence, command) in bindings {
            var node = rootNode
            let keys = sequence.map { String($0) }
            for (index, key) in keys.enumerated() {
                if node.children[key] == nil {
                    node.children[key] = KeyNode()
                }
                node = node.children[key]!
                if index == keys.count - 1 {
                    node.command = command
                }
            }
        }
        return rootNode.children
    }
}
