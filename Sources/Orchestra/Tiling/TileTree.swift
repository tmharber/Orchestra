import CoreGraphics
import Foundation

final class TileTree {
    private(set) var root: TileNode

    init(rootID: UUID) {
        root = .leaf(id: rootID)
    }

    func splitLeaf(id: UUID, edge: SplitInsertionEdge, newID: UUID) -> Bool {
        splitLeaf(id: id, edge: edge, newID: newID, in: &root)
    }

    func closeLeaf(id: UUID) -> TileCloseResult? {
        if case .leaf(let rootID) = root, rootID == id {
            return nil
        }

        return closeLeaf(id: id, in: &root)
    }

    func containsLeaf(id: UUID) -> Bool {
        containsLeaf(id: id, in: root)
    }

    func firstLeafID() -> UUID? {
        firstLeafID(in: root)
    }

    func updateRatio(splitID: UUID, ratio: CGFloat) -> Bool {
        updateRatio(splitID: splitID, ratio: ratio, in: &root)
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
