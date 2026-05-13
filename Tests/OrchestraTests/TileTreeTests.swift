import XCTest
@testable import Orchestra

final class TileTreeTests: XCTestCase {
    func testSplitLeafAddsNewLeafAndPreservesExistingLeaf() {
        let rootID = UUID()
        let newID = UUID()
        let tree = TileTree(rootID: rootID)

        XCTAssertTrue(tree.splitLeaf(id: rootID, edge: .right, newID: newID))
        XCTAssertTrue(tree.containsLeaf(id: rootID))
        XCTAssertTrue(tree.containsLeaf(id: newID))
    }

    func testSplitLeafPlacesBeforeOrAfterBasedOnEdge() {
        let rootID = UUID()
        let leftID = UUID()
        let tree = TileTree(rootID: rootID)

        XCTAssertTrue(tree.splitLeaf(id: rootID, edge: .left, newID: leftID))

        guard case .split(_, .horizontal, let first, let second, _) = tree.root else {
            return XCTFail("Expected root split")
        }

        XCTAssertEqual(first.id, leftID)
        XCTAssertEqual(second.id, rootID)
    }

    func testSplitLeafPlacesAfterForRightEdge() {
        let rootID = UUID()
        let rightID = UUID()
        let tree = TileTree(rootID: rootID)

        XCTAssertTrue(tree.splitLeaf(id: rootID, edge: .right, newID: rightID))

        guard case .split(_, .horizontal, let first, let second, _) = tree.root else {
            return XCTFail("Expected root split")
        }

        XCTAssertEqual(first.id, rootID)
        XCTAssertEqual(second.id, rightID)
    }

    func testClosingOnlyLeafKeepsTreeAlive() {
        let rootID = UUID()
        let tree = TileTree(rootID: rootID)

        XCTAssertNil(tree.closeLeaf(id: rootID))
        XCTAssertTrue(tree.containsLeaf(id: rootID))
    }

    func testClosingLeafPromotesSibling() {
        let rootID = UUID()
        let newID = UUID()
        let tree = TileTree(rootID: rootID)

        XCTAssertTrue(tree.splitLeaf(id: rootID, edge: .right, newID: newID))
        XCTAssertEqual(tree.closeLeaf(id: rootID), rootID)
        XCTAssertFalse(tree.containsLeaf(id: rootID))
        XCTAssertTrue(tree.containsLeaf(id: newID))
        XCTAssertEqual(tree.firstLeafID(), newID)
    }

    func testUpdateRatioChangesOnlyMatchingSplit() {
        let rootID = UUID()
        let newID = UUID()
        let tree = TileTree(rootID: rootID)

        XCTAssertTrue(tree.splitLeaf(id: rootID, edge: .bottom, newID: newID))
        let splitID = tree.root.id

        XCTAssertTrue(tree.updateRatio(splitID: splitID, ratio: 0.7))

        guard case .split(_, _, _, _, let ratio) = tree.root else {
            return XCTFail("Expected root split")
        }

        XCTAssertEqual(ratio, 0.7)
    }
}
