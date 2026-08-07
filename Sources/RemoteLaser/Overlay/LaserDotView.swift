import AppKit
import QuartzCore

final class LaserDotView: NSView {
    private var dotLayer: CALayer!

    var dotRadius: CGFloat = 10
    var dotColor: NSColor = .systemRed

    // Trail: a ring buffer of stamps (position + birth time). Stamps stay at
    // their original position and fade based on age; the dot leads and the
    // stamps persist independently. Lets you "circle things" — the ink stays
    // and fades out over `trailFade` seconds.
    private struct Stamp {
        var position: CGPoint
        var birth: TimeInterval
    }
    private var stamps: [Stamp] = []
    private var trailLayers: [CALayer] = []
    private var trailLength: Int = 0
    private var trailFade: TimeInterval = 2.0
    private var pushCounter: UInt64 = 0
    private var lastLoggedStamp: UInt64 = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        wantsLayer = true
        layer = CALayer()
        layer?.isOpaque = false
        layer?.backgroundColor = .clear

        dotLayer = CALayer()
        dotLayer.isOpaque = false
        dotLayer.cornerRadius = dotRadius
        dotLayer.backgroundColor = dotColor.cgColor
        dotLayer.position = CGPoint(x: NSMidX(bounds), y: NSMidY(bounds))
        layer?.addSublayer(dotLayer)
    }

    override func layout() {
        super.layout()
        dotLayer.bounds = CGRect(x: 0, y: 0, width: dotRadius * 2, height: dotRadius * 2)
        dotLayer.cornerRadius = dotRadius
        dotLayer.position = CGPoint(x: NSMidX(bounds), y: NSMidY(bounds))
    }

    func setDotColor(_ color: NSColor) {
        dotColor = color
        dotLayer.backgroundColor = color.cgColor
        for tl in trailLayers { tl.backgroundColor = color.cgColor }
    }

    func setDotRadius(_ radius: CGFloat) {
        dotRadius = radius
        layout()
    }

    /// Configure the persistent stamp trail.
    /// - Parameters:
    ///   - length: max number of stamps kept in memory (0 disables the trail).
    ///   - fade: seconds for a stamp to fade from full to invisible (0 = never fade).
    func setTrail(length: Int, fade: TimeInterval) {
        let length = max(0, min(length, 500))
        if length == trailLength && fade == trailFade { return }
        trailLength = length
        trailFade = max(0, fade)

        // Tear down existing
        for tl in trailLayers { tl.removeFromSuperlayer() }
        trailLayers.removeAll()
        stamps.removeAll()

        guard length > 0 else { return }

        // Build a pool of `length` sublayers, inserted below the main dot.
        for _ in 0..<length {
            let tl = CALayer()
            tl.isOpaque = false
            tl.cornerRadius = dotRadius
            tl.backgroundColor = dotColor.cgColor
            tl.opacity = 0
            tl.bounds = CGRect(x: 0, y: 0, width: dotRadius * 2, height: dotRadius * 2)
            layer?.insertSublayer(tl, below: dotLayer)
            trailLayers.append(tl)
        }
    }

    /// Snap the dot to a point with no animation, then push a new stamp into the
    /// buffer at that position. Called once per 60Hz tick by the EventProcessor.
    func setPositionImmediate(_ point: CGPoint) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        dotLayer.position = point
        if trailLength > 0 { stamp(at: point) }
        CATransaction.commit()
        #if DEBUG
        print("[LaserDotView] snap point=\(point) radius=\(dotRadius) trail=\(trailLength) stamps=\(stamps.count)")
        #endif
    }

    /// Re-render existing stamps based on their current age only — do NOT push
    /// a new stamp. Called by the 60Hz pump when the dot is hidden so the ink
    /// keeps fading on screen after the dot has gone.
    func updateTrailFadesOnly() {
        guard trailLength > 0, !stamps.isEmpty else { return }
        renderTrail(now: ProcessInfo.processInfo.systemUptime)
    }

    /// Wipe the stamp buffer immediately (hides all ink). Call on hide, or when
    /// the dot re-appears after being hidden, so a fresh session doesn't show
    /// a stray line from the previous session's last position.
    func clearTrail() {
        stamps.removeAll()
        for tl in trailLayers { tl.opacity = 0 }
        #if DEBUG
        print("[LaserDotView] clearTrail — stamps wiped")
        #endif
    }

    private func stamp(at point: CGPoint) {
        let now = ProcessInfo.processInfo.systemUptime
        stamps.append(Stamp(position: point, birth: now))
        pushCounter &+= 1

        // Drop expired (faded) stamps. If fade == 0, never drop by age.
        if trailFade > 0 {
            let cutoff = now - trailFade
            while let first = stamps.first, first.birth < cutoff {
                stamps.removeFirst()
            }
        }
        // Cap by buffer length.
        while stamps.count > trailLength {
            stamps.removeFirst()
        }

        renderTrail(now: now)

        if pushCounter &- lastLoggedStamp >= 60 {
            lastLoggedStamp = pushCounter
            #if DEBUG
            print("[LaserDotView] stamp #\(pushCounter) live=\(stamps.count)/\(trailLength) fade=\(trailFade)s")
            #endif
        }
    }

    private func renderTrail(now: TimeInterval) {
        let n = stamps.count
        for i in 0..<trailLayers.count {
            let tl = trailLayers[i]
            if i >= n {
                tl.opacity = 0
                continue
            }
            let s = stamps[i]
            let age = now - s.birth
            let t = trailFade > 0 ? min(max(age / trailFade, 0), 1) : 0
            // Smoothstep-ish fade: hold near full then ease out near the end.
            let opacity = 0.85 * (1.0 - t * t)
            let radius = dotRadius * (1.0 - 0.5 * t)
            tl.position = s.position
            tl.bounds = CGRect(x: 0, y: 0, width: radius * 2, height: radius * 2)
            tl.cornerRadius = radius
            tl.opacity = Float(opacity)
        }
    }
}