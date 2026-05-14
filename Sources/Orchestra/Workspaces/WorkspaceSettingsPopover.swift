import AppKit

final class WorkspaceSettingsDialogView: NSView {
    private let nameLabel = NSTextField(labelWithString: "Name")
    private let nameField = NSTextField(string: "")
    private let directoryLabel = NSTextField(labelWithString: "Default directory")
    private let directoryField = NSTextField(string: "")

    var workspaceName: String {
        nameField.stringValue
    }

    var defaultDirectory: String {
        directoryField.stringValue
    }

    init(workspace: Workspace) {
        super.init(frame: NSRect(x: 0, y: 0, width: 380, height: 112))

        nameLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        nameLabel.textColor = .labelColor
        nameField.stringValue = workspace.name

        directoryLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        directoryLabel.textColor = .labelColor

        directoryField.stringValue = workspace.defaultDirectory
        directoryField.placeholderString = NSHomeDirectory()

        addSubview(nameLabel)
        addSubview(nameField)
        addSubview(directoryLabel)
        addSubview(directoryField)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()

        nameLabel.frame = NSRect(x: 0, y: bounds.height - 18, width: bounds.width, height: 16)
        nameField.frame = NSRect(x: 0, y: bounds.height - 48, width: bounds.width, height: 24)
        directoryLabel.frame = NSRect(x: 0, y: bounds.height - 78, width: bounds.width, height: 16)
        directoryField.frame = NSRect(x: 0, y: 4, width: bounds.width, height: 24)
    }

    func focusField(in window: NSWindow?) {
        window?.makeFirstResponder(nameField)
        nameField.currentEditor()?.selectAll(nil)
    }
}
