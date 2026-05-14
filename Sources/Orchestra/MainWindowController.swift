import AppKit

final class MainWindowController: NSWindowController, NSToolbarDelegate {
    private let contentView = MainContentView()
    private weak var addTerminalButton: NSButton?
    private weak var observedTileContainer: TileContainerView?

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 820),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Orchestra"
        window.minSize = NSSize(width: 820, height: 520)
        self.init(window: window)
        configureWindow()
    }

    private func configureWindow() {
        window?.contentView = contentView
        window?.center()
        window?.titlebarSeparatorStyle = .none
        window?.titlebarAppearsTransparent = true
        installToolbar()
        contentView.onActiveTileContainerChanged = { [weak self] tileContainer in
            self?.observeTileContainer(tileContainer)
        }
        observeTileContainer(contentView.activeTileContainer)
    }

    private func installToolbar() {
        let toolbar = NSToolbar(identifier: "OrchestraToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        window?.toolbar = toolbar
    }

    @objc func enterSplitMode(_ sender: Any?) {
        contentView.activeTileContainer.enterSplitMode()
    }

    @objc func toggleSplitMode(_ sender: Any?) {
        contentView.activeTileContainer.toggleSplitMode()
    }

    @objc func closeActivePane(_ sender: Any?) {
        contentView.activeTileContainer.closeActivePane()
    }

    @objc func splitActivePaneRight(_ sender: Any?) {
        contentView.activeTileContainer.splitActivePane(edge: .right)
    }

    @objc func splitActivePaneDown(_ sender: Any?) {
        contentView.activeTileContainer.splitActivePane(edge: .bottom)
    }

    @objc func toggleActiveTerminalMouseReporting(_ sender: Any?) {
        contentView.activeTileContainer.toggleActivePaneMouseReporting()
    }

    @objc func toggleLeftSidebar(_ sender: Any?) {
        contentView.isLeftSidebarVisible.toggle()
    }

    @objc func toggleRightSidebar(_ sender: Any?) {
        contentView.isRightSidebarVisible.toggle()
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.toggleLeftSidebar, .addTerminal, .toggleRightSidebar, .flexibleSpace]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.toggleLeftSidebar, .addTerminal, .toggleRightSidebar]
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.target = self

        switch itemIdentifier {
        case .addTerminal:
            item.label = "Add Terminal"
            item.paletteLabel = "Add Terminal"
            item.toolTip = "Add terminal"
            let symbolConfig = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
            let image = (NSImage(systemSymbolName: "plus", accessibilityDescription: "Add terminal") ?? NSImage())
                .withSymbolConfiguration(symbolConfig) ?? NSImage()
            let button = NSButton(
                image: image,
                target: self,
                action: #selector(toggleSplitMode(_:))
            )
            button.setButtonType(.toggle)
            button.bezelStyle = .accessoryBarAction
            button.isBordered = true
            button.toolTip = "Add terminal"
            button.translatesAutoresizingMaskIntoConstraints = false
            button.widthAnchor.constraint(equalToConstant: 30).isActive = true
            button.heightAnchor.constraint(equalToConstant: 24).isActive = true
            item.view = button
            addTerminalButton = button
            updateAddTerminalButton(isActive: contentView.activeTileContainer.isSplitModeActive)
        case .toggleLeftSidebar:
            item.label = "Left Sidebar"
            item.paletteLabel = "Left Sidebar"
            item.toolTip = "Toggle left sidebar"
            item.image = NSImage(systemSymbolName: "sidebar.left", accessibilityDescription: "Toggle left sidebar")
            item.action = #selector(toggleLeftSidebar(_:))
        case .toggleRightSidebar:
            item.label = "Right Sidebar"
            item.paletteLabel = "Right Sidebar"
            item.toolTip = "Toggle right sidebar"
            item.image = NSImage(systemSymbolName: "sidebar.right", accessibilityDescription: "Toggle right sidebar")
            item.action = #selector(toggleRightSidebar(_:))
        default:
            return nil
        }

        return item
    }

    private func updateAddTerminalButton(isActive: Bool) {
        addTerminalButton?.state = isActive ? .on : .off
        addTerminalButton?.contentTintColor = isActive ? .controlAccentColor : .labelColor
        addTerminalButton?.toolTip = isActive ? "Exit add terminal mode" : "Add terminal"
    }

    private func observeTileContainer(_ tileContainer: TileContainerView) {
        observedTileContainer?.onSplitModeChanged = nil
        observedTileContainer = tileContainer
        tileContainer.onSplitModeChanged = { [weak self] isActive in
            self?.updateAddTerminalButton(isActive: isActive)
        }
        updateAddTerminalButton(isActive: tileContainer.isSplitModeActive)
    }

    func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(toggleActiveTerminalMouseReporting(_:)) {
            if let menuItem = item as? NSMenuItem {
                menuItem.state = contentView.activeTileContainer.activePaneAllowsTerminalMouseReporting ? .on : .off
            }

            return contentView.activeTileContainer.paneCount > 0
        }

        return true
    }
}

private extension NSToolbarItem.Identifier {
    static let addTerminal = NSToolbarItem.Identifier("AddTerminal")
    static let toggleLeftSidebar = NSToolbarItem.Identifier("ToggleLeftSidebar")
    static let toggleRightSidebar = NSToolbarItem.Identifier("ToggleRightSidebar")
}

final class MainContentView: NSView {
    private let sidebarWidth: CGFloat = DS.Metrics.sidebarWidth
    private let workspaceStore = WorkspaceStore()
    private let leftSidebar: WorkspaceNavigatorView
    private let rightSidebar = SidebarPlaceholderView(title: "Context", detail: "Notes and shared context")
    private let leftDivider = MainContentView.makeDivider()
    private let rightDivider = MainContentView.makeDivider()
    private weak var displayedTileContainer: TileContainerView?
    private var focusRestoreGeneration = 0
    var onActiveTileContainerChanged: ((TileContainerView) -> Void)?

    var activeTileContainer: TileContainerView {
        workspaceStore.active.tileContainer
    }

    var isLeftSidebarVisible = true {
        didSet {
            guard oldValue != isLeftSidebarVisible else {
                return
            }

            applyLayout(animated: true)
        }
    }

    var isRightSidebarVisible = true {
        didSet {
            guard oldValue != isRightSidebarVisible else {
                return
            }

            applyLayout(animated: true)
        }
    }

    override init(frame frameRect: NSRect) {
        leftSidebar = WorkspaceNavigatorView(store: workspaceStore)
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        configureWorkspaceCallbacks()

        addSubview(activeTileContainer)
        addSubview(leftSidebar)
        addSubview(rightSidebar)
        addSubview(leftDivider)
        addSubview(rightDivider)
        displayedTileContainer = activeTileContainer
    }

    private static func makeDivider() -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = DS.Palette.sidebarDivider.cgColor
        return view
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyDynamicColors()
    }

    private func applyDynamicColors() {
        let divider = DS.Palette.sidebarDivider.cgColor
        leftDivider.layer?.backgroundColor = divider
        rightDivider.layer?.backgroundColor = divider
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        applyLayout(animated: false)
    }

    private func applyLayout(animated: Bool) {
        let frames = targetFrames()
        let shouldAnimate = animated && window != nil

        if isLeftSidebarVisible {
            leftSidebar.isHidden = false
            leftDivider.isHidden = false
        }

        if isRightSidebarVisible {
            rightSidebar.isHidden = false
            rightDivider.isHidden = false
        }

        guard shouldAnimate else {
            leftSidebar.frame = frames.leftSidebar
            rightSidebar.frame = frames.rightSidebar
            leftDivider.frame = frames.leftDivider
            rightDivider.frame = frames.rightDivider
            displayedTileContainer?.frame = frames.tileContainer
            leftSidebar.alphaValue = isLeftSidebarVisible ? 1 : 0
            rightSidebar.alphaValue = isRightSidebarVisible ? 1 : 0
            leftDivider.alphaValue = isLeftSidebarVisible ? 1 : 0
            rightDivider.alphaValue = isRightSidebarVisible ? 1 : 0
            leftSidebar.isHidden = !isLeftSidebarVisible
            rightSidebar.isHidden = !isRightSidebarVisible
            leftDivider.isHidden = !isLeftSidebarVisible
            rightDivider.isHidden = !isRightSidebarVisible
            return
        }

        layoutSubtreeIfNeeded()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            leftSidebar.animator().frame = frames.leftSidebar
            rightSidebar.animator().frame = frames.rightSidebar
            leftDivider.animator().frame = frames.leftDivider
            rightDivider.animator().frame = frames.rightDivider
            displayedTileContainer?.animator().frame = frames.tileContainer
            leftSidebar.animator().alphaValue = isLeftSidebarVisible ? 1 : 0
            rightSidebar.animator().alphaValue = isRightSidebarVisible ? 1 : 0
            leftDivider.animator().alphaValue = isLeftSidebarVisible ? 1 : 0
            rightDivider.animator().alphaValue = isRightSidebarVisible ? 1 : 0
        } completionHandler: {
            self.leftSidebar.isHidden = !self.isLeftSidebarVisible
            self.rightSidebar.isHidden = !self.isRightSidebarVisible
            self.leftDivider.isHidden = !self.isLeftSidebarVisible
            self.rightDivider.isHidden = !self.isRightSidebarVisible
        }
    }

    private struct LayoutFrames {
        var leftSidebar: NSRect
        var leftDivider: NSRect
        var tileContainer: NSRect
        var rightDivider: NSRect
        var rightSidebar: NSRect
    }

    private func targetFrames() -> LayoutFrames {
        let leftWidth = isLeftSidebarVisible ? sidebarWidth : 0
        let rightWidth = isRightSidebarVisible ? sidebarWidth : 0
        let dividerWidth: CGFloat = 1

        let rightX = bounds.width - rightWidth
        let tileX = leftWidth + (leftWidth > 0 ? dividerWidth : 0)
        let tileWidth = max(0, rightX - tileX - (rightWidth > 0 ? dividerWidth : 0))

        return LayoutFrames(
            leftSidebar: NSRect(x: 0, y: 0, width: leftWidth, height: bounds.height),
            leftDivider: NSRect(x: leftWidth, y: 0, width: dividerWidth, height: bounds.height),
            tileContainer: NSRect(x: tileX, y: 0, width: tileWidth, height: bounds.height),
            rightDivider: NSRect(x: rightX - dividerWidth, y: 0, width: dividerWidth, height: bounds.height),
            rightSidebar: NSRect(x: rightX, y: 0, width: rightWidth, height: bounds.height)
        )
    }

    private func configureWorkspaceCallbacks() {
        leftSidebar.onSelectWorkspace = { [weak self] workspace in
            self?.workspaceStore.setActive(workspace.id)
        }
        leftSidebar.onAddRoot = { [weak self] in
            self?.workspaceStore.addRoot()
        }
        leftSidebar.onAddChild = { [weak self] workspace in
            self?.workspaceStore.addChild(parent: workspace)
        }
        leftSidebar.onSettings = { [weak self] workspace in
            self?.showSettings(for: workspace)
        }
        leftSidebar.onDelete = { [weak self] workspace, anchorView in
            self?.confirmDelete(workspace, anchoredTo: anchorView)
        }
        workspaceStore.onChange = { [weak self] in
            self?.leftSidebar.reloadData()
        }
        workspaceStore.onActiveWorkspaceChanged = { [weak self] workspace in
            self?.showWorkspace(workspace)
        }
    }

    private func showWorkspace(_ workspace: Workspace) {
        if displayedTileContainer !== workspace.tileContainer {
            displayedTileContainer?.removeFromSuperview()
            addSubview(workspace.tileContainer, positioned: .below, relativeTo: rightSidebar)
            displayedTileContainer = workspace.tileContainer
        }

        applyLayout(animated: false)
        onActiveTileContainerChanged?(workspace.tileContainer)
        focusRestoreGeneration += 1
        let generation = focusRestoreGeneration
        let workspaceID = workspace.id
        DispatchQueue.main.async { [weak self, weak workspace] in
            guard
                let self,
                let workspace,
                self.focusRestoreGeneration == generation,
                self.workspaceStore.activeID == workspaceID
            else {
                return
            }

            workspace.tileContainer.restoreFocus()
        }
    }

    private func confirmDelete(_ workspace: Workspace, anchoredTo anchorView: NSView) {
        let terminalCount = workspaceStore.subtreeTerminalCount(for: workspace)
        let childNames = workspaceStore.subtreeWorkspaceNames(for: workspace)

        guard terminalCount > 0 || !childNames.isEmpty else {
            workspaceStore.delete(workspace)
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Close \"\(workspace.name)\"?"
        alert.addButton(withTitle: "Close Workspace")
        alert.addButton(withTitle: "Cancel")
        alert.accessoryView = deleteWarningView(childNames: childNames, terminalCount: terminalCount)

        guard let window else {
            if alert.runModal() == .alertFirstButtonReturn {
                workspaceStore.delete(workspace)
            }
            return
        }

        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn else {
                return
            }
            self?.workspaceStore.delete(workspace)
        }
    }

    private func showSettings(for workspace: Workspace) {
        let settingsView = WorkspaceSettingsDialogView(workspace: workspace)
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Workspace Settings"
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        alert.accessoryView = settingsView

        guard let window else {
            if alert.runModal() == .alertFirstButtonReturn {
                workspaceStore.rename(workspace, to: settingsView.workspaceName)
                workspace.defaultDirectory = settingsView.defaultDirectory
                leftSidebar.reloadData()
            }
            return
        }

        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn else {
                return
            }
            self?.workspaceStore.rename(workspace, to: settingsView.workspaceName)
            workspace.defaultDirectory = settingsView.defaultDirectory
            self?.leftSidebar.reloadData()
        }

        DispatchQueue.main.async {
            settingsView.focusField(in: alert.window)
        }
    }

    private func deleteWarningView(childNames: [String], terminalCount: Int) -> NSView {
        let text = NSMutableAttributedString()
        if !childNames.isEmpty {
            text.append(NSAttributedString(string: "This will also close child workspaces \(formattedList(childNames)), terminating "))
        } else {
            text.append(NSAttributedString(string: "This will terminate "))
        }
        text.append(NSAttributedString(
            string: "\(terminalCount)",
            attributes: [.font: NSFont.systemFont(ofSize: 13, weight: .semibold)]
        ))
        text.append(NSAttributedString(string: " running \(terminalCount == 1 ? "terminal" : "terminals") in total."))

        let label = NSTextField(labelWithAttributedString: text)
        label.maximumNumberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.frame = NSRect(x: 0, y: 0, width: 360, height: 48)
        return label
    }

    private func formattedList(_ names: [String]) -> String {
        switch names.count {
        case 0:
            return ""
        case 1:
            return names[0]
        case 2:
            return "\(names[0]) and \(names[1])"
        default:
            let head = names.dropLast().joined(separator: ", ")
            return "\(head), and \(names[names.count - 1])"
        }
    }
}

final class SidebarPlaceholderView: NSVisualEffectView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")

    init(title: String, detail: String) {
        super.init(frame: .zero)
        material = .sidebar
        blendingMode = .behindWindow
        state = .followsWindowActiveState

        titleLabel.attributedStringValue = .tracked(
            title,
            font: DS.Typography.sidebarTitle(),
            color: .labelColor,
            tracking: -0.3
        )

        detailLabel.stringValue = detail
        detailLabel.font = DS.Typography.emptyStateSecondary()
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.lineBreakMode = .byWordWrapping
        detailLabel.maximumNumberOfLines = 0

        addSubview(titleLabel)
        addSubview(detailLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()

        let inset = DS.Metrics.sidebarInset
        let titleBaseline = DS.Metrics.sidebarHeaderTitleBaseline
        let titleHeight = DS.Metrics.sidebarHeaderTitleHeight

        titleLabel.frame = NSRect(
            x: inset,
            y: bounds.height - titleBaseline - titleHeight,
            width: max(0, bounds.width - inset * 2),
            height: titleHeight
        )

        detailLabel.frame = NSRect(
            x: inset,
            y: titleLabel.frame.minY - 14 - 48,
            width: max(0, bounds.width - inset * 2),
            height: 48
        )
    }
}
