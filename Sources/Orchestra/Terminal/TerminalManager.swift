import AppKit

final class TerminalManager {
    private var panesByID: [UUID: TerminalPaneView] = [:]

    var panes: [TerminalPaneView] {
        Array(panesByID.values)
    }

    var count: Int {
        panesByID.count
    }

    func makePane(currentDirectory: String = NSHomeDirectory()) -> TerminalPaneView {
        let pane = TerminalPaneView(currentDirectory: currentDirectory)
        panesByID[pane.id] = pane
        return pane
    }

    func pane(id: UUID) -> TerminalPaneView? {
        panesByID[id]
    }

    func removePane(_ pane: TerminalPaneView) {
        panesByID[pane.id] = nil
        pane.removeFromSuperview()
    }
}
