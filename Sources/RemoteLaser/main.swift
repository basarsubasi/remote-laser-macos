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
let delegate = AppDelegate(port: options.port, speed: options.speed, sensitivity: options.sensitivity)
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()