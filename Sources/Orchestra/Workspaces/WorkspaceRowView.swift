import AppKit

final class WorkspaceRowView: NSTableCellView {
    private let chromeView = NSView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let renameField = RenameTextField(frame: .zero)
    private let countBadge = NSTextField(labelWithString: "")
    private let addButton = NSButton()
    private let settingsButton = NSButton()
    private let deleteButton = NSButton()
    private var trackingArea: NSTrackingArea?
    private var workspace: Workspace?
    private var canAddChild = false
    private var isHovered = false {
        didSet {
            updateButtonVisibility()
            needsLayout = true
        }
    }

    var onAddChild: ((Workspace) -> Void)?
    var onRename: ((Workspace, String) -> Void)?
    var onSettings: ((Workspace) -> Void)?
    var onDelete: ((Workspace, NSView) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        clipsToBounds = false

        chromeView.wantsLayer = true
        chromeView.clipsToBounds = true
        chromeView.layer?.cornerRadius = 5
        chromeView.layer?.borderWidth = 0

        titleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        let renameGesture = NSClickGestureRecognizer(target: self, action: #selector(beginRenamingFromGesture(_:)))
        renameGesture.numberOfClicksRequired = 2
        titleLabel.addGestureRecognizer(renameGesture)

        renameField.font = .systemFont(ofSize: 13, weight: .regular)
        renameField.maximumLength = 80
        renameField.isHidden = true
        renameField.onCommit = { [weak self] name in
            self?.commitRename(name)
        }
        renameField.onCancel = { [weak self] in
            self?.cancelRename()
        }

        countBadge.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        countBadge.alignment = .center
        countBadge.textColor = .secondaryLabelColor
        countBadge.lineBreakMode = .byClipping
        countBadge.wantsLayer = true
        countBadge.layer?.cornerRadius = 7
        countBadge.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        configureIconButton(addButton, symbolName: "plus", tooltip: "Add child workspace", action: #selector(addChild(_:)))
        configureIconButton(settingsButton, symbolName: "gearshape", tooltip: "Workspace settings", action: #selector(openSettings(_:)))
        configureIconButton(deleteButton, symbolName: "xmark", tooltip: "Close workspace", action: #selector(deleteWorkspace(_:)))

        addSubview(chromeView)
        chromeView.addSubview(titleLabel)
        chromeView.addSubview(renameField)
        chromeView.addSubview(countBadge)
        chromeView.addSubview(addButton)
        chromeView.addSubview(settingsButton)
        chromeView.addSubview(deleteButton)
        updateButtonVisibility()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        workspace = nil
        canAddChild = false
        onAddChild = nil
        onRename = nil
        onSettings = nil
        onDelete = nil
        cancelRename()
        isHovered = false
    }

    func configure(
        workspace: Workspace,
        isActive: Bool,
        canAddChild: Bool,
        onAddChild: @escaping (Workspace) -> Void,
        onRename: @escaping (Workspace, String) -> Void,
        onSettings: @escaping (Workspace) -> Void,
        onDelete: @escaping (Workspace, NSView) -> Void
    ) {
        self.workspace = workspace
        self.onAddChild = onAddChild
        self.onRename = onRename
        self.onSettings = onSettings
        self.onDelete = onDelete
        if renameField.isHidden {
            titleLabel.stringValue = workspace.name
        }
        countBadge.stringValue = "\(workspace.terminalCount)"
        countBadge.isHidden = workspace.terminalCount == 0
        self.canAddChild = canAddChild
        addButton.contentTintColor = canAddChild ? .labelColor : .disabledControlTextColor

        if isActive {
            chromeView.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.14).cgColor
            chromeView.layer?.borderWidth = 1
            chromeView.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.75).cgColor
            titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        } else {
            chromeView.layer?.backgroundColor = isHovered ? NSColor.controlAccentColor.withAlphaComponent(0.08).cgColor : NSColor.clear.cgColor
            chromeView.layer?.borderWidth = 0
            titleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        }

        updateButtonVisibility()
        needsLayout = true
    }

    override func layout() {
        super.layout()

        let buttonSize: CGFloat = 20
        let buttonGap: CGFloat = 2
        let titleLeft: CGFloat = 8
        let minimumTitleWidth: CGFloat = 28
        let badgeGap: CGFloat = 6
        let rightPadding: CGFloat = 6
        let chromeFrame = visibleChromeFrame()
        chromeView.frame = chromeFrame
        let chromeBounds = chromeView.bounds
        var right = chromeBounds.maxX - rightPadding

        for button in [deleteButton, settingsButton, addButton] {
            button.frame = NSRect(
                x: right - buttonSize,
                y: floor((bounds.height - buttonSize) / 2),
                width: buttonSize,
                height: buttonSize
            )
            right = button.frame.minX - buttonGap
        }

        let desiredBadgeWidth = max(18, min(36, countBadge.intrinsicContentSize.width + 8))
        let textAreaRight = right - 4
        let maximumTitleWidthWithBadge = textAreaRight - titleLeft - badgeGap - desiredBadgeWidth
        let canShowBadge = countBadge.stringValue != "0" && maximumTitleWidthWithBadge >= minimumTitleWidth
        let naturalTitleWidth = ceil(titleLabel.intrinsicContentSize.width) + 8
        let titleWidth = canShowBadge
            ? min(naturalTitleWidth, maximumTitleWidthWithBadge)
            : max(0, textAreaRight - titleLeft)

        countBadge.isHidden = !canShowBadge
        if canShowBadge {
            countBadge.frame = NSRect(
                x: titleLeft + titleWidth + badgeGap,
                y: floor((bounds.height - 16) / 2),
                width: desiredBadgeWidth,
                height: 16
            )
        } else {
            countBadge.frame = NSRect(x: right, y: floor((bounds.height - 16) / 2), width: 0, height: 16)
        }

        titleLabel.frame = NSRect(
            x: titleLeft,
            y: floor((chromeBounds.height - 18) / 2),
            width: titleWidth,
            height: 18
        )
        renameField.frame = titleLabel.frame.insetBy(dx: -3, dy: -3)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let titlePoint = convert(point, to: chromeView)
        if event.clickCount == 2, titleLabel.frame.contains(titlePoint) {
            beginRenaming()
            return
        }

        super.mouseDown(with: event)
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
        if chromeView.layer?.borderWidth == 0 {
            chromeView.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.08).cgColor
        }
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        if chromeView.layer?.borderWidth == 0 {
            chromeView.layer?.backgroundColor = NSColor.clear.cgColor
        }
    }

    private func visibleChromeFrame() -> NSRect {
        guard let clipView = enclosingScrollView?.contentView else {
            return bounds
        }

        let rowOriginInClip = convert(NSPoint(x: bounds.minX, y: bounds.minY), to: clipView)
        let availableWidth = clipView.bounds.width - rowOriginInClip.x - 6
        return NSRect(
            x: bounds.minX,
            y: bounds.minY,
            width: max(0, min(bounds.width, availableWidth)),
            height: bounds.height
        )
    }

    private func configureIconButton(_ button: NSButton, symbolName: String, tooltip: String, action: Selector) {
        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: tooltip)
        button.imagePosition = .imageOnly
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.target = self
        button.action = action
        button.toolTip = tooltip
        button.contentTintColor = .labelColor
    }

    private func updateButtonVisibility() {
        let shouldShow = isHovered
        addButton.isHidden = !shouldShow
        settingsButton.isHidden = !shouldShow
        deleteButton.isHidden = !shouldShow
        addButton.isEnabled = shouldShow && canAddChild
        settingsButton.isEnabled = shouldShow
        deleteButton.isEnabled = shouldShow
    }

    @objc private func addChild(_ sender: Any?) {
        guard let workspace, addButton.isEnabled else {
            NSSound.beep()
            return
        }
        onAddChild?(workspace)
    }

    @objc private func openSettings(_ sender: Any?) {
        guard let workspace else {
            return
        }
        onSettings?(workspace)
    }

    @objc private func deleteWorkspace(_ sender: Any?) {
        guard let workspace else {
            return
        }
        onDelete?(workspace, deleteButton)
    }

    @objc private func beginRenamingFromGesture(_ sender: Any?) {
        beginRenaming()
    }

    private func beginRenaming() {
        guard let workspace else {
            return
        }

        renameField.stringValue = workspace.name
        renameField.isHidden = false
        titleLabel.isHidden = true
        window?.makeFirstResponder(renameField)
        renameField.currentEditor()?.selectAll(nil)
    }

    private func commitRename(_ rawName: String) {
        guard let workspace else {
            cancelRename()
            return
        }

        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            onRename?(workspace, trimmed)
            titleLabel.stringValue = workspace.name
        }

        renameField.isHidden = true
        titleLabel.isHidden = false
        window?.makeFirstResponder(nil)
    }

    private func cancelRename() {
        renameField.isHidden = true
        titleLabel.isHidden = false
    }
}
