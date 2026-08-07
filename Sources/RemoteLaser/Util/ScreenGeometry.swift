import Foundation
import AppKit

enum ScreenGeometry {
    static func mainVisibleFrame() -> CGRect {
        NSScreen.main?.visibleFrame ?? .zero
    }

    static func mainFrame() -> CGRect {
        NSScreen.main?.frame ?? .zero
    }
}