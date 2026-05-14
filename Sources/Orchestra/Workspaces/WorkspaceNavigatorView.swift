import AppKit

final class WorkspaceNavigatorView: NSVisualEffectView {
    private let store: WorkspaceStore
    private let titleLabel = NSTextField(labelWithString: "Workspaces")
    private let addRootButton = SidebarHeaderButton()
    private let scrollView = NSScrollView()
    private let outlineView = NSOutlineView()
    private let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("WorkspaceColumn"))

    var onSelectWorkspace: ((Workspace) -> Void)?
    var onAddRoot: (() -> Void)?
    var onAddChild: ((Workspace) -> Void)?
    var onSettings: ((Workspace) -> Void)?
    var onDelete: ((Workspace, NSView) -> Void)?

    init(store: WorkspaceStore) {
        self.store = store
        super.init(frame: .zero)
        material = .sidebar
        blendingMode = .behindWindow
        state = .followsWindowActiveState

        titleLabel.attributedStringValue = .tracked(
            "Workspaces",
            font: DS.Typography.sidebarTitle(),
            color: .labelColor,
            tracking: -0.3
        )

        addRootButton.symbolName = "plus"
        addRootButton.target = self
        addRootButton.action = #selector(addRoot(_:))
        addRootButton.toolTip = "Add workspace"

        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        column.minWidth = 0
        outlineView.headerView = nil
        outlineView.rowHeight = DS.Metrics.rowHeight
        outlineView.intercellSpacing = NSSize(width: 0, height: 2)
        outlineView.indentationPerLevel = 14
        outlineView.selectionHighlightStyle = .none
        outlineView.backgroundColor = .clear
        outlineView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        outlineView.autoresizingMask = [.width]
        outlineView.dataSource = self
        outlineView.delegate = self

        scrollView.contentView = WorkspaceNavigatorClipView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.usesPredominantAxisScrolling = true
        scrollView.horizontalScrollElasticity = .none
        scrollView.documentView = outlineView

        addSubview(titleLabel)
        addSubview(addRootButton)
        addSubview(scrollView)
        reloadData()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()

        let inset = DS.Metrics.sidebarInset
        let headerHeight = DS.Metrics.sidebarHeaderHeight
        let buttonSize: CGFloat = 26
        let titleHeight: CGFloat = 28
        let titleBaseline: CGFloat = 18

        titleLabel.frame = NSRect(
            x: inset,
            y: bounds.height - titleBaseline - titleHeight,
            width: max(0, bounds.width - inset - buttonSize - 12),
            height: titleHeight
        )

        addRootButton.frame = NSRect(
            x: bounds.width - buttonSize - inset + 4,
            y: titleLabel.frame.midY - buttonSize / 2,
            width: buttonSize,
            height: buttonSize
        )

        scrollView.frame = NSRect(
            x: 0,
            y: 0,
            width: bounds.width,
            height: max(0, bounds.height - headerHeight)
        )
        let contentWidth = max(0, scrollView.contentView.bounds.width)
        scrollView.contentView.bounds.origin.x = 0
        outlineView.frame.size.width = contentWidth
        column.width = contentWidth
    }

    func reloadData() {
        outlineView.reloadData()
        restoreExpansion()
        selectActiveWorkspace()
    }

    @objc private func addRoot(_ sender: Any?) {
        onAddRoot?()
    }

    private func restoreExpansion() {
        store.roots.forEach { restoreExpansion(for: $0) }
    }

    private func restoreExpansion(for workspace: Workspace) {
        if workspace.isExpanded {
            outlineView.expandItem(workspace)
        } else {
            outlineView.collapseItem(workspace)
        }
        workspace.children.forEach { restoreExpansion(for: $0) }
    }

    private func selectActiveWorkspace() {
        guard let workspace = store.workspace(id: store.activeID) else {
            return
        }

        let row = outlineView.row(forItem: workspace)
        guard row >= 0 else {
            return
        }
        outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
    }
}

final class SidebarHeaderButton: NSButton {
    private var trackingArea: NSTrackingArea?
    private var isHovered = false { didSet { updateAppearance() } }

    var symbolName: String = "plus" {
        didSet {
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
            image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
                .withSymbolConfiguration(config)
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.cornerCurve = .continuous
        isBordered = false
        bezelStyle = .smallSquare
        imagePosition = .imageOnly
        contentTintColor = .secondaryLabelColor

        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        image = NSImage(systemSymbolName: "plus", accessibilityDescription: nil)?
            .withSymbolConfiguration(config)

        updateAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        trackingArea = area
        addTrackingArea(area)
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
    }

    private func updateAppearance() {
        if isHovered {
            layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.08).cgColor
            contentTintColor = .labelColor
        } else {
            layer?.backgroundColor = NSColor.clear.cgColor
            contentTintColor = .secondaryLabelColor
        }
    }
}

private final class WorkspaceNavigatorClipView: NSClipView {
    override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
        var constrained = super.constrainBoundsRect(proposedBounds)
        constrained.origin.x = 0
        return constrained
    }
}

extension WorkspaceNavigatorView: NSOutlineViewDataSource, NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let workspace = item as? Workspace {
            return workspace.children.count
        }
        return store.roots.count
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let workspace = item as? Workspace {
            return workspace.children[index]
        }
        return store.roots[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let workspace = item as? Workspace else {
            return false
        }
        return !workspace.children.isEmpty
    }

    func outlineView(
        _ outlineView: NSOutlineView,
        viewFor tableColumn: NSTableColumn?,
        item: Any
    ) -> NSView? {
        guard let workspace = item as? Workspace else {
            return nil
        }

        let identifier = NSUserInterfaceItemIdentifier("WorkspaceRowView")
        let rowView = outlineView.makeView(withIdentifier: identifier, owner: self) as? WorkspaceRowView ?? WorkspaceRowView()
        rowView.identifier = identifier
        rowView.configure(
            workspace: workspace,
            isActive: workspace.id == store.activeID,
            canAddChild: store.depth(of: workspace) < 5,
            onAddChild: { [weak self] workspace in
                self?.onAddChild?(workspace)
            },
            onRename: { [weak self] workspace, name in
                self?.store.rename(workspace, to: name)
            },
            onSettings: { [weak self] workspace in
                self?.onSettings?(workspace)
            },
            onDelete: { [weak self] workspace, anchorView in
                self?.onDelete?(workspace, anchorView)
            }
        )
        return rowView
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        let row = outlineView.selectedRow
        guard row >= 0, let workspace = outlineView.item(atRow: row) as? Workspace else {
            return
        }
        onSelectWorkspace?(workspace)
    }

    func outlineViewItemDidExpand(_ notification: Notification) {
        if let workspace = notification.userInfo?["NSObject"] as? Workspace {
            workspace.isExpanded = true
        }
    }

    func outlineViewItemDidCollapse(_ notification: Notification) {
        if let workspace = notification.userInfo?["NSObject"] as? Workspace {
            workspace.isExpanded = false
        }
    }
}
