import AppKit

final class WorkspaceNavigatorView: NSView {
    private let store: WorkspaceStore
    private let titleLabel = NSTextField(labelWithString: "Workspaces")
    private let addRootButton = NSButton()
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
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = .labelColor

        addRootButton.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "Add workspace")
        addRootButton.imagePosition = .imageOnly
        addRootButton.isBordered = false
        addRootButton.target = self
        addRootButton.action = #selector(addRoot(_:))
        addRootButton.toolTip = "Add workspace"

        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        column.minWidth = 0
        outlineView.headerView = nil
        outlineView.rowHeight = 30
        outlineView.intercellSpacing = NSSize(width: 0, height: 2)
        outlineView.indentationPerLevel = 12
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

        let headerHeight: CGFloat = 52
        let titleHeight: CGFloat = 22
        let buttonSize: CGFloat = 24
        let headerTopPadding: CGFloat = 14
        let headerY = bounds.height - buttonSize - headerTopPadding
        titleLabel.frame = NSRect(
            x: 14,
            y: headerY + floor((buttonSize - titleHeight) / 2),
            width: max(0, bounds.width - 14 - buttonSize - 12),
            height: titleHeight
        )
        addRootButton.frame = NSRect(
            x: bounds.width - buttonSize - 10,
            y: headerY,
            width: buttonSize,
            height: buttonSize
        )
        scrollView.frame = NSRect(x: 0, y: 0, width: bounds.width, height: max(0, bounds.height - headerHeight))
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
