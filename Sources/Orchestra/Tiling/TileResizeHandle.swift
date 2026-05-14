import AppKit

final class TileResizeHandle: NSView {
    private let axis: SplitAxis
    private let splitID: UUID
    private let frameProvider: (UUID) -> NSRect?
    private let onResize: (UUID, CGFloat) -> Void
    private let onResizeEnded: () -> Void
    private let minimumPaneSize = NSSize(width: 200, height: 100)
    private let indicator = NSView()
    private var trackingArea: NSTrackingArea?
    private var isHovered = false
    private var isDragging = false

    init(
        axis: SplitAxis,
        splitID: UUID,
        frameProvider: @escaping (UUID) -> NSRect?,
        onResize: @escaping (UUID, CGFloat) -> Void,
        onResizeEnded: @escaping () -> Void
    ) {
        self.axis = axis
        self.splitID = splitID
        self.frameProvider = frameProvider
        self.onResize = onResize
        self.onResizeEnded = onResizeEnded
        super.init(frame: .zero)

        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        indicator.wantsLayer = true
        indicator.layer?.cornerRadius = 1
        indicator.layer?.cornerCurve = .continuous
        indicator.layer?.backgroundColor = NSColor.clear.cgColor
        addSubview(indicator)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        let thickness: CGFloat = 2
        switch axis {
        case .horizontal:
            indicator.frame = NSRect(
                x: (bounds.width - thickness) / 2,
                y: 0,
                width: thickness,
                height: bounds.height
            )
        case .vertical:
            indicator.frame = NSRect(
                x: 0,
                y: (bounds.height - thickness) / 2,
                width: bounds.width,
                height: thickness
            )
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        trackingArea = area
        addTrackingArea(area)
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        applyHoverState()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        applyHoverState()
    }

    private func applyHoverState() {
        let highlighted = isHovered || isDragging
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            indicator.animator().layer?.backgroundColor = highlighted
                ? NSColor.controlAccentColor.withAlphaComponent(0.6).cgColor
                : NSColor.clear.cgColor
        }
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

        isDragging = true
        applyHoverState()
        updateRatio(with: event, parentFrame: parentFrame, in: container)

        while true {
            guard let nextEvent = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp, .keyDown]) else {
                isDragging = false
                applyHoverState()
                return
            }

            if nextEvent.type == .leftMouseUp {
                isDragging = false
                applyHoverState()
                onResizeEnded()
                return
            }

            if nextEvent.type == .keyDown {
                guard nextEvent.keyCode != 53 else {
                    isDragging = false
                    applyHoverState()
                    onResizeEnded()
                    return
                }

                NSApp.sendEvent(nextEvent)
                continue
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
            let span = max(parentFrame.width - TileLayoutMetrics.dividerSize, 1)
            let minimumRatio = minimumPaneSize.width / span
            guard minimumRatio < 0.5 else {
                return 0.5
            }

            return ((point.x - parentFrame.minX) / span).clamped(to: minimumRatio...(1 - minimumRatio))
        case .vertical:
            let span = max(parentFrame.height - TileLayoutMetrics.dividerSize, 1)
            let minimumRatio = minimumPaneSize.height / span
            guard minimumRatio < 0.5 else {
                return 0.5
            }

            return ((parentFrame.maxY - point.y) / span).clamped(to: minimumRatio...(1 - minimumRatio))
        }
    }
}

enum TileLayoutMetrics {
    static let dividerSize: CGFloat = 8
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
