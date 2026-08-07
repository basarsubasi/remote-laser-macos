import AppKit
import Darwin

final class AppDelegate: NSObject, NSApplicationDelegate {

    private let port: Int
    private let smooth: Double
    private let sensitivity: Double
    private let dotSize: Double
    private let autoHide: Double
    private let trailLength: Int
    private var statusItem: NSStatusItem?
    private var overlay: LaserOverlayController!
    private var processor: EventProcessor!
    private var server: LaserServer!

    init(port: Int = 8080,
         smooth: Double = 0.2,
         sensitivity: Double = 1.0,
         dotSize: Double = 10,
         autoHide: Double = 1.0,
         trailLength: Int = 0) {
        self.port = port
        self.smooth = smooth
        self.sensitivity = sensitivity
        self.dotSize = dotSize
        self.autoHide = autoHide
        self.trailLength = trailLength
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        overlay = LaserOverlayController()
        overlay.install()
        processor = EventProcessor(overlay: overlay,
                                   smooth: smooth,
                                   sensitivity: sensitivity,
                                   dotSize: dotSize,
                                   autoHide: autoHide,
                                   trailLength: trailLength)
        processor.startDisplayLink()

        let processor = self.processor!
        let server = LaserServer(port: port) { event in
            Task { @MainActor in
                processor.apply(event)
            }
        }
        server.start()
        self.server = server

        showDiagnosticDot()
        setupStatusItem()
        print("RemoteLaser listening on ws://0.0.0.0:\(port)/laser")
        print("LAN IP hint: \(primaryLANIP() ?? "<unknown>")")
    }

    func applicationWillTerminate(_ notification: Notification) {
        print("[RemoteLaser] terminating — stopping server…")
        server?.stop()
        print("[RemoteLaser] bye.")
    }

    private func showDiagnosticDot() {
        guard let dv = overlay.dotView else {
            print("[Diagnostic] dotView is nil!" )
            return
        }
        let saveRadius = dv.dotRadius
        let radius = max(20, saveRadius * 2)
        dv.setDotRadius(radius)
        dv.layout()
        let center = CGPoint(x: NSMidX(dv.bounds), y: NSMidY(dv.bounds))
        print("[Diagnostic] *** Showing BIG test dot at screen CENTER \(center) for 5 seconds ***")
        print("[Diagnostic] bounds=\(dv.bounds) temporarilyRadius=\(radius) (configured \(saveRadius))")
        dv.isHidden = false
        dv.setPositionImmediate(center)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.overlay.hide()
            dv.setDotRadius(saveRadius)
            print("[Diagnostic] test dot hidden, reverted radius to \(saveRadius)")
        }
    }

    // MARK: - Menu bar

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = statusIcon()
        }
        item.menu = buildMenu()
        statusItem = item
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(makeInfo("RemoteLaser"))
        menu.addItem(.separator())
        menu.addItem(makeInfo("Status: Running (port \(port))"))
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        return menu
    }

    private func makeInfo(_ text: String) -> NSMenuItem {
        let item = NSMenuItem(title: text, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Helpers

    private func statusIcon() -> NSImage? {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.systemRed.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 4, dy: 4)).fill()
            return true
        }
        image.isTemplate = false
        return image
    }

    private func primaryLANIP() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }
        var pointer: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let cur = pointer {
            let iface = cur.pointee
            let addrPtr = iface.ifa_addr
            if let addrPtr = addrPtr, addrPtr.pointee.sa_family == UInt8(AF_INET) {
                let interfaceName = String(cString: iface.ifa_name)
                if interfaceName.hasPrefix("en") || interfaceName.hasPrefix("wlan") {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(
                        addrPtr, socklen_t(addrPtr.pointee.sa_len),
                        &hostname, socklen_t(hostname.count),
                        nil, 0, NI_NUMERICHOST
                    )
                    let ip = String(cString: hostname)
                    if !ip.hasPrefix("127.") {
                        address = ip
                        break
                    }
                }
            }
            pointer = iface.ifa_next
        }
        return address
    }
}