import AppKit

final class LaserOverlayController {
    private var window: NSWindow?
    private(set) var dotView: LaserDotView?
    private(set) var frame: CGRect = .zero

    func install() {
        guard window == nil else { return }
        layout()

        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false

        let dot = LaserDotView(frame: panel.contentView?.bounds ?? .zero)
        dot.autoresizingMask = [.width, .height]
        panel.contentView = dot
        dot.isHidden = true

        panel.orderFrontRegardless()
        self.window = panel
        self.dotView = dot
        #if DEBUG
        print("[Overlay] install frame=\(frame) windowFrame=\(panel.frame) dotBounds=\(dot.bounds) windowLevel=\(panel.level.rawValue) isVisible=\(panel.isVisible)")
        #endif

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.relayout()
        }
    }

    func reveal() {
        #if DEBUG
        print("[Overlay] reveal called, dotView exists=\(dotView != nil), window visible=\(window?.isVisible ?? false)")
        #endif
        dotView?.isHidden = false
    }

    func hide() {
        #if DEBUG
        print("[Overlay] hide called")
        #endif
        dotView?.isHidden = true
    }

    private func layout() {
        frame = ScreenGeometry.mainVisibleFrame()
    }

    func relayout() {
        layout()
        window?.setFrame(frame, display: true)
    }

    func pointFor(normalizedX x: Double, normalizedY y: Double, sensitivity: Double = 1.0) -> CGPoint {
        let sx = min(max(0.5 + (x - 0.5) * sensitivity, 0), 1)
        let sy = min(max(0.5 + (y - 0.5) * sensitivity, 0), 1)
        let point = CGPoint(
            x: CGFloat(sx) * frame.width,
            y: (1 - CGFloat(sy)) * frame.height
        )
        #if DEBUG
        print("[Overlay] pointFor input=(\(x), \(y)) sens=\(sensitivity) mapped=(\(sx), \(sy)) point=\(point) frame=\(frame)")
        #endif
        return point
    }
}