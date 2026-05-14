import AppKit

final class WorkspaceSettingsDialogView: NSView {
    private let nameLabel = NSTextField(labelWithString: "Name")
    private let nameField = NSTextField(string: "")
    private let directoryLabel = NSTextField(labelWithString: "Default Directory")
    private let directoryField = NSTextField(string: "")

    var workspaceName: String {
        nameField.stringValue
    }

    var defaultDirectory: String {
        directoryField.stringValue
    }

    init(workspace: Workspace) {
        super.init(frame: NSRect(x: 0, y: 0, width: 400, height: 136))

        nameLabel.font = DS.Typography.dialogLabel()
        nameLabel.textColor = .labelColor
        nameField.stringValue = workspace.name
        nameField.font = DS.Typography.dialogValue()

        directoryLabel.font = DS.Typography.dialogLabel()
        directoryLabel.textColor = .labelColor
        directoryField.stringValue = workspace.defaultDirectory
        directoryField.placeholderString = NSHomeDirectory()
        directoryField.font = DS.Typography.dialogMono()

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

        let labelHeight: CGFloat = 16
        let fieldHeight: CGFloat = 24
        let gapLabelToField: CGFloat = 6
        let gapBetweenGroups: CGFloat = 16

        nameLabel.frame = NSRect(x: 0, y: bounds.height - labelHeight, width: bounds.width, height: labelHeight)
        nameField.frame = NSRect(
            x: 0,
            y: nameLabel.frame.minY - gapLabelToField - fieldHeight,
            width: bounds.width,
            height: fieldHeight
        )
        directoryLabel.frame = NSRect(
            x: 0,
            y: nameField.frame.minY - gapBetweenGroups - labelHeight,
            width: bounds.width,
            height: labelHeight
        )
        directoryField.frame = NSRect(
            x: 0,
            y: directoryLabel.frame.minY - gapLabelToField - fieldHeight,
            width: bounds.width,
            height: fieldHeight
        )
    }

    func focusField(in window: NSWindow?) {
        window?.makeFirstResponder(nameField)
        nameField.currentEditor()?.selectAll(nil)
    }
}
