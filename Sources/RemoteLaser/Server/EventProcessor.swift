import AppKit

@MainActor
final class EventProcessor: @unchecked Sendable {
    private let overlay: LaserOverlayController
    private var hideWorkItem: DispatchWorkItem?
    private let hideDelay: TimeInterval
    private let smooth: Double
    private let sensitivity: Double
    private let dotSize: CGFloat

    // 60Hz pump
    private var displayTimer: DispatchSourceTimer?
    private var currentPoint: CGPoint?
    private var targetPoint: CGPoint?
    private var lastFrameIndex: UInt64 = 0
    private var lastLoggedFrame: UInt64 = 0

    init(overlay: LaserOverlayController,
         smooth: Double = 0.2,
         sensitivity: Double = 1.0,
         dotSize: Double = 10,
         autoHide: Double = 1.0) {
        self.overlay = overlay
        self.smooth = smooth
        self.sensitivity = sensitivity
        self.dotSize = CGFloat(dotSize)
        self.hideDelay = max(0, autoHide)
    }

    func startDisplayLink() {
        guard displayTimer == nil else { return }
        overlay.dotView?.setDotRadius(dotSize)
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: 1.0 / 60.0)
        timer.setEventHandler { [weak self] in self?.tick() }
        timer.resume()
        displayTimer = timer
        #if DEBUG
        print("[EventProcessor] 60Hz pump started (smooth=\(smooth), dotSize=\(dotSize))")
        #endif
    }

    private func tick() {
        lastFrameIndex &+= 1
        guard let dot = overlay.dotView, !dot.isHidden, let cur = currentPoint, let tgt = targetPoint else {
            return
        }
        let alpha = CGFloat(smooth)
        let next = CGPoint(
            x: cur.x + (tgt.x - cur.x) * alpha,
            y: cur.y + (tgt.y - cur.y) * alpha
        )
        currentPoint = next
        dot.setPositionImmediate(next)
        if lastFrameIndex &- lastLoggedFrame >= 60 {
            lastLoggedFrame = lastFrameIndex
            #if DEBUG
            print("[EventProcessor] 60Hz tick #\(lastFrameIndex) cur=\(next) tgt=\(tgt)")
            #endif
        }
    }

    func apply(_ event: LaserEvent) {
        #if DEBUG
        print("[EventProcessor] received: type=\(event.type) x=\(event.x ?? -1) y=\(event.y ?? -1)")
        #endif
        switch event.type {
        case .move:
            guard let x = event.x, let y = event.y else {
                #if DEBUG
                print("[EventProcessor] move event missing x/y, skipping")
                #endif
                return
            }
            overlay.reveal()
            let point = overlay.pointFor(normalizedX: x, normalizedY: y, sensitivity: sensitivity)
            targetPoint = point
            if currentPoint == nil {
                currentPoint = point
                #if DEBUG
                print("[EventProcessor] initialized currentPoint=\(point)")
                #endif
            }
            scheduleAutoHide()
        case .down, .up:
            // Reserved for phase 2
            break
        case .hide:
            overlay.hide()
            currentPoint = nil
            targetPoint = nil
        }
    }

    func reset() {
        overlay.hide()
        hideWorkItem?.cancel()
        hideWorkItem = nil
        currentPoint = nil
        targetPoint = nil
    }

    private func scheduleAutoHide() {
        hideWorkItem?.cancel()
        guard hideDelay > 0 else { return } // --auto-hide 0 = stay visible forever
        let item = DispatchWorkItem { [weak self] in
            self?.overlay.hide()
            self?.currentPoint = nil
            self?.targetPoint = nil
            #if DEBUG
            print("[EventProcessor] auto-hide fired after \(self?.hideDelay ?? 0)s")
            #endif
        }
        hideWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + hideDelay, execute: item)
    }
}