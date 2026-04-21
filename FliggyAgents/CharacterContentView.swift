import AppKit

class KeyableWindow: NSWindow {
    var fileDropHandler: (([URL]) -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func draggedFileURLs(from sender: NSDraggingInfo) -> [URL] {
        let classes: [AnyClass] = [NSURL.self]
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]
        let objects = sender.draggingPasteboard.readObjects(forClasses: classes, options: options) as? [URL]
        return (objects ?? []).filter { $0.isFileURL }
    }

    func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        draggedFileURLs(from: sender).isEmpty ? [] : .copy
    }

    func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        draggedFileURLs(from: sender).isEmpty ? [] : .copy
    }

    func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        !draggedFileURLs(from: sender).isEmpty
    }

    func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = draggedFileURLs(from: sender)
        guard !urls.isEmpty else { return false }
        fileDropHandler?(urls)
        return true
    }
}

class CharacterContentView: NSView {
    weak var character: WalkerCharacter?
    private static let hoverExitGracePeriod: CFTimeInterval = 0.12
    private static let characterHoverEnabled = false
    private var isFileDropTargeted = false {
        didSet { updateDropAppearance() }
    }
    private var hoverTrackingArea: NSTrackingArea?
    private var isHoveringInteractiveContent = false
    private var pendingHoverExitDeadline: CFTimeInterval?
    private var hoverExitWorkItem: DispatchWorkItem?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
            self.hoverTrackingArea = nil
        }
        guard Self.characterHoverEnabled else {
            cancelPendingHoverExit()
            pendingHoverExitDeadline = nil
            setHoverState(false)
            return
        }
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .mouseMoved, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        hoverTrackingArea = trackingArea
    }

    private func updateDropAppearance() {
        wantsLayer = true
        layer?.cornerRadius = 24
        layer?.borderWidth = isFileDropTargeted ? 3 : 0
        layer?.borderColor = NSColor.systemBlue.withAlphaComponent(0.9).cgColor
        layer?.backgroundColor = isFileDropTargeted
            ? NSColor.systemBlue.withAlphaComponent(0.12).cgColor
            : NSColor.clear.cgColor
        layer?.shadowColor = NSColor.systemBlue.cgColor
        layer?.shadowOpacity = isFileDropTargeted ? 0.28 : 0
        layer?.shadowRadius = isFileDropTargeted ? 18 : 0
    }

    private func draggedFileURLs(from sender: NSDraggingInfo) -> [URL] {
        let classes: [AnyClass] = [NSURL.self]
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]
        let objects = sender.draggingPasteboard.readObjects(forClasses: classes, options: options) as? [URL]
        return (objects ?? []).filter { $0.isFileURL }
    }

    func isMouseOverInteractiveContent() -> Bool {
        guard Self.characterHoverEnabled else { return false }
        guard let window else { return false }
        let windowPoint = convert(window.mouseLocationOutsideOfEventStream, from: nil)
        return isInteractivePoint(windowPoint)
    }

    private func setHoverState(_ isHovering: Bool) {
        guard isHoveringInteractiveContent != isHovering else { return }
        isHoveringInteractiveContent = isHovering
        character?.setHoveringCharacter(isHovering)
    }

    private func syncHoverState(withWindowPoint point: NSPoint, forceExit: Bool = false) {
        guard Self.characterHoverEnabled else {
            cancelPendingHoverExit()
            pendingHoverExitDeadline = nil
            setHoverState(false)
            return
        }
        let localPoint = convert(point, from: nil)
        applyHoverResolution(
            wantsHover: isInteractivePoint(localPoint),
            forceExit: forceExit
        )
    }

    private func fallbackInteractiveRect() -> NSRect {
        CharacterHoverHitTesting.fallbackInteractiveRect(for: bounds)
    }

    private func sampleInteractivePixel(at point: NSPoint) -> Bool {
        let screenPoint = window?.convertPoint(toScreen: convert(point, to: nil)) ?? .zero
        guard let primaryScreen = NSScreen.screens.first else { return false }
        let flippedY = primaryScreen.frame.height - screenPoint.y

        let captureRect = CGRect(x: screenPoint.x - 0.5, y: flippedY - 0.5, width: 1, height: 1)
        guard let windowID = window?.windowNumber, windowID > 0 else { return false }

        if let image = CGWindowListCreateImage(
            captureRect,
            .optionIncludingWindow,
            CGWindowID(windowID),
            [.boundsIgnoreFraming, .bestResolution]
        ) {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            var pixel: [UInt8] = [0, 0, 0, 0]
            if let ctx = CGContext(
                data: &pixel, width: 1, height: 1,
                bitsPerComponent: 8, bytesPerRow: 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) {
                ctx.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
                return pixel[3] > 30
            }
        }

        return false
    }

    private func isInteractivePoint(_ point: NSPoint) -> Bool {
        CharacterHoverHitTesting.isInteractive(
            point: point,
            bounds: bounds,
            sampledOpaquePixel: sampleInteractivePixel(at: point)
        )
    }

    private func applyHoverResolution(
        wantsHover: Bool,
        forceExit: Bool = false,
        now: CFTimeInterval = CACurrentMediaTime()
    ) {
        let resolution = CharacterHoverStability.resolve(
            isHovering: isHoveringInteractiveContent,
            wantsHover: wantsHover,
            pendingExitDeadline: pendingHoverExitDeadline,
            now: now,
            exitGracePeriod: Self.hoverExitGracePeriod,
            forceExit: forceExit
        )

        if resolution.pendingExitDeadline != pendingHoverExitDeadline {
            if let deadline = resolution.pendingExitDeadline {
                scheduleHoverExitCheck(deadline: deadline)
            } else {
                cancelPendingHoverExit()
            }
        }

        pendingHoverExitDeadline = resolution.pendingExitDeadline
        setHoverState(resolution.isHovering)
    }

    private func scheduleHoverExitCheck(deadline: CFTimeInterval) {
        cancelPendingHoverExit()

        let delay = max(0, deadline - CACurrentMediaTime())
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.hoverExitWorkItem = nil
            let wantsHover = self.isMouseOverInteractiveContent()
            self.applyHoverResolution(wantsHover: wantsHover)
        }

        hoverExitWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func cancelPendingHoverExit() {
        hoverExitWorkItem?.cancel()
        hoverExitWorkItem = nil
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let localPoint = convert(point, from: superview)
        return isInteractivePoint(localPoint) ? self : nil
    }

    override func mouseEntered(with event: NSEvent) {
        syncHoverState(withWindowPoint: event.locationInWindow)
        super.mouseEntered(with: event)
    }

    override func mouseMoved(with event: NSEvent) {
        syncHoverState(withWindowPoint: event.locationInWindow)
        super.mouseMoved(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        cancelPendingHoverExit()
        pendingHoverExitDeadline = nil
        setHoverState(false)
        super.mouseExited(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        cancelPendingHoverExit()
        pendingHoverExitDeadline = nil
        setHoverState(false)
        if let window {
            let screenPoint = window.convertPoint(toScreen: event.locationInWindow)
            character?.beginDrag(screenPoint: screenPoint)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        cancelPendingHoverExit()
        pendingHoverExitDeadline = nil
        setHoverState(false)
        guard let window else { return }
        let screenPoint = window.convertPoint(toScreen: event.locationInWindow)
        character?.updateDrag(screenPoint: screenPoint)
    }

    override func mouseUp(with event: NSEvent) {
        character?.endDrag()
        syncHoverState(withWindowPoint: event.locationInWindow)
        character?.handleClick()
    }

    override func rightMouseUp(with event: NSEvent) {
        syncHoverState(withWindowPoint: event.locationInWindow)
        character?.handleSecondaryClick()
    }

    override func otherMouseUp(with event: NSEvent) {
        guard event.buttonNumber == 2 else {
            super.otherMouseUp(with: event)
            return
        }
        syncHoverState(withWindowPoint: event.locationInWindow)
        character?.handleSecondaryClick()
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let urls = draggedFileURLs(from: sender)
        guard !urls.isEmpty else { return [] }
        isFileDropTargeted = true
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let urls = draggedFileURLs(from: sender)
        isFileDropTargeted = !urls.isEmpty
        return urls.isEmpty ? [] : .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        isFileDropTargeted = false
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        !draggedFileURLs(from: sender).isEmpty
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = draggedFileURLs(from: sender)
        guard !urls.isEmpty else {
            isFileDropTargeted = false
            return false
        }
        character?.handleExternalFileDrop(urls)
        isFileDropTargeted = false
        return true
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        isFileDropTargeted = false
    }
}
