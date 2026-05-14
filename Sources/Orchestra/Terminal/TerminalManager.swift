import AppKit

final class TerminalManager {
    private var panesByID: [UUID: TerminalPaneView] = [:]
    var onCountChanged: ((Int) -> Void)?
    var onRunningCountChanged: ((Int) -> Void)?

    var panes: [TerminalPaneView] {
        Array(panesByID.values)
    }

    var count: Int {
        panesByID.count
    }

    var runningCount: Int {
        panesByID.values.filter(\.isProcessRunning).count
    }

    func makePane(currentDirectory: String = NSHomeDirectory()) -> TerminalPaneView {
        let pane = TerminalPaneView(currentDirectory: currentDirectory)
        pane.onRunningStateChanged = { [weak self] _ in
            guard let self else {
                return
            }

            self.onRunningCountChanged?(self.runningCount)
        }
        panesByID[pane.id] = pane
        onCountChanged?(count)
        onRunningCountChanged?(runningCount)
        return pane
    }

    func pane(id: UUID) -> TerminalPaneView? {
        panesByID[id]
    }

    func removePane(_ pane: TerminalPaneView) {
        panesByID[pane.id] = nil
        pane.removeFromSuperview()
        onCountChanged?(count)
        onRunningCountChanged?(runningCount)
    }

    func removeAll(terminating: Bool) {
        let panes = Array(panesByID.values)
        panesByID.removeAll()
        panes.forEach { pane in
            if terminating {
                pane.terminateProcess()
            }
            pane.removeFromSuperview()
        }
        onCountChanged?(count)
        onRunningCountChanged?(runningCount)
    }
}
