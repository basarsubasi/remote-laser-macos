import AppKit
import QuartzCore

final class LaserDotView: NSView {
    private var dotLayer: CALayer!

    var dotRadius: CGFloat = 10
    var dotColor: NSColor = .systemRed

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
    }

    func setDotRadius(_ radius: CGFloat) {
        dotRadius = radius
        layout()
    }

    /// Snap directly to a point with no animation (used by the 60Hz interpolator
    /// which drives position itself every frame).
    func setPositionImmediate(_ point: CGPoint) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        dotLayer.position = point
        CATransaction.commit()
        #if DEBUG
        print("[LaserDotView] snap point=\(point) isHidden=\(isHidden) bounds=\(dotLayer.bounds) radius=\(dotRadius)")
        #endif
    }
}