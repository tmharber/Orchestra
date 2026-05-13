import CoreGraphics
import Foundation

enum SplitAxis {
    case horizontal
    case vertical
}

enum SplitInsertionEdge {
    case left
    case right
    case top
    case bottom

    var axis: SplitAxis {
        switch self {
        case .left, .right:
            return .horizontal
        case .top, .bottom:
            return .vertical
        }
    }

    var insertsBeforeExistingPane: Bool {
        switch self {
        case .left, .top:
            return true
        case .right, .bottom:
            return false
        }
    }
}

indirect enum TileNode {
    case leaf(id: UUID)
    case split(id: UUID, axis: SplitAxis, first: TileNode, second: TileNode, ratio: CGFloat)

    var id: UUID {
        switch self {
        case .leaf(let id), .split(let id, _, _, _, _):
            return id
        }
    }
}
