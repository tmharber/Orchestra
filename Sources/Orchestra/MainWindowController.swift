import AppKit

final class MainWindowController: NSWindowController, NSToolbarDelegate {
    private let contentView = MainContentView()
    private weak var addTerminalButton: NSButton?

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
        installToolbar()
        contentView.tileContainer.onSplitModeChanged = { [weak self] isActive in
            self?.updateAddTerminalButton(isActive: isActive)
        }
    }

    private func installToolbar() {
        let toolbar = NSToolbar(identifier: "OrchestraToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        window?.toolbar = toolbar
    }

    @objc func enterSplitMode(_ sender: Any?) {
        contentView.tileContainer.enterSplitMode()
    }

    @objc func toggleSplitMode(_ sender: Any?) {
        contentView.tileContainer.toggleSplitMode()
    }

    @objc func closeActivePane(_ sender: Any?) {
        contentView.tileContainer.closeActivePane()
    }

    @objc func splitActivePaneRight(_ sender: Any?) {
        contentView.tileContainer.splitActivePane(edge: .right)
    }

    @objc func splitActivePaneDown(_ sender: Any?) {
        contentView.tileContainer.splitActivePane(edge: .bottom)
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
            let button = NSButton(
                image: NSImage(systemSymbolName: "plus", accessibilityDescription: "Add terminal") ?? NSImage(),
                target: self,
                action: #selector(toggleSplitMode(_:))
            )
            button.setButtonType(.toggle)
            button.bezelStyle = .texturedRounded
            button.toolTip = "Add terminal"
            button.translatesAutoresizingMaskIntoConstraints = false
            button.widthAnchor.constraint(equalToConstant: 32).isActive = true
            button.heightAnchor.constraint(equalToConstant: 28).isActive = true
            item.view = button
            addTerminalButton = button
            updateAddTerminalButton(isActive: contentView.tileContainer.isSplitModeActive)
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
}

private extension NSToolbarItem.Identifier {
    static let addTerminal = NSToolbarItem.Identifier("AddTerminal")
    static let toggleLeftSidebar = NSToolbarItem.Identifier("ToggleLeftSidebar")
    static let toggleRightSidebar = NSToolbarItem.Identifier("ToggleRightSidebar")
}

final class MainContentView: NSView {
    private let sidebarWidth: CGFloat = 220
    private let leftSidebar = SidebarPlaceholderView(title: "Tasks", detail: "Agent status and task list")
    private let rightSidebar = SidebarPlaceholderView(title: "Context", detail: "Notes and shared context")
    let tileContainer = TileContainerView()

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
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        addSubview(leftSidebar)
        addSubview(tileContainer)
        addSubview(rightSidebar)
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
        }

        if isRightSidebarVisible {
            rightSidebar.isHidden = false
        }

        guard shouldAnimate else {
            leftSidebar.frame = frames.leftSidebar
            rightSidebar.frame = frames.rightSidebar
            tileContainer.frame = frames.tileContainer
            leftSidebar.alphaValue = isLeftSidebarVisible ? 1 : 0
            rightSidebar.alphaValue = isRightSidebarVisible ? 1 : 0
            leftSidebar.isHidden = !isLeftSidebarVisible
            rightSidebar.isHidden = !isRightSidebarVisible
            return
        }

        layoutSubtreeIfNeeded()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            leftSidebar.animator().frame = frames.leftSidebar
            rightSidebar.animator().frame = frames.rightSidebar
            tileContainer.animator().frame = frames.tileContainer
            leftSidebar.animator().alphaValue = isLeftSidebarVisible ? 1 : 0
            rightSidebar.animator().alphaValue = isRightSidebarVisible ? 1 : 0
        } completionHandler: {
            self.leftSidebar.isHidden = !self.isLeftSidebarVisible
            self.rightSidebar.isHidden = !self.isRightSidebarVisible
        }
    }

    private func targetFrames() -> (leftSidebar: NSRect, tileContainer: NSRect, rightSidebar: NSRect) {

        let leftWidth = isLeftSidebarVisible ? sidebarWidth : 0
        let rightWidth = isRightSidebarVisible ? sidebarWidth : 0
        let dividerWidth: CGFloat = 1

        let rightX = bounds.width - rightWidth
        let tileX = leftWidth + (leftWidth > 0 ? dividerWidth : 0)
        let tileWidth = max(0, rightX - tileX - (rightWidth > 0 ? dividerWidth : 0))

        return (
            leftSidebar: NSRect(x: 0, y: 0, width: leftWidth, height: bounds.height),
            tileContainer: NSRect(x: tileX, y: 0, width: tileWidth, height: bounds.height),
            rightSidebar: NSRect(x: rightX, y: 0, width: rightWidth, height: bounds.height)
        )
    }
}

final class SidebarPlaceholderView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")

    init(title: String, detail: String) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        titleLabel.stringValue = title
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .labelColor

        detailLabel.stringValue = detail
        detailLabel.font = .systemFont(ofSize: 12)
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

        let padding: CGFloat = 16
        titleLabel.frame = NSRect(
            x: padding,
            y: bounds.height - padding - 20,
            width: max(0, bounds.width - padding * 2),
            height: 20
        )
        detailLabel.frame = NSRect(
            x: padding,
            y: bounds.height - padding - 76,
            width: max(0, bounds.width - padding * 2),
            height: 44
        )
    }
}
