import Foundation

extension Notification.Name {
    static let vimiumStateDidChange = Notification.Name("vimiumStateDidChange")
}

enum VimiumMode: Equatable {
    case normal
    case insert
    case hint
}

enum Command: Equatable {
    case scrollDown
    case scrollUp
    case scrollLeft
    case scrollRight
    case scrollPageDown
    case scrollPageUp
    case scrollFullPageDown
    case scrollFullPageUp
    case scrollToTop
    case scrollToBottom
    case goBack
    case goForward
    case reload
    case enterInsertMode
    case activateHints
    case activateHintsNewTab
    case activateHintsCopyLink
}

enum HintAction {
    case click
    case commandClick
    case copyLink
}

enum KeyOutcome {
    case pass
    case swallow
}
