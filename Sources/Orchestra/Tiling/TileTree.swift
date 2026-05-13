import CoreGraphics
import Foundation

final class TileTree {
    private(set) var root: TileNode?

    var isEmpty: Bool {
        root == nil
    }

    init(rootID: UUID) {
        root = .leaf(id: rootID)
    }

    init() {
        root = nil
    }

    func setRoot(id: UUID) {
        root = .leaf(id: id)
    }

    func splitLeaf(id: UUID, edge: SplitInsertionEdge, newID: UUID) -> Bool {
        guard var root else {
            return false
        }

        defer {
            self.root = root
        }

        return splitLeaf(id: id, edge: edge, newID: newID, in: &root)
    }

    func closeLeaf(id: UUID) -> TileCloseResult? {
        guard var root else {
            return nil
        }

        if case .leaf(let rootID) = root, rootID == id {
            self.root = nil
            return TileCloseResult(closedID: rootID, focusID: nil)
        }

        let result = closeLeaf(id: id, in: &root)
        self.root = root
        return result
    }

    func containsLeaf(id: UUID) -> Bool {
        guard let root else {
            return false
        }

        return containsLeaf(id: id, in: root)
    }

    func firstLeafID() -> UUID? {
        guard let root else {
            return nil
        }

        return firstLeafID(in: root)
    }

    func updateRatio(splitID: UUID, ratio: CGFloat) -> Bool {
        guard var root else {
            return false
        }

        defer {
            self.root = root
        }

        return updateRatio(splitID: splitID, ratio: ratio, in: &root)
    }

    private func splitLeaf(id: UUID, edge: SplitInsertionEdge, newID: UUID, in node: inout TileNode) -> Bool {
        switch node {
        case .leaf(let leafID):
            guard leafID == id else {
                return false
            }

            let existing = TileNode.leaf(id: leafID)
            let new = TileNode.leaf(id: newID)
            node = .split(
                id: UUID(),
                axis: edge.axis,
                first: edge.insertsBeforeExistingPane ? new : existing,
                second: edge.insertsBeforeExistingPane ? existing : new,
                ratio: 0.5
            )
            return true

        case .split(let splitID, let axis, var first, var second, let ratio):
            if splitLeaf(id: id, edge: edge, newID: newID, in: &first) {
                node = .split(id: splitID, axis: axis, first: first, second: second, ratio: ratio)
                return true
            }

            if splitLeaf(id: id, edge: edge, newID: newID, in: &second) {
                node = .split(id: splitID, axis: axis, first: first, second: second, ratio: ratio)
                return true
            }

            return false
        }
    }

    private func closeLeaf(id: UUID, in node: inout TileNode) -> TileCloseResult? {
        switch node {
        case .leaf:
            return nil

        case .split(_, _, let first, let second, _):
            if case .leaf(let firstID) = first, firstID == id {
                node = second
                return TileCloseResult(closedID: firstID, focusID: firstLeafID(in: second))
            }

            if case .leaf(let secondID) = second, secondID == id {
                node = first
                return TileCloseResult(closedID: secondID, focusID: firstLeafID(in: first))
            }
        }

        guard case .split(let splitID, let axis, var first, var second, let ratio) = node else {
            return nil
        }

        if let closed = closeLeaf(id: id, in: &first) {
            node = .split(id: splitID, axis: axis, first: first, second: second, ratio: ratio)
            return closed
        }

        if let closed = closeLeaf(id: id, in: &second) {
            node = .split(id: splitID, axis: axis, first: first, second: second, ratio: ratio)
            return closed
        }

        return nil
    }

    private func containsLeaf(id: UUID, in node: TileNode) -> Bool {
        switch node {
        case .leaf(let leafID):
            return leafID == id
        case .split(_, _, let first, let second, _):
            return containsLeaf(id: id, in: first) || containsLeaf(id: id, in: second)
        }
    }

    private func firstLeafID(in node: TileNode) -> UUID? {
        switch node {
        case .leaf(let id):
            return id
        case .split(_, _, let first, let second, _):
            return firstLeafID(in: first) ?? firstLeafID(in: second)
        }
    }

    private func updateRatio(splitID: UUID, ratio: CGFloat, in node: inout TileNode) -> Bool {
        switch node {
        case .leaf:
            return false

        case .split(let id, let axis, var first, var second, let existingRatio):
            if id == splitID {
                node = .split(id: id, axis: axis, first: first, second: second, ratio: ratio)
                return true
            }

            if updateRatio(splitID: splitID, ratio: ratio, in: &first) {
                node = .split(id: id, axis: axis, first: first, second: second, ratio: existingRatio)
                return true
            }

            if updateRatio(splitID: splitID, ratio: ratio, in: &second) {
                node = .split(id: id, axis: axis, first: first, second: second, ratio: existingRatio)
                return true
            }

            return false
        }
    }
}

struct TileCloseResult {
    let closedID: UUID
    let focusID: UUID?
}
