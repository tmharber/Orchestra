import AppKit
import SwiftTerm

final class TerminalPaneView: NSView {
    let id = UUID()
    let terminalView = LocalProcessTerminalView(frame: .zero)
    private(set) var currentDirectory: String
    private(set) var hasReportedCurrentDirectory = false
    private(set) var isProcessRunning = false {
        didSet {
            guard oldValue != isProcessRunning else {
                return
            }

            onRunningStateChanged?(isProcessRunning)
        }
    }

    var onClose: ((UUID) -> Void)?
    var onFocus: ((UUID) -> Void)?
    var onRunningStateChanged: ((Bool) -> Void)?

    var isActive = false {
        didSet {
            if isActive {
                isAlerting = false
            }
            updateBorder()
        }
    }

    private var isAlerting = false {
        didSet {
            guard oldValue != isAlerting else { return }
            updateBorder()
        }
    }

    var canClose = true {
        didSet {
            closeButton.isEnabled = canClose
            closeButton.toolTip = canClose ? "Close terminal" : "At least one terminal must stay open"
            if !canClose {
                closeButton.isHidden = true
            }
        }
    }

    private let titleLabel = NSTextField(labelWithString: "")
    private let renameField = RenameTextField(frame: .zero)
    private let closeButton = NSButton()
    private let restartButton = NSButton()
    private let maximumPaneNameLength = 80
    private var paneName = "Terminal"
    private var currentFolderName: String
    private var processStatus: String?
    private var didStartProcess = false
    private var trackingArea: NSTrackingArea?
    private var bellInterceptor: BellInterceptingTerminalDelegate?

    init(frame frameRect: NSRect = .zero, currentDirectory: String = NSHomeDirectory()) {
        let resolvedDirectory = DirectoryResolver.existingDirectory(currentDirectory, fallback: NSHomeDirectory())
        self.currentDirectory = resolvedDirectory
        currentFolderName = URL(fileURLWithPath: resolvedDirectory).lastPathComponent
        super.init(frame: frameRect)

        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1
        layer?.backgroundColor = NSColor.black.cgColor

        titleLabel.font = .systemFont(ofSize: 11, weight: .medium)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(beginRenamingFromClick(_:))))

        renameField.font = .systemFont(ofSize: 11, weight: .medium)
        renameField.isHidden = true
        renameField.maximumLength = maximumPaneNameLength
        renameField.onCommit = { [weak self] name in
            self?.commitRename(name)
        }
        renameField.onCancel = { [weak self] in
            self?.cancelRename()
        }

        closeButton.bezelStyle = .circular
        closeButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close terminal")
        closeButton.imagePosition = .imageOnly
        closeButton.isBordered = false
        closeButton.target = self
        closeButton.action = #selector(closePane(_:))
        closeButton.isHidden = true

        restartButton.bezelStyle = .circular
        restartButton.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Restart terminal")
        restartButton.imagePosition = .imageOnly
        restartButton.isBordered = false
        restartButton.target = self
        restartButton.action = #selector(restartPane(_:))
        restartButton.toolTip = "Restart terminal"
        restartButton.isHidden = true

        terminalView.autoresizingMask = [.width, .height]
        terminalView.font = TerminalFontProvider.preferredFont()
        terminalView.allowMouseReporting = false
        terminalView.processDelegate = self

        if let wrapped = terminalView.terminalDelegate {
            let interceptor = BellInterceptingTerminalDelegate(
                wrapping: wrapped,
                onBell: { [weak self] in self?.handleBell() },
                onUserInput: { [weak self] in self?.handleUserInput() }
            )
            bellInterceptor = interceptor
            terminalView.terminalDelegate = interceptor
        }

        addSubview(titleLabel)
        addSubview(renameField)
        addSubview(restartButton)
        addSubview(closeButton)
        addSubview(terminalView)
        updateTitle()
        updateBorder()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        startProcessIfReady()
    }

    override func layout() {
        super.layout()

        let chromeHeight: CGFloat = 26
        restartButton.frame = NSRect(x: 7, y: bounds.height - 22, width: 16, height: 16)
        closeButton.frame = NSRect(x: restartButton.isHidden ? 7 : 27, y: bounds.height - 22, width: 16, height: 16)
        let titleX: CGFloat = restartButton.isHidden && closeButton.isHidden ? 30 : (closeButton.frame.maxX + 7)
        titleLabel.frame = NSRect(
            x: titleX,
            y: bounds.height - chromeHeight + 4,
            width: max(0, bounds.width - titleX - 12),
            height: 16
        )
        renameField.frame = titleLabel.frame.insetBy(dx: -3, dy: -2)
        terminalView.frame = NSRect(
            x: 1,
            y: 1,
            width: max(0, bounds.width - 2),
            height: max(0, bounds.height - chromeHeight - 1)
        )

        startProcessIfReady()
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if titleLabel.frame.contains(point) {
            beginRenaming()
            return
        }

        isAlerting = false
        onFocus?(id)
        window?.makeFirstResponder(terminalView)
        super.mouseDown(with: event)
    }

    private func handleBell() {
        isAlerting = true
    }

    fileprivate func handleUserInput() {
        isAlerting = false
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
        closeButton.isHidden = !canClose
        restartButton.isHidden = processStatus == nil
        needsLayout = true
    }

    override func mouseExited(with event: NSEvent) {
        closeButton.isHidden = true
        restartButton.isHidden = processStatus == nil
        needsLayout = true
    }

    @objc private func closePane(_ sender: Any?) {
        guard canClose else {
            NSSound.beep()
            return
        }

        onClose?(id)
    }

    func terminateProcess() {
        terminalView.terminate()
    }

    private func startProcessIfReady() {
        guard window != nil, !didStartProcess, terminalView.bounds.width > 0, terminalView.bounds.height > 0 else {
            return
        }

        didStartProcess = true
        isProcessRunning = true
        processStatus = nil
        restartButton.isHidden = true
        updateTitle()
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let shellName = URL(fileURLWithPath: shell).lastPathComponent
        terminalView.startProcess(
            executable: shell,
            args: ["-l"],
            environment: nil,
            execName: "-" + shellName,
            currentDirectory: currentDirectory
        )
    }

    private func updateTitle() {
        var parts = [paneName, currentFolderName]
        if let processStatus {
            parts.append(processStatus)
        }
        titleLabel.stringValue = parts.joined(separator: " · ")
    }

    private func beginRenaming() {
        renameField.stringValue = paneName
        renameField.isHidden = false
        titleLabel.isHidden = true
        window?.makeFirstResponder(renameField)
        renameField.currentEditor()?.selectAll(nil)
    }

    @objc private func beginRenamingFromClick(_ sender: Any?) {
        beginRenaming()
    }

    private func commitRename(_ rawName: String) {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        paneName = trimmed.isEmpty ? "Terminal" : String(trimmed.prefix(maximumPaneNameLength))
        renameField.isHidden = true
        titleLabel.isHidden = false
        updateTitle()
        window?.makeFirstResponder(terminalView)
    }

    private func cancelRename() {
        renameField.isHidden = true
        titleLabel.isHidden = false
        window?.makeFirstResponder(terminalView)
    }

    private func directoryPath(from directory: String?) -> String? {
        guard let directory, !directory.isEmpty else {
            return nil
        }

        if let url = URL(string: directory), url.scheme == "file" {
            return url.path.removingPercentEncoding ?? url.path
        }

        return directory
    }

    @objc private func restartPane(_ sender: Any?) {
        didStartProcess = false
        startProcessIfReady()
    }

    private func updateBorder() {
        let color: NSColor
        let width: CGFloat
        if isAlerting {
            color = NSColor.systemOrange
            width = 2
        } else if isActive {
            color = .controlAccentColor
            width = 1
        } else {
            color = .separatorColor
            width = 1
        }
        layer?.borderColor = color.cgColor
        layer?.borderWidth = width
    }
}

private final class BellInterceptingTerminalDelegate: NSObject, TerminalViewDelegate {
    private weak var wrapped: TerminalViewDelegate?
    private let onBell: () -> Void
    private let onUserInput: () -> Void

    init(
        wrapping wrapped: TerminalViewDelegate,
        onBell: @escaping () -> Void,
        onUserInput: @escaping () -> Void
    ) {
        self.wrapped = wrapped
        self.onBell = onBell
        self.onUserInput = onUserInput
    }

    func bell(source: TerminalView) {
        onBell()
    }

    func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
        wrapped?.sizeChanged(source: source, newCols: newCols, newRows: newRows)
    }

    func setTerminalTitle(source: TerminalView, title: String) {
        wrapped?.setTerminalTitle(source: source, title: title)
    }

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        wrapped?.hostCurrentDirectoryUpdate(source: source, directory: directory)
    }

    func send(source: TerminalView, data: ArraySlice<UInt8>) {
        onUserInput()
        wrapped?.send(source: source, data: data)
    }

    func scrolled(source: TerminalView, position: Double) {
        wrapped?.scrolled(source: source, position: position)
    }

    func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {
        if let wrapped {
            wrapped.requestOpenLink(source: source, link: link, params: params)
        } else if let url = URL(string: link) {
            NSWorkspace.shared.open(url)
        }
    }

    func clipboardCopy(source: TerminalView, content: Data) {
        wrapped?.clipboardCopy(source: source, content: content)
    }

    func iTermContent(source: TerminalView, content: ArraySlice<UInt8>) {
        wrapped?.iTermContent(source: source, content: content)
    }

    func rangeChanged(source: TerminalView, startY: Int, endY: Int) {
        wrapped?.rangeChanged(source: source, startY: startY, endY: endY)
    }
}

extension TerminalPaneView: LocalProcessTerminalViewDelegate {
    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        guard let directoryPath = directoryPath(from: directory), !directoryPath.isEmpty else {
            return
        }

        currentDirectory = directoryPath
        hasReportedCurrentDirectory = true
        currentFolderName = URL(fileURLWithPath: directoryPath).lastPathComponent
        updateTitle()
    }

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        didStartProcess = false
        isProcessRunning = false
        processStatus = exitCode.map { "Exited \($0)" } ?? "Exited"
        restartButton.isHidden = false
        updateTitle()
        needsLayout = true
    }
}

final class RenameTextField: NSTextField, NSTextFieldDelegate {
    var maximumLength = 80
    var onCommit: ((String) -> Void)?
    var onCancel: (() -> Void)?
    private var handledExplicitCommand = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        delegate = self
        isBezeled = true
        isBordered = true
        drawsBackground = true
        focusRingType = .none
        lineBreakMode = .byTruncatingTail
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func textDidEndEditing(_ notification: Notification) {
        super.textDidEndEditing(notification)

        guard !handledExplicitCommand else {
            handledExplicitCommand = false
            return
        }

        onCommit?(stringValue)
    }

    func controlTextDidChange(_ obj: Notification) {
        guard stringValue.count > maximumLength else {
            return
        }

        stringValue = String(stringValue.prefix(maximumLength))
    }

    func control(
        _ control: NSControl,
        textView: NSTextView,
        doCommandBy commandSelector: Selector
    ) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.insertNewline(_:)):
            handledExplicitCommand = true
            onCommit?(stringValue)
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            handledExplicitCommand = true
            onCancel?()
            return true
        default:
            return false
        }
    }
}
