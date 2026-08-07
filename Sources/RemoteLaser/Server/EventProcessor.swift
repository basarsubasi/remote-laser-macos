import AppKit

@MainActor
final class EventProcessor: @unchecked Sendable {
    private let overlay: LaserOverlayController
    private var hideWorkItem: DispatchWorkItem?
    private let hideDelay: TimeInterval
    private let smooth: Double
    private let sensitivity: Double
    private let dotSize: CGFloat
    private let trailLength: Int
    private let trailFade: TimeInterval

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
         autoHide: Double = 1.0,
         trailLength: Int = 0,
         trailFade: Double = 2.0) {
        self.overlay = overlay
        self.smooth = smooth
        self.sensitivity = sensitivity
        self.dotSize = CGFloat(dotSize)
        self.hideDelay = max(0, autoHide)
        self.trailLength = trailLength
        self.trailFade = max(0, trailFade)
    }

    func startDisplayLink() {
        guard displayTimer == nil else { return }
        overlay.dotView?.setDotRadius(dotSize)
        overlay.dotView?.setTrail(length: trailLength, fade: trailFade)
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: 1.0 / 60.0)
        timer.setEventHandler { [weak self] in self?.tick() }
        timer.resume()
        displayTimer = timer
        #if DEBUG
        print("[EventProcessor] 60Hz pump started (smooth=\(smooth), dotSize=\(dotSize), trailLength=\(trailLength), trailFade=\(trailFade)s)")
        #endif
    }

    private func tick() {
        lastFrameIndex &+= 1
        guard let dot = overlay.dotView else { return }
        if !dot.isHidden, let cur = currentPoint, let tgt = targetPoint {
            // Dot visible and following a target — lerp + push a new stamp.
            let alpha = CGFloat(smooth)
            let next = CGPoint(
                x: cur.x + (tgt.x - cur.x) * alpha,
                y: cur.y + (tgt.y - cur.y) * alpha
            )
            currentPoint = next
            dot.setPositionImmediate(next)
        } else if trailLength > 0 {
            // Dot hidden (or no target yet) but ink should keep fading.
            dot.updateTrailFadesOnly()
        }
        if lastFrameIndex &- lastLoggedFrame >= 60 {
            lastLoggedFrame = lastFrameIndex
            #if DEBUG
            print("[EventProcessor] 60Hz tick #\(lastFrameIndex) hidden=\(dot.isHidden) cur=\(String(describing: currentPoint))")
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
                // First move after a hide: snap directly to the new spot (no
                // interpolated line) but DON'T clear the existing ink — the
                // stamps are independent and will continue to fade on their own.
                currentPoint = point
                #if DEBUG
                print("[EventProcessor] initialized currentPoint=\(point) (ink preserved)")
                #endif
            }
            scheduleAutoHide()
        case .down, .up:
            // Reserved for phase 2
            break
        case .hide:
            // Explicit hide from the client: turn off the laser AND clear ink.
            overlay.hide()
            overlay.dotView?.clearTrail()
            currentPoint = nil
            targetPoint = nil
        }
    }

    func reset() {
        overlay.hide()
        overlay.dotView?.clearTrail()
        hideWorkItem?.cancel()
        hideWorkItem = nil
        currentPoint = nil
        targetPoint = nil
    }

    private func scheduleAutoHide() {
        hideWorkItem?.cancel()
        guard hideDelay > 0 else { return } // --auto-hide 0 = stay visible forever
        let item = DispatchWorkItem { [weak self] in
            // Hide the dot only — preserve the ink so the circle a user just
            // drew keeps fading on screen. The 60Hz pump keeps rendering the
            // stamps with their age-based opacity until they expire.
            self?.overlay.hide()
            self?.currentPoint = nil
            self?.targetPoint = nil
            #if DEBUG
            print("[EventProcessor] auto-hide fired after \(self?.hideDelay ?? 0)s (ink preserved, fading)")
            #endif
        }
        hideWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + hideDelay, execute: item)
    }
}