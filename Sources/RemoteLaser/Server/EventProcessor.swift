import AppKit

@MainActor
final class EventProcessor: @unchecked Sendable {
    private let overlay: LaserOverlayController
    private var hideWorkItem: DispatchWorkItem?
    private let hideDelay: TimeInterval = 4
    private let speed: Double
    private let sensitivity: Double

    init(overlay: LaserOverlayController, speed: Double = 0.12, sensitivity: Double = 1.0) {
        self.overlay = overlay
        self.speed = speed
        self.sensitivity = sensitivity
    }

    func apply(_ event: LaserEvent) {
        switch event.type {
        case .move:
            guard let x = event.x, let y = event.y else { return }
            overlay.reveal()
            let point = overlay.pointFor(normalizedX: x, normalizedY: y, sensitivity: sensitivity)
            overlay.dotView?.moveTo(point, duration: speed)
            scheduleAutoHide()
        case .down, .up:
            // Reserved for phase 2 (toggle / click semantics)
            break
        case .hide:
            overlay.hide()
        }
    }

    func reset() {
        overlay.hide()
        hideWorkItem?.cancel()
        hideWorkItem = nil
    }

    private func scheduleAutoHide() {
        hideWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.overlay.hide()
        }
        hideWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + hideDelay, execute: item)
    }
}