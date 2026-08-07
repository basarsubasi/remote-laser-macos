import AppKit
import QuartzCore

final class LaserDotView: NSView {
    private var glowLayer: CAGradientLayer!
    private var dotLayer: CALayer!

    var dotRadius: CGFloat = 10
    var glowRadius: CGFloat = 44
    var dotColor: NSColor = .systemRed
    var glowColor: NSColor = .systemRed

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

        glowLayer = CAGradientLayer()
        glowLayer.type = .radial
        glowLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        glowLayer.endPoint = CGPoint(x: 1, y: 1)
        glowLayer.isOpaque = false
        glowLayer.opacity = 0.7
        glowLayer.masksToBounds = false
        glowLayer.position = CGPoint(x: NSMidX(bounds), y: NSMidY(bounds))
        layer?.addSublayer(glowLayer)

        dotLayer = CALayer()
        dotLayer.isOpaque = false
        dotLayer.cornerRadius = dotRadius
        dotLayer.backgroundColor = dotColor.cgColor
        dotLayer.position = CGPoint(x: NSMidX(bounds), y: NSMidY(bounds))
        layer?.addSublayer(dotLayer)

        applyColors()
    }

    override func layout() {
        super.layout()
        let center = CGPoint(x: NSMidX(bounds), y: NSMidY(bounds))
        glowLayer.bounds = CGRect(x: 0, y: 0, width: glowRadius * 2, height: glowRadius * 2)
        glowLayer.position = center
        dotLayer.bounds = CGRect(x: 0, y: 0, width: dotRadius * 2, height: dotRadius * 2)
        dotLayer.position = center
    }

    func setDotColor(_ color: NSColor) {
        dotColor = color
        dotLayer.backgroundColor = color.cgColor
    }

    func setGlowColor(_ color: NSColor) {
        glowColor = color
        applyColors()
    }

func moveTo(_ point: CGPoint, duration: Double = 0.12) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(controlPoints: 0.3, 0.0, 0.2, 1.0))
        glowLayer.position = point
        dotLayer.position = point
        CATransaction.commit()
        #if DEBUG
        print("[LaserDotView] moveTo point=\(point) duration=\(duration) isHidden=\(isHidden) bounds=\(bounds) dotBounds=\(dotLayer.bounds) glowBounds=\(glowLayer.bounds) dotColor=\(dotLayer.backgroundColor ?? CGColor(gray: 0, alpha: 0))")
        #endif
    }

    private func applyColors() {
        let opaque = glowColor.cgColor
        let clear = glowColor.cgColor.copy(alpha: 0)!
        glowLayer.colors = [opaque, clear]
    }
}