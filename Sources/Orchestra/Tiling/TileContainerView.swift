import AppKit

final class TileContainerView: NSView {
    private let terminalManager = TerminalManager()
    private let tree: TileTree
    private var resizeHandles: [TileResizeHandle] = []
    private var splitOverlay: TileSplitModeOverlayView?
    private var nodeFrames: [UUID: NSRect] = [:]
    private(set) var activePaneID: UUID?
    private let emptyStateLabel = NSTextField(labelWithString: "No sessions.\nPress '+' to get started")
    var onSplitModeChanged: ((Bool) -> Void)?

    var isSplitModeActive: Bool {
        splitOverlay != nil
    }

    override init(frame frameRect: NSRect) {
        tree = TileTree()

        super.init(frame: frameRect)

        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        configureEmptyStateLabel()
        updateEmptyState()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        layoutTileTree()
        splitOverlay?.frame = bounds
        layoutEmptyState()
    }

    func enterSplitMode() {
        guard !tree.isEmpty else {
            createInitialPane()
            return
        }

        guard splitOverlay == nil else {
            return
        }

        let overlay = TileSplitModeOverlayView(frame: bounds)
        overlay.autoresizingMask = [.width, .height]
        overlay.candidateProvider = { [weak self] point in
            self?.splitCandidate(at: point)
        }
        overlay.onCommit = { [weak self] candidate in
            self?.commitSplit(candidate)
        }
        overlay.onCancel = { [weak self] in
            self?.exitSplitMode()
        }

        splitOverlay = overlay
        addSubview(overlay, positioned: .above, relativeTo: nil)
        window?.makeFirstResponder(overlay)
        onSplitModeChanged?(true)
    }

    func toggleSplitMode() {
        if isSplitModeActive {
            exitSplitMode()
        } else {
            enterSplitMode()
        }
    }

    func splitActivePane(edge: SplitInsertionEdge) {
        guard let activePaneID else {
            createInitialPane()
            return
        }

        splitPane(id: activePaneID, edge: edge)
    }

    func closeActivePane() {
        guard let activePaneID, let result = tree.closeLeaf(id: activePaneID), let closedPane = terminalManager.pane(id: result.closedID) else {
            NSSound.beep()
            return
        }

        terminalManager.removePane(closedPane)
        self.activePaneID = result.focusID ?? tree.firstLeafID()
        layoutTileTree()
    }

    func frame(for splitID: UUID) -> NSRect? {
        nodeFrames[splitID]
    }

    private func commitSplit(_ candidate: SplitCandidate) {
        splitPane(id: candidate.paneID, edge: candidate.edge)
        exitSplitMode()
    }

    private func createInitialPane() {
        let pane = terminalManager.makePane()
        tree.setRoot(id: pane.id)
        activePaneID = pane.id
        addPane(pane)
        layoutTileTree(animated: true, appearingPaneID: pane.id)
        window?.makeFirstResponder(pane.terminalView)
    }

    private func splitPane(id: UUID, edge: SplitInsertionEdge) {
        let currentDirectory = terminalManager.pane(id: id)?.currentDirectory ?? NSHomeDirectory()
        let newPane = terminalManager.makePane(currentDirectory: currentDirectory)
        addPane(newPane)

        guard tree.splitLeaf(id: id, edge: edge, newID: newPane.id) else {
            terminalManager.removePane(newPane)
            return
        }

        activePaneID = newPane.id
        layoutTileTree(animated: true, appearingPaneID: newPane.id)
    }

    private func exitSplitMode() {
        splitOverlay?.removeFromSuperview()
        splitOverlay = nil
        window?.makeFirstResponder(terminalManager.pane(id: activePaneID ?? UUID())?.terminalView)
        onSplitModeChanged?(false)
    }

    private func addPane(_ pane: TerminalPaneView) {
        pane.onClose = { [weak self] id in
            self?.activePaneID = id
            self?.closeActivePane()
        }
        pane.onFocus = { [weak self] id in
            self?.setActivePane(id)
        }
        addSubview(pane)
        updateCloseAvailability()
        updateEmptyState()
    }

    private func setActivePane(_ id: UUID) {
        if let oldID = activePaneID, oldID != id {
            terminalManager.pane(id: oldID)?.isActive = false
        }

        activePaneID = id
        terminalManager.pane(id: id)?.isActive = true
    }

    private func layoutTileTree(animated: Bool = false, appearingPaneID: UUID? = nil, rebuildHandles: Bool = true) {
        if rebuildHandles {
            resizeHandles.forEach { $0.removeFromSuperview() }
            resizeHandles.removeAll()
        }
        nodeFrames.removeAll()

        guard let root = tree.root else {
            terminalManager.panes.forEach { $0.removeFromSuperview() }
            activePaneID = nil
            updateEmptyState()
            return
        }

        if animated && window != nil {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.layout(
                    node: root,
                    in: self.bounds.insetBy(dx: 6, dy: 6),
                    animated: true,
                    appearingPaneID: appearingPaneID,
                    rebuildHandles: rebuildHandles
                )
            }
        } else {
            layout(
                node: root,
                in: bounds.insetBy(dx: 6, dy: 6),
                animated: false,
                appearingPaneID: nil,
                rebuildHandles: rebuildHandles
            )
        }

        if let activePaneID {
            terminalManager.pane(id: activePaneID)?.isActive = true
        }
        updateCloseAvailability()
        updateEmptyState()
    }

    private func updateCloseAvailability() {
        terminalManager.panes.forEach { $0.canClose = true }
    }

    private func layout(node: TileNode, in frame: NSRect, animated: Bool, appearingPaneID: UUID?, rebuildHandles: Bool) {
        nodeFrames[node.id] = frame

        switch node {
        case .leaf(let paneID):
            guard let pane = terminalManager.pane(id: paneID) else {
                return
            }

            let targetFrame = frame.insetBy(dx: 3, dy: 3)
            if animated {
                if paneID == appearingPaneID {
                    pane.alphaValue = 0
                    pane.frame = targetFrame.insetBy(dx: targetFrame.width * 0.18, dy: targetFrame.height * 0.18)
                    pane.animator().alphaValue = 1
                }

                pane.animator().frame = targetFrame
            } else {
                pane.alphaValue = 1
                pane.frame = targetFrame
            }
            return

        case .split(let splitID, let axis, let first, let second, let ratio):
            let divider: CGFloat = 8

            switch axis {
            case .horizontal:
                let firstWidth = floor((frame.width - divider) * ratio)
                let firstFrame = NSRect(
                    x: frame.minX,
                    y: frame.minY,
                    width: firstWidth,
                    height: frame.height
                )
                let secondFrame = NSRect(
                    x: firstFrame.maxX + divider,
                    y: frame.minY,
                    width: max(0, frame.width - firstWidth - divider),
                    height: frame.height
                )
                layout(node: first, in: firstFrame, animated: animated, appearingPaneID: appearingPaneID, rebuildHandles: rebuildHandles)
                layout(node: second, in: secondFrame, animated: animated, appearingPaneID: appearingPaneID, rebuildHandles: rebuildHandles)
                if rebuildHandles {
                    addResizeHandle(axis: axis, splitID: splitID, frame: NSRect(
                        x: firstFrame.maxX,
                        y: frame.minY,
                        width: divider,
                        height: frame.height
                    ))
                }
            case .vertical:
                let firstHeight = floor((frame.height - divider) * ratio)
                let secondHeight = max(0, frame.height - firstHeight - divider)
                let secondFrame = NSRect(
                    x: frame.minX,
                    y: frame.minY,
                    width: frame.width,
                    height: secondHeight
                )
                let firstFrame = NSRect(
                    x: frame.minX,
                    y: secondFrame.maxY + divider,
                    width: frame.width,
                    height: firstHeight
                )
                layout(node: first, in: firstFrame, animated: animated, appearingPaneID: appearingPaneID, rebuildHandles: rebuildHandles)
                layout(node: second, in: secondFrame, animated: animated, appearingPaneID: appearingPaneID, rebuildHandles: rebuildHandles)
                if rebuildHandles {
                    addResizeHandle(axis: axis, splitID: splitID, frame: NSRect(
                        x: frame.minX,
                        y: secondFrame.maxY,
                        width: frame.width,
                        height: divider
                    ))
                }
            }
        }
    }

    private func addResizeHandle(axis: SplitAxis, splitID: UUID, frame: NSRect) {
        let handle = TileResizeHandle(
            axis: axis,
            splitID: splitID,
            frameProvider: { [weak self] splitID in
                self?.frame(for: splitID)
            },
            onResize: { [weak self] splitID, ratio in
                guard let self, self.tree.updateRatio(splitID: splitID, ratio: ratio) else {
                    return
                }

                self.layoutTileTree(rebuildHandles: false)
            },
            onResizeEnded: { [weak self] in
                self?.layoutTileTree()
            }
        )
        handle.frame = frame
        resizeHandles.append(handle)
        addSubview(handle)
    }

    private func splitCandidate(at point: NSPoint) -> SplitCandidate? {
        guard let root = tree.root, let leafID = leafID(at: point, in: root), let paneFrame = nodeFrames[leafID] else {
            return nil
        }

        guard let edge = edgeZone(for: point, in: paneFrame) else {
            return nil
        }

        return SplitCandidate(paneID: leafID, edge: edge, paneFrame: paneFrame)
    }

    private func leafID(at point: NSPoint, in node: TileNode) -> UUID? {
        guard nodeFrames[node.id]?.contains(point) == true else {
            return nil
        }

        switch node {
        case .leaf(let id):
            return id
        case .split(_, _, let first, let second, _):
            return leafID(at: point, in: first) ?? leafID(at: point, in: second)
        }
    }

    private func edgeZone(for point: NSPoint, in frame: NSRect) -> SplitInsertionEdge? {
        let localX = point.x - frame.minX
        let localY = point.y - frame.minY
        let width = max(frame.width, 1)
        let height = max(frame.height, 1)

        if localY >= height * 0.7 {
            return .top
        }

        if localY <= height * 0.3 {
            return .bottom
        }

        if localX <= width * 0.3 {
            return .left
        }

        if localX >= width * 0.7 {
            return .right
        }

        return nil
    }

    private func configureEmptyStateLabel() {
        emptyStateLabel.font = .systemFont(ofSize: 18, weight: .medium)
        emptyStateLabel.textColor = .secondaryLabelColor
        emptyStateLabel.alignment = .center
        emptyStateLabel.maximumNumberOfLines = 2
        emptyStateLabel.lineBreakMode = .byWordWrapping
        emptyStateLabel.isHidden = true
        addSubview(emptyStateLabel)
    }

    private func layoutEmptyState() {
        let size = emptyStateLabel.sizeThatFits(NSSize(width: max(0, bounds.width - 48), height: .greatestFiniteMagnitude))
        emptyStateLabel.frame = NSRect(
            x: (bounds.width - size.width) / 2,
            y: (bounds.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }

    private func updateEmptyState() {
        let isEmpty = tree.isEmpty
        emptyStateLabel.isHidden = !isEmpty
        if isEmpty {
            addSubview(emptyStateLabel, positioned: .above, relativeTo: nil)
            layoutEmptyState()
        }
    }
}
