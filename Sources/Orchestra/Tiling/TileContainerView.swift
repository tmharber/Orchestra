import AppKit

final class TileContainerView: NSView {
    private let terminalManager = TerminalManager()
    private let tree: TileTree
    private var resizeHandles: [TileResizeHandle] = []
    private var splitOverlay: TileSplitModeOverlayView?
    private var nodeFrames: [UUID: NSRect] = [:]
    private(set) var activePaneID: UUID?
    private let emptyStateContainer = NSView()
    private let emptyStateIcon = NSImageView()
    private let emptyStatePrimary = NSTextField(labelWithString: "No terminals yet")
    private let emptyStateCaptionPrefix = NSTextField(labelWithString: "Press")
    private let emptyStateCaptionSuffix = NSTextField(labelWithString: "to add a terminal")
    private let emptyStateShortcut = KeyboardShortcutBadge(text: "⌘T")
    var onSplitModeChanged: ((Bool) -> Void)?
    var onTerminalCountChanged: ((Int) -> Void)?
    var defaultDirectory = ""

    var terminalCount: Int {
        terminalManager.runningCount
    }

    var paneCount: Int {
        terminalManager.count
    }

    var isSplitModeActive: Bool {
        splitOverlay != nil
    }

    override init(frame frameRect: NSRect) {
        tree = TileTree()

        super.init(frame: frameRect)

        wantsLayer = true
        layer?.backgroundColor = DS.Palette.tileGutter.cgColor
        terminalManager.onRunningCountChanged = { [weak self] count in
            self?.onTerminalCountChanged?(count)
        }
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

    func restoreFocus() {
        guard
            let targetID = activePaneID ?? tree.firstLeafID(),
            let pane = terminalManager.pane(id: targetID)
        else {
            return
        }

        activePaneID = pane.id
        setActivePane(pane.id)
        window?.makeFirstResponder(pane.terminalView)
    }

    func terminateAll() {
        exitSplitMode()
        resizeHandles.forEach { $0.removeFromSuperview() }
        resizeHandles.removeAll()
        nodeFrames.removeAll()
        tree.removeAll()
        activePaneID = nil
        terminalManager.removeAll(terminating: true)
        layoutTileTree()
        updateEmptyState()
    }

    var activePaneAllowsTerminalMouseReporting: Bool {
        guard let activePaneID, let pane = terminalManager.pane(id: activePaneID) else {
            return false
        }

        return pane.terminalView.allowMouseReporting
    }

    func toggleActivePaneMouseReporting() {
        guard let activePaneID, let pane = terminalManager.pane(id: activePaneID) else {
            NSSound.beep()
            return
        }

        pane.terminalView.allowMouseReporting.toggle()
        window?.makeFirstResponder(pane.terminalView)
    }

    func frame(for splitID: UUID) -> NSRect? {
        nodeFrames[splitID]
    }

    private func commitSplit(_ candidate: SplitCandidate) {
        splitPane(id: candidate.paneID, edge: candidate.edge)
        exitSplitMode()
    }

    private func createInitialPane() {
        let pane = terminalManager.makePane(currentDirectory: newPaneDirectory(fallback: NSHomeDirectory()))
        tree.setRoot(id: pane.id)
        activePaneID = pane.id
        addPane(pane)
        layoutTileTree(animated: true, appearingPaneID: pane.id)
        window?.makeFirstResponder(pane.terminalView)
    }

    private func splitPane(id: UUID, edge: SplitInsertionEdge) {
        let fallbackDirectory: String
        if let pane = terminalManager.pane(id: id), pane.hasReportedCurrentDirectory {
            fallbackDirectory = pane.currentDirectory
        } else {
            fallbackDirectory = NSHomeDirectory()
        }

        let newPane = terminalManager.makePane(currentDirectory: newPaneDirectory(fallback: fallbackDirectory))
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
        if let activePaneID, let pane = terminalManager.pane(id: activePaneID) {
            window?.makeFirstResponder(pane.terminalView)
        }
        onSplitModeChanged?(false)
    }

    private func newPaneDirectory(fallback: String) -> String {
        let trimmed = defaultDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        return DirectoryResolver.existingDirectory(trimmed.isEmpty ? fallback : trimmed, fallback: fallback)
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
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                self.layout(
                    node: root,
                    in: self.bounds.insetBy(dx: DS.Metrics.tileInset, dy: DS.Metrics.tileInset),
                    animated: true,
                    appearingPaneID: appearingPaneID,
                    rebuildHandles: rebuildHandles
                )
            }
        } else {
            layout(
                node: root,
                in: bounds.insetBy(dx: DS.Metrics.tileInset, dy: DS.Metrics.tileInset),
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

            let targetFrame = frame.insetBy(dx: 1, dy: 1)
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
            let divider = TileLayoutMetrics.dividerSize

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
        emptyStateContainer.wantsLayer = true
        emptyStateContainer.isHidden = true

        let iconConfig = NSImage.SymbolConfiguration(pointSize: 28, weight: .light)
        emptyStateIcon.image = NSImage(systemSymbolName: "terminal", accessibilityDescription: nil)?
            .withSymbolConfiguration(iconConfig)
        emptyStateIcon.contentTintColor = NSColor.tertiaryLabelColor
        emptyStateIcon.imageScaling = .scaleProportionallyDown

        emptyStatePrimary.font = DS.Typography.emptyStatePrimary()
        emptyStatePrimary.textColor = .secondaryLabelColor
        emptyStatePrimary.alignment = .center

        emptyStateCaptionPrefix.font = DS.Typography.emptyStateSecondary()
        emptyStateCaptionPrefix.textColor = .tertiaryLabelColor
        emptyStateCaptionSuffix.font = DS.Typography.emptyStateSecondary()
        emptyStateCaptionSuffix.textColor = .tertiaryLabelColor

        emptyStateContainer.addSubview(emptyStateIcon)
        emptyStateContainer.addSubview(emptyStatePrimary)
        emptyStateContainer.addSubview(emptyStateCaptionPrefix)
        emptyStateContainer.addSubview(emptyStateShortcut)
        emptyStateContainer.addSubview(emptyStateCaptionSuffix)
        addSubview(emptyStateContainer)
    }

    private func layoutEmptyState() {
        let iconHeight: CGFloat = 38
        let titleHeight: CGFloat = 22
        let captionRowHeight: CGFloat = 22
        let badgeGap: CGFloat = 6
        let totalHeight = iconHeight + 16 + titleHeight + 14 + captionRowHeight

        emptyStateCaptionPrefix.sizeToFit()
        emptyStateCaptionSuffix.sizeToFit()
        emptyStatePrimary.sizeToFit()

        let prefixWidth = ceil(emptyStateCaptionPrefix.frame.width) + 2
        let suffixWidth = ceil(emptyStateCaptionSuffix.frame.width) + 2
        let badgeSize = emptyStateShortcut.intrinsicContentSize
        let rowWidth = prefixWidth + badgeGap + badgeSize.width + badgeGap + suffixWidth
        let titleWidth = ceil(emptyStatePrimary.frame.width)
        let containerWidth = max(rowWidth, titleWidth, 220) + 24

        emptyStateContainer.frame = NSRect(
            x: floor((bounds.width - containerWidth) / 2),
            y: floor((bounds.height - totalHeight) / 2),
            width: containerWidth,
            height: totalHeight
        )

        let cw = emptyStateContainer.bounds.width
        var y = totalHeight - iconHeight
        emptyStateIcon.frame = NSRect(x: floor((cw - 36) / 2), y: y, width: 36, height: iconHeight)
        y -= (16 + titleHeight)
        emptyStatePrimary.frame = NSRect(x: 0, y: y, width: cw, height: titleHeight)
        y -= (14 + captionRowHeight)

        var x = floor((cw - rowWidth) / 2)

        let prefixHeight = ceil(emptyStateCaptionPrefix.frame.height)
        let suffixHeight = ceil(emptyStateCaptionSuffix.frame.height)
        let textY = y + floor((captionRowHeight - prefixHeight) / 2)

        emptyStateCaptionPrefix.frame = NSRect(x: x, y: textY, width: prefixWidth, height: prefixHeight)
        x += prefixWidth + badgeGap

        emptyStateShortcut.frame = NSRect(
            x: x,
            y: y + floor((captionRowHeight - badgeSize.height) / 2),
            width: badgeSize.width,
            height: badgeSize.height
        )
        x += badgeSize.width + badgeGap

        emptyStateCaptionSuffix.frame = NSRect(
            x: x,
            y: y + floor((captionRowHeight - suffixHeight) / 2),
            width: suffixWidth,
            height: suffixHeight
        )
    }

    private func updateEmptyState() {
        let isEmpty = tree.isEmpty
        emptyStateContainer.isHidden = !isEmpty
        if isEmpty {
            addSubview(emptyStateContainer, positioned: .above, relativeTo: nil)
            layoutEmptyState()
        }
    }
}

final class KeyboardShortcutBadge: NSView {
    private let label = NSTextField(labelWithString: "")

    init(text: String) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 5
        layer?.cornerCurve = .continuous
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.quaternaryLabelColor.cgColor
        layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.04).cgColor

        label.stringValue = text
        label.font = .monospacedSystemFont(ofSize: 11, weight: .semibold)
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        addSubview(label)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        let textSize = label.intrinsicContentSize
        return NSSize(width: textSize.width + 14, height: 22)
    }

    override func layout() {
        super.layout()
        label.frame = bounds.insetBy(dx: 6, dy: 2)
    }
}
