import Foundation

final class Workspace {
    let id: UUID
    var name: String
    var defaultDirectory: String {
        didSet {
            tileContainer.defaultDirectory = defaultDirectory
        }
    }
    var children: [Workspace]
    weak var parent: Workspace?
    var isExpanded: Bool
    let tileContainer: TileContainerView
    var terminalCount: Int

    init(
        id: UUID = UUID(),
        name: String,
        defaultDirectory: String = "",
        children: [Workspace] = [],
        isExpanded: Bool = true,
        tileContainer: TileContainerView = TileContainerView()
    ) {
        self.id = id
        self.name = name
        self.defaultDirectory = defaultDirectory
        self.children = children
        self.isExpanded = isExpanded
        self.tileContainer = tileContainer
        terminalCount = tileContainer.terminalCount
        tileContainer.defaultDirectory = defaultDirectory
        children.forEach { $0.parent = self }
    }
}
