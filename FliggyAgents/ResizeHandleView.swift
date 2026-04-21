import AppKit

enum ResizeEdge {
    case left
    case right
    case top
    case bottom
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}

final class ResizeHandleView: NSView {
    let edge: ResizeEdge
    var onDrag: ((ResizeEdge, CGFloat, CGFloat) -> Void)?
    var onDragStart: ((ResizeEdge) -> Void)?
    var onDragEnd: ((ResizeEdge) -> Void)?
    private var dragStartScreenPoint: NSPoint?

    init(frame frameRect: NSRect, edge: ResizeEdge) {
        self.edge = edge
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func resetCursorRects() {
        discardCursorRects()
        let cursor: NSCursor
        switch edge {
        case .left, .right:
            cursor = .resizeLeftRight
        case .top, .bottom:
            cursor = .resizeUpDown
        case .topLeft, .bottomRight, .topRight, .bottomLeft:
            cursor = .crosshair
        }
        addCursorRect(bounds, cursor: cursor)
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        dragStartScreenPoint = window.convertPoint(toScreen: event.locationInWindow)
        onDragStart?(edge)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window, let dragStartScreenPoint else { return }
        let current = window.convertPoint(toScreen: event.locationInWindow)
        onDrag?(edge, current.x - dragStartScreenPoint.x, current.y - dragStartScreenPoint.y)
    }

    override func mouseUp(with event: NSEvent) {
        dragStartScreenPoint = nil
        onDragEnd?(edge)
    }
}
