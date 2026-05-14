import XCTest
@testable import Orchestra

final class WorkspaceStoreTests: XCTestCase {
    func testStoreBootsWithDefaultWorkspace() {
        let store = WorkspaceStore()

        XCTAssertEqual(store.roots.count, 1)
        XCTAssertEqual(store.roots[0].name, WorkspaceStore.defaultWorkspaceName)
        XCTAssertEqual(store.activeID, store.roots[0].id)
    }

    func testAddingDefaultWorkspaceReusesEmptyPlaceholder() {
        let store = WorkspaceStore()

        let workspace = store.addRoot()

        XCTAssertEqual(store.roots.map(\.name), [WorkspaceStore.defaultWorkspaceName])
        XCTAssertEqual(store.activeID, workspace.id)
    }

    func testAddingNamedWorkspaceKeepsExistingDefaultWorkspace() {
        let store = WorkspaceStore()

        let workspace = store.addRoot(name: "Orchestra")

        XCTAssertEqual(store.roots.map(\.name), [WorkspaceStore.defaultWorkspaceName, "Orchestra"])
        XCTAssertEqual(store.activeID, workspace.id)
    }

    func testTerminalCountChangeDoesNotRemoveWorkspace() {
        let store = WorkspaceStore()
        let first = store.roots[0]
        _ = store.addRoot(name: "Orchestra")

        first.terminalCount = 0
        store.ensureAtLeastOneWorkspace()

        XCTAssertEqual(store.roots.map(\.name), [WorkspaceStore.defaultWorkspaceName, "Orchestra"])
    }

    func testDeletingLastWorkspaceCreatesFreshDefaultWorkspace() {
        let store = WorkspaceStore()
        let originalID = store.roots[0].id

        store.delete(store.roots[0])

        XCTAssertEqual(store.roots.count, 1)
        XCTAssertEqual(store.roots[0].name, WorkspaceStore.defaultWorkspaceName)
        XCTAssertNotEqual(store.roots[0].id, originalID)
        XCTAssertEqual(store.activeID, store.roots[0].id)
    }

    func testChildWorkspaceCopiesParentDefaultDirectoryAtCreation() throws {
        let store = WorkspaceStore()
        let parent = store.addRoot(name: "Parent")
        parent.defaultDirectory = "~/dev/testA"

        let child = try XCTUnwrap(store.addChild(parent: parent, name: "Child"))

        XCTAssertEqual(child.defaultDirectory, "~/dev/testA")

        child.defaultDirectory = "~/dev/testB"
        XCTAssertEqual(parent.defaultDirectory, "~/dev/testA")
        XCTAssertEqual(child.defaultDirectory, "~/dev/testB")
    }

    func testDepthCapPreventsChildrenPastFiveLevels() throws {
        let store = WorkspaceStore()
        let root = store.addRoot(name: "Root")
        var current = root

        for index in 2...5 {
            current = try XCTUnwrap(store.addChild(parent: current, name: "Level \(index)"))
        }

        XCTAssertNil(store.addChild(parent: current, name: "Too Deep"))
    }

    func testDeletingWorkspaceClearsTerminalCountCallbackBeforeTermination() {
        let workspace = Workspace(name: "Root")
        let store = WorkspaceStore(roots: [workspace])

        store.delete(workspace)

        XCTAssertNil(workspace.tileContainer.onTerminalCountChanged)
    }
}
