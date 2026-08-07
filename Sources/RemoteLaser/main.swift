import AppKit
import Foundation

// Force unbuffered stdout so diagnostic prints flush immediately.
setvbuf(stdout, nil, _IONBF, 0)

let options = Options.parse(CommandLine.arguments)

if options.help {
    print(Options.usage)
    exit(0)
}

let application = NSApplication.shared
let delegate = AppDelegate(port: options.port,
                           smooth: options.smooth,
                           sensitivity: options.sensitivity,
                           dotSize: options.dotSize,
                           autoHide: options.autoHide,
                           trailLength: options.trailLength,
                           trailFade: options.trailFade,
                           allowedIPs: options.allowedIPs)
application.delegate = delegate
application.setActivationPolicy(.accessory)

// Route SIGINT (Ctrl+C) and SIGTERM to a clean NSApp.terminate() so
// applicationWillTerminate → server.stop() runs before exit. Without this,
// the default signal disposition terminates the process abruptly.
let sigintSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
let sigtermSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
signal(SIGINT, SIG_IGN)
signal(SIGTERM, SIG_IGN)
sigintSource.setEventHandler {
    print("\n[RemoteLaser] SIGINT received — shutting down…")
    application.terminate(nil)
}
sigtermSource.setEventHandler {
    print("\n[RemoteLaser] SIGTERM received — shutting down…")
    application.terminate(nil)
}
sigintSource.resume()
sigtermSource.resume()

application.run()