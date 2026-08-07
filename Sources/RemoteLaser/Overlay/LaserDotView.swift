import AppKit
import QuartzCore

final class LaserDotView: NSView {
    private var dotLayer: CALayer!

    var dotRadius: CGFloat = 10
    var dotColor: NSColor = .systemRed

    // Trail
    private var trailLayers: [CALayer] = []
    private var posBuffer: [CGPoint] = []
    private var bufferCount = 0
    private var bufferHead = 0      // index of newest sample
    private var trailLength: Int = 0

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

    /// Configure the trailing tail. `length` = number of fading segments behind the dot.
    /// 0 disables the trail (removes all trail sublayers).
    func setTrailLength(_ length: Int) {
        let length = max(0, min(length, 200))
        if length == trailLength { return }
        trailLength = length

        // Tear down existing
        for tl in trailLayers { tl.removeFromSuperlayer() }
        trailLayers.removeAll()
        posBuffer.removeAll()
        bufferCount = 0
        bufferHead = 0

        guard length > 0 else { return }

        // Build trail sublayers, inserted below the main dot so the dot leads.
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

        // Ring buffer holds the most recent (length + 1) positions.
        let cap = length + 1
        posBuffer.reserveCapacity(cap)
        for _ in 0..<cap { posBuffer.append(.zero) }
        bufferCount = 0
        bufferHead = 0
    }

    /// Snap directly to a point with no animation. Also pushes the point into
    /// the trail ring buffer and updates every trail segment so the tail follows
    /// the dot with a one-tick-per-segment stagger and a fade+width taper.
    func setPositionImmediate(_ point: CGPoint) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        dotLayer.position = point
        if trailLength > 0 { updateTrail(at: point) }
        CATransaction.commit()
        #if DEBUG
        print("[LaserDotView] snap point=\(point) isHidden=\(isHidden) radius=\(dotRadius) trailLen=\(trailLength)")
        #endif
    }

    /// Wipe the trail buffer (call on hide / fresh re-appearance so the tail
    /// doesn't draw a stray line across the screen from the old location).
    func clearTrail() {
        bufferCount = 0
        bufferHead = 0
        for tl in trailLayers { tl.opacity = 0 }
    }

    private func updateTrail(at point: CGPoint) {
        let cap = posBuffer.count
        guard cap > 0 else { return }

        // Push the new sample into the ring buffer.
        if bufferCount < cap {
            // fill phase: append straight after head
            posBuffer[bufferHead] = point
            bufferHead = (bufferHead + 1) % cap
            bufferCount += 1
        } else {
            posBuffer[bufferHead] = point
            bufferHead = (bufferHead + 1) % cap
        }

        // Walk trail segments from newest-oldest-nearest to oldest-farthest.
        // Segment i shows the sample (i+1) ticks ago.
        let n = trailLayers.count
        for i in 0..<n {
            // index into ring buffer: (head - 1 - i) mod cap gives (i+1)-th newest
            let idx = ((bufferHead - 1 - i - 1) % cap + cap) % cap
            let p = posBuffer[idx]
            // Distance from head: i+1 = recent; close samples get bigger, more opaque.
            let t = CGFloat(i) / CGFloat(max(n, 1))   // 0 (near dot) → 1 (tail tip)
            let r = dotRadius * (1.0 - 0.75 * t)      // taper width to 25% at the tip
            let layer = trailLayers[i]
            layer.position = p
            layer.bounds = CGRect(x: 0, y: 0, width: r * 2, height: r * 2)
            layer.cornerRadius = r
            layer.opacity = Float(0.7 * (1.0 - t))
        }
    }
}