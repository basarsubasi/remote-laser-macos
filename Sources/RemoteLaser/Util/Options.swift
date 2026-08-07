import Foundation

struct Options {
    var port: Int = 8080
    var speed: Double = 0.12
    var sensitivity: Double = 1.0
    var help: Bool = false

    static let usage = """
    Usage: RemoteLaser [--port <1-65535>] [--speed <0-2>] [--sensitivity <0.1-10>] [-h|--help]

    Options:
      --port <n>           WebSocket server port (default: 8080)
      --speed <sec>        Dot slide animation duration in seconds (default: 0.12).
                          0 = instant (no slide), higher = smoother/slower slide.
      --sensitivity <n>    Input gain around screen center (default: 1.0).
                          >1 amplifies finger movement (dot covers more distance),
                          <1 dampens it (dot moves less per finger drag).
      -h, --help           Show this message and exit
    """

    static func parse(_ args: [String]) -> Options {
        var opts = Options()
        var i = 1
        while i < args.count {
            let arg = args[i]
            switch arg {
            case "-h", "--help":
                opts.help = true
                i += 1
            case "--port":
                guard i + 1 < args.count, let value = Int(args[i + 1]) else {
                    fail("--port requires a numeric value")
                }
                opts.port = validatePort(value)
                i += 2
            case "--speed":
                guard i + 1 < args.count, let value = Double(args[i + 1]) else {
                    fail("--speed requires a numeric value")
                }
                opts.speed = validateSpeed(value)
                i += 2
            case "--sensitivity":
                guard i + 1 < args.count, let value = Double(args[i + 1]) else {
                    fail("--sensitivity requires a numeric value")
                }
                opts.sensitivity = validateSensitivity(value)
                i += 2
            default:
                if arg.hasPrefix("--port=") {
                    let value = String(arg.dropFirst("--port=".count))
                    guard let n = Int(value) else { fail("--port requires a numeric value") }
                    opts.port = validatePort(n)
                    i += 1
                } else if arg.hasPrefix("--speed=") {
                    let value = String(arg.dropFirst("--speed=".count))
                    guard let n = Double(value) else { fail("--speed requires a numeric value") }
                    opts.speed = validateSpeed(n)
                    i += 1
                } else if arg.hasPrefix("--sensitivity=") {
                    let value = String(arg.dropFirst("--sensitivity=".count))
                    guard let n = Double(value) else { fail("--sensitivity requires a numeric value") }
                    opts.sensitivity = validateSensitivity(n)
                    i += 1
                } else {
                    fail("Unknown argument: \(arg)")
                }
            }
        }
        return opts
    }

    private static func validatePort(_ value: Int) -> Int {
        guard (1...65_535).contains(value) else {
            fail("--port must be between 1 and 65535")
        }
        return value
    }

    private static func validateSpeed(_ value: Double) -> Double {
        guard (0...2).contains(value) else {
            fail("--speed must be between 0 and 2 seconds")
        }
        return value
    }

    private static func validateSensitivity(_ value: Double) -> Double {
        guard (0.1...10).contains(value) else {
            fail("--sensitivity must be between 0.1 and 10")
        }
        return value
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("RemoteLaser: \(message)\n".utf8))
        FileHandle.standardError.write(Data((usage + "\n").utf8))
        exit(1)
    }
}