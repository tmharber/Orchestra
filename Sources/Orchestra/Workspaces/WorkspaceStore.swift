import Foundation

final class WorkspaceStore {
    static let defaultWorkspaceName = "Workspace"

    var roots: [Workspace]
    var activeID: UUID
    var onChange: (() -> Void)?
    var onActiveWorkspaceChanged: ((Workspace) -> Void)?

    var active: Workspace {
        if let workspace = workspace(id: activeID) {
            return workspace
        }

        ensureAtLeastOneWorkspace()
        return workspace(id: activeID) ?? roots[0]
    }

    init(roots: [Workspace] = []) {
        self.roots = roots
        roots.forEach { $0.parent = nil }

        if let first = roots.first {
            activeID = first.id
        } else {
            let workspace = Workspace(name: Self.defaultWorkspaceName)
            self.roots = [workspace]
            activeID = workspace.id
        }

        wireTerminalCountCallbacks()
        ensureAtLeastOneWorkspace(notify: false)
    }

    @discardableResult
    func addRoot(name: String = WorkspaceStore.defaultWorkspaceName) -> Workspace {
        if let placeholder = reusableDefaultWorkspace(for: name) {
            activeID = placeholder.id
            onChange?()
            onActiveWorkspaceChanged?(placeholder)
            return placeholder
        }

        let workspace = Workspace(name: name)
        workspace.parent = nil
        roots.append(workspace)
        wireTerminalCountCallback(for: workspace)
        activeID = workspace.id
        onChange?()
        onActiveWorkspaceChanged?(active)
        return workspace
    }

    @discardableResult
    func addChild(parent: Workspace, name: String = WorkspaceStore.defaultWorkspaceName) -> Workspace? {
        guard depth(of: parent) < 5 else {
            return nil
        }

        let child = Workspace(name: name, defaultDirectory: parent.defaultDirectory)
        child.parent = parent
        parent.children.append(child)
        parent.isExpanded = true
        wireTerminalCountCallback(for: child)
        activeID = child.id
        onChange?()
        onActiveWorkspaceChanged?(active)
        return child
    }

    func delete(_ workspace: Workspace) {
        let deletedActiveWorkspace = contains(workspaceID: activeID, in: workspace)
        terminateSubtree(workspace)
        remove(workspace)
        ensureAtLeastOneWorkspace(notify: false)
        if deletedActiveWorkspace || self.workspace(id: activeID) == nil {
            activeID = firstWorkspace()?.id ?? roots[0].id
        }

        onChange?()
        onActiveWorkspaceChanged?(active)
    }

    func setActive(_ id: UUID) {
        guard activeID != id, workspace(id: id) != nil else {
            return
        }

        activeID = id
        onActiveWorkspaceChanged?(active)
        onChange?()
    }

    func rename(_ workspace: Workspace, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, workspace.name != trimmed else {
            return
        }

        workspace.name = String(trimmed.prefix(80))
        onChange?()
    }

    func depth(of workspace: Workspace) -> Int {
        var depth = 1
        var current = workspace.parent
        while let parent = current {
            depth += 1
            current = parent.parent
        }
        return depth
    }

    func workspace(id: UUID) -> Workspace? {
        for root in roots {
            if let found = workspace(id: id, in: root) {
                return found
            }
        }
        return nil
    }

    func subtreeTerminalCount(for workspace: Workspace) -> Int {
        workspace.terminalCount + workspace.children.reduce(0) { $0 + subtreeTerminalCount(for: $1) }
    }

    func subtreeWorkspaceNames(for workspace: Workspace) -> [String] {
        workspace.children.flatMap { child in
            [child.name] + subtreeWorkspaceNames(for: child)
        }
    }

    func ensureAtLeastOneWorkspace() {
        ensureAtLeastOneWorkspace(notify: true)
    }

    private func ensureAtLeastOneWorkspace(notify: Bool) {
        if roots.isEmpty {
            let workspace = Workspace(name: Self.defaultWorkspaceName)
            roots = [workspace]
            wireTerminalCountCallback(for: workspace)
            activeID = workspace.id
            if notify {
                onActiveWorkspaceChanged?(workspace)
                onChange?()
            }
            return
        }

        if workspace(id: activeID) == nil {
            activeID = firstWorkspace()?.id ?? roots[0].id
        }
        if notify {
            onChange?()
        }
    }

    private func firstWorkspace() -> Workspace? {
        roots.first
    }

    private func reusableDefaultWorkspace(for name: String) -> Workspace? {
        guard
            name == Self.defaultWorkspaceName,
            roots.count == 1,
            let workspace = roots.first,
            workspace.name == Self.defaultWorkspaceName,
            workspace.children.isEmpty,
            workspace.tileContainer.paneCount == 0
        else {
            return nil
        }

        return workspace
    }

    private func workspace(id: UUID, in workspace: Workspace) -> Workspace? {
        if workspace.id == id {
            return workspace
        }

        for child in workspace.children {
            if let found = self.workspace(id: id, in: child) {
                return found
            }
        }
        return nil
    }

    private func contains(workspaceID: UUID, in workspace: Workspace) -> Bool {
        if workspace.id == workspaceID {
            return true
        }
        return workspace.children.contains { contains(workspaceID: workspaceID, in: $0) }
    }

    private func remove(_ workspace: Workspace) {
        if let parent = workspace.parent {
            parent.children.removeAll { $0.id == workspace.id }
        } else {
            roots.removeAll { $0.id == workspace.id }
        }
        workspace.parent = nil
    }

    private func terminateSubtree(_ workspace: Workspace) {
        workspace.children.forEach { terminateSubtree($0) }
        workspace.tileContainer.onTerminalCountChanged = nil
        workspace.tileContainer.terminateAll()
    }

    private func wireTerminalCountCallbacks() {
        roots.forEach { wireTerminalCountCallbacks(in: $0) }
    }

    private func wireTerminalCountCallbacks(in workspace: Workspace) {
        wireTerminalCountCallback(for: workspace)
        workspace.children.forEach { wireTerminalCountCallbacks(in: $0) }
    }

    private func wireTerminalCountCallback(for workspace: Workspace) {
        workspace.terminalCount = workspace.tileContainer.terminalCount
        workspace.tileContainer.onTerminalCountChanged = { [weak self, weak workspace] count in
            guard let self, let workspace else {
                return
            }

            workspace.terminalCount = count
            self.onChange?()
        }
    }
}
