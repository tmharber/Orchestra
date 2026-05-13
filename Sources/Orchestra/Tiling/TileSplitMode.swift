import AppKit

struct SplitCandidate: Equatable {
    let paneID: UUID
    let edge: SplitInsertionEdge
    let paneFrame: NSRect
}

final class TileSplitModeOverlayView: NSView {
    var candidateProvider: ((NSPoint) -> SplitCandidate?)?
    var onCommit: ((SplitCandidate) -> Void)?
    var onCancel: (() -> Void)?

    private var trackingArea: NSTrackingArea?
    private var pendingCandidate: SplitCandidate?
    private var visibleCandidate: SplitCandidate?
    private var dwellTimer: Timer?

    override var acceptsFirstResponder: Bool {
        true
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        dwellTimer?.invalidate()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseMoved, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        trackingArea = area
        addTrackingArea(area)
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let next = candidateProvider?(point)

        guard next != pendingCandidate else {
            return
        }

        pendingCandidate = next
        visibleCandidate = nil
        needsDisplay = true
        dwellTimer?.invalidate()

        if let next {
            dwellTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false) { [weak self] _ in
                self?.visibleCandidate = next
                self?.needsDisplay = true
            }
        }
    }

    override func mouseExited(with event: NSEvent) {
        clearCandidate()
    }

    override func mouseDown(with event: NSEvent) {
        guard let visibleCandidate else {
            return
        }

        onCommit?(visibleCandidate)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
        } else {
            super.keyDown(with: event)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.08).setFill()
        bounds.fill()

        guard let visibleCandidate else {
            return
        }

        let preview = previewFrame(for: visibleCandidate)
        NSColor.controlAccentColor.withAlphaComponent(0.25).setFill()
        preview.fill()

        let path = NSBezierPath(rect: preview)
        path.lineWidth = 2
        NSColor.controlAccentColor.withAlphaComponent(0.8).setStroke()
        path.stroke()
    }

    private func previewFrame(for candidate: SplitCandidate) -> NSRect {
        var frame = candidate.paneFrame

        switch candidate.edge {
        case .left:
            frame.size.width *= 0.5
        case .right:
            frame.origin.x += frame.width * 0.5
            frame.size.width *= 0.5
        case .top:
            frame.origin.y += frame.height * 0.5
            frame.size.height *= 0.5
        case .bottom:
            frame.size.height *= 0.5
        }

        return frame
    }

    private func clearCandidate() {
        dwellTimer?.invalidate()
        dwellTimer = nil
        pendingCandidate = nil
        visibleCandidate = nil
        needsDisplay = true
    }
}
