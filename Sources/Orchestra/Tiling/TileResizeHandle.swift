import AppKit

final class TileResizeHandle: NSView {
    private let axis: SplitAxis
    private let splitID: UUID
    private let frameProvider: (UUID) -> NSRect?
    private let onResize: (UUID, CGFloat) -> Void
    private let minimumPaneSize = NSSize(width: 200, height: 100)
    private let dividerSize: CGFloat = 8

    init(
        axis: SplitAxis,
        splitID: UUID,
        frameProvider: @escaping (UUID) -> NSRect?,
        onResize: @escaping (UUID, CGFloat) -> Void
    ) {
        self.axis = axis
        self.splitID = splitID
        self.frameProvider = frameProvider
        self.onResize = onResize
        super.init(frame: .zero)

        wantsLayer = true
        layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.12).cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func resetCursorRects() {
        switch axis {
        case .horizontal:
            addCursorRect(bounds, cursor: .resizeLeftRight)
        case .vertical:
            addCursorRect(bounds, cursor: .resizeUpDown)
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard
            let container = superview as? TileContainerView,
            let parentFrame = frameProvider(splitID),
            let window
        else {
            return
        }

        updateRatio(with: event, parentFrame: parentFrame, in: container)

        while true {
            guard let nextEvent = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) else {
                return
            }

            if nextEvent.type == .leftMouseUp {
                return
            }

            updateRatio(with: nextEvent, parentFrame: parentFrame, in: container)
        }
    }

    private func updateRatio(with event: NSEvent, parentFrame: NSRect, in container: TileContainerView) {
        let point = container.convert(event.locationInWindow, from: nil)
        onResize(splitID, ratio(for: point, parentFrame: parentFrame))
    }

    private func ratio(for point: NSPoint, parentFrame: NSRect) -> CGFloat {
        switch axis {
        case .horizontal:
            let span = max(parentFrame.width - dividerSize, 1)
            let minimumRatio = minimumPaneSize.width / span
            guard minimumRatio < 0.5 else {
                return 0.5
            }

            return ((point.x - parentFrame.minX) / span).clamped(to: minimumRatio...(1 - minimumRatio))
        case .vertical:
            let span = max(parentFrame.height - dividerSize, 1)
            let minimumRatio = minimumPaneSize.height / span
            guard minimumRatio < 0.5 else {
                return 0.5
            }

            return ((parentFrame.maxY - point.y) / span).clamped(to: minimumRatio...(1 - minimumRatio))
        }
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
